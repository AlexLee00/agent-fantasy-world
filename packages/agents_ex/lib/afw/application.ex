defmodule AFW.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: AFW.PubSub},
      {Registry, keys: :unique, name: AFW.AgentRegistry},
      AFWWeb.Endpoint,
      {AFW.Chain.Cache, []},
      {AFW.Chain.Writer, Application.get_all_env(:afw)},
      {AFW.Settlement.Hub, []},
      {AFW.Combat.Stats, []},
      {AFW.Simulation.Metrics, []},
      {AFW.Agent.Supervisor, []},
      {AFW.Guardian.Monitor, []}
    ]

    opts = [strategy: :one_for_one, name: AFW.Supervisor]
    result = Supervisor.start_link(children, opts)

    case result do
      {:ok, pid} ->
        Task.start(fn -> boot_defaults() end)
        {:ok, pid}

      other ->
        other
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    AFWWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp boot_defaults do
    unless System.get_env("AFW_DISABLE_BOOT_AGENTS") in ["1", "true", "TRUE"] do
      Enum.each(Application.fetch_env!(:afw, :default_agents), fn attrs ->
        AFW.Agent.Supervisor.start_agent(attrs)
      end)
    end
  end
end
