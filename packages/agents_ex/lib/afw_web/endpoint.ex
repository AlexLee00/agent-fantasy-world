defmodule AFWWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :afw

  @session_options [
    store: :cookie,
    key: "_afw_key",
    signing_salt: "afw-liveview"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false
  )

  plug(Plug.Static,
    at: "/",
    from: :afw,
    gzip: false,
    only: AFWWeb.static_paths()
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AFWWeb.Router)
end
