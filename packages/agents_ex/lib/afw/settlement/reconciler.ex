defmodule AFW.Settlement.Reconciler do
  @moduledoc "Compares optimistic balances with chain balances and corrects local state."

  require Logger

  alias AFW.Chain.Client
  alias AFW.Settlement.State

  def reconcile do
    Enum.each(State.all_agent_ids(), fn agent_id ->
      agent = Client.get_agent(agent_id)
      on_chain = Client.get_soul_balance(agent["observer"])
      local = State.confirmed_soul(agent_id)

      if on_chain != local do
        Logger.warning("Reconciliation mismatch: agent #{agent_id}, chain=#{on_chain}, local=#{local}")
        State.correct_confirmed(agent_id, on_chain)
        Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:reconciliation_mismatch, agent_id, on_chain, local})
      end
    end)
  end
end
