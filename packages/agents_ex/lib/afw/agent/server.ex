defmodule AFW.Agent.Server do
  @moduledoc "One GenServer per autonomous AFW agent."
  use GenServer
  require Logger

  alias AFW.Agent.State
  alias AFW.Agent.Loop

  def start_link(opts) do
    name =
      case opts[:agent_id] do
        nil -> []
        agent_id -> [name: via_tuple(agent_id)]
      end

    GenServer.start_link(__MODULE__, opts, name)
  end

  def via_tuple(agent_id), do: {:via, Registry, {AFW.AgentRegistry, agent_id}}

  @impl true
  def init(opts) do
    state = %State{
      agent_id: opts[:agent_id],
      label: opts[:label],
      class_id: opts[:class_id],
      personality: opts[:personality],
      tick_interval: opts[:tick_interval] || Application.fetch_env!(:afw, :tick_interval_ms),
      brain_module: opts[:brain_module] || AFW.Brain.ClaudeCode,
      zone_id: 1,
      level: 1,
      experience: 0,
      status: :alive,
      stats: %{hp: 100, max_hp: 100, mp: 50, max_mp: 50, attack: 20, defense: 15, speed: 10},
      history: [],
      tick_count: 0,
      max_ticks: opts[:max_ticks] || Application.fetch_env!(:afw, :simulation_ticks)
    }

    schedule_tick(state.tick_interval)
    Logger.info("Started AFW agent #{state.label || "Agent"} class=#{state.class_id} on-chain agentId=#{inspect(state.agent_id)}")
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state = Loop.execute_tick(state)
    action = (new_state.last_action || %{})[:action] || "IDLE"
    Logger.info("Agent ##{new_state.agent_id} tick=#{new_state.tick_count} action=#{action}")

    Phoenix.PubSub.broadcast(
      AFW.PubSub,
      "agents",
      {:agent_updated, Map.from_struct(new_state)}
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

      reraise error, __STACKTRACE__
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
end
