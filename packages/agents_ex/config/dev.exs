import Config

config :afw, AFWWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: String.duplicate("afw_dev_secret_", 8),
  watchers: []

config :logger, level: :info
