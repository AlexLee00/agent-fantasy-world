defmodule AFWWeb.AgentLive do
  use AFWWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    agent_id = String.to_integer(id)

    {:ok,
     assign(socket,
       agent_id: agent_id,
       agent: AFW.Chain.Client.get_agent(agent_id),
       memories: AFW.Memory.Store.recent(agent_id, 20)
     )}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Agent #<%= @agent_id %></h1>
      <h2>Recent Memory</h2>
      <div :if={@memories == []}>No memories recorded in this runtime session.</div>
      <div :for={memory <- @memories} style="padding:10px;margin-bottom:8px;border-radius:12px;background:#fffaf1;border:1px solid #ddd;">
        <strong><%= memory.type %></strong>
        <div><%= memory.content %></div>
        <small><%= memory.created_at %></small>
      </div>
      <h2>On-chain Snapshot</h2>
      <pre><%= inspect(@agent, pretty: true) %></pre>
    </section>
    """
  end
end
