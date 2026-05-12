System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")

Application.put_env(:afw, :tier4_node_backend, System.get_env("TIER4_NODE_BACKEND", "afw-basic"))

Application.put_env(
  :afw,
  :tier4_node_port,
  String.to_integer(System.get_env("TIER4_NODE_PORT", "18791"))
)

Application.put_env(:afw, :tier4_node_public_url, System.get_env("TIER4_NODE_PUBLIC_URL", ""))

Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)
Application.ensure_all_started(:req)
Application.ensure_all_started(:plug_cowboy)

port = Application.get_env(:afw, :tier4_node_port, 18_791)
endpoint = AFW.Tier4.NodeServer.infer_url()

{:ok, _pid} = AFW.Tier4.NodeServer.start_link(port: port)

IO.puts(
  Jason.encode!(
    %{
      status: "running",
      service: "afw-tier4-node",
      port: port,
      inferEndpoint: endpoint,
      healthEndpoint: String.replace(endpoint, ~r{/infer$}, "/health"),
      backend: Application.get_env(:afw, :tier4_node_backend, "afw-basic")
    },
    pretty: true
  )
)

Process.sleep(:infinity)
