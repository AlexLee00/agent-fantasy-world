defmodule AFWWeb.Layouts do
  use AFWWeb, :html

  def root(assigns) do
    ~H"""
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>AFW Live Dashboard</title>
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
