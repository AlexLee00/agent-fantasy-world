defmodule AFW.Contribution.OnChain do
  @moduledoc "On-chain contribution metrics from AFW contracts."

  alias AFW.Chain.Client
  alias AFW.Tier4.EndpointVerifier

  def fetch_metrics(opts \\ []) do
    nodes = Client.get_node_stats()
    verify_nodes = Keyword.get(opts, :verify_nodes, verify_nodes?())
    endpoint_verifier = Keyword.get(opts, :endpoint_verifier, &EndpointVerifier.verify/1)

    %{
      nodes: maybe_verify_nodes(nodes, verify_nodes, endpoint_verifier),
      creators: Client.get_creator_stats()
    }
  end

  def eligible_nodes(nodes, endpoint_verifier \\ &EndpointVerifier.verify/1) do
    nodes
    |> Enum.map(&verify_node(&1, endpoint_verifier))
    |> Enum.filter(&Map.get(&1, :reward_eligible, false))
  end

  defp maybe_verify_nodes(nodes, true, endpoint_verifier),
    do: eligible_nodes(nodes, endpoint_verifier)

  defp maybe_verify_nodes(nodes, false, _endpoint_verifier), do: nodes

  defp verify_node(node, endpoint_verifier) do
    endpoint = Map.get(node, :endpoint) || Map.get(node, "endpoint")

    case endpoint_verifier.(endpoint) do
      {:ok, %{endpoint: verified_endpoint}} ->
        node
        |> Map.put(:endpoint, verified_endpoint)
        |> Map.put(:reward_eligible, true)
        |> Map.put(:verification_status, :passed)

      {:error, reason} ->
        node
        |> Map.put(:reward_eligible, false)
        |> Map.put(:verification_status, :failed)
        |> Map.put(:verification_error, reason)
    end
  end

  defp verify_nodes? do
    Application.get_env(:afw, :contribution_verify_node_endpoints, true)
  end
end
