defmodule AFW.Agent.Loop do
  @moduledoc "Tick execution for Elixir agents. Mirrors the Python loop using OTP-friendly state transitions."

  alias AFW.Chain.Client
  alias AFW.Brain.PromptBuilder
  alias AFW.World.Event
  alias AFW.World.Combat

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
        "FIGHT" -> Combat.resolve(context, event)
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
      event.type == :trade -> %{"action" => "TRADE", "target" => "marketplace"}
      true -> %{"action" => "EXPLORE", "target" => event.target}
    end
  end

  @fight_cooldown_ticks 3

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

    # Cooldown: ticks since last FIGHT
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

  defp rest(_context) do
    %{summary: "Rested at the local tavern and recovered stamina off-chain.", status: :resting}
  end

  defp talk(context, event) do
    npc_name =
      case Enum.find(context.npcs, fn npc -> npc.name == event.target end) do
        nil -> event.target || "a local NPC"
        npc -> npc.name
      end

    %{
      summary: "Talked with #{npc_name} and gathered local information off-chain.",
      status: :alive
    }
  end

  defp explore(_context, event) do
    %{
      summary: "Explored toward #{event.target || "the frontier"} and logged the movement off-chain.",
      status: :traveling
    }
  end

  defp trade(context) do
    case context.items do
      [item | _] ->
        case Client.create_market_order(item.item_id, 1, 5 * 1_000_000_000_000_000_000) do
          {:ok, _} ->
            %{summary: "Listed an item on the marketplace.", status: :alive}

          {:error, reason} ->
            %{summary: "Trade was skipped after marketplace rejection: #{reason}", status: :alive}
        end

      [] ->
        case context.orders do
          [order | _] ->
            case Client.fill_market_order(order.order_id) do
              {:ok, _} ->
                %{summary: "Filled a marketplace order.", status: :alive}

              {:error, reason} ->
                %{summary: "Order fill was skipped after marketplace rejection: #{reason}", status: :alive}
            end

          [] ->
            %{summary: "No valid trade was available.", status: :alive}
        end
    end
  end
end
