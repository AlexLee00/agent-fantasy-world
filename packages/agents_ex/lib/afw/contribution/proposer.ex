defmodule AFW.Contribution.Proposer do
  @moduledoc "Builds reward proposals and submits them through Settlement Hub."

  alias AFW.Contribution.ProposalStore
  alias AFW.Settlement.Hub

  @epoch_pool 1_000 * 1_000_000_000_000_000_000

  def submit_epoch_rewards(epoch, scores) do
    proposal = build_epoch_rewards(epoch, scores)
    ProposalStore.save(proposal)

    if Application.get_env(:afw, :contribution_auto_submit, false) do
      submit_pool(:node_reward_pool, epoch, proposal.pools.node_reward_pool.recipients)
      submit_pool(:bounty_pool, epoch, proposal.pools.bounty_pool.recipients)
    end

    proposal
  end

  def build_epoch_rewards(epoch, scores) do
    node_entries = scores[:nodes] || []
    bounty_entries = (scores[:developers] || []) ++ (scores[:creators] || [])
    node_distribution = distribution(:node_reward_pool, node_entries)
    bounty_distribution = distribution(:bounty_pool, bounty_entries)
    unresolved = node_distribution.unresolved ++ bounty_distribution.unresolved

    %{
      id: "contribution-epoch-#{epoch}-#{System.system_time(:second)}",
      epoch: epoch,
      status:
        if(unresolved == [], do: "ready_for_multisig_review", else: "needs_recipient_mapping"),
      createdAt: DateTime.utc_now(),
      pools: %{
        node_reward_pool: Map.drop(node_distribution, [:unresolved]),
        bounty_pool: Map.drop(bounty_distribution, [:unresolved])
      },
      unresolvedRecipients: unresolved,
      autoSubmit: Application.get_env(:afw, :contribution_auto_submit, false),
      summary: summary(node_distribution, bounty_distribution, unresolved)
    }
  end

  defp submit_pool(_pool_key, _epoch, []), do: :ok

  defp submit_pool(pool_key, epoch, recipients) do
    addresses = Enum.map(recipients, & &1.address)
    amounts = Enum.map(recipients, & &1.amount)

    Hub.submit_event(%{
      type: :distribution_rewards,
      priority: :deferred,
      agent_id: 0,
      data: %{
        pool_key: pool_key,
        epoch: epoch,
        addresses: addresses,
        amounts: amounts,
        soul_changes: [],
        summary: "Distribution proposal for #{Atom.to_string(pool_key)} epoch #{epoch}"
      }
    })
  end

  def proportional_distribution(entries) do
    :legacy
    |> distribution(entries)
    |> Map.get(:recipients)
    |> Enum.map(fn recipient -> {recipient.address, recipient.amount} end)
    |> Enum.unzip()
  end

  defp distribution(pool_key, entries) do
    valid_entries =
      entries |> Enum.filter(&(&1[:score] > 0)) |> Enum.filter(&valid_evm_address?(&1[:address]))

    unresolved =
      entries |> Enum.filter(&(&1[:score] > 0)) |> Enum.reject(&valid_evm_address?(&1[:address]))

    total = Enum.reduce(valid_entries, 0.0, fn entry, acc -> acc + entry.score end)

    recipients =
      valid_entries
      |> Enum.map(fn entry ->
        %{
          address: entry.address,
          amount: if(total == 0, do: 0, else: trunc(@epoch_pool * (entry.score / total))),
          score: entry.score,
          source: entry[:source] || Atom.to_string(pool_key)
        }
      end)
      |> Enum.filter(&(&1.amount > 0))

    %{
      pool: pool_key,
      totalAmount: Enum.reduce(recipients, 0, fn row, acc -> acc + row.amount end),
      recipientCount: length(recipients),
      recipients: recipients,
      unresolved:
        Enum.map(unresolved, fn entry ->
          %{
            address: entry.address,
            score: entry.score,
            source: entry[:source] || "unknown",
            reason: "recipient is not an EVM address"
          }
        end)
    }
  end

  defp summary(node_distribution, bounty_distribution, unresolved) do
    %{
      nodeRecipientCount: node_distribution.recipientCount,
      bountyRecipientCount: bounty_distribution.recipientCount,
      unresolvedRecipientCount: length(unresolved),
      totalAFW: node_distribution.totalAmount + bounty_distribution.totalAmount
    }
  end

  defp valid_evm_address?(value) when is_binary(value), do: value =~ ~r/^0x[0-9a-fA-F]{40}$/
  defp valid_evm_address?(_value), do: false
end
