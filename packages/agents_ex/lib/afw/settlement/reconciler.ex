defmodule AFW.Settlement.Reconciler do
  @moduledoc "Compares optimistic balances with chain balances and corrects local state."

  require Logger

  alias AFW.Agent.Server
  alias AFW.Chain.Client
  alias AFW.Economy.Constants
  alias AFW.Reconciliation.Metrics, as: ReconciliationMetrics
  alias AFW.Settlement.State

  def reconcile do
    agent_ids = State.all_agent_ids()

    mismatch_count =
      Enum.reduce(agent_ids, 0, fn agent_id, acc ->
        agent = Client.get_agent_fresh_state(agent_id)
        on_chain = Client.get_soul_balance(agent["observer"])
        local = State.confirmed_soul(agent_id)
        on_chain_hp = get_in(agent, ["stats", "hp"]) || 0
        offchain_hp = get_in(State.get_agent_view(agent_id), [:agent, "stats", "hp"]) || 0
        status_id = agent["statusId"] || 0

        if on_chain != local or on_chain_hp != offchain_hp do
          Logger.warning("Reconciliation mismatch: agent #{agent_id}, chain=#{on_chain}, local=#{local}")
          State.correct_confirmed(agent_id, on_chain)
          handle_status_sync(agent_id, agent, status_id, on_chain_hp)
          Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:reconciliation_mismatch, agent_id, on_chain, local})
          acc + 1
        else
          acc
        end
      end)

    if mismatch_count == 0 do
      Logger.info("[reconcile] check #{agent_ids |> length()} agents, 0 mismatches")
    else
      Logger.warning("[reconcile] check #{length(agent_ids)} agents, #{mismatch_count} mismatches")
    end

    ReconciliationMetrics.record(length(agent_ids), mismatch_count)
  end

  defp handle_status_sync(agent_id, agent, status_id, on_chain_hp) do
    max_hp = get_in(agent, ["stats", "maxHp"]) || on_chain_hp

    if status_id != Constants.alive_status_id() do
      State.correct_offchain(agent_id, %{
        hp: max_hp,
        statusName: "RESTING",
        statusId: Constants.resting_status_id()
      })

      Server.apply_reconciled_state(agent_id, %{
        status: :resting,
        post_combat_cooldown: 2,
        stats: %{hp: max_hp, max_hp: max_hp}
      })
    else
      State.correct_offchain(agent_id, %{hp: on_chain_hp, statusId: status_id, statusName: agent["statusName"]})
    end
  end
end
