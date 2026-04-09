defmodule AFWWeb.MarketplaceLive do
  use AFWWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, orders: AFW.Chain.Client.active_orders())}
  end

  def render(assigns) do
    ~H"""
    <section>
      <h1>Marketplace Orders</h1>
      <div :for={order <- @orders}>
        Order #<%= order.order_id %> · item <%= order.item_id %> · price <%= order.price_in_soul %>
      </div>
    </section>
    """
  end
end
