defmodule AFW.Brain.NodeProvider do
  @moduledoc "Tier 4 node-backed brain provider."
  @behaviour AFW.Brain.Interface

  alias AFW.Chain.Client
  alias AFW.Tier4.EndpointVerifier

  @default_timeout 10_000

  def decide(context) do
    decide_with_nodes(context, Client.get_node_stats())
  end

  def decide_with_nodes(context, nodes, opts \\ []) do
    request = Keyword.get(opts, :request, &request_inference/3)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    payload = request_payload(context)

    nodes
    |> candidate_nodes()
    |> try_candidates(payload, request, timeout, [])
  end

  def candidate_nodes(nodes) do
    preferred = preferred_endpoint()

    nodes
    |> Enum.filter(&Map.get(&1, :active, true))
    |> Enum.map(&normalize_node/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.endpoint)
    |> Enum.sort_by(fn node ->
      cond do
        preferred != "" and node.endpoint == preferred -> {0, node.endpoint}
        EndpointVerifier.external_endpoint?(node.endpoint) -> {1, node.endpoint}
        true -> {2, node.endpoint}
      end
    end)
  end

  defp try_candidates([], _payload, _request, _timeout, []), do: {:error, :no_available_node}

  defp try_candidates([], _payload, _request, _timeout, failures) do
    {:error, {:all_nodes_failed, Enum.reverse(failures)}}
  end

  defp try_candidates([node | rest], payload, request, timeout, failures) do
    case request.(node.endpoint, payload, timeout) do
      {:ok, action} ->
        {:ok, action}

      {:error, reason} ->
        try_candidates(rest, payload, request, timeout, [{node.endpoint, reason} | failures])
    end
  end

  defp request_inference(endpoint, payload, timeout) do
    with {:ok, %{status: 200, body: body}} <-
           Req.post(endpoint, json: payload, receive_timeout: timeout, retry: false),
         {:ok, action} <- decode_action(body) do
      {:ok, action}
    else
      {:ok, %{status: status, body: body}} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp decode_body(body) when is_map(body), do: body

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end

  defp decode_body(_body), do: %{}

  defp decode_action(body) do
    decoded = decode_body(body)

    case decoded["action"] || decoded[:action] || decoded do
      action when is_map(action) -> {:ok, action}
      other -> {:error, {:invalid_action, other}}
    end
  end

  defp request_payload(context) do
    %{
      prompt:
        Map.get(context, :prompt) || Map.get(context, "prompt") || "Choose one safe AFW action.",
      event:
        json_safe(
          Map.get(context, :event) || Map.get(context, "event") || %{target: "aethermoor"}
        )
    }
  end

  defp json_safe(%_struct{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {json_key(key), json_safe(item)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value) when value in [nil, true, false], do: value
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key), do: key

  defp normalize_node(%{endpoint: endpoint} = node) when is_binary(endpoint) do
    endpoint = EndpointVerifier.normalize_infer_endpoint(endpoint)

    if endpoint == "" do
      nil
    else
      Map.put(node, :endpoint, endpoint)
    end
  end

  defp normalize_node(%{"endpoint" => endpoint} = node) when is_binary(endpoint) do
    endpoint = EndpointVerifier.normalize_infer_endpoint(endpoint)

    if endpoint == "" do
      nil
    else
      %{
        address: Map.get(node, "address"),
        active: Map.get(node, "active", true),
        endpoint: endpoint
      }
    end
  end

  defp normalize_node(_node), do: nil

  defp preferred_endpoint do
    :afw
    |> Application.get_env(:tier4_node_public_url, "")
    |> EndpointVerifier.normalize_infer_endpoint()
  end
end
