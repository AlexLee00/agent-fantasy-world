defmodule AFW.Simulation.Metrics do
  @moduledoc "Collects simulation metrics and writes them to JSON for long-running verification."
  use GenServer

  @flush_every 5

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def record_tick(payload) when is_map(payload) do
    GenServer.cast(__MODULE__, {:tick, payload})
  end

  def record_crash(agent_id, reason) do
    GenServer.cast(__MODULE__, {:crash, agent_id, reason})
  end

  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @impl true
  def init(_opts) do
    {:ok,
     %{
       started_at: DateTime.utc_now(),
       total_ticks: 0,
       total_duration_ms: 0,
       action_counts: %{},
       per_agent: %{},
       crash_count: 0,
       crashes: [],
       last_tick_at: nil
     }}
  end

  @impl true
  def handle_cast({:tick, payload}, state) do
    agent_id = payload.agent_id
    duration_ms = payload.duration_ms || 0
    action = payload.action || "UNKNOWN"

    per_agent =
      Map.update(
        state.per_agent,
        agent_id,
        %{
          label: payload.label,
          ticks: 1,
          duration_ms: duration_ms,
          last_action: action,
          last_tick: payload.tick,
          action_counts: %{action => 1}
        },
        fn current ->
          %{
            current
            | label: payload.label || current.label,
              ticks: current.ticks + 1,
              duration_ms: current.duration_ms + duration_ms,
              last_action: action,
              last_tick: payload.tick,
              action_counts: Map.update(current.action_counts, action, 1, &(&1 + 1))
          }
        end
      )

    next_state = %{
      state
      | total_ticks: state.total_ticks + 1,
        total_duration_ms: state.total_duration_ms + duration_ms,
        action_counts: Map.update(state.action_counts, action, 1, &(&1 + 1)),
        per_agent: per_agent,
        last_tick_at: DateTime.utc_now()
    }

    maybe_flush(next_state)
    {:noreply, next_state}
  end

  def handle_cast({:crash, agent_id, reason}, state) do
    crash = %{agent_id: agent_id, reason: reason, at: DateTime.utc_now()}

    next_state = %{
      state
      | crash_count: state.crash_count + 1,
        crashes: Enum.take([crash | state.crashes], 20)
    }

    maybe_flush(next_state)
    {:noreply, next_state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, export(state), state}
  end

  defp maybe_flush(state) do
    if rem(state.total_ticks, @flush_every) == 0 or state.crash_count > 0 do
      path =
        Application.get_env(
          :afw,
          :simulation_metrics_path,
          "../agents/logs/simulation_metrics.json"
        )

      resolved = Path.expand(path, File.cwd!())
      File.mkdir_p!(Path.dirname(resolved))
      File.write!(resolved, Jason.encode_to_iodata!(export(state), pretty: true))
    end
  end

  defp export(state) do
    avg_tick_ms =
      if state.total_ticks == 0 do
        0.0
      else
        state.total_duration_ms / state.total_ticks
      end

    %{
      startedAt: state.started_at,
      lastTickAt: state.last_tick_at,
      totalTicks: state.total_ticks,
      averageTickMs: Float.round(avg_tick_ms, 2),
      actionCounts: state.action_counts,
      actionRatios: ratio_map(state.action_counts, state.total_ticks),
      crashCount: state.crash_count,
      recentCrashes: Enum.map(state.crashes, &stringify_crash/1),
      perAgent:
        Map.new(state.per_agent, fn {agent_id, payload} ->
          avg_agent_ms =
            if payload.ticks == 0 do
              0.0
            else
              payload.duration_ms / payload.ticks
            end

          {agent_id,
           %{
             label: payload.label,
             ticks: payload.ticks,
             averageTickMs: Float.round(avg_agent_ms, 2),
             lastAction: payload.last_action,
             lastTick: payload.last_tick,
             actionCounts: payload.action_counts,
             actionRatios: ratio_map(payload.action_counts, payload.ticks)
           }}
        end)
    }
  end

  defp ratio_map(_counts, 0), do: %{}

  defp ratio_map(counts, total) do
    Map.new(counts, fn {key, count} ->
      {key, Float.round(count / total, 4)}
    end)
  end

  defp stringify_crash(crash) do
    %{agentId: crash.agent_id, reason: crash.reason, at: crash.at}
  end
end
