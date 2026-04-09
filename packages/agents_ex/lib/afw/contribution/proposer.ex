defmodule AFW.Contribution.Proposer do
  @moduledoc "Builds reward proposals and submits them through Settlement Hub."

  alias AFW.Settlement.Hub

  @epoch_pool 1_000 * 1_000_000_000_000_000_000

  def submit_epoch_rewards(epoch, scores) do
    submit_pool(:node_reward_pool, epoch, scores[:nodes] || [])
    submit_pool(:bounty_pool, epoch, (scores[:developers] || []) ++ (scores[:creators] || []))
    :ok
  end

  defp submit_pool(_pool_key, _epoch, []), do: :ok

  defp submit_pool(pool_key, epoch, entries) do
    {addresses, amounts} = proportional_distribution(entries)

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
    total = Enum.reduce(entries, 0.0, fn entry, acc -> acc + entry.score end)

    entries
    |> Enum.filter(&(&1.score > 0))
    |> Enum.map(fn entry ->
      share =
        if total == 0 do
          0
        else
          trunc(@epoch_pool * (entry.score / total))
        end

      {entry.address, share}
    end)
    |> Enum.unzip()
  end
end
