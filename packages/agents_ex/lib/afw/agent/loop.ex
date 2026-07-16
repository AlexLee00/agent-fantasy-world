defmodule AFW.Agent.Loop do
  @moduledoc "Tick execution for Elixir agents using optimistic settlement as the write path."

  alias AFW.Agent.Movement
  alias AFW.Brain.PromptBuilder
  alias AFW.Chain.{Client, Reader}
  alias AFW.Economy.Constants
  alias AFW.Memory.{Reflection, Retriever, Store}
  alias AFW.Settlement.Hub
  alias AFW.Settlement.State, as: SettlementState
  alias AFW.Social.Dialogue
  alias AFW.World.Combat
  alias AFW.World.Event

  @fight_cooldown_ticks 3
  @target_lock_ttl_ms 30_000
  @target_lock_table :targeted_monsters
  @failed_orders_table :failed_orders
  @pending_market_sells_table :pending_market_sells
  @failed_order_ttl_ms 300_000
  @pending_market_sell_ttl_ms 300_000

  def execute_tick(state) do
    snapshot = SettlementState.get_agent_view(state.agent_id)

    base_context = %{
      agent: snapshot.agent,
      zone: snapshot.zone,
      monsters: snapshot.monsters,
      npcs: snapshot.npcs,
      items: snapshot.items,
      orders: snapshot.orders,
      treasury_balance: snapshot.treasury_balance,
      settlement: snapshot.settlement,
      history: Enum.take(state.history || [], -5)
    }

    event = Event.generate(base_context, state.tick_count + 1)

    context =
      Map.put(base_context, :memories, Retriever.relevant_for_context(base_context, event))

    decision =
      case forced_decision(context, state) do
        {:decided, payload} ->
          payload

        :continue ->
          case precomputed_decision(context, event, state) do
            {:decided, payload} ->
              payload

            :continue ->
              prompt = PromptBuilder.build(context, event)

              try do
                case state.brain_module.decide(%{prompt: prompt, context: context, event: event}) do
                  {:ok, payload} -> payload
                  {:error, _reason} -> fallback_decision(context, event)
                end
              rescue
                _ -> fallback_decision(context, event)
              catch
                :exit, _ -> fallback_decision(context, event)
              end
              |> normalize_decision(context, event, state)
          end
      end

    action_name = decision["action"] || decision[:action] || "EXPLORE"

    result =
      case action_name do
        "FIGHT" -> fight(context, event)
        "REST" -> rest(context)
        "TRADE" -> trade(context)
        "TALK" -> talk(context, event)
        "USE_ITEM" -> %{summary: "Used an item from inventory.", status: :alive}
        _ -> explore(context, event)
      end

    # S1 M-3/M-4: tile-based movement along an A* path; region boundary
    # crossings submit a :region_transition settlement event (BATCH).
    movement = Movement.step(state, context, action_name)

    next_cooldown =
      case action_name do
        "FIGHT" -> 2
        "REST" -> 0
        _ when state.post_combat_cooldown > 0 -> max(state.post_combat_cooldown - 1, 0)
        _ -> state.post_combat_cooldown
      end

    history_entry = %{
      tick: state.tick_count + 1,
      action: action_name,
      target: decision["target"] || decision[:target] || "",
      summary: result.summary,
      event: event.type,
      dialogue: dialogue_line(decision, result)
    }

    next_state = %{
      state
      | tick_count: state.tick_count + 1,
        history: (state.history || []) ++ [history_entry],
        last_action: history_entry,
        post_combat_cooldown: next_cooldown,
        consecutive_trades: next_trade_streak(state, action_name),
        pos: movement.pos,
        dest: movement.dest,
        path: movement.path,
        zone_id: if(movement.region > 0, do: movement.region, else: state.zone_id)
    }

    record_memory(next_state.agent_id, history_entry)
    record_dialogue(next_state, history_entry)
    maybe_reflect(next_state.agent_id, next_state.tick_count)
    next_state
  end

  defp forced_decision(context, state) do
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)

    cond do
      state.post_combat_cooldown > 0 and hp < max_hp ->
        {:decided, %{"action" => "REST", "target" => "tavern"}}

      true ->
        :continue
    end
  end

  defp fallback_decision(context, event) do
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)
    hp_ratio = hp / max_hp

    cond do
      hp_ratio <= 0.7 or event.type == :survival ->
        %{"action" => "REST", "target" => "tavern"}

      event.type == :trade ->
        %{"action" => "TRADE", "target" => "marketplace"}

      event.type == :npc ->
        %{"action" => "TALK", "target" => event.target}

      event.type == :monster and hp_ratio > 0.7 ->
        %{"action" => "FIGHT", "target" => event.target}

      true ->
        %{"action" => "EXPLORE", "target" => event.target}
    end
  end

  defp precomputed_decision(context, event, state) do
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)
    hp_ratio = hp / max_hp
    recent = Enum.take(state.history || [], -12)
    total_recent_fights = Enum.count(recent, &(&1.action == "FIGHT"))
    talk_count = Enum.count(Enum.take(recent, -5), &(&1.action == "TALK"))

    cond do
      hp_ratio <= 0.7 ->
        {:decided, %{"action" => "REST", "target" => "tavern"}}

      event.type == :monster and total_recent_fights >= fight_cap(state.class_id) ->
        {:decided, post_fight_fallback(context, event, talk_count)}

      state.consecutive_trades >= 3 ->
        {:decided, %{"action" => "EXPLORE", "target" => "roads beyond #{context.zone["name"]}"}}

      event.type == :monster and state.class_id in [2, 3] and state.tick_count <= 1 ->
        {:decided, %{"action" => "TALK", "target" => event.target || "locals"}}

      event.type == :npc and talk_count >= 2 ->
        {:decided, %{"action" => "EXPLORE", "target" => "roads beyond #{context.zone["name"]}"}}

      true ->
        :continue
    end
  end

  defp normalize_decision(decision, context, event, state) do
    action = decision["action"] || decision[:action] || "EXPLORE"
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)
    hp_ratio = hp / max_hp
    recent = Enum.take(state.history || [], -12)
    recent5 = Enum.take(recent, -5) |> Enum.map(& &1.action)
    fight_count = Enum.count(recent5, &(&1 == "FIGHT"))
    talk_count = Enum.count(recent5, &(&1 == "TALK"))
    total_recent_fights = Enum.count(recent, &(&1.action == "FIGHT"))
    has_items = context.items != []
    has_npcs = context.npcs != []

    ticks_since_fight =
      case Enum.reverse(recent) |> Enum.find_index(&(&1.action == "FIGHT")) do
        nil -> 999
        idx -> idx
      end

    fight_cap = fight_cap(state.class_id)
    fight_budget_ok = total_recent_fights < fight_cap

    class_prefers_caution =
      state.class_id in [2, 3] and (state.tick_count == 0 or total_recent_fights >= 1)

    fight_blocked =
      action == "FIGHT" and
        (hp_ratio <= 0.7 or fight_count >= 1 or
           ticks_since_fight < @fight_cooldown_ticks or not fight_budget_ok or
           class_prefers_caution)

    cond do
      hp_ratio <= 0.5 ->
        %{"action" => "REST", "target" => "tavern"}

      fight_blocked ->
        post_fight_fallback(context, event, talk_count, has_items, has_npcs)

      action == "TALK" and talk_count >= 2 ->
        %{"action" => "EXPLORE", "target" => "roads beyond #{context.zone["name"]}"}

      action == "TRADE" and not has_items and context.orders == [] ->
        %{"action" => "EXPLORE", "target" => "market lane"}

      action == "TALK" and not has_npcs ->
        %{"action" => "EXPLORE", "target" => "roads"}

      true ->
        Map.new(decision)
    end
  end

  defp fight_cap(1), do: 2
  defp fight_cap(_), do: 1

  defp post_fight_fallback(context, event, talk_count) do
    post_fight_fallback(context, event, talk_count, context.items != [], context.npcs != [])
  end

  defp post_fight_fallback(context, event, talk_count, has_items, has_npcs) do
    cond do
      has_items ->
        %{"action" => "TRADE", "target" => "marketplace"}

      talk_count >= 2 ->
        %{"action" => "EXPLORE", "target" => "roads beyond #{context.zone["name"]}"}

      has_npcs ->
        %{"action" => "TALK", "target" => event.target || "locals"}

      true ->
        %{"action" => "EXPLORE", "target" => event.target || "frontier path"}
    end
  end

  defp fight(context, event) do
    spendable = SettlementState.spendable_soul(context.agent["agentId"])

    if spendable < 0 do
      explore_with_reason("FIGHT skipped, pending lock active")
    else
      case pick_fight_target(context.agent["zoneId"], context.agent["agentId"]) do
        {:ok, monster} ->
          updated_event = %{event | target: monster.name, metadata: monster}
          simulation = Combat.simulate(context, updated_event)

          Hub.submit_event(%{
            type: :combat_result,
            priority: :normal,
            agent_id: context.agent["agentId"],
            data: %{
              agent_id: context.agent["agentId"],
              monster_id: monster.monster_id,
              zone_id: context.agent["zoneId"],
              soul_changes: [
                %{agent_id: context.agent["agentId"], delta: simulation.optimistic_soul_delta}
              ],
              state_changes:
                simulation.state_changes ++
                  [%{agent_id: context.agent["agentId"], field: :hp, value: simulation.hp_after}],
              hp_after: simulation.hp_after,
              summary: simulation.summary
            }
          })

          %{summary: simulation.summary <> " (settling...)", status: :alive}

        :no_targets ->
          explore_with_reason("FIGHT skipped, no alive monsters were available")
      end
    end
  end

  defp rest(context) do
    tavern = Enum.find(context.npcs, &(&1.role == "TAVERN"))
    potion_id = Client.find_item_type_id(Constants.rest_item_name())
    soul_balance = SettlementState.spendable_soul(context.agent["agentId"])

    cond do
      tavern && potion_id ->
        price_entry = Client.get_npc_price(tavern.npc_id, potion_id)

        cond do
          not price_entry.available ->
            offchain_rest(context, tavern.name)

          soul_balance < price_entry.price ->
            explore_with_reason("REST skipped, insufficient SOUL for #{tavern.name}")

          true ->
            previous_hp = get_in(context, [:agent, "stats", "hp"]) || 0
            healed_stats = heal_stats(context.agent["stats"])

            Hub.submit_event(%{
              type: :npc_purchase,
              priority: :normal,
              agent_id: context.agent["agentId"],
              data: %{
                agent_id: context.agent["agentId"],
                npc_id: tavern.npc_id,
                item_id: potion_id,
                zone_id: context.agent["zoneId"],
                status_id: Constants.resting_status_id(),
                heal_stats: healed_stats,
                soul_changes: [%{agent_id: context.agent["agentId"], delta: -price_entry.price}],
                state_changes: [
                  %{agent_id: context.agent["agentId"], field: :statusName, value: "RESTING"},
                  %{agent_id: context.agent["agentId"], field: :hp, value: healed_stats["hp"]}
                ],
                summary:
                  "REST #{tavern.name}##{tavern.npc_id} -> HP #{previous_hp}→#{healed_stats["hp"]}, -#{format_soul(price_entry.price)} SOUL"
              }
            })

            %{
              summary:
                "REST #{tavern.name}##{tavern.npc_id} -> HP #{previous_hp}→#{healed_stats["hp"]}, -#{format_soul(price_entry.price)} SOUL (settling...)",
              status: :resting
            }
        end

      true ->
        offchain_rest(context, "camp")
    end
  end

  defp talk(context, event) do
    npc_name =
      case Enum.find(context.npcs, fn npc -> npc.name == event.target end) do
        nil -> event.target || "a local NPC"
        npc -> npc.name
      end

    dialogue =
      case event.type do
        :npc -> "I asked #{npc_name} what changed in #{context.zone["name"]}."
        :monster -> "I will learn about #{event.target} before rushing into danger."
        _ -> "I traded rumors with #{npc_name} and marked it in memory."
      end

    %{
      summary: "TALK #{npc_name} -> gathered local information off-chain.",
      dialogue: dialogue,
      status: :alive
    }
  end

  defp explore(_context, event) do
    %{
      summary: "EXPLORE #{event.target || "the frontier"} -> logged movement off-chain.",
      status: :traveling
    }
  end

  defp trade(context) do
    fresh_orders = available_trade_orders()

    case cheapest_order(context, fresh_orders) do
      order when not is_nil(order) ->
        soul_balance = SettlementState.spendable_soul(context.agent["agentId"])

        cond do
          soul_balance < order.price_in_soul ->
            maybe_list_item(context)

          true ->
            burned = Float.round(order.price_in_soul * 0.02 / Constants.one_soul(), 2)

            Hub.submit_event(%{
              type: :marketplace_trade,
              priority: :batch,
              agent_id: context.agent["agentId"],
              data: %{
                agent_id: context.agent["agentId"],
                mode: :buy,
                order_id: order.order_id,
                item_id: order.item_id,
                soul_changes: [%{agent_id: context.agent["agentId"], delta: -order.price_in_soul}],
                summary:
                  "TRADE buy item##{order.item_id} via order##{order.order_id} -> filled -#{format_soul(order.price_in_soul)} SOUL (#{burned} burned)"
              }
            })

            %{
              summary:
                "TRADE buy item##{order.item_id} via order##{order.order_id} -> filled -#{format_soul(order.price_in_soul)} SOUL (#{burned} burned, settling...)",
              status: :alive
            }
        end

      nil ->
        maybe_list_item(context)
    end
  end

  defp offchain_rest(context, source) do
    previous_hp = get_in(context, [:agent, "stats", "hp"]) || 0
    healed_hp = min(previous_hp + 10, get_in(context, [:agent, "stats", "maxHp"]) || previous_hp)

    %{
      summary: "REST #{source} -> HP #{previous_hp}→#{healed_hp} (off-chain recovery)",
      status: :resting
    }
  end

  defp heal_stats(stats) do
    max_hp = stats["maxHp"] || 0
    max_mp = stats["maxMp"] || 0

    %{
      "hp" => max_hp,
      "maxHp" => max_hp,
      "mp" => max_mp,
      "maxMp" => max_mp,
      "attack" => stats["attack"] || 0,
      "defense" => stats["defense"] || 0,
      "speed" => stats["speed"] || 0
    }
  end

  defp cheapest_order(%{agent: agent}, orders) do
    observer = String.downcase(agent["observer"] || "")

    foreign =
      orders
      |> Enum.reject(&(String.downcase(&1.seller || "") == observer))
      |> Enum.sort_by(& &1.price_in_soul)
      |> List.first()

    foreign || orders |> Enum.sort_by(& &1.price_in_soul) |> List.first()
  end

  defp maybe_list_item(context) do
    fresh_items = Reader.get_agent_items(context.agent["observer"])

    existing_orders =
      Reader.get_active_orders()
      |> Enum.filter(
        &(String.downcase(&1.seller || "") == String.downcase(context.agent["observer"] || ""))
      )
      |> MapSet.new(& &1.item_id)

    case fresh_items do
      [item | _] ->
        if MapSet.member?(existing_orders, item.item_id) or
             pending_market_sell?(context.agent["agentId"], item.item_id) do
          %{
            summary: "TRADE skipped, an active order already exists for item##{item.item_id}.",
            status: :alive
          }
        else
          price_in_soul = trade_price(item)
          lock_market_sell(context.agent["agentId"], item.item_id)

          Hub.submit_event(%{
            type: :marketplace_trade,
            priority: :batch,
            agent_id: context.agent["agentId"],
            data: %{
              agent_id: context.agent["agentId"],
              mode: :sell,
              item_id: item.item_id,
              amount: 1,
              price_in_soul: price_in_soul,
              soul_changes: [],
              summary:
                "TRADE sell #{item.name}##{item.item_id} -> listed #{format_soul(price_in_soul)} SOUL"
            }
          })

          %{
            summary:
              "TRADE sell #{item.name}##{item.item_id} -> listed #{format_soul(price_in_soul)} SOUL (settling...)",
            status: :alive
          }
        end

      [] ->
        %{summary: "No valid trade was available.", status: :alive}
    end
  end

  defp pending_market_sell?(agent_id, item_id) do
    ensure_pending_market_sells_table!()
    cleanup_pending_market_sells()

    if :ets.lookup(@pending_market_sells_table, {agent_id, item_id}) != [] do
      true
    else
      pending_market_sell_event?(agent_id, item_id)
    end
  end

  defp pending_market_sell_event?(agent_id, item_id) do
    case :ets.whereis(:event_queue) do
      :undefined ->
        false

      _ ->
        :event_queue
        |> :ets.tab2list()
        |> Enum.any?(fn {_key, event} ->
          event.type == :marketplace_trade and event.agent_id == agent_id and
            Map.get(event.data, :mode) == :sell and Map.get(event.data, :item_id) == item_id
        end)
    end
  end

  defp lock_market_sell(agent_id, item_id) do
    ensure_pending_market_sells_table!()

    :ets.insert(
      @pending_market_sells_table,
      {{agent_id, item_id}, System.monotonic_time(:millisecond)}
    )
  end

  defp available_trade_orders do
    ensure_failed_orders_table!()
    cleanup_failed_orders()
    blacklisted = failed_order_ids()

    Reader.get_active_orders()
    |> Enum.reject(
      &(MapSet.member?(blacklisted, &1.order_id) or pending_market_buy?(&1.order_id))
    )
  end

  defp pending_market_buy?(order_id) do
    case :ets.whereis(:event_queue) do
      :undefined ->
        false

      _ ->
        :event_queue
        |> :ets.tab2list()
        |> Enum.any?(fn {_key, event} ->
          event.type == :marketplace_trade and Map.get(event.data, :mode) == :buy and
            Map.get(event.data, :order_id) == order_id
        end)
    end
  end

  defp failed_order_ids do
    @failed_orders_table
    |> :ets.tab2list()
    |> Enum.map(fn {order_id, _ts} -> order_id end)
    |> MapSet.new()
  end

  defp ensure_failed_orders_table! do
    case :ets.whereis(@failed_orders_table) do
      :undefined ->
        :ets.new(@failed_orders_table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @failed_orders_table
    end
  end

  defp cleanup_failed_orders do
    now = System.monotonic_time(:millisecond)

    @failed_orders_table
    |> :ets.tab2list()
    |> Enum.each(fn {order_id, failed_at} ->
      if now - failed_at > @failed_order_ttl_ms do
        :ets.delete(@failed_orders_table, order_id)
      end
    end)
  end

  defp ensure_pending_market_sells_table! do
    case :ets.whereis(@pending_market_sells_table) do
      :undefined ->
        :ets.new(@pending_market_sells_table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @pending_market_sells_table
    end
  end

  defp cleanup_pending_market_sells do
    now = System.monotonic_time(:millisecond)

    @pending_market_sells_table
    |> :ets.tab2list()
    |> Enum.each(fn {key, inserted_at} ->
      if now - inserted_at > @pending_market_sell_ttl_ms do
        :ets.delete(@pending_market_sells_table, key)
      end
    end)
  end

  defp next_trade_streak(state, "TRADE"), do: (state.consecutive_trades || 0) + 1
  defp next_trade_streak(_state, _), do: 0

  defp pick_fight_target(zone_id, agent_id) do
    ensure_target_table!()
    cleanup_stale_target_locks()

    targeted =
      :ets.tab2list(@target_lock_table)
      |> Map.new(fn {monster_id, owner, _at} -> {monster_id, owner} end)

    available =
      Reader.get_alive_monsters_in_zone(zone_id)
      |> Enum.reject(fn monster -> Map.has_key?(targeted, monster.monster_id) end)

    case available do
      [target | _] ->
        :ets.insert(
          @target_lock_table,
          {target.monster_id, agent_id, System.monotonic_time(:millisecond)}
        )

        {:ok, target}

      [] ->
        :no_targets
    end
  end

  defp ensure_target_table! do
    case :ets.whereis(@target_lock_table) do
      :undefined ->
        :ets.new(@target_lock_table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @target_lock_table
    end
  end

  defp cleanup_stale_target_locks do
    now = System.monotonic_time(:millisecond)

    @target_lock_table
    |> :ets.tab2list()
    |> Enum.each(fn {monster_id, _agent_id, claimed_at} ->
      if now - claimed_at > @target_lock_ttl_ms do
        :ets.delete(@target_lock_table, monster_id)
      end
    end)
  end

  defp trade_price(item) do
    multiplier =
      case item.tier do
        1 -> 6
        2 -> 14
        _ -> 8
      end

    multiplier * Constants.one_soul()
  end

  defp format_soul(amount) when is_integer(amount) do
    Float.round(amount / Constants.one_soul(), 2)
  end

  defp explore_with_reason(reason) do
    %{summary: "#{reason}. Explored the nearby roads instead.", status: :traveling}
  end

  defp record_memory(agent_id, history_entry) do
    Store.record(agent_id, :action, history_entry.summary, %{
      tick: history_entry.tick,
      action: history_entry.action,
      target: history_entry.target,
      event: history_entry.event,
      dialogue: history_entry.dialogue
    })
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp record_dialogue(state, %{action: "TALK", dialogue: dialogue} = history_entry)
       when is_binary(dialogue) do
    Dialogue.record(state.agent_id, state.label || "Agent", dialogue, %{
      tick: history_entry.tick,
      target: history_entry.target,
      event: history_entry.event
    })
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp record_dialogue(_state, _history_entry), do: :ok

  defp dialogue_line(decision, result) do
    [decision["dialogue"], decision[:dialogue], result[:dialogue]]
    |> Enum.find_value(fn
      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: nil, else: value

      _ ->
        nil
    end)
  end

  defp maybe_reflect(agent_id, tick) when tick > 0 and rem(tick, 50) == 0 do
    Reflection.reflect(agent_id, tick)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp maybe_reflect(_agent_id, _tick), do: :ok
end
