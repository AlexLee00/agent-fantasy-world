defmodule AFW.Tier4.EndpointVerifierTest do
  use ExUnit.Case, async: true

  alias AFW.Tier4.EndpointVerifier

  test "normalizes base URL to infer endpoint" do
    assert EndpointVerifier.normalize_infer_endpoint("https://node.example.com") ==
             "https://node.example.com/infer"

    assert EndpointVerifier.normalize_infer_endpoint("https://node.example.com/infer") ==
             "https://node.example.com/infer"
  end

  test "builds matching health endpoint" do
    assert EndpointVerifier.health_url("https://node.example.com/infer") ==
             "https://node.example.com/health"
  end

  test "rejects local endpoints before HTTP probing" do
    assert {:error, %{reason: :not_external}} =
             EndpointVerifier.verify("http://127.0.0.1:18791/infer")
  end

  test "verifies health and inference responses" do
    request = fn
      :get, "https://node.example.com/health", _opts ->
        {:ok, %{status: 200, body: %{"status" => "ok"}}}

      :post, "https://node.example.com/infer", _opts ->
        {:ok, %{status: 200, body: %{"action" => %{"action" => "EXPLORE"}}}}
    end

    assert {:ok, %{endpoint: "https://node.example.com/infer"}} =
             EndpointVerifier.verify("https://node.example.com", request: request)
  end

  test "fails when inference payload is not a Brain action" do
    request = fn
      :get, _url, _opts -> {:ok, %{status: 200, body: %{"status" => "ok"}}}
      :post, _url, _opts -> {:ok, %{status: 200, body: %{"status" => "ok"}}}
    end

    assert {:error, %{reason: :invalid_infer_response}} =
             EndpointVerifier.verify("https://node.example.com", request: request)
  end
end
