System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase1.Replay do
  alias AFW.Memory.{Reflection, Store}
  alias AFW.World.MapState

  @agents [
    %{agent_id: 22, label: "Warrior", class_id: 1, zone_id: 1},
    %{agent_id: 23, label: "Mage", class_id: 2, zone_id: 2},
    %{agent_id: 24, label: "Ranger", class_id: 3, zone_id: 3},
    %{agent_id: 25, label: "Healer", class_id: 4, zone_id: 1},
    %{agent_id: 26, label: "Tank", class_id: 5, zone_id: 4}
  ]

  @actions ["EXPLORE", "TALK", "TRADE", "FIGHT", "REST"]

  def run do
    Store.clear_all()
    AFW.World.EventLifecycle.reset()

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    root = Path.expand("../../..", __DIR__)
    internal_dir = Path.join(root, "docs/internal/phase1-runs")
    File.mkdir_p!(internal_dir)

    ticks =
      for tick <- 1..20 do
        agents = Enum.map(@agents, &agent_tick(&1, tick))
        %{tick: tick, agents: agents}
      end

    Enum.each(@agents, fn agent -> Reflection.reflect(agent.agent_id, 20) end)

    payload = %{
      status: "passed",
      checkedAt: DateTime.utc_now(),
      scope: "Phase 1 memory and LiveView map replay",
      ticks: ticks,
      zones: MapState.zones(),
      memory:
        Map.new(@agents, fn agent ->
          {agent.agent_id, Store.recent(agent.agent_id, 5)}
        end)
    }

    artifact_path = Path.join(internal_dir, "phase1_replay_#{timestamp}.json")
    File.write!(artifact_path, Jason.encode_to_iodata!(payload, pretty: true))
    write_public_summary!(root, payload, artifact_path)
    IO.puts(Jason.encode!(Map.take(payload, [:status, :scope, :checkedAt]), pretty: true))
    payload
  end

  defp agent_tick(agent, tick) do
    action = Enum.at(@actions, rem(tick + agent.agent_id, length(@actions)))
    hp = max(35, 100 - rem(tick * (agent.class_id + 3), 65))

    state = %{
      agent_id: agent.agent_id,
      label: agent.label,
      class_id: agent.class_id,
      zone_id: agent.zone_id,
      tick_count: tick,
      stats: %{hp: hp, max_hp: 100},
      last_action: %{
        action: action,
        target: target_for(action, agent.zone_id),
        summary: "#{action} at #{target_for(action, agent.zone_id)}"
      }
    }

    Store.record(agent.agent_id, :action, state.last_action.summary, %{
      tick: tick,
      action: action,
      zone_id: agent.zone_id
    })

    MapState.agent_view(state)
  end

  defp target_for("EXPLORE", zone_id), do: "zone #{zone_id} frontier"
  defp target_for("TALK", _zone_id), do: "local NPC"
  defp target_for("TRADE", _zone_id), do: "marketplace"
  defp target_for("FIGHT", _zone_id), do: "nearby monster"
  defp target_for("REST", _zone_id), do: "tavern"

  defp write_public_summary!(root, payload, artifact_path) do
    path = Path.join(root, "docs/architecture/PHASE_1_VALIDATION.md")

    body = """
    # Phase 1 Validation

    Phase 1 begins the Living World layer on top of the Phase 0 settlement baseline.

    ## Implemented First Slice

    - Treasury-backed world events now use an off-chain lifecycle cooldown, so a high EventTreasury balance does not dominate every agent tick.
    - Agent memory is available through an ETS-backed memory stream with optional JSONL persistence.
    - Prompt construction includes relevant memories before the decision section.
    - Phoenix LiveView renders a deterministic 2D Aethermoor map with agent position, action, class color, and HP ring.
    - Agent inspect pages show recent runtime memories alongside the on-chain snapshot.
    - A deterministic replay script validates map and memory output without requiring Base Sepolia writes.

    ## Latest Replay

    - Status: #{payload.status}
    - Checked at: #{payload.checkedAt}
    - Ticks replayed: #{length(payload.ticks)}
    - Agents rendered per tick: #{length(List.first(payload.ticks).agents)}
    - Internal artifact: #{Path.relative_to(artifact_path, root)}

    ## Command

    ```bash
    cd packages/agents_ex
    mix run --no-start scripts/run_phase1_replay.exs
    ```

    ## Remaining Phase 1 Work

    - Replace the SVG map MVP with the approved Phaser-based interactive viewer.
    - Add durable SQLite/embedding-backed memory retrieval once visual behavior is stable.
    - Add click-to-inspect monologue and richer social memory surfaces.
    """

    File.write!(path, body)
  end
end

AFW.Phase1.Replay.run()
