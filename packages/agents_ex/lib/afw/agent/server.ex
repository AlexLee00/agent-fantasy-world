defmodule AFW.Agent.Server do
  @moduledoc "One GenServer per autonomous AFW agent."
  use GenServer
  require Logger

  alias AFW.Agent.State
  alias AFW.Agent.Loop
  alias AFW.Simulation.Metrics
  alias AFW.World.MapState

  def start_link(opts) do
    name =
      case opts[:agent_id] do
        nil -> []
        agent_id -> [name: via_tuple(agent_id)]
      end

    GenServer.start_link(__MODULE__, opts, name)
  end

  def via_tuple(agent_id), do: {:via, Registry, {AFW.AgentRegistry, agent_id}}

  def apply_reconciled_state(agent_id, attrs) do
    GenServer.cast(via_tuple(agent_id), {:apply_reconciled_state, attrs})
  catch
    :exit, _ -> :ok
  end

  @impl true
  def init(opts) do
    state = %State{
      agent_id: opts[:agent_id],
      label: opts[:label],
      class_id: opts[:class_id],
      personality: opts[:personality],
      tick_interval: opts[:tick_interval] || Application.fetch_env!(:afw, :tick_interval_ms),
      brain_module: opts[:brain_module] || AFW.Brain.Interface.provider_module(),
      zone_id: 1,
      level: 1,
      experience: 0,
      status: :alive,
      stats: %{hp: 100, max_hp: 100, mp: 50, max_mp: 50, attack: 20, defense: 15, speed: 10},
      history: [],
      tick_count: 0,
      max_ticks: opts[:max_ticks] || Application.fetch_env!(:afw, :simulation_ticks),
      post_combat_cooldown: 0,
      consecutive_trades: 0
    }

    schedule_tick(state.tick_interval)

    Logger.info(
      "Started AFW agent #{state.label || "Agent"} class=#{state.class_id} on-chain agentId=#{inspect(state.agent_id)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    started_at = System.monotonic_time(:millisecond)
    new_state = Loop.execute_tick(state)
    duration_ms = System.monotonic_time(:millisecond) - started_at
    action = (new_state.last_action || %{})[:action] || "IDLE"
    target = (new_state.last_action || %{})[:target] || "-"
    summary = (new_state.last_action || %{})[:summary] || "-"

    Logger.info(
      "[tick #{new_state.tick_count}] Agent##{new_state.agent_id} #{action} #{target} duration=#{duration_ms}ms summary=\"#{summary}\""
    )

    Metrics.record_tick(%{
      agent_id: new_state.agent_id,
      label: new_state.label,
      tick: new_state.tick_count,
      action: action,
      target: target,
      duration_ms: duration_ms
    })

    Phoenix.PubSub.broadcast(
      AFW.PubSub,
      "agents",
      {:agent_updated,
       Map.from_struct(new_state) |> Map.put(:map, MapState.agent_view(new_state))}
    )

    unless new_state.tick_count >= new_state.max_ticks do
      schedule_tick(new_state.tick_interval)
    end

    {:noreply, new_state}
  rescue
    error ->
      Phoenix.PubSub.broadcast(
        AFW.PubSub,
        "guardian",
        {:agent_crashed, state.agent_id, Exception.message(error)}
      )

      Metrics.record_crash(state.agent_id, Exception.message(error))

      reraise error, __STACKTRACE__
  end

  @impl true
  def handle_cast({:apply_reconciled_state, attrs}, state) do
    next_state =
      state
      |> maybe_put(:status, attrs[:status])
      |> maybe_put(:zone_id, attrs[:zone_id])
      |> maybe_put(:post_combat_cooldown, attrs[:post_combat_cooldown])
      |> maybe_merge_stats(attrs[:stats])

    {:noreply, next_state}
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end

  defp maybe_put(state, _key, nil), do: state
  defp maybe_put(state, key, value), do: Map.put(state, key, value)

  defp maybe_merge_stats(state, nil), do: state
  defp maybe_merge_stats(state, stats), do: %{state | stats: Map.merge(state.stats || %{}, stats)}
end
