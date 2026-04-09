defmodule AFWWeb.CombatLogLive do
  use AFWWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, logs: [])}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Combat Log</h1>
      <p>Recent combat activity broadcast by agent and guardian processes.</p>
      <pre><%= inspect(@logs, pretty: true) %></pre>
    </section>
    """
  end
end
