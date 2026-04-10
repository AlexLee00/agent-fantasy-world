Application.ensure_all_started(:afw)

alias AFW.Agent.Server
alias AFW.Agent.Supervisor
alias AFW.Chain.Client
alias AFW.Guardian.Economics
alias AFW.Guardian.Metrics, as: GuardianMetrics
alias AFW.Reconciliation.Metrics, as: ReconciliationMetrics
alias AFW.Settlement.Metrics, as: SettlementMetrics
alias AFW.Simulation.Balance
alias AFW.Simulation.Metrics

log_path = Path.expand("../logs/simulation_100tick.json", __DIR__)
balance_path = Path.expand("../logs/balance_proposals.json", __DIR__)
File.mkdir_p!(Path.dirname(log_path))

if length(Client.get_monsters_in_zone(1)) == 0 or length(Client.get_npcs_in_zone(1)) == 0 do
  AFW.Seed.run()
end

agents = [
  %{agent_id: 22, class_id: 1, label: "Warrior", personality: [90, 10, 30, 80, 50], max_ticks: 34},
  %{agent_id: 23, class_id: 2, label: "Mage", personality: [30, 80, 70, 40, 60], max_ticks: 34},
  %{agent_id: 24, class_id: 3, label: "Ranger", personality: [50, 50, 90, 50, 50], max_ticks: 34}
]

Enum.each(agents, fn attrs ->
  case Supervisor.start_agent(attrs) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
    other -> IO.puts("agent start result=#{inspect(other)}")
  end
end)

wait_for_ticks = fn wait_for_ticks ->
  snapshot = Metrics.snapshot()

  if snapshot.totalTicks >= 102 do
    snapshot
  else
    Process.sleep(5_000)
    wait_for_ticks.(wait_for_ticks)
  end
end

_tick_snapshot = wait_for_ticks.(wait_for_ticks)
Process.sleep(310_000)

simulation = Metrics.snapshot()
settlement = SettlementMetrics.snapshot()
economy = Economics.snapshot()
guardian = GuardianMetrics.snapshot()
reconciliation = ReconciliationMetrics.snapshot()
balance = Balance.summary()

states =
  Enum.map(agents, fn %{agent_id: agent_id} ->
    case GenServer.whereis(Server.via_tuple(agent_id)) do
      nil ->
        %{agent_id: agent_id, tick_count: 0, down: true}

      pid ->
        try do
          server_state = :sys.get_state(pid, 30_000)
          %{agent_id: agent_id, tick_count: server_state.tick_count, down: false}
        catch
          :exit, _ -> %{agent_id: agent_id, tick_count: 0, down: true}
        end
    end
  end)

result = %{
  totalTicks: simulation.totalTicks,
  crashCount: simulation.crashCount,
  averageTickMs: simulation.averageTickMs,
  agents:
    Map.new(agents, fn %{agent_id: agent_id, label: label} ->
      chain_agent = Client.get_agent(agent_id)
      settlement_summary = AFW.Settlement.State.settlement_summary(agent_id)

      {agent_id,
       %{
         class: label,
         level: chain_agent["level"],
         soul: settlement_summary.displaySoul,
         status: chain_agent["statusName"],
         zoneId: chain_agent["zoneId"],
         ticks: simulation.perAgent[to_string(agent_id)] || simulation.perAgent[agent_id]
       }}
    end),
  actionDistribution: simulation.actionCounts,
  settlement: settlement,
  economy: %{
    totalSOULMinted: economy.soul.total_minted,
    totalSOULBurned: economy.soul.total_burned,
    circulatingSOUL: economy.soul.circulating,
    inflationRate: economy.soul.inflation_rate,
    giniCoefficient: economy.wealth.gini,
    treasuryBalance: economy.treasury.balance
  },
  guardian: guardian,
  reconciliation: reconciliation,
  recentServerStates: states
}

File.write!(log_path, Jason.encode_to_iodata!(result, pretty: true))
File.write!(balance_path, Jason.encode_to_iodata!(balance, pretty: true))

IO.puts("Wrote #{log_path}")
IO.puts("Wrote #{balance_path}")
IO.puts(Jason.encode!(result, pretty: true))
