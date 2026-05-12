System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
Application.ensure_all_started(:afw)

defmodule AFW.Phase2.Tier4NodeSmoke.Router do
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/infer" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{
        action: %{
          action: "EXPLORE",
          confidence: 0.91,
          reasoning: "Tier 4 smoke node returned a deterministic response.",
          dialogue: "I will scout the next path.",
          emotion: "focused"
        }
      })
    )
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule AFW.Phase2.Tier4NodeSmoke do
  alias AFW.Brain.NodeProvider
  alias AFW.Chain.Client

  def run do
    endpoint = System.get_env("TIER4_NODE_ENDPOINT", "http://127.0.0.1:18791/infer")
    uri = URI.parse(endpoint)
    port = uri.port || 18791

    {:ok, _pid} = Plug.Cowboy.http(AFW.Phase2.Tier4NodeSmoke.Router, [], port: port)
    operator = Client.account_address()
    nodes = Client.get_node_stats()

    registration =
      if Enum.any?(nodes, &same_address?(&1.address, operator)) do
        %{status: "already_registered", operator: operator}
      else
        case Client.register_node(
               0,
               %{cpu_cores: 8, ram_gb: 32, gpu_vram_gb: 16, bandwidth_mbps: 1000},
               endpoint
             ) do
          {:ok, tx} -> %{status: "registered", operator: operator, txHash: tx.tx_hash}
          {:error, reason} -> raise "Tier 4 node registration failed: #{inspect(reason)}"
        end
      end

    # Let public RPCs converge before reading the active node list again.
    Process.sleep(1_000)

    decision =
      case NodeProvider.decide(%{prompt: "Choose one safe AFW action."}) do
        {:ok, action} -> action
        {:error, reason} -> raise "Tier 4 inference failed: #{inspect(reason)}"
      end

    payload = %{
      status: "passed",
      endpoint: endpoint,
      registration: registration,
      activeNodes: Client.get_node_stats(),
      decision: decision
    }

    IO.puts(Jason.encode!(payload, pretty: true))
    payload
  end

  defp same_address?(left, right), do: String.downcase(left) == String.downcase(right)
end

AFW.Phase2.Tier4NodeSmoke.run()
