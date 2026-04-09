defmodule AFW.MixProject do
  use Mix.Project

  def project do
    [
      app: :afw,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {AFW.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ethereumex, "~> 0.10"},
      {:ex_abi, "~> 0.7"},
      {:ex_keccak, "~> 0.7"},
      {:ex_secp256k1, "~> 0.7"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_cowboy, "~> 2.7"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:dotenvy, "~> 0.8"}
    ]
  end

  defp aliases do
    [
      seed: ["run -e 'AFW.Seed.run()'"]
    ]
  end
end
