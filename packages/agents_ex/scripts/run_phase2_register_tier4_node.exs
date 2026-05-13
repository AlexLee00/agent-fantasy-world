System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
System.put_env("AFW_DISABLE_ENDPOINT", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase2.RegisterTier4Node do
  alias AFW.Chain.Client
  alias AFW.Tier4.EndpointVerifier

  def run do
    endpoint =
      System.get_env("TIER4_NODE_ENDPOINT") ||
        System.get_env("TIER4_NODE_PUBLIC_URL") ||
        raise "Set TIER4_NODE_ENDPOINT or TIER4_NODE_PUBLIC_URL before registering a Tier 4 node."

    infer_endpoint = EndpointVerifier.normalize_infer_endpoint(endpoint)
    verify_endpoint!(infer_endpoint)

    operator = Client.account_address()
    active_nodes = Client.get_node_stats()

    registration =
      case Enum.find(active_nodes, &same_address?(&1.address, operator)) do
        nil ->
          register(operator, infer_endpoint)

        %{endpoint: ^infer_endpoint} = node ->
          %{status: "already_registered", operator: operator, endpoint: node.endpoint}

        node ->
          raise """
          Operator wallet #{operator} is already registered with #{node.endpoint}.
          NodeRegistry does not support endpoint updates yet. Use a fresh operator wallet
          for the public endpoint or schedule a contract upgrade.
          """
      end

    payload = %{
      status: "passed",
      operator: operator,
      endpoint: infer_endpoint,
      registration: registration,
      activeNodes: Client.get_node_stats()
    }

    IO.puts(Jason.encode!(payload, pretty: true))
    payload
  end

  defp verify_endpoint!(endpoint) do
    if System.get_env("TIER4_SKIP_ENDPOINT_VERIFY", "false") in ["1", "true", "TRUE"] do
      :ok
    else
      case EndpointVerifier.verify(endpoint) do
        {:ok, _result} -> :ok
        {:error, reason} -> raise "Tier 4 endpoint verification failed: #{inspect(reason)}"
      end
    end
  end

  defp register(operator, endpoint) do
    tier = System.get_env("TIER4_NODE_TIER", "0") |> String.to_integer()

    spec = %{
      cpu_cores: env_int("TIER4_NODE_CPU_CORES", 8),
      ram_gb: env_int("TIER4_NODE_RAM_GB", 32),
      gpu_vram_gb: env_int("TIER4_NODE_GPU_VRAM_GB", 16),
      bandwidth_mbps: env_int("TIER4_NODE_BANDWIDTH_MBPS", 1000)
    }

    case Client.register_node(tier, spec, endpoint) do
      {:ok, tx} ->
        %{status: "registered", operator: operator, endpoint: endpoint, txHash: tx.tx_hash}

      {:error, reason} ->
        raise "Tier 4 node registration failed: #{inspect(reason)}"
    end
  end

  defp env_int(name, default) do
    name
    |> System.get_env(Integer.to_string(default))
    |> String.to_integer()
  end

  defp same_address?(left, right), do: String.downcase(left) == String.downcase(right)
end

AFW.Phase2.RegisterTier4Node.run()
