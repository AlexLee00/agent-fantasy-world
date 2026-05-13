defmodule AFW.Contribution.ReadinessTest do
  use ExUnit.Case, async: true

  alias AFW.Contribution.Readiness

  @account "0x1111111111111111111111111111111111111111"
  @contributor "0x2222222222222222222222222222222222222222"

  test "passes when distribution, payout, and external node checks are ready" do
    report =
      Readiness.check(
        account_address: @account,
        contracts: contracts(),
        recipient_map: %{"github:repo" => @contributor},
        nodes: [%{active: true, endpoint: "https://node.example.com/infer"}]
      )

    assert report.status == :passed
  end

  test "blocks localhost tier4 endpoints" do
    refute Readiness.external_endpoint?("http://127.0.0.1:18791/infer")
    refute Readiness.external_endpoint?("http://localhost:18791/infer")
    assert Readiness.external_endpoint?("https://node.example.com/infer")
  end

  test "blocks deployer payout mapping in production readiness" do
    report =
      Readiness.check(
        account_address: @account,
        contracts: contracts(),
        recipient_map: %{"github:repo" => @account},
        nodes: [%{active: true, endpoint: "https://node.example.com/infer"}]
      )

    assert report.status == :blocked

    assert Enum.any?(
             report.checks,
             &(&1.id == "production_payout_ownership" and &1.status == :fail)
           )
  end

  test "can require live verification for external tier4 endpoints" do
    verifier = fn "https://node.example.com/infer" ->
      {:ok, %{endpoint: "https://node.example.com/infer"}}
    end

    report =
      Readiness.check(
        account_address: @account,
        contracts: contracts(),
        recipient_map: %{"github:repo" => @contributor},
        nodes: [%{active: true, endpoint: "https://node.example.com/infer"}],
        verify_endpoints: true,
        endpoint_verifier: verifier
      )

    assert report.status == :passed
  end

  test "blocks external tier4 endpoints that fail live verification" do
    verifier = fn "https://node.example.com/infer" ->
      {:error, %{endpoint: "https://node.example.com/infer", reason: :timeout}}
    end

    report =
      Readiness.check(
        account_address: @account,
        contracts: contracts(),
        recipient_map: %{"github:repo" => @contributor},
        nodes: [%{active: true, endpoint: "https://node.example.com/infer"}],
        verify_endpoints: true,
        endpoint_verifier: verifier
      )

    assert report.status == :blocked

    assert Enum.any?(
             report.checks,
             &(&1.id == "tier4_external_endpoint" and &1.status == :fail)
           )
  end

  defp contracts do
    %{
      afw_distributor: "0x3333333333333333333333333333333333333333",
      node_reward_pool: "0x4444444444444444444444444444444444444444",
      bounty_pool: "0x5555555555555555555555555555555555555555",
      ecosystem_treasury: "0x6666666666666666666666666666666666666666",
      team_vesting_wallet: "0x7777777777777777777777777777777777777777",
      advisor_vesting_wallet: "0x8888888888888888888888888888888888888888"
    }
  end
end
