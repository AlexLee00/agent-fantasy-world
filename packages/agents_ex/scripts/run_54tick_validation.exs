Application.ensure_all_started(:afw)

alias AFW.Agent.Supervisor
alias AFW.Guardian.Metrics, as: GuardianMetrics
alias AFW.Guardian.Monitor
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
Process.sleep(45_000)

settlement = SettlementMetrics.snapshot()
guardian = GuardianMetrics.snapshot()
rest_count = Map.get(simulation.actionCounts, "REST", 0)

summary = %{
  totalTicks: simulation.totalTicks,
  averageTickMs: simulation.averageTickMs,
  crashCount: simulation.crashCount,
  actionCounts: simulation.actionCounts,
  restCount: rest_count,
  settlement: settlement,
  guardian: guardian
}

IO.puts(Jason.encode!(summary, pretty: true))
