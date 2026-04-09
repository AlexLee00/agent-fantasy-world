defmodule AFWWeb.TreasuryLive do
  use AFWWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, treasury_balance: AFW.Chain.Client.get_treasury_balance())}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Event Treasury</h1>
      <p>Current treasury balance: <%= @treasury_balance %></p>
    </section>
    """
  end
end
