defmodule AFWWeb.AgentLive do
  use AFWWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    agent_id = String.to_integer(id)
    agent = AFW.Chain.Client.get_agent(agent_id)

    {:ok,
     assign(socket,
       agent_id: agent_id,
       agent: agent,
       memories: AFW.Memory.Store.recent(agent_id, 20),
       dialogue: AFW.Social.Dialogue.for_agent(agent_id, 20),
       monologue: AFW.Memory.Monologue.for_agent(agent_id, agent)
     )}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Agent #<%= @agent_id %></h1>
      <h2>Monologue</h2>
      <div style="padding:14px;margin-bottom:14px;border-radius:14px;background:#f5f8ff;border:1px solid #d8def8;font-size:18px;line-height:1.5;">
        <%= @monologue %>
      </div>
      <h2>Recent Memory</h2>
      <div :if={@memories == []}>No memories recorded in this runtime session.</div>
      <div :for={memory <- @memories} style="padding:10px;margin-bottom:8px;border-radius:12px;background:#fffaf1;border:1px solid #ddd;">
        <strong><%= memory.type %></strong>
        <div><%= memory.content %></div>
        <small><%= memory.created_at %></small>
      </div>
      <h2>Dialogue Transcript</h2>
      <div :if={@dialogue == []}>No dialogue recorded in this runtime session.</div>
      <div :for={entry <- @dialogue} style="padding:10px;margin-bottom:8px;border-radius:12px;background:#f5f8ff;border:1px solid #d8def8;">
        <strong><%= entry.speaker %></strong>
        <div><%= entry.line %></div>
        <small><%= entry.created_at %></small>
      </div>
      <h2>On-chain Snapshot</h2>
      <pre><%= inspect(@agent, pretty: true) %></pre>
    </section>
    """
  end
end
