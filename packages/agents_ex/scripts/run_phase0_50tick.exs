System.put_env("AFW_DISABLE_ENDPOINT", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase0.FiftyTickRun do
  alias AFW.Agent.Supervisor, as: AgentSupervisor
  alias AFW.Chain.{Client, Preflight}
  alias AFW.Chain.Reader
  alias AFW.Guardian.{Economics, Monitor}
  alias AFW.Guardian.Metrics, as: GuardianMetrics
  alias AFW.Reconciliation.Metrics, as: ReconciliationMetrics
  alias AFW.Settlement.{Hub, Reconciler}
  alias AFW.Settlement.Metrics, as: SettlementMetrics
  alias AFW.Settlement.State, as: SettlementState
  alias AFW.Simulation.Metrics, as: SimulationMetrics

  @agent_templates [
    %{agent_id: 22, class_id: 1, label: "Phase0 Warrior", personality: [90, 10, 30, 80, 50]},
    %{agent_id: 23, class_id: 2, label: "Phase0 Mage", personality: [30, 80, 70, 40, 60]},
    %{agent_id: 24, class_id: 3, label: "Phase0 Ranger", personality: [50, 50, 90, 50, 50]},
    %{agent_id: nil, class_id: 4, label: "Phase0 Healer", personality: [20, 70, 60, 35, 95]},
    %{agent_id: nil, class_id: 5, label: "Phase0 Tank", personality: [65, 20, 35, 95, 40]}
  ]

  def run do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    root = Path.expand("../../..", __DIR__)
    artifact_dir = Path.join(root, "docs/internal/phase0-runs")
    File.mkdir_p!(artifact_dir)

    preflight_report = run_preflight!(artifact_dir, timestamp)
    seed_status = AFW.Seed.ensure!()

    target_ticks = env_int("PHASE0_TARGET_TICKS", 50)
    agent_count = env_int("PHASE0_AGENT_COUNT", 5)

    tick_interval =
      env_int("PHASE0_TICK_INTERVAL_MS", Application.fetch_env!(:afw, :tick_interval_ms))

    max_ticks = ceil_div(target_ticks, agent_count) + 1
    agents = ensure_agents(Enum.take(@agent_templates, agent_count))
    prime_agents_for_validation(agents)

    Enum.each(agents, fn attrs ->
      attrs
      |> Map.put(:tick_interval, tick_interval)
      |> Map.put(:max_ticks, max_ticks)
      |> AgentSupervisor.start_agent()
      |> case do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        other -> raise "Unable to start agent #{inspect(attrs)}: #{inspect(other)}"
      end
    end)

    wait_for_ticks!(target_ticks, max(target_ticks * tick_interval * 2, 120_000))
    initial_guardian_epochs = GuardianMetrics.snapshot().epochsAnalyzed
    Monitor.force_epoch()
    wait_for_guardian_epoch!(initial_guardian_epochs, 120_000)
    force_settlement()
    Reconciler.reconcile()
    Process.sleep(5_000)

    payload = build_payload(preflight_report, seed_status, agents)
    raw_path = Path.join(artifact_dir, "phase0_50tick_#{timestamp}.json")
    combat_path = Path.join(artifact_dir, "simulation_combat_debug_#{timestamp}.json")
    File.write!(raw_path, Jason.encode_to_iodata!(payload, pretty: true))
    File.write!(combat_path, Jason.encode_to_iodata!(payload.settlement, pretty: true))
    write_public_summary!(root, payload, raw_path, :fifty_tick)

    IO.puts(
      Jason.encode!(Map.take(payload, [:status, :criteria, :simulation, :settlement, :guardian]),
        pretty: true
      )
    )

    if payload.status != "passed" do
      raise "Phase 0 50-tick validation failed. Artifact: #{raw_path}"
    end

    payload
  end

  defp run_preflight!(artifact_dir, timestamp) do
    case Preflight.run() do
      {:ok, report} ->
        report

      {:error, report} ->
        path = Path.join(artifact_dir, "phase0_50tick_preflight_failed_#{timestamp}.json")
        File.write!(path, Jason.encode_to_iodata!(report, pretty: true))
        raise "Preflight failed. Details written to #{path}"
    end
  end

  defp ensure_agents(templates) do
    Enum.map(templates, fn attrs ->
      case Map.get(attrs, :agent_id) do
        nil ->
          case find_existing_agent(attrs.class_id, Enum.map(templates, & &1.agent_id)) do
            nil -> create_replacement(attrs)
            agent_id -> Map.put(attrs, :agent_id, agent_id)
          end

        agent_id ->
          if agent_exists?(agent_id), do: attrs, else: create_replacement(attrs)
      end
    end)
  end

  defp find_existing_agent(class_id, excluded_ids) do
    total = Reader.call_uint(:agent_registry, "totalAgents", [])
    excluded = excluded_ids |> Enum.reject(&is_nil/1) |> MapSet.new()

    total..1//-1
    |> Enum.find(fn agent_id ->
      try do
        if MapSet.member?(excluded, agent_id) do
          false
        else
          agent = Client.get_agent(agent_id)
          agent["classId"] == class_id and agent["statusId"] != 2
        end
      rescue
        _ -> false
      end
    end)
  rescue
    _ -> nil
  end

  defp create_replacement(attrs) do
    {:ok, created} = Client.create_agent(attrs.class_id, attrs.personality)
    Map.put(attrs, :agent_id, created.agent_id)
  end

  defp agent_exists?(agent_id) do
    Client.get_agent(agent_id)
    true
  rescue
    _ -> false
  end

  defp wait_for_ticks!(target_ticks, timeout_ms) do
    started = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> SimulationMetrics.snapshot() end)
    |> Enum.find(fn snapshot ->
      elapsed = System.monotonic_time(:millisecond) - started

      cond do
        snapshot.crashCount > 0 ->
          raise "Agent crash detected during 50-tick run: #{inspect(snapshot.recentCrashes)}"

        snapshot.totalTicks >= target_ticks ->
          true

        elapsed > timeout_ms ->
          raise "Timed out waiting for #{target_ticks} ticks; snapshot=#{inspect(snapshot)}"

        true ->
          Process.sleep(1_000)
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

  defp wait_for_guardian_epoch!(initial_epochs, timeout_ms) do
    started = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> GuardianMetrics.snapshot() end)
    |> Enum.find(fn snapshot ->
      elapsed = System.monotonic_time(:millisecond) - started

      cond do
        snapshot.epochsAnalyzed > initial_epochs ->
          true

        elapsed > timeout_ms ->
          raise "Timed out waiting for Guardian epoch completion; snapshot=#{inspect(snapshot)}"

        true ->
          Process.sleep(2_000)
          false
      end
    end)
  end

  defp build_payload(preflight_report, seed_status, agents) do
    simulation = SimulationMetrics.snapshot()
    settlement = SettlementMetrics.snapshot()
    guardian = GuardianMetrics.snapshot()
    reconciliation = ReconciliationMetrics.snapshot()
    economics = Economics.snapshot()
    alive_agents = count_alive(agents)
    rest_count = Map.get(simulation.actionCounts, "REST", 0)

    stale_discards =
      Enum.reduce(settlement.discardReasons, 0, fn {reason, count}, acc ->
        if String.contains?(reason, "order_not_active") or
             String.contains?(reason, "stale_snapshot") do
          acc + count
        else
          acc
        end
      end)

    criteria = %{
      fiveAgentsAlive: alive_agents >= 5,
      zeroCrashes: simulation.crashCount == 0,
      guardianEpoch: guardian.epochsAnalyzed >= 1,
      restActions: rest_count >= 5,
      staleMarketplaceDiscards: stale_discards < 5,
      zeroSettlementFailures: settlement.failedEvents == 0
    }

    %{
      status: if(Enum.all?(Map.values(criteria)), do: "passed", else: "failed"),
      checkedAt: DateTime.utc_now(),
      preflight: preflight_report,
      seed: seed_status,
      agents: Enum.map(agents, &Map.take(&1, [:agent_id, :class_id, :label])),
      aliveAgents: alive_agents,
      criteria: criteria,
      simulation: simulation,
      settlement: settlement,
      guardian: guardian,
      reconciliation: reconciliation,
      economy: economics
    }
  end

  defp count_alive(agents) do
    Enum.count(agents, fn %{agent_id: agent_id} ->
      try do
        agent = Client.get_agent(agent_id)
        agent["statusId"] != 2 and agent["statusName"] not in ["DEAD", "STATUS_2"]
      rescue
        _ -> false
      end
    end)
  end

  defp prime_agents_for_validation(agents) do
    Enum.each(agents, fn %{agent_id: agent_id} ->
      agent = Client.get_agent(agent_id)
      max_hp = get_in(agent, ["stats", "maxHp"]) || 100
      validation_hp = max(div(max_hp * 35, 100), 1)

      SettlementState.correct_offchain(agent_id, %{
        hp: validation_hp,
        statusId: 1,
        statusName: "ALIVE"
      })
    end)
  end

  defp write_public_summary!(root, payload, _raw_path, mode) do
    path = Path.join(root, "docs/architecture/PHASE_0_VALIDATION.md")

    body = """
    # Phase 0 Validation

    Last updated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    ## Latest Run

    - Mode: #{mode}
    - Status: #{payload.status}
    - Agents alive: #{payload.aliveAgents}
    - Total ticks: #{payload.simulation.totalTicks}
    - Average tick: #{payload.simulation.averageTickMs} ms
    - Settlement confirmed: #{payload.settlement.confirmedEvents}
    - Settlement failed: #{payload.settlement.failedEvents}
    - Settlement discarded: #{payload.settlement.discardedEvents}
    - Guardian epochs: #{payload.guardian.epochsAnalyzed}
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

AFW.Phase0.FiftyTickRun.run()
