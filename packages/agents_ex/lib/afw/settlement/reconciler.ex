defmodule AFW.Settlement.Reconciler do
  @moduledoc "Compares optimistic balances with chain balances and corrects local state."

  require Logger

  alias AFW.Chain.Client
  alias AFW.Reconciliation.Metrics, as: ReconciliationMetrics
  alias AFW.Settlement.State

  def reconcile do
    agent_ids = State.all_agent_ids()

    mismatch_count =
      Enum.reduce(agent_ids, 0, fn agent_id, acc ->
        agent = Client.get_agent(agent_id)
        on_chain = Client.get_soul_balance(agent["observer"])
        local = State.confirmed_soul(agent_id)

        if on_chain != local do
          Logger.warning("Reconciliation mismatch: agent #{agent_id}, chain=#{on_chain}, local=#{local}")
          State.correct_confirmed(agent_id, on_chain)
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
end
