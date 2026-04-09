defmodule AFW.Settlement.Settler do
  @moduledoc "Executes on-chain settlement for queued optimistic events."

  alias AFW.Chain.Writer
  alias AFW.Settlement.State

  def settle(events) do
    events
    |> Enum.group_by(& &1.type)
    |> Enum.each(fn {_type, batch} -> Enum.each(batch, &settle_event/1) end)
  end

  def settle_event(event) do
    case execute(event) do
      {:ok, payload} ->
        State.release_lock(event.id, event.agent_id)
        State.confirm_event(event)
        Phoenix.PubSub.broadcast(AFW.PubSub, "agents", {:settlement_confirmed, event.agent_id, event.id, payload})
        {:ok, payload}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute(%{type: :combat_result, data: data}) do
    Writer.resolve_combat(data.agent_id, data.monster_id)
  end

  defp execute(%{type: :npc_purchase, data: data}) do
    with {:ok, _purchase} <- Writer.buy_from_npc(data.npc_id, data.item_id) do
      Writer.update_agent_state(data.agent_id, data.heal_stats, Map.get(data, :exp_gained, 0), data.zone_id, data.status_id)
    end
  end

  defp execute(%{type: :marketplace_trade, data: %{mode: :sell} = data}) do
    Writer.create_market_order(data.item_id, data.amount, data.price_in_soul)
  end

  defp execute(%{type: :marketplace_trade, data: %{mode: :buy} = data}) do
    Writer.fill_market_order(data.order_id)
  end

  defp execute(%{type: :agent_created, data: data}) do
    Writer.create_agent(data.class_id, data.personality)
  end

  defp execute(_event), do: {:ok, %{status: :noop}}
end
