defmodule AFWWeb.DashboardLive do
  use AFWWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AFW.PubSub, "agents")
      Phoenix.PubSub.subscribe(AFW.PubSub, "guardian")
    end

    {:ok,
     assign(socket,
       agents: [],
       guardian: %{},
       title: "AFW Dashboard"
     )}
  end

  @impl true
  def handle_info({:agent_updated, agent_state}, socket) do
    agents = upsert_agent(socket.assigns.agents, agent_state)
    {:noreply, assign(socket, agents: agents)}
  end

  def handle_info({:guardian_metrics, payload}, socket) do
    {:noreply, assign(socket, guardian: payload)}
  end

  def handle_info({:guardian_dashboard, payload}, socket) do
    {:noreply, assign(socket, guardian: payload)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section>
      <h1>Agent Fantasy World</h1>
      <p>Primary Elixir/OTP runtime with GenServer agents, Guardian, and LiveView telemetry.</p>

      <h2>Agents</h2>
      <div :for={agent <- @agents} style="padding:12px;margin-bottom:10px;border-radius:14px;background:#fffaf1;border:1px solid #ddd;">
        <strong><%= agent.label || "Agent" %> #<%= agent.agent_id %></strong>
        <div>Tick: <%= agent.tick_count %> · Last action: <%= (agent.last_action || %{})[:action] || "idle" %></div>
      </div>

      <h2>Guardian</h2>
      <pre><%= Jason.encode_to_iodata!(@guardian, pretty: true) |> IO.iodata_to_binary() %></pre>
    </section>
    """
  end

  defp upsert_agent(agents, agent_state) do
    others = Enum.reject(agents, &(&1.agent_id == agent_state.agent_id))
    others ++ [agent_state]
  end
end
