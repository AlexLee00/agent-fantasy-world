defmodule AFWWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :afw

  socket("/live", Phoenix.LiveView.Socket,
    websocket: true,
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
  plug(AFWWeb.Router)
end
