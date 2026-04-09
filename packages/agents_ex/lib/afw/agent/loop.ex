defmodule AFW.Agent.Loop do
  @moduledoc "Tick execution for Elixir agents. Mirrors the Python loop using OTP-friendly state transitions."

  alias AFW.Brain.PromptBuilder
  alias AFW.Chain.Client
  alias AFW.Economy.Constants
  alias AFW.World.Combat
  alias AFW.World.Event

  @fight_cooldown_ticks 3

  def execute_tick(state) do
    snapshot = Client.snapshot(state.agent_id)

    context = %{
      agent: snapshot.agent,
      zone: snapshot.zone,
      monsters: snapshot.monsters,
      npcs: snapshot.npcs,
      items: snapshot.items,
      orders: snapshot.orders,
      treasury_balance: snapshot.treasury_balance,
      history: Enum.take(state.history || [], -5)
    }

    event = Event.generate(context, state.tick_count + 1)

    decision =
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

    result =
      case decision["action"] || decision[:action] do
        "FIGHT" -> fight(context, event)
        "REST" -> rest(context)
        "TRADE" -> trade(context)
        "TALK" -> talk(context, event)
        "USE_ITEM" -> %{summary: "Used an item from inventory.", status: :alive}
        _ -> explore(context, event)
      end

    history_entry = %{
      tick: state.tick_count + 1,
      action: decision["action"] || decision[:action] || "EXPLORE",
      target: decision["target"] || decision[:target] || "",
      summary: result.summary,
      event: event.type
    }

    %{
      state
      | tick_count: state.tick_count + 1,
        history: (state.history || []) ++ [history_entry],
        last_action: history_entry
    }
  end

  defp fallback_decision(context, event) do
    hp = get_in(context, [:agent, "stats", "hp"]) || 0
    max_hp = max(get_in(context, [:agent, "stats", "maxHp"]) || 1, 1)
    hp_ratio = hp / max_hp

    cond do
      hp_ratio <= 0.5 or event.type == :survival -> %{"action" => "REST", "target" => "tavern"}
      event.type == :trade -> %{"action" => "TRADE", "target" => "marketplace"}
      event.type == :npc -> %{"action" => "TALK", "target" => event.target}
      event.type == :monster and hp_ratio > 0.7 -> %{"action" => "FIGHT", "target" => event.target}
      true -> %{"action" => "EXPLORE", "target" => event.target}
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
      hp_ratio <= 0.5 ->
        {:decided, %{"action" => "REST", "target" => "tavern"}}

      event.type == :monster and total_recent_fights >= fight_cap(state.class_id) ->
        {:decided, post_fight_fallback(context, event, talk_count)}

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
           ticks_since_fight < @fight_cooldown_ticks or not fight_budget_ok or class_prefers_caution)

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
      has_items -> %{"action" => "TRADE", "target" => "marketplace"}
      talk_count >= 2 -> %{"action" => "EXPLORE", "target" => "roads beyond #{context.zone["name"]}"}
      has_npcs -> %{"action" => "TALK", "target" => event.target || "locals"}
      true -> %{"action" => "EXPLORE", "target" => event.target || "frontier path"}
    end
  end

  defp fight(context, event) do
    case Combat.resolve(context, event) do
      %{success?: false, error: reason} ->
        fallback = explore(context, event)
        %{summary: "FIGHT failed, fallback to EXPLORE: #{reason}. #{fallback.summary}", status: fallback.status}

      result ->
        result
    end
  end

  defp rest(context) do
    tavern = Enum.find(context.npcs, &(&1.role == "TAVERN"))
    potion_id = Client.find_item_type_id(Constants.rest_item_name())
    soul_balance = Client.get_soul_balance(context.agent["observer"])

    cond do
      tavern && potion_id ->
        price_entry = Client.get_npc_price(tavern.npc_id, potion_id)

        cond do
          not price_entry.available ->
            offchain_rest(context, tavern.name)

          soul_balance < price_entry.price ->
            explore_with_reason("REST skipped, insufficient SOUL for #{tavern.name}")

          true ->
            case Client.buy_from_npc(tavern.npc_id, potion_id) do
              {:ok, _payload} ->
                previous_hp = get_in(context, [:agent, "stats", "hp"]) || 0
                healed_stats = heal_stats(context.agent["stats"])

                case Client.update_agent_state(
                       context.agent["agentId"],
                       healed_stats,
                       0,
                       context.agent["zoneId"],
                       Constants.resting_status_id()
                     ) do
                  {:ok, _} ->
                    %{
                      summary:
                        "REST #{tavern.name}##{tavern.npc_id} -> HP #{previous_hp}→#{healed_stats["hp"]}, -#{format_soul(price_entry.price)} SOUL",
                      status: :resting
                    }

                  {:error, reason} ->
                    %{
                      summary: "REST purchase succeeded at #{tavern.name}, but state sync failed: #{reason}",
                      status: :resting
                    }
                end

              {:error, reason} ->
                explore_with_reason("REST failed at #{tavern.name}: #{reason}")
            end
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

    %{
      summary: "TALK #{npc_name} -> gathered local information off-chain.",
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
    case cheapest_order(context) do
      order when not is_nil(order) ->
        soul_balance = Client.get_soul_balance(context.agent["observer"])

        cond do
          soul_balance < order.price_in_soul ->
            maybe_list_item(context)

          true ->
            case Client.fill_market_order(order.order_id) do
              {:ok, _} ->
                burned = Float.round(order.price_in_soul * 0.02 / Constants.one_soul(), 2)

                %{
                  summary:
                    "TRADE buy item##{order.item_id} via order##{order.order_id} -> filled -#{format_soul(order.price_in_soul)} SOUL (#{burned} burned)",
                  status: :alive
                }

              {:error, reason} ->
                explore_with_reason("TRADE buy failed for order##{order.order_id}: #{reason}")
            end
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
    max_hp = stats["maxHp"] || stats[:max_hp] || stats[:maxHp] || 0
    max_mp = stats["maxMp"] || stats[:max_mp] || stats[:maxMp] || 0

    %{
      "hp" => max_hp,
      "maxHp" => max_hp,
      "mp" => max_mp,
      "maxMp" => max_mp,
      "attack" => stats["attack"] || stats[:attack] || 0,
      "defense" => stats["defense"] || stats[:defense] || 0,
      "speed" => stats["speed"] || stats[:speed] || 0
    }
  end

  defp cheapest_order(%{orders: orders, agent: agent}) do
    observer = String.downcase(agent["observer"] || "")

    foreign_order =
      orders
      |> Enum.reject(&(String.downcase(&1.seller || "") == observer))
      |> Enum.sort_by(& &1.price_in_soul)
      |> List.first()

    foreign_order ||
      (orders
       |> Enum.sort_by(& &1.price_in_soul)
       |> List.first())
  end

  defp maybe_list_item(context) do
    case context.items do
      [item | _] ->
        price_in_soul = trade_price(item)

        case Client.create_market_order(item.item_id, 1, price_in_soul) do
          {:ok, _} ->
            %{
              summary: "TRADE sell #{item.name}##{item.item_id} -> listed #{format_soul(price_in_soul)} SOUL",
              status: :alive
            }

          {:error, reason} ->
            explore_with_reason("TRADE sell failed for #{item.name}: #{reason}")
        end

      [] ->
        %{summary: "No valid trade was available.", status: :alive}
    end
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
    %{
      summary: "#{reason}. Explored the nearby roads instead.",
      status: :traveling
    }
  end
end
