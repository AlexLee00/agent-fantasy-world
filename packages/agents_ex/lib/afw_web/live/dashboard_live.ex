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
       zones: AFW.World.MapState.zones(),
       combat: AFW.Combat.Stats.snapshot(),
       guardian: %{},
       guardian_alerts: [],
       world_event: nil,
       title: "AFW Dashboard"
     )}
  end

  @impl true
  def handle_info({:agent_updated, agent_state}, socket) do
    agents = upsert_agent(socket.assigns.agents, agent_state)
    {:noreply, assign(socket, agents: agents)}
  end

  def handle_info({:settlement_optimistic, agent_id, settlement}, socket) do
    {:noreply,
     assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:settlement_confirmed, agent_id, _event_id, _payload}, socket) do
    settlement = AFW.Settlement.State.settlement_summary(agent_id)

    {:noreply,
     assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:settlement_failed, agent_id, _event_id, _reason}, socket) do
    settlement = AFW.Settlement.State.settlement_summary(agent_id)

    {:noreply,
     assign(socket, agents: update_agent_settlement(socket.assigns.agents, agent_id, settlement))}
  end

  def handle_info({:guardian_metrics, payload}, socket) do
    alerts = build_alerts(payload)
    {:noreply, assign(socket, guardian: payload, guardian_alerts: alerts)}
  end

  def handle_info({:guardian_dashboard, payload}, socket) do
    alerts = build_alerts(payload)
    {:noreply, assign(socket, guardian: payload, guardian_alerts: alerts)}
  end

  def handle_info({:world_event_triggered, payload}, socket) do
    {:noreply, assign(socket, world_event: payload)}
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

      <div :if={@world_event} style="padding:12px;margin-bottom:16px;border-radius:14px;background:#fff2dc;border:1px solid #e8bb6b;">
        <strong>World Event</strong>
        <div><%= @world_event.type || @world_event[:type] %> is now active.</div>
      </div>

      <div :for={alert <- @guardian_alerts} style="padding:12px;margin-bottom:12px;border-radius:14px;background:#ffe9e9;border:1px solid #ffb3b3;">
        <strong>Guardian <%= String.upcase(alert.severity) %></strong>
        <div><%= alert.message %></div>
      </div>

      <h2>Aethermoor Map</h2>
      <div style="padding:14px;border-radius:18px;background:#f8f3e8;border:1px solid #dfd2ba;margin-bottom:18px;">
        <div
          id="aethermoor-phaser"
          phx-hook="AethermoorPhaser"
          phx-update="ignore"
          data-zones={Jason.encode!(@zones)}
          data-agents={Jason.encode!(map_agents(@agents))}
          style="min-height:360px;border-radius:16px;overflow:hidden;background:#16120d;"
        >
          <div style="padding:16px;color:#f7e8c7;">
            Loading Phaser world viewer...
          </div>
        </div>
        <div style="margin-top:8px;color:#6b5a46;font-size:13px;">
          Phaser 4 viewer. Click an agent marker to inspect its on-chain state and memory.
        </div>
      </div>

      <h2>Economy</h2>
      <div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:18px;">
        <div style="padding:12px;border-radius:14px;background:#f6fff7;border:1px solid #d9ead7;">
          <strong>SOUL Supply</strong>
          <div>Minted: <%= get_in(@guardian, [:economy, :totalSOULMinted]) || 0 %></div>
          <div>Burned: <%= get_in(@guardian, [:economy, :totalSOULBurned]) || 0 %></div>
          <div>Inflation: <%= pct(get_in(@guardian, [:economy, :inflationRate]) || 0) %></div>
        </div>
        <div style="padding:12px;border-radius:14px;background:#f5f8ff;border:1px solid #d8def8;">
          <strong>Distribution</strong>
          <div>Gini: <%= get_in(@guardian, [:agents, :wealthGini]) || 0 %></div>
          <div>Queued settlements: <%= @guardian[:queuedEvents] || 0 %></div>
          <div>Proposals: <%= length(@guardian[:balanceProposals] || []) %></div>
        </div>
        <div style="padding:12px;border-radius:14px;background:#fffaf1;border:1px solid #eadfca;">
          <strong>EventTreasury</strong>
          <div>Balance: <%= get_in(@guardian, [:treasury, :balance]) || 0 %></div>
          <div>Next: <%= get_in(@guardian, [:treasury, :nextEvent]) || "MINI" %></div>
          <div>Remaining: <%= get_in(@guardian, [:treasury, :remainingToNext]) || 0 %></div>
        </div>
      </div>

      <h2>Agents</h2>
      <div :for={agent <- @agents} style="padding:12px;margin-bottom:10px;border-radius:14px;background:#fffaf1;border:1px solid #ddd;">
        <strong>
          <.link navigate={"/agents/#{agent.agent_id}"}><%= agent.label || "Agent" %> #<%= agent.agent_id %></.link>
        </strong>
        <div>Tick: <%= agent.tick_count %> · Last action: <%= (agent.last_action || %{})[:action] || "idle" %></div>
        <div :if={agent[:settlement]}>
          SOUL: <%= agent.settlement.confirmedSoul %> (confirmed) + <%= agent.settlement.pendingSoul %> (pending) = <%= agent.settlement.displaySoul %>
          · <%= settlement_status(agent.settlement.recentEvents || []) %>
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
      <div :if={@guardian[:balanceProposals] && @guardian[:balanceProposals] != []} style="padding:12px;margin-bottom:16px;border-radius:14px;background:#f9f4ff;border:1px solid #ddcef2;">
        <strong>Balance Proposals</strong>
        <div :for={proposal <- @guardian[:balanceProposals]}><%= proposal %></div>
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

  defp build_alerts(payload) do
    anomalies = payload[:anomalies] || []
    severity = payload[:severity] || "low"

    if anomalies == [] and severity == "low" do
      []
    else
      [
        %{
          severity: severity,
          message:
            "#{length(anomalies)} anomaly signals detected. Proposed action: #{payload[:proposedAction] || "OBSERVE"}."
        }
      ]
    end
  end

  defp pct(value) when is_number(value), do: "#{Float.round(value * 100.0, 2)}%"
  defp pct(_), do: "0.0%"

  defp map_agents(agents), do: Enum.map(agents, &map_agent/1)
  defp map_agent(agent), do: agent[:map] || AFW.World.MapState.agent_view(agent)

  defp settlement_status([latest | _]) do
    case latest[:status] do
      :confirmed -> "✓ confirmed"
      :failed -> "✗ failed"
      _ -> "⏳ settling"
    end
  end

  defp settlement_status(_), do: "✓ confirmed"
end
