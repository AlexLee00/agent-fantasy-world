defmodule AFW.Settlement.Settler do
  @moduledoc "Executes on-chain settlement for queued optimistic events."

  alias AFW.Chain.{Client, Reader, Writer}
  alias AFW.Settlement.{Metrics, State}

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
        Metrics.record_confirmed(event)
        Phoenix.PubSub.broadcast(AFW.PubSub, "agents", {:settlement_confirmed, event.agent_id, event.id, payload})
        {:ok, payload}

      {:error, reason} ->
        {:error, reason}

      {:discard, reason} ->
        State.release_lock(event.id, event.agent_id)
        State.rollback_event(event)
        Metrics.record_failed(event, reason)
        Phoenix.PubSub.broadcast(AFW.PubSub, "agents", {:settlement_failed, event.agent_id, event.id, reason})
        {:ok, %{status: :discarded, reason: reason}}
    end
  end

  defp execute(%{type: :combat_result, data: data}) do
    with :ok <- validate_combat(data.agent_id, data.monster_id) do
      Writer.resolve_combat(data.agent_id, data.monster_id)
    end
  end

  defp execute(%{type: :npc_purchase, data: data}) do
    with :ok <- validate_npc_purchase(data.agent_id, data.npc_id, data.item_id),
         {:ok, _purchase} <- Writer.buy_from_npc(data.npc_id, data.item_id) do
      Writer.update_agent_state(data.agent_id, data.heal_stats, Map.get(data, :exp_gained, 0), data.zone_id, data.status_id)
    end
  end

  defp execute(%{type: :marketplace_trade, data: %{mode: :sell} = data}) do
    with :ok <- validate_market_sell(data.agent_id, data.item_id, data.amount) do
      Writer.create_market_order(data.item_id, data.amount, data.price_in_soul)
    end
  end

  defp execute(%{type: :marketplace_trade, data: %{mode: :buy} = data}) do
    with :ok <- validate_market_buy(data.agent_id, data.order_id) do
      Writer.fill_market_order(data.order_id)
    end
  end

  defp execute(%{type: :distribution_rewards, data: %{pool_key: :node_reward_pool} = data}) do
    Writer.distribute_node_rewards(data.addresses, data.amounts, data.epoch)
  end

  defp execute(%{type: :distribution_rewards, data: %{pool_key: :bounty_pool} = data}) do
    Writer.distribute_bounty_rewards(data.addresses, data.amounts, data.epoch)
  end

  defp execute(%{type: :governance_action, data: data}) do
    Writer.propose_governance_action(
      data.proposal_type,
      data.title,
      data.description,
      data.target_contract,
      data.call_data
    )
  end

  defp execute(%{type: :world_event}) do
    Writer.trigger_event_treasury_check()
  end

  defp execute(%{type: :agent_created, data: data}) do
    Writer.create_agent(data.class_id, data.personality)
  end

  defp execute(_event), do: {:ok, %{status: :noop}}

  defp validate_combat(agent_id, monster_id) do
    agent = Client.get_agent(agent_id)
    soul = Client.get_soul_balance(agent["observer"])

    cond do
      agent["statusName"] not in ["ALIVE", "STATUS_1"] and agent["statusId"] != 1 ->
        {:discard, "Combat precheck failed: agent #{agent_id} is not alive"}

      soul < 0 ->
        {:discard, "Combat precheck failed: agent #{agent_id} has insufficient SOUL"}

      true ->
        case Reader.call_contract(:monster_registry, "getMonster", [monster_id]) do
          [{_, hp, _, _, _, _, alive}] when alive and hp > 0 -> :ok
          _ -> {:discard, "Combat precheck failed: monster #{monster_id} is not alive"}
        end
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_npc_purchase(agent_id, npc_id, item_id) do
    agent = Client.get_agent(agent_id)
    soul = Client.get_soul_balance(agent["observer"])
    price = Client.get_npc_price(npc_id, item_id)

    cond do
      not price.available -> {:discard, "NPC purchase precheck failed: item unavailable"}
      soul < price.price -> {:discard, "NPC purchase precheck failed: insufficient SOUL"}
      true -> :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_market_sell(agent_id, item_id, amount) do
    agent = Client.get_agent(agent_id)
    items = Client.get_agent_items(agent["observer"])

    case Enum.find(items, &(&1.item_id == item_id and &1.balance >= amount)) do
      nil -> {:discard, "Marketplace sell precheck failed: item unavailable"}
      _ -> :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_market_buy(agent_id, order_id) do
    agent = Client.get_agent(agent_id)
    soul = Client.get_soul_balance(agent["observer"])

    case Enum.find(Client.active_orders(), &(&1.order_id == order_id)) do
      nil -> {:discard, "Marketplace buy precheck failed: order inactive"}
      order when soul < order.price_in_soul -> {:discard, "Marketplace buy precheck failed: insufficient SOUL"}
      _ -> :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end
end
