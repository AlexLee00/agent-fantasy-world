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
       combat: AFW.Combat.Stats.snapshot(),
       guardian: %{},
       title: "AFW Dashboard"
     )}
  end

  @impl true
  def handle_info({:agent_updated, agent_state}, socket) do
    agents = upsert_agent(socket.assigns.agents, agent_state)
    {:noreply, assign(socket, agents: agents)}
  end

  def handle_info({:settlement_optimistic, agent_id, settlement}, socket) do
    {:noreply, assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:settlement_confirmed, agent_id, _event_id, _payload}, socket) do
    settlement = AFW.Settlement.State.settlement_summary(agent_id)
    {:noreply, assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:settlement_failed, agent_id, _event_id, _reason}, socket) do
    settlement = AFW.Settlement.State.settlement_summary(agent_id)
    {:noreply, assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:guardian_metrics, payload}, socket) do
    {:noreply, assign(socket, guardian: payload)}
  end

  def handle_info({:guardian_dashboard, payload}, socket) do
    {:noreply, assign(socket, guardian: payload)}
  end

  def handle_info({:combat_stats, payload}, socket) do
    {:noreply, assign(socket, combat: payload)}
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
        <div :if={agent[:settlement]}>
          SOUL: <%= agent.settlement.confirmedSoul %> (confirmed) + <%= agent.settlement.pendingSoul %> (pending) = <%= agent.settlement.displaySoul %>
        </div>
      </div>

      <h2>Guardian</h2>
      <div style="padding:12px;margin-bottom:16px;border-radius:14px;background:#f6fff7;border:1px solid #d9ead7;">
        <strong>Combat Success</strong>
        <div>
          Attempts: <%= @combat[:fight_attempts] || @combat["fight_attempts"] || 0 %>
          · Successes: <%= @combat[:fight_successes] || @combat["fight_successes"] || 0 %>
          · Failures: <%= @combat[:fight_failures] || @combat["fight_failures"] || 0 %>
          · Rate: <%= ((@combat[:success_rate] || @combat["success_rate"] || 0.0) * 100) |> Float.round(2) %>%
        </div>
      </div>
      <pre><%= Jason.encode_to_iodata!(@guardian, pretty: true) |> IO.iodata_to_binary() %></pre>
    </section>
    """
  end

  defp upsert_agent(agents, agent_state) do
    others = Enum.reject(agents, &(&1.agent_id == agent_state.agent_id))
    others ++ [agent_state]
  end

  defp update_agent_settlement(agents, agent_id, settlement) do
    Enum.map(agents, fn agent ->
      if agent.agent_id == agent_id do
        Map.put(agent, :settlement, settlement)
      else
        agent
      end
    end)
  end
end
