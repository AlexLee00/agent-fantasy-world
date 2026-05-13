System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)
Application.ensure_all_started(:req)
Application.ensure_all_started(:ethereumex)

defmodule AFW.Phase2.Tier4ProviderCheck do
  alias AFW.Brain.NodeProvider
  alias AFW.Chain.Client

  def run do
    nodes = Client.get_node_stats()

    result =
      NodeProvider.decide_with_nodes(
        %{prompt: "Choose one safe AFW action.", event: %{target: "lumenveil"}},
        nodes
      )

    payload = %{
      status: status(result),
      activeNodes: Enum.map(nodes, &Map.take(&1, [:address, :active, :endpoint])),
      candidateEndpoints: Enum.map(NodeProvider.candidate_nodes(nodes), & &1.endpoint),
      result: format_result(result)
    }

    IO.puts(Jason.encode!(payload, pretty: true))

    if payload.status != "passed" do
      System.halt(1)
    end

    payload
  end

  defp status({:ok, _action}), do: "passed"
  defp status({:error, _reason}), do: "failed"

  defp format_result({:ok, action}), do: %{action: action}
  defp format_result({:error, reason}), do: %{error: inspect(reason)}
end

AFW.Phase2.Tier4ProviderCheck.run()
