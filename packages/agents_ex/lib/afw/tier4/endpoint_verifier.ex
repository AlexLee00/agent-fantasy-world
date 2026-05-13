defmodule AFW.Tier4.EndpointVerifier do
  @moduledoc "Validates externally reachable Tier 4 node HTTP endpoints."

  @default_timeout 5_000

  def verify(endpoint, opts \\ []) do
    infer_url = normalize_infer_endpoint(endpoint)

    cond do
      infer_url == "" ->
        {:error, failure(:missing_endpoint, endpoint, "Endpoint is required.")}

      not external_endpoint?(infer_url) ->
        {:error, failure(:not_external, infer_url, "Endpoint must be externally reachable.")}

      true ->
        verify_http(infer_url, opts)
    end
  end

  def normalize_infer_endpoint(endpoint) when is_binary(endpoint) do
    endpoint = String.trim(endpoint)

    cond do
      endpoint == "" -> ""
      String.ends_with?(endpoint, "/infer") -> endpoint
      true -> String.trim_trailing(endpoint, "/") <> "/infer"
    end
  end

  def normalize_infer_endpoint(_endpoint), do: ""

  def external_endpoint?(endpoint) when is_binary(endpoint) do
    case URI.parse(endpoint) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        not local_host?(String.downcase(host))

      _ ->
        false
    end
  end

  def external_endpoint?(_endpoint), do: false

  def health_url(infer_url) do
    infer_url
    |> normalize_infer_endpoint()
    |> String.replace(~r{/infer$}, "/health")
  end

  defp verify_http(infer_url, opts) do
    request = Keyword.get(opts, :request, &default_request/3)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    health_url = health_url(infer_url)

    with {:ok, health_body} <- request_ok(request, :get, health_url, timeout),
         {:ok, infer_body} <- request_ok(request, :post, infer_url, timeout),
         :ok <- validate_infer_body(infer_body) do
      {:ok,
       %{
         status: :passed,
         endpoint: infer_url,
         healthUrl: health_url,
         health: health_body,
         inference: infer_body
       }}
    else
      {:error, reason} ->
        {:error, failure(reason, infer_url, "Tier 4 endpoint verification failed.")}
    end
  end

  defp request_ok(request, method, url, timeout) do
    payload =
      if method == :post do
        %{prompt: "Choose one safe AFW action.", event: %{target: "aethermoor"}}
      end

    case request.(method, url, timeout: timeout, json: payload) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, method, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, method, reason}}
    end
  end

  defp validate_infer_body(%{"action" => action}) when is_map(action), do: :ok
  defp validate_infer_body(%{action: action}) when is_map(action), do: :ok
  defp validate_infer_body(_body), do: {:error, :invalid_infer_response}

  defp default_request(:get, url, opts) do
    Req.request(method: :get, url: url, receive_timeout: opts[:timeout], retry: false)
  end

  defp default_request(:post, url, opts) do
    Req.request(
      method: :post,
      url: url,
      json: opts[:json],
      receive_timeout: opts[:timeout],
      retry: false
    )
  end

  defp failure(reason, endpoint, detail) do
    %{
      status: :failed,
      reason: reason,
      endpoint: endpoint,
      detail: detail
    }
  end

  defp local_host?("localhost"), do: true
  defp local_host?("0.0.0.0"), do: true
  defp local_host?("::1"), do: true
  defp local_host?("127." <> _rest), do: true
  defp local_host?("10." <> _rest), do: true
  defp local_host?("192.168." <> _rest), do: true
  defp local_host?("172." <> rest), do: private_172?(rest)
  defp local_host?(host), do: String.ends_with?(host, ".local")

  defp private_172?(rest) do
    rest
    |> String.split(".", parts: 2)
    |> List.first()
    |> case do
      nil -> false
      value -> match?({number, ""} when number in 16..31, Integer.parse(value))
    end
  end
end
