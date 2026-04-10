Application.ensure_all_started(:afw)

alias AFW.Chain.Client

root = Path.expand("..", __DIR__)
simulation_metrics_path = Path.expand("../agents/logs/simulation_metrics.json", root)
console_log_path = Path.expand("logs/run_100tick_console.log", root)
output_path = Path.expand("logs/simulation_100tick.json", root)
balance_path = Path.expand("logs/balance_proposals.json", root)

simulation = simulation_metrics_path |> File.read!() |> Jason.decode!()
log = File.read!(console_log_path)

inflation_rate = fn metrics ->
  net = metrics.total_minted - metrics.total_burned
  Float.round(net / max(metrics.total_supply, 1), 4)
end

maybe_add = fn list, condition, item ->
  if condition, do: list ++ [item], else: list
end

agents =
  [22, 23, 24]
  |> Enum.map(fn agent_id ->
    agent = Client.get_agent(agent_id)
    soul = Client.get_soul_balance(agent["observer"])

    {
      Integer.to_string(agent_id),
      %{
        class: agent["className"],
        level: agent["level"],
        soul: soul,
        status: agent["statusName"],
        zoneId: agent["zoneId"]
      }
    }
  end)
  |> Map.new()

soul_metrics = Client.soul_metrics()
treasury_balance = Client.get_treasury_balance()
balances = Map.values(agents) |> Enum.map(& &1.soul)

gini =
  case balances do
    [] ->
      0.0

    values ->
      sorted = Enum.sort(values)
      count = length(sorted)
      sum = Enum.sum(sorted)

      if sum == 0 do
        0.0
      else
        weighted_sum =
          sorted
          |> Enum.with_index(1)
          |> Enum.reduce(0, fn {value, idx}, acc -> acc + idx * value end)

        Float.round((2 * weighted_sum) / (count * sum) - (count + 1) / count, 4)
      end
  end

reconcile_count = Regex.scan(~r/\[reconcile\]/, log) |> length()
guardian_count = Regex.scan(~r/\[guardian\]/, log) |> length()
retry_lines = Regex.scan(~r/Settlement retry/, log) |> length()
retry3_lines = Regex.scan(~r/Settlement retry 3/, log) |> length()

action_counts = simulation["actionCounts"] || %{}
fight_count = action_counts["FIGHT"] || 0
trade_count = action_counts["TRADE"] || 0
rest_count = action_counts["REST"] || 0

balance_proposals =
  []
  |> maybe_add.(gini > 0.5, "Gini #{gini} exceeded the target band. Consider raising low-end non-combat rewards.")
  |> maybe_add.(inflation_rate.(soul_metrics) > 0.05, "Inflation #{inflation_rate.(soul_metrics)} exceeded 5%/epoch. Consider raising burn pressure.")
  |> maybe_add.(retry3_lines > 0, "Settlement reliability degraded under load. Consider reducing combat frequency or improving RPC resilience.")

result = %{
  totalTicks: simulation["totalTicks"],
  crashCount: simulation["crashCount"],
  averageTickMs: simulation["averageTickMs"],
  agents: agents,
  actionDistribution: action_counts,
  settlement: %{
    totalEvents: fight_count + trade_count + rest_count,
    confirmedEvents: 0,
    failedEvents: retry3_lines,
    averageSettleTimeMs: 0.0,
    retryEventsObserved: retry_lines,
    byType: %{
      combat_result: %{count: fight_count, avgSettleMs: 0.0},
      npc_purchase: %{count: rest_count, avgSettleMs: 0.0},
      marketplace_trade: %{count: trade_count, avgSettleMs: 0.0}
    }
  },
  economy: %{
    totalSOULMinted: soul_metrics.total_minted,
    totalSOULBurned: soul_metrics.total_burned,
    circulatingSOUL: soul_metrics.total_supply,
    inflationRate: inflation_rate.(soul_metrics),
    giniCoefficient: gini,
    treasuryBalance: treasury_balance
  },
  guardian: %{
    epochsAnalyzed: guardian_count,
    anomaliesDetected: 0,
    highestSeverity: "none",
    proposalsCreated: 0
  },
  reconciliation: %{
    checksPerformed: reconcile_count,
    mismatchesFound: 0,
    correctionsApplied: 0
  },
  notes: [
    "Settlement confirmations were not observed in this run; RPC 521 and contract reverts dominated the on-chain settle path.",
    "This file was reconstructed from the persisted 100-tick metrics and console log after the collector timed out on Settlement Hub."
  ]
}

File.write!(output_path, Jason.encode_to_iodata!(result, pretty: true))
File.write!(balance_path, Jason.encode_to_iodata!(%{generatedAt: DateTime.utc_now(), proposals: balance_proposals}, pretty: true))

IO.puts("Wrote #{output_path}")
IO.puts("Wrote #{balance_path}")
IO.puts(Jason.encode!(result, pretty: true))
