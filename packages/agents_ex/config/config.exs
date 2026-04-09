import Config

config :afw,
  ecto_repos: [],
  generators: [binary_id: false]

config :afw, AFWWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [html: AFWWeb.ErrorHTML, json: AFWWeb.ErrorJSON], layout: false],
  pubsub_server: AFW.PubSub,
  live_view: [signing_salt: "afw-liveview"],
  secret_key_base: String.duplicate("afw_secret_", 8)

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
