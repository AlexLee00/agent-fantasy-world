defmodule AFWWeb.Layouts do
  use AFWWeb, :html

  def root(assigns) do
    ~H"""
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>AFW Live Dashboard</title>
        <script defer src="/deps/phoenix/phoenix.min.js">
        </script>
        <script defer src="/deps/phoenix_live_view/phoenix_live_view.min.js">
        </script>
        <script defer src="https://cdn.jsdelivr.net/npm/phaser@4.0.0/dist/phaser.min.js">
        </script>
        <script defer src="/assets/afw_live.js">
        </script>
      </head>
      <body style="margin:0;font-family:system-ui;background:#f3ede2;color:#1f1b16;">
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <main style="max-width:1280px;margin:0 auto;padding:24px;">
      <%= @inner_content %>
    </main>
    """
  end
end
