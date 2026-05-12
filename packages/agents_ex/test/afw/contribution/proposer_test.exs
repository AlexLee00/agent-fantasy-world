defmodule AFW.Contribution.ProposerTest do
  use ExUnit.Case, async: false

  alias AFW.Contribution.{ProposalStore, Proposer}

  setup do
    ProposalStore.clear_all()
    Application.put_env(:afw, :contribution_auto_submit, false)
    Application.put_env(:afw, :contribution_developer_reward_address, "")

    on_exit(fn ->
      ProposalStore.clear_all()
      Application.put_env(:afw, :contribution_auto_submit, false)
      Application.put_env(:afw, :contribution_developer_reward_address, "")
    end)

    :ok
  end

  test "builds reviewable proposal and separates non-EVM recipients" do
    proposal =
      Proposer.build_epoch_rewards(7, %{
        nodes: [
          %{
            address: "0x1111111111111111111111111111111111111111",
            score: 100,
            source: "node"
          }
        ],
        developers: [%{address: "github:repo", score: 50, source: "github"}],
        creators: [
          %{
            address: "0x2222222222222222222222222222222222222222",
            score: 50,
            source: "creator"
          }
        ]
      })

    assert proposal.status == "needs_recipient_mapping"
    assert proposal.pools.node_reward_pool.recipientCount == 1
    assert proposal.pools.bounty_pool.recipientCount == 1

    assert [%{address: "github:repo", reason: "recipient is not an EVM address"}] =
             proposal.unresolvedRecipients
  end

  test "submit_epoch_rewards persists proposal without auto-submit" do
    proposal =
      Proposer.submit_epoch_rewards(1, %{
        nodes: [],
        developers: [%{address: "github:repo", score: 10, source: "github"}],
        creators: []
      })

    assert proposal.autoSubmit == false
    assert [stored] = ProposalStore.latest(1)
    assert stored.id == proposal.id
  end

  test "developer score uses configured payout address when available" do
    Application.put_env(
      :afw,
      :contribution_developer_reward_address,
      "0x3333333333333333333333333333333333333333"
    )

    assert [%{address: "0x3333333333333333333333333333333333333333"}] =
             AFW.Contribution.Scorer.developer_scores(%{
               prs_merged: 1,
               issues_closed: 0,
               commits: 0
             })
  end
end
