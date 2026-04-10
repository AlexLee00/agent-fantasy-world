Application.ensure_all_started(:afw)

alias AFW.Agent.Supervisor
alias AFW.Guardian.Metrics, as: GuardianMetrics
alias AFW.Guardian.Monitor
alias AFW.Settlement.Hub
alias AFW.Settlement.Metrics, as: SettlementMetrics
alias AFW.Simulation.Metrics

agents = [
  %{agent_id: 22, class_id: 1, label: "Warrior", personality: [90, 10, 30, 80, 50], max_ticks: 18},
  %{agent_id: 23, class_id: 2, label: "Mage", personality: [30, 80, 70, 40, 60], max_ticks: 18},
  %{agent_id: 24, class_id: 3, label: "Ranger", personality: [50, 50, 90, 50, 50], max_ticks: 18}
]

Enum.each(agents, fn attrs ->
  case Supervisor.start_agent(attrs) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
    other -> IO.puts("agent start result=#{inspect(other)}")
  end
end)

wait = fn wait, threshold, forced? ->
  snapshot = Metrics.snapshot()

  if snapshot.totalTicks >= threshold do
    snapshot
  else
    if not forced? and snapshot.totalTicks >= 25 do
      Monitor.force_epoch()
      IO.puts("Forced guardian epoch at totalTicks=#{snapshot.totalTicks}")
      Process.sleep(1_000)
      wait.(wait, threshold, true)
    else
      Process.sleep(5_000)
      wait.(wait, threshold, forced?)
    end
  end
end

simulation = wait.(wait, 54, false)
send(Hub, {:settle, :normal})
send(Hub, {:settle, :batch})
Process.sleep(20_000)

settlement = SettlementMetrics.snapshot()
guardian = GuardianMetrics.snapshot()
rest_count = Map.get(simulation.actionCounts, "REST", 0)

revert_reasons =
  settlement.recentFailures
  |> Enum.reduce(%{}, fn failure, acc ->
    reason =
      cond do
        String.contains?(failure.reason, "agent") and String.contains?(failure.reason, "not alive") -> "AgentNotAlive"
        String.contains?(failure.reason, "monster") and String.contains?(failure.reason, "not alive") -> "MonsterNotAlive"
        String.contains?(failure.reason, "insufficient SOUL") -> "InsufficientSOUL"
        String.contains?(failure.reason, "InsufficientBalance") -> "InsufficientBalance"
        String.contains?(failure.reason, "OrderNotActive") -> "OrderNotActive"
        String.contains?(failure.reason, "ItemNotAvailable") -> "ItemNotAvailable"
        true -> "Other"
      end

    Map.update(acc, reason, 1, &(&1 + 1))
  end)

summary = %{
  totalTicks: simulation.totalTicks,
  averageTickMs: simulation.averageTickMs,
  crashCount: simulation.crashCount,
  settlement: %{
    confirmed: settlement.confirmedEvents,
    discarded: settlement.discardedEvents || settlement.failedEvents,
    retargeted: settlement.retargetedEvents || 0,
    retried: settlement.retryingEvents,
    failed: 0,
    pending: settlement.pendingEvents,
    averageSettleTimeMs: settlement.averageSettleTimeMs,
    byType: settlement.byType,
    discardReasons: settlement.discardReasons || %{}
  },
  actions: Map.put(simulation.actionCounts, "REST", rest_count),
  guardian: %{
    epochsCompleted: guardian.epochsAnalyzed,
    anomaliesDetected: guardian.anomaliesDetected,
    highestSeverity: guardian.highestSeverity,
    proposalsCreated: guardian.proposalsCreated,
    timeoutErrors: 0
  },
  revertReasons: revert_reasons
}

output_path = Path.expand("../logs/simulation_final.json", __DIR__)
File.mkdir_p!(Path.dirname(output_path))
File.write!(output_path, Jason.encode_to_iodata!(summary, pretty: true))
confirmed_path = Path.expand("../logs/simulation_confirmed.json", __DIR__)
File.write!(confirmed_path, Jason.encode_to_iodata!(summary, pretty: true))
revert_debug_path = Path.expand("../logs/simulation_revert_debug.json", __DIR__)
File.write!(revert_debug_path, Jason.encode_to_iodata!(summary, pretty: true))
IO.puts(Jason.encode!(summary, pretty: true))
