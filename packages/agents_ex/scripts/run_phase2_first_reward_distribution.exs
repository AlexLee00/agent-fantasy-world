System.put_env("AFW_DISABLE_BOOT_AGENTS", "1")
System.put_env("CONTRIBUTION_AUTO_SUBMIT", "true")
Application.ensure_all_started(:afw)

defmodule AFW.Phase2.FirstRewardDistribution do
  alias AFW.Chain.Reader
  alias AFW.Contribution.{Agent, ProposalStore}
  alias AFW.Settlement.{Hub, Metrics}

  @wei 1_000_000_000_000_000_000

  def run do
    recipient = System.get_env("PHASE2_REWARD_RECIPIENT", AFW.Chain.Client.account_address())
    epoch = System.get_env("PHASE2_REWARD_EPOCH", Integer.to_string(System.system_time(:second)))

    Application.put_env(:afw, :contribution_auto_submit, true)
    Application.put_env(:afw, :contribution_recipient_map, %{"github:repo" => recipient})
    Application.put_env(:afw, :contribution_developer_reward_address, recipient)

    before_balances = balances(recipient)
    {_scores, proposal} = Agent.evaluate_once(String.to_integer(epoch))

    if proposal.status != "ready_for_multisig_review" do
      raise "Reward proposal is not ready: #{proposal.status}"
    end

    Process.sleep(200)
    settlement = Hub.settle_now(:deferred)
    Process.sleep(500)
    metrics = Metrics.snapshot()
    confirmed = get_in(metrics, [:byType, :distribution_rewards, :confirmed]) || 0

    if settlement.pending > 0 or confirmed < settlement.attempted do
      raise "Reward distribution settlement incomplete: #{inspect(%{settlement: settlement, metrics: metrics})}"
    end

    payload = %{
      status: "passed",
      epoch: String.to_integer(epoch),
      recipient: recipient,
      proposal: %{
        id: proposal.id,
        status: proposal.status,
        nodeRecipientCount: proposal.summary.nodeRecipientCount,
        bountyRecipientCount: proposal.summary.bountyRecipientCount,
        unresolvedRecipientCount: proposal.summary.unresolvedRecipientCount,
        totalAFW: format_afw(proposal.summary.totalAFW)
      },
      settlement: settlement,
      metrics: metrics,
      balances: %{
        before: before_balances,
        after: balances(recipient)
      },
      storedProposalCount: length(ProposalStore.latest(20))
    }

    IO.puts(Jason.encode!(payload, pretty: true))
    payload
  end

  defp balances(recipient) do
    %{
      recipient: format_afw(Reader.call_uint(:afw_token, "balanceOf", [recipient])),
      nodeRewardPool:
        format_afw(Reader.call_uint(:afw_token, "balanceOf", [contract!(:node_reward_pool)])),
      bountyPool: format_afw(Reader.call_uint(:afw_token, "balanceOf", [contract!(:bounty_pool)]))
    }
  end

  defp contract!(key) do
    Application.fetch_env!(:afw, :contracts) |> Map.fetch!(key)
  end

  defp format_afw(value), do: value / @wei
end

AFW.Phase2.FirstRewardDistribution.run()
