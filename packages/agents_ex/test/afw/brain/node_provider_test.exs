defmodule AFW.Brain.NodeProviderTest do
  use ExUnit.Case, async: false

  alias AFW.Brain.NodeProvider

  setup do
    previous = Application.get_env(:afw, :tier4_node_public_url, "")

    on_exit(fn ->
      Application.put_env(:afw, :tier4_node_public_url, previous)
    end)

    :ok
  end

  test "prioritizes configured durable endpoint before stale and local endpoints" do
    Application.put_env(:afw, :tier4_node_public_url, "https://durable.example.com")

    nodes = [
      %{active: true, endpoint: "http://127.0.0.1:18791/infer"},
      %{active: true, endpoint: "https://stale.example.com/infer"},
      %{active: true, endpoint: "https://durable.example.com/infer"}
    ]

    assert [
             %{endpoint: "https://durable.example.com/infer"},
             %{endpoint: "https://stale.example.com/infer"},
             %{endpoint: "http://127.0.0.1:18791/infer"}
           ] = NodeProvider.candidate_nodes(nodes)
  end

  test "falls through failed nodes until an inference endpoint succeeds" do
    Application.put_env(:afw, :tier4_node_public_url, "https://durable.example.com")

    nodes = [
      %{active: true, endpoint: "https://stale.example.com/infer"},
      %{active: true, endpoint: "https://durable.example.com/infer"}
    ]

    request = fn
      "https://durable.example.com/infer", _payload, _timeout ->
        {:ok, %{"action" => "EXPLORE", "confidence" => 0.8}}

      endpoint, _payload, _timeout ->
        {:error, {:unreachable, endpoint}}
    end

    assert {:ok, %{"action" => "EXPLORE"}} =
             NodeProvider.decide_with_nodes(%{prompt: "Choose safely"}, nodes, request: request)
  end

  test "returns all node failures when no candidate succeeds" do
    nodes = [
      %{active: true, endpoint: "https://stale.example.com/infer"},
      %{active: true, endpoint: "https://other.example.com/infer"}
    ]

    request = fn endpoint, _payload, _timeout -> {:error, {:unreachable, endpoint}} end

    assert {:error, {:all_nodes_failed, failures}} =
             NodeProvider.decide_with_nodes(%{prompt: "Choose safely"}, nodes, request: request)

    assert length(failures) == 2
  end
end
