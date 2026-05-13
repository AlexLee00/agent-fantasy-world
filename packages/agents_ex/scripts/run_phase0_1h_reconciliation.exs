System.put_env("AFW_DISABLE_ENDPOINT", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase0.ReconciliationRun do
  alias AFW.Agent.Supervisor, as: AgentSupervisor
  alias AFW.Chain.{Client, Preflight}
  alias AFW.Guardian.Monitor
  alias AFW.Reconciliation.Metrics, as: ReconciliationMetrics
  alias AFW.Settlement.{Hub, Reconciler}
  alias AFW.Settlement.Metrics, as: SettlementMetrics
  alias AFW.Simulation.Metrics, as: SimulationMetrics

  @personalities [
    [90, 10, 30, 80, 50],
    [30, 80, 70, 40, 60],
    [50, 50, 90, 50, 50],
    [20, 70, 60, 35, 95],
    [65, 20, 35, 95, 40],
    [75, 25, 45, 70, 40],
    [35, 85, 75, 35, 65],
    [45, 45, 95, 55, 50],
    [25, 60, 55, 45, 90],
    [80, 30, 30, 100, 35]
  ]

  def run do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    root = Path.expand("../../..", __DIR__)
    artifact_dir = Path.join(root, "docs/internal/phase0-runs")
    File.mkdir_p!(artifact_dir)

    preflight_report = run_preflight!(artifact_dir, timestamp)
    seed_status = AFW.Seed.ensure!()

    agent_count = env_int("PHASE0_LOAD_AGENT_COUNT", 10)
    duration_ms = env_int("PHASE0_LOAD_DURATION_MS", 3_600_000)
    tick_interval = env_int("PHASE0_TICK_INTERVAL_MS", Application.fetch_env!(:afw, :tick_interval_ms))
    agents = ensure_agents(agent_count)
    max_ticks = ceil_div(duration_ms, tick_interval) + 5

    Enum.each(agents, fn attrs ->
      attrs
      |> Map.put(:tick_interval, tick_interval)
      |> Map.put(:max_ticks, max_ticks)
      |> AgentSupervisor.start_agent()
      |> case do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        other -> raise "Unable to start load agent #{inspect(attrs)}: #{inspect(other)}"
      end
    end)

    wait_for_duration!(duration_ms)
    Monitor.force_epoch()
    force_settlement()
    Reconciler.reconcile()
    Process.sleep(5_000)

    payload = build_payload(preflight_report, seed_status, agents, duration_ms)
    raw_path = Path.join(artifact_dir, "phase0_1h_reconciliation_#{timestamp}.json")
    File.write!(raw_path, Jason.encode_to_iodata!(payload, pretty: true))
    write_public_summary!(root, payload, :one_hour_reconciliation)
    IO.puts(Jason.encode!(Map.take(payload, [:status, :criteria, :simulation, :settlement, :reconciliation]), pretty: true))

    if payload.status != "passed" do
      raise "Phase 0 one-hour reconciliation validation failed. Artifact: #{raw_path}"
    end

    payload
  end

  defp run_preflight!(artifact_dir, timestamp) do
    case Preflight.run() do
      {:ok, report} ->
        report

      {:error, report} ->
        path = Path.join(artifact_dir, "phase0_1h_preflight_failed_#{timestamp}.json")
        File.write!(path, Jason.encode_to_iodata!(report, pretty: true))
        raise "Preflight failed. Details written to #{path}"
    end
  end

  defp ensure_agents(count) do
    Enum.map(1..count, fn index ->
      class_id = rem(index - 1, 5) + 1
      personality = Enum.at(@personalities, rem(index - 1, length(@personalities)))
      {:ok, created} = Client.create_agent(class_id, personality)

      %{
        agent_id: created.agent_id,
        class_id: class_id,
        label: "Phase0 Load #{index}",
        personality: personality
      }
    end)
  end

  defp wait_for_duration!(duration_ms) do
    started = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> SimulationMetrics.snapshot() end)
    |> Enum.find(fn snapshot ->
      elapsed = System.monotonic_time(:millisecond) - started

      cond do
        snapshot.crashCount > 0 ->
          raise "Agent crash detected during reconciliation run: #{inspect(snapshot.recentCrashes)}"

        elapsed >= duration_ms ->
          true

        true ->
          Process.sleep(5_000)
          false
      end
    end)
  end

  defp force_settlement do
    hub = Process.whereis(Hub)
    if hub, do: send(hub, {:settle, :normal})
    if hub, do: send(hub, {:settle, :batch})
    Process.sleep(20_000)
  end

  defp build_payload(preflight_report, seed_status, agents, duration_ms) do
    simulation = SimulationMetrics.snapshot()
    settlement = SettlementMetrics.snapshot()
    reconciliation = ReconciliationMetrics.snapshot()

    criteria = %{
      tenAgentsStarted: length(agents) >= 10,
      zeroCrashes: simulation.crashCount == 0,
      zeroSettlementFailures: settlement.failedEvents == 0,
      zeroReconciliationDrift: reconciliation.mismatchesFound == 0,
      checksPerformed: reconciliation.checksPerformed > 0
    }

    %{
      status: if(Enum.all?(Map.values(criteria)), do: "passed", else: "failed"),
      checkedAt: DateTime.utc_now(),
      durationMs: duration_ms,
      preflight: preflight_report,
      seed: seed_status,
      agents: Enum.map(agents, &Map.take(&1, [:agent_id, :class_id, :label])),
      criteria: criteria,
      simulation: simulation,
      settlement: settlement,
      reconciliation: reconciliation
    }
  end

  defp write_public_summary!(root, payload, mode) do
    path = Path.join(root, "docs/architecture/PHASE_0_VALIDATION.md")

    body = """
    # Phase 0 Validation

    Last updated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    ## Latest Run

    - Mode: #{mode}
    - Status: #{payload.status}
    - Duration: #{payload.durationMs} ms
    - Agents started: #{length(payload.agents)}
    - Total ticks: #{payload.simulation.totalTicks}
    - Average tick: #{payload.simulation.averageTickMs} ms
    - Settlement confirmed: #{payload.settlement.confirmedEvents}
    - Settlement failed: #{payload.settlement.failedEvents}
    - Reconciliation checks: #{payload.reconciliation.checksPerformed}
    - Reconciliation mismatches: #{payload.reconciliation.mismatchesFound}

    ## Exit Criteria Snapshot

    ```json
    #{Jason.encode!(payload.criteria, pretty: true)}
    ```

    Raw run artifacts are stored under `docs/internal/phase0-runs/` and are intentionally ignored by Git.
    """

    File.write!(path, body)
  end

  defp env_int(name, default) do
    case System.get_env(name) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp ceil_div(a, b), do: div(a + b - 1, b)
end

AFW.Phase0.ReconciliationRun.run()
