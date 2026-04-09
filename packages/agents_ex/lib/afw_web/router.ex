defmodule AFWWeb.Router do
  use AFWWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AFWWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", AFWWeb do
    pipe_through(:browser)

    live("/", DashboardLive)
    live("/agents/:id", AgentLive)
    live("/combat", CombatLogLive)
    live("/marketplace", MarketplaceLive)
    live("/treasury", TreasuryLive)
  end
end
