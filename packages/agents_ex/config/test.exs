import Config

config :afw, AFWWeb.Endpoint,
  server: false,
  secret_key_base: String.duplicate("afw_test_secret_", 8)

config :logger, level: :warning
