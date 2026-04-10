defmodule AFW.Settlement.Settler do
  @moduledoc "Executes on-chain settlement for queued optimistic events."
  require Logger

  alias AFW.Chain.{Client, Reader, Writer}
  alias AFW.Settlement.{Metrics, State}
  @failed_orders_table :failed_orders

  def settle(events) do
    events
    |> Enum.group_by(& &1.type)
    |> Enum.each(fn {_type, batch} -> Enum.each(batch, &settle_event/1) end)
  end

  def settle_event(event) do
    log_attempt(event)

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
        log_discard(event, reason)
        State.release_lock(event.id, event.agent_id)
        State.rollback_event(event)
        Metrics.record_discard(event, reason)
        Phoenix.PubSub.broadcast(AFW.PubSub, "agents", {:settlement_failed, event.agent_id, event.id, reason})
        {:ok, %{status: :discarded, reason: reason}}
    end
  end

  defp execute(%{type: :combat_result} = event) do
    with :ok <- precheck_combat(event) do
      settle_combat(event, 0)
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

  defp execute(%{type: :marketplace_trade, data: %{mode: :buy}} = event) do
    settle_market_buy(event, 0)
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

  defp settle_combat(%{data: data}, attempt) do
    with {:ok, agent} <- validate_agent_alive(data.agent_id),
         :ok <- ensure_agent_ready_for_combat(agent, data.agent_id),
         {:ok, _soul} <- validate_positive_soul(agent, data.agent_id),
         {:ok, monster_id} <- validate_or_retarget_monster(data.zone_id, data.monster_id, attempt),
         {:ok, payload} <- Writer.resolve_combat(data.agent_id, monster_id) do
      {:ok, payload}
    else
      {:error, reason} ->
        handle_combat_error(event_with_monster(data.agent_id, data, monster_id_or_original(data.monster_id)), reason, attempt)

      other ->
        other
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_npc_purchase(agent_id, npc_id, item_id) do
    agent = Client.get_agent_fresh_state(agent_id)
    soul = Client.get_soul_balance(agent["observer"])
    price = Client.get_npc_price(npc_id, item_id)
    npc = Client.get_npc_fresh(npc_id)

    cond do
      not price.available -> {:discard, "NPC purchase precheck failed: item unavailable"}
      is_nil(npc) or not npc.active -> {:discard, "NPC purchase precheck failed: npc_not_active"}
      soul < price.price -> {:discard, "NPC purchase precheck failed: insufficient SOUL"}
      true -> :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_market_sell(agent_id, item_id, amount) do
    agent = Client.get_agent_fresh_state(agent_id)
    items = Client.get_agent_items(agent["observer"])
    active_same_item? =
      Client.get_active_orders()
      |> Enum.any?(fn order ->
        String.downcase(order.seller || "") == String.downcase(agent["observer"] || "") and order.item_id == item_id
      end)

    cond do
      active_same_item? -> {:discard, "Marketplace sell precheck failed: stale_snapshot"}
      is_nil(Enum.find(items, &(&1.item_id == item_id and &1.balance >= amount))) ->
        {:discard, "Marketplace sell precheck failed: item unavailable"}

      true ->
        :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_market_buy(agent_id, order_id) do
    agent = Client.get_agent_fresh_state(agent_id)
    soul = Client.get_soul_balance(agent["observer"])

    case Enum.find(Client.get_active_orders(), &(&1.order_id == order_id)) do
      nil -> {:discard, "Marketplace buy precheck failed: order inactive"}
      order when soul < order.price_in_soul -> {:discard, "Marketplace buy precheck failed: insufficient SOUL"}
      _ -> :ok
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp settle_market_buy(%{data: data} = event, attempt) do
    with :ok <- validate_market_buy(data.agent_id, data.order_id),
         {:ok, payload} <- Writer.fill_market_order(data.order_id) do
      {:ok, payload}
    else
      {:error, {:revert, reason}} ->
        maybe_retry_market_buy(event, reason, attempt)

      {:error, :call_failed} ->
        {:error, :call_failed}

      {:discard, reason} ->
        maybe_retry_market_buy(event, reason, attempt)

      other ->
        other
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp maybe_retry_market_buy(%{data: data} = event, reason, attempt) do
    if attempt < 1 and String.contains?(to_string(reason), "order") do
      replacement =
        Client.get_active_orders()
        |> Enum.reject(&(&1.order_id == data.order_id))
        |> Enum.filter(&(&1.item_id == data.item_id))
        |> Enum.sort_by(& &1.price_in_soul)
        |> List.first()

      case replacement do
        nil ->
          blacklist_order(data.order_id)
          {:discard, "Marketplace buy precheck failed: order_not_active"}

        next_order ->
          Logger.info("[settle] RETARGET marketplace_trade: order=#{data.order_id} -> #{next_order.order_id}")
          Metrics.record_retargeted(:marketplace_trade, "order_not_active")
          settle_market_buy(put_in(event.data.order_id, next_order.order_id), attempt + 1)
      end
    else
      blacklist_order(data.order_id)
      {:discard, reason}
    end
  end

  defp validate_agent_alive(agent_id) do
    agent = Client.get_agent_fresh_state(agent_id)
    hp = get_in(agent, ["stats", "hp"]) || 0

    Logger.info("[settle] pre-validate: agent##{agent_id} status=#{agent["statusId"]} hp=#{hp}")

    if hp > 0 do
      {:ok, agent}
    else
      {:discard, "Combat precheck failed: agent_not_alive"}
    end
  end

  defp ensure_agent_ready_for_combat(agent, agent_id) do
    if agent["statusId"] == 1 do
      :ok
    else
      Logger.info("[settle] combat sync: agent##{agent_id} status #{agent["statusId"]} -> 1")

      case Writer.update_agent_state(
             agent_id,
             agent["stats"],
             0,
             agent["zoneId"],
             1
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> {:discard, "Combat precheck failed: stale_snapshot #{inspect(reason)}"}
      end
    end
  rescue
    error -> {:discard, Exception.message(error)}
  end

  defp validate_positive_soul(agent, agent_id) do
    soul = Client.get_soul_balance(agent["observer"])
    if soul >= 0, do: {:ok, soul}, else: {:discard, "Combat precheck failed: insufficient_soul agent=#{agent_id}"}
  end

  defp validate_or_retarget_monster(zone_id, monster_id, attempt) do
    case Reader.call_contract(:monster_registry, "getMonster", [monster_id]) do
      [{_, hp, _, _, _, _, alive}] when alive and hp > 0 ->
        Logger.info("[settle] pre-validate: monster##{monster_id} alive=true hp=#{hp}")
        {:ok, monster_id}

      _ when attempt < 1 ->
        case find_alive_monster(zone_id, monster_id) do
          {:ok, new_monster_id} ->
            Logger.info("[settle] RETARGET combat_result: monster=#{monster_id} -> #{new_monster_id}")
            Metrics.record_retargeted(:combat_result, "monster_dead")
            {:ok, new_monster_id}

          :none ->
            {:discard, "Combat precheck failed: no_alive_monsters"}
        end

      _ ->
        {:discard, "Combat precheck failed: monster_dead"}
    end
  end

  defp find_alive_monster(zone_id, exclude_monster_id) do
    case Client.get_alive_monsters_in_zone(zone_id) |> Enum.reject(&(&1.monster_id == exclude_monster_id)) |> List.first() do
      nil -> :none
      monster -> {:ok, monster.monster_id}
    end
  end

  defp log_discard(event, reason) do
    Logger.warning("[settle] DISCARD #{event.type}: reason=#{discard_category(reason)} details=#{inspect(reason)} agent=#{event.agent_id}")
  end

  defp log_attempt(event) do
    Logger.info("[settle] #{event.type} attempt: agent=#{event.agent_id} data=#{inspect(event.data)}")
  end

  defp precheck_combat(%{data: data}) do
    case {Client.get_agent_fresh_state(data.agent_id), Client.get_monster_fresh(data.monster_id)} do
      {nil, _} ->
        {:discard, :read_failed}

      {_, nil} ->
        {:discard, :read_failed}

      {agent, monster} ->
        hp = get_in(agent, ["stats", "hp"]) || 0
        atk = get_in(agent, ["stats", "attack"]) || 0
        Logger.info("[settle] precheck: agent status=#{agent["statusId"]} hp=#{hp} atk=#{atk}, monster alive=#{monster.alive} hp=#{monster.hp}")

        cond do
          hp <= 0 -> {:discard, :agent_zero_hp}
          atk <= 0 -> {:discard, :agent_zero_attack}
          not monster.alive -> {:discard, :monster_dead}
          true -> :ok
        end
    end
  rescue
    _ -> {:discard, :read_failed}
  end

  defp handle_combat_error(event, {:revert, reason}, attempt) do
    case reason do
      "CombatResolver: monster dead" ->
        settle_combat(event, attempt + 1)

      "MonsterRegistry: already dead" ->
        settle_combat(event, attempt + 1)

      "AgentRegistry: agent not found" ->
        {:discard, :agent_not_found}

      "AgentRegistry: status not found" ->
        {:discard, :invalid_status}

      other ->
        Logger.error("[settle] unknown revert: #{other}")
        {:discard, {:unknown_revert, other}}
    end
  end

  defp handle_combat_error(_event, :call_failed, _attempt), do: {:error, :call_failed}
  defp handle_combat_error(_event, reason, _attempt), do: {:discard, reason}

  defp blacklist_order(nil), do: :ok
  defp blacklist_order(order_id) do
    ensure_failed_orders_table!()
    :ets.insert(@failed_orders_table, {order_id, System.monotonic_time(:millisecond)})
    :ok
  end

  defp ensure_failed_orders_table! do
    case :ets.whereis(@failed_orders_table) do
      :undefined ->
        :ets.new(@failed_orders_table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

      _ ->
        @failed_orders_table
    end
  end

  defp event_with_monster(agent_id, data, monster_id) do
    %{type: :combat_result, agent_id: agent_id, data: Map.put(data, :monster_id, monster_id)}
  end

  defp monster_id_or_original(monster_id), do: monster_id

  defp discard_category(reason) do
    text = to_string(reason)

    cond do
      String.contains?(text, "monster_dead") -> "monster_dead"
      String.contains?(text, "no_alive_monsters") -> "no_alive_monsters"
      String.contains?(text, "agent_not_alive") -> "agent_not_alive"
      String.contains?(text, "insufficient SOUL") or String.contains?(text, "insufficient_soul") -> "insufficient_soul"
      String.contains?(text, "order inactive") or String.contains?(text, "order_not_active") -> "order_not_active"
      String.contains?(text, "stale_snapshot") -> "stale_snapshot"
      true -> "other"
    end
  end
end
