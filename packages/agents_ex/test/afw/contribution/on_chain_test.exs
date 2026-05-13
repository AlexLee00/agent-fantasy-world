defmodule AFW.Contribution.OnChainTest do
  use ExUnit.Case, async: true

  alias AFW.Contribution.OnChain

  test "keeps only verified nodes as reward eligible" do
    verifier = fn
      "https://durable.example.com/infer" ->
        {:ok, %{endpoint: "https://durable.example.com/infer"}}

      endpoint ->
        {:error, %{endpoint: endpoint, reason: :unreachable}}
    end

    nodes = [
      %{
        active: true,
        address: "0x1111111111111111111111111111111111111111",
        endpoint: "https://stale.example.com/infer"
      },
      %{
        active: true,
        address: "0x2222222222222222222222222222222222222222",
        endpoint: "https://durable.example.com/infer"
      }
    ]

    assert [
             %{
               address: "0x2222222222222222222222222222222222222222",
               reward_eligible: true,
               verification_status: :passed
             }
           ] = OnChain.eligible_nodes(nodes, verifier)
  end
end
