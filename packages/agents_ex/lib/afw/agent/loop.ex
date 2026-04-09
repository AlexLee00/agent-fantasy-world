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
    prompt = PromptBuilder.build(context, event)

    decision =
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

    result =
      case decision["action"] || decision[:action] do
        "FIGHT" -> Combat.resolve(context, event)
        "REST" -> rest(context)
        "TRADE" -> trade(context)
        "TALK" -> %{summary: "Spoke with locals and gathered rumors.", status: :alive}
        "USE_ITEM" -> %{summary: "Used an item from inventory.", status: :alive}
        _ -> %{summary: "Explored the zone for new opportunities.", status: :traveling}
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
      hp_ratio < 0.3 or event.type == :survival -> %{"action" => "REST", "target" => "tavern"}
      event.type == :monster -> %{"action" => "FIGHT", "target" => event.target}
      event.type == :trade -> %{"action" => "TRADE", "target" => "marketplace"}
      event.type == :npc -> %{"action" => "TALK", "target" => event.target}
      true -> %{"action" => "EXPLORE", "target" => event.target}
    end
  end

  defp rest(context) do
    npc =
      Enum.find(context.npcs, fn npc -> String.upcase(npc.role) == "TAVERN" end) ||
        List.first(context.npcs)

    if npc do
      _ = Client.buy_from_npc(npc.npc_id, 1)
    end

    %{summary: "Recovered at the local tavern and stabilized resources.", status: :resting}
  end

  defp trade(context) do
    case context.items do
      [item | _] ->
        _ = Client.create_market_order(item.item_id, 1, 5 * 1_000_000_000_000_000_000)
        %{summary: "Listed an item on the marketplace.", status: :alive}

      [] ->
        case context.orders do
          [order | _] ->
            _ = Client.fill_market_order(order.order_id)
            %{summary: "Filled a marketplace order.", status: :alive}

          [] ->
            %{summary: "No valid trade was available.", status: :alive}
        end
    end
  end
end
