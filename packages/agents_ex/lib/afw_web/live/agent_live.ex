defmodule AFWWeb.AgentLive do
  use AFWWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, agent_id: id, agent: AFW.Chain.Client.get_agent(String.to_integer(id)))}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Agent #<%= @agent_id %></h1>
      <pre><%= inspect(@agent, pretty: true) %></pre>
    </section>
    """
  end
end
