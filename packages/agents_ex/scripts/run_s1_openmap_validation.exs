# run_s1_openmap_validation.exs — S1 TS-3: 50-tick open-map integration run.
#
# Starts 5 agents near region boundaries (so transitions actually occur),
# runs ~50 ticks of tile-based movement, then force-settles and checks:
#   - every agent holds a passable tile position and moved (tile-based)
#   - region transition events >= 3
#   - settlement failures == 0, agent crashes == 0
#
# Usage:
#   NODE... (Elixir only, no Hardhat needed)
#   S1_TICK_INTERVAL_MS=3000 mix run scripts/run_s1_openmap_validation.exs
#
# Artifacts: docs/internal/phase3-runs/s1_openmap_50tick_<ts>.json (gitignored)
#            docs/architecture/PHASE_3_S1_VALIDATION.md (public summary)

System.put_env("AFW_DISABLE_ENDPOINT", "1")
System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase3.S1OpenMapValidation do
  alias AFW.Agent.Supervisor, as: AgentSupervisor
  alias AFW.Chain.{Client, Preflight, Reader}
  alias AFW.Settlement.{Hub, Reconciler}
  alias AFW.Settlement.Metrics, as: SettlementMetrics
  alias AFW.Simulation.Metrics, as: SimulationMetrics
  alias AFW.World.Grid

  @samples :s1_validation_samples

  # spawn tiles sit directly on/next to the Havenmoor hub boundary so that
  # boundary crossings actually occur within a 50-tick budget
  @agent_templates [
    %{agent_id: 22, class_id: 1, label: "S1 Warrior", personality: [90, 10, 30, 80, 50], pos: {208, 230}},
    %{agent_id: 23, class_id: 2, label: "S1 Mage", personality: [30, 80, 70, 40, 60], pos: {303, 270}},
    %{agent_id: 24, class_id: 3, label: "S1 Ranger", personality: [50, 50, 90, 50, 50], pos: {230, 208}},
    %{agent_id: nil, class_id: 4, label: "S1 Healer", personality: [20, 70, 60, 35, 95], pos: {207, 270}},
    %{agent_id: nil, class_id: 5, label: "S1 Tank", personality: [65, 20, 35, 95, 40], pos: {270, 207}}
  ]

  def run do
    Grid.load!()

    Enum.each(@agent_templates, fn %{pos: {x, y}} ->
      unless Grid.passable?(x, y), do: raise("validation spawn {#{x},#{y}} is not passable")
    end)

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    root = Path.expand("../../..", __DIR__)
    artifact_dir = Path.join(root, "docs/internal/phase3-runs")
    File.mkdir_p!(artifact_dir)

    run_preflight!(artifact_dir, timestamp)
    seed_status = AFW.Seed.ensure!()

    target_ticks = env_int("S1_TARGET_TICKS", 50)
    tick_interval = env_int("S1_TICK_INTERVAL_MS", 3_000)
    agents = ensure_agents(@agent_templates)
    agent_ids = Enum.map(agents, & &1.agent_id)
    max_ticks = div(target_ticks + length(agents) - 1, length(agents)) + 1

    ensure_samples_table!()
    sampler = spawn_link(fn -> sample_loop(agent_ids) end)

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

    wait_for_ticks!(target_ticks, max(target_ticks * tick_interval * 3, 180_000))
    Process.sleep(2_000)
    send(sampler, :stop)

    force_settlement()
    Reconciler.reconcile()
    Process.sleep(5_000)

    payload = build_payload(seed_status, agents, target_ticks)
    raw_path = Path.join(artifact_dir, "s1_openmap_50tick_#{timestamp}.json")
    File.write!(raw_path, Jason.encode_to_iodata!(payload, pretty: true))
    write_public_summary!(root, payload)

    IO.puts(Jason.encode!(Map.take(payload, [:status, :criteria, :movement]), pretty: true))

    if payload.status != "passed" do
      raise "S1 open-map 50-tick validation failed. Artifact: #{raw_path}"
    end

    IO.puts("artifact: #{raw_path}")
    payload
  end

  defp run_preflight!(artifact_dir, timestamp) do
    case Preflight.run() do
      {:ok, report} ->
        report

      {:error, report} ->
        path = Path.join(artifact_dir, "s1_preflight_failed_#{timestamp}.json")
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

  defp ensure_samples_table! do
    case :ets.whereis(@samples) do
      :undefined -> :ets.new(@samples, [:named_table, :public, :set])
      _ -> @samples
    end
  end

  defp sample_loop(agent_ids) do
    Hub.queued_events_snapshot()
    |> Enum.filter(&(&1.type == :region_transition))
    |> Enum.each(fn event ->
      :ets.insert(@samples, {{:transition, event.id}, event.data})
    end)

    Enum.each(agent_ids, fn agent_id ->
      case Registry.lookup(AFW.AgentRegistry, agent_id) do
        [{pid, _}] ->
          try do
            state = :sys.get_state(pid, 500)

            if state.pos do
              :ets.insert(@samples, {{:pos, agent_id, state.pos}, true})
              track_region(agent_id, state.pos)
            end
          catch
            _, _ -> :ok
          end

        _ ->
          :ok
      end
    end)

    receive do
      :stop -> :ok
    after
      300 -> sample_loop(agent_ids)
    end
  end

  # position-derived crossing detection: robust even when a queued
  # region_transition event settles between two queue samples
  defp track_region(agent_id, {x, y}) do
    region = Grid.region_at(x, y)

    case :ets.lookup(@samples, {:last_region, agent_id}) do
      [{_key, ^region}] ->
        :ok

      [{_key, previous}] when region > 0 ->
        :ets.insert(
          @samples,
          {{:crossing, agent_id, :erlang.unique_integer([:monotonic])}, {previous, region}}
        )

        :ets.insert(@samples, {{:last_region, agent_id}, region})

      [] ->
        :ets.insert(@samples, {{:last_region, agent_id}, region})

      _other ->
        :ok
    end
  end

  defp wait_for_ticks!(target_ticks, timeout_ms) do
    started = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> SimulationMetrics.snapshot() end)
    |> Enum.find(fn snapshot ->
      elapsed = System.monotonic_time(:millisecond) - started

      cond do
        snapshot.crashCount > 0 ->
          raise "Agent crash detected during S1 run: #{inspect(snapshot.recentCrashes)}"

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

  defp build_payload(seed_status, agents, target_ticks) do
    simulation = SimulationMetrics.snapshot()
    settlement = SettlementMetrics.snapshot()

    samples = :ets.tab2list(@samples)

    transitions =
      for {{:transition, id}, data} <- samples do
        %{id: id, from: data[:from_region], to: data[:to_region], agent_id: data[:agent_id]}
      end

    crossings =
      for {{:crossing, agent_id, _seq}, {from, to}} <- samples do
        %{agent_id: agent_id, from: from, to: to}
      end

    positions_by_agent =
      samples
      |> Enum.flat_map(fn
        {{:pos, agent_id, pos}, _} -> [{agent_id, pos}]
        _ -> []
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    movement =
      Map.new(agents, fn %{agent_id: agent_id} ->
        positions = Enum.uniq(Map.get(positions_by_agent, agent_id, []))

        {agent_id,
         %{
           distinct_tiles: length(positions),
           all_passable: Enum.all?(positions, fn {x, y} -> Grid.passable?(x, y) end),
           sample: Enum.take(positions, 5) |> Enum.map(fn {x, y} -> [x, y] end)
         }}
      end)

    observed_transitions = max(length(transitions), length(crossings))

    criteria = %{
      allAgentsTileMoving:
        Enum.all?(movement, fn {_id, m} -> m.distinct_tiles >= 2 and m.all_passable end),
      regionTransitions: observed_transitions >= 3,
      zeroSettlementFailures: settlement.failedEvents == 0,
      zeroCrashes: simulation.crashCount == 0,
      targetTicksReached: simulation.totalTicks >= target_ticks
    }

    %{
      status: if(Enum.all?(Map.values(criteria)), do: "passed", else: "failed"),
      checkedAt: DateTime.utc_now(),
      seed: seed_status,
      agents: Enum.map(agents, &Map.take(&1, [:agent_id, :class_id, :label])),
      criteria: criteria,
      movement: movement,
      transitions: transitions,
      crossings: crossings,
      transitionCount: observed_transitions,
      simulation: simulation,
      settlement: settlement
    }
  end

  defp write_public_summary!(root, payload) do
    path = Path.join(root, "docs/architecture/PHASE_3_S1_VALIDATION.md")

    body = """
    # Phase 3 / S1 Open Map Validation

    Last updated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    ## Latest Run (TS-3)

    - Status: #{payload.status}
    - Total ticks: #{payload.simulation.totalTicks}
    - Average tick: #{payload.simulation.averageTickMs} ms
    - Region transitions observed: #{payload.transitionCount}
    - Settlement confirmed: #{payload.settlement.confirmedEvents}
    - Settlement failed: #{payload.settlement.failedEvents}
    - Settlement discarded: #{payload.settlement.discardedEvents}

    ## Exit Criteria Snapshot

    ```json
    #{Jason.encode!(payload.criteria, pretty: true)}
    ```

    Raw run artifacts are stored under `docs/internal/phase3-runs/` and are
    intentionally ignored by Git.
    """

    File.write!(path, body)
  end

  defp env_int(name, default) do
    case System.get_env(name) do
      nil -> default
      value -> String.to_integer(value)
    end
  end
end

AFW.Phase3.S1OpenMapValidation.run()
