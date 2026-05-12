defmodule AFW.Tier4.NodeServerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias AFW.Tier4.NodeServer

  setup do
    previous_backend = Application.get_env(:afw, :tier4_node_backend, "afw-basic")

    Application.put_env(:afw, :tier4_node_backend, "afw-basic")

    on_exit(fn ->
      Application.put_env(:afw, :tier4_node_backend, previous_backend)
    end)

    :ok
  end

  test "health endpoint reports node service status" do
    response =
      :get
      |> conn("/health")
      |> NodeServer.call([])

    assert response.status == 200
    assert Jason.decode!(response.resp_body)["status"] == "ok"
  end

  test "infer endpoint returns standard action payload" do
    response =
      :post
      |> conn("/infer", Jason.encode!(%{prompt: "Scout safely", event: %{target: "lumenveil"}}))
      |> put_req_header("content-type", "application/json")
      |> NodeServer.call([])

    body = Jason.decode!(response.resp_body)

    assert response.status == 200
    assert body["action"]["action"] in ["EXPLORE", "FIGHT", "REST", "TRADE", "TALK"]
    assert body["node"]["service"] == "afw-tier4-node"
  end
end
