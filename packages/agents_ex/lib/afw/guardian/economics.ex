defmodule AFW.Guardian.Economics do
  @moduledoc "Computes economic metrics from on-chain reads plus optimistic settlement state."

  require Logger

  alias AFW.Chain.Client
  alias AFW.Combat.Stats
  @thresholds [
    %{amount: 1_000 * 1_000_000_000_000_000_000, type: "MINI"},
    %{amount: 5_000 * 1_000_000_000_000_000_000, type: "ZONE"},
    %{amount: 10_000 * 1_000_000_000_000_000_000, type: "WORLD_BOSS"}
  ]

  def snapshot do
    queued = queued_events()
    optimistic = optimistic_balances()
    tasks = [
      Task.async(fn -> {:soul_metrics, Client.soul_metrics()} end),
      Task.async(fn -> {:combat, Stats.snapshot()} end),
      Task.async(fn -> {:treasury_balance, Client.get_treasury_balance()} end),
      Task.async(fn -> {:orders, Client.active_orders()} end)
    ]

    results =
      Task.yield_many(tasks, 10_000)
      |> Enum.map(fn {task, result} ->
        case result || Task.shutdown(task, :brutal_kill) do
          {:ok, value} -> value
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    metrics = Map.get(results, :soul_metrics, %{total_minted: 0, total_burned: 0, total_supply: 0})
    combat = Map.get(results, :combat, %{fight_attempts: 0, fight_successes: 0, fight_failures: 0, success_rate: 0.0})
    treasury_balance = Map.get(results, :treasury_balance, 0)
    orders = Map.get(results, :orders, [])

    snapshot = %{
      soul: %{
        total_minted: metrics.total_minted,
        total_burned: metrics.total_burned,
        circulating: metrics.total_supply,
        inflation_rate: inflation_rate(metrics),
        balances: optimistic
      },
      wealth: %{
        gini: gini(optimistic)
      },
      combat: %{
        total_fights: combat.fight_attempts,
        wins: combat.fight_successes,
        losses: combat.fight_failures,
        win_rate: combat.success_rate,
        pending_combats: Enum.count(queued, &(&1.type == :combat_result))
      },
      marketplace: %{
        active_orders: length(orders),
        trade_volume: trade_volume(orders, queued),
        fill_rate: fill_rate(orders, queued),
        total_burned: metrics.total_burned
      },
      treasury: treasury_view(treasury_balance, queued)
    }

    log_snapshot(snapshot)
    snapshot
  end

  def treasury_view(balance, queued \\ queued_events()) do
    next_threshold =
      Enum.find(@thresholds, List.last(@thresholds), fn threshold ->
        balance < threshold.amount
      end)

    pending_death =
      queued
      |> Enum.filter(&(&1.type == :death_penalty))
      |> Enum.flat_map(fn event -> Map.get(event.data, :soul_changes, []) end)
      |> Enum.reduce(0, fn change, acc -> acc + max(change[:delta] || 0, 0) end)

    %{
      balance: balance,
      next_threshold: next_threshold.type,
      next_threshold_amount: next_threshold.amount,
      remaining_to_next: max(next_threshold.amount - balance, 0),
      queued_inflow: pending_death,
      estimated_eta_epochs: estimate_eta(balance, next_threshold.amount, pending_death)
    }
  end

  defp optimistic_balances do
    case :ets.whereis(:optimistic_state) do
      :undefined ->
        []

      _ ->
        :ets.tab2list(:optimistic_state)
        |> Enum.map(fn {agent_id, state} ->
          agent = Client.get_agent(agent_id)
          confirmed = Map.get(state, :confirmed_soul, Client.get_soul_balance(agent["observer"]))
          pending = Map.get(state, :optimistic_delta, 0)

          %{
            agent_id: agent_id,
            wallet: agent["observer"],
            confirmed: confirmed,
            pending: pending,
            total: confirmed + pending
          }
        end)
    end
  end

  defp inflation_rate(%{total_supply: 0}), do: 0.0

  defp inflation_rate(metrics) do
    net = metrics.total_minted - metrics.total_burned
    Float.round(net / max(metrics.total_supply, 1), 4)
  end

  defp gini([]), do: 0.0

  defp gini(balances) do
    values = balances |> Enum.map(& &1.total) |> Enum.sort()
    count = length(values)
    sum = Enum.sum(values)

    if count == 0 or sum == 0 do
      0.0
    else
      weighted_sum =
        values
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {value, idx}, acc -> acc + idx * value end)

      Float.round((2 * weighted_sum) / (count * sum) - (count + 1) / count, 4)
    end
  end

  defp trade_volume(orders, queued) do
    active_value = Enum.reduce(orders, 0, fn order, acc -> acc + order.price_in_soul * order.amount end)

    queued_value =
      queued
      |> Enum.filter(&(&1.type == :marketplace_trade))
      |> Enum.reduce(0, fn event, acc -> acc + (Map.get(event.data, :price_in_soul, 0) || 0) end)

    active_value + queued_value
  end

  defp fill_rate(orders, queued) do
    pending_trades = Enum.count(queued, &(&1.type == :marketplace_trade))
    total = length(orders) + pending_trades
    if total == 0, do: 0.0, else: Float.round(pending_trades / total, 4)
  end

  defp estimate_eta(balance, threshold, queued_inflow) do
    per_epoch = max(queued_inflow, 1_000_000_000_000_000_000)
    max(div(max(threshold - balance, 0), per_epoch), 0)
  end

  defp log_snapshot(snapshot) do
    top = snapshot.soul.balances |> Enum.max_by(& &1.total, fn -> %{agent_id: nil, total: 0} end)
    bottom = snapshot.soul.balances |> Enum.min_by(& &1.total, fn -> %{agent_id: nil, total: 0} end)

    Logger.info(
      "[economics] SOUL: minted=#{snapshot.soul.total_minted} burned=#{snapshot.soul.total_burned} circulating=#{snapshot.soul.circulating} inflation=#{Float.round(snapshot.soul.inflation_rate * 100, 2)}%"
    )

    Logger.info(
      "[economics] Gini=#{snapshot.wealth.gini}, topAgent=#{top.agent_id || "n/a"} #{top.total}, bottomAgent=#{bottom.agent_id || "n/a"} #{bottom.total}"
    )

    Logger.info(
      "[economics] Treasury: #{snapshot.treasury.balance} SOUL (next: #{snapshot.treasury.next_threshold} at #{snapshot.treasury.next_threshold_amount})"
    )
  end

  defp queued_events do
    case :ets.whereis(:event_queue) do
      :undefined -> []
      _ -> :ets.tab2list(:event_queue) |> Enum.map(fn {_key, event} -> event end)
    end
  end
end
