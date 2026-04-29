defmodule AFW.Agent.Supervisor do
  @moduledoc "Dynamic supervisor for autonomous AFW agents."
  use DynamicSupervisor

  alias AFW.Agent.Server
  alias AFW.Chain.Client

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(attrs) do
    personality = Map.fetch!(attrs, :personality)
    class_id = Map.fetch!(attrs, :class_id)
    label = Map.get(attrs, :label, "Agent")

    result =
      case Map.get(attrs, :agent_id) do
        nil ->
          {:ok, created} = Client.create_agent(class_id, personality)
          created

        agent_id ->
          %{agent_id: agent_id}
      end

    spec = %{
      id: {:agent, result.agent_id},
      start:
        {Server, :start_link,
         [
           [
             agent_id: result.agent_id,
             class_id: class_id,
             personality: personality,
             label: label,
             tick_interval: Map.get(attrs, :tick_interval),
             max_ticks: Map.get(attrs, :max_ticks),
             brain_module: Map.get(attrs, :brain_module)
           ]
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
