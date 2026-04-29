defmodule AFW.Guardian.Proposer do
  @moduledoc "Builds GovernanceDAO freeze proposals from Guardian findings."

  alias AFW.Chain.{ABI, Contracts}
  alias AFW.Guardian.Metrics
  alias AFW.Settlement.Hub

  def freeze_wallet(wallet, evidence) do
    {:ok, freeze_call_data} = ABI.encode("freezeWallet", [wallet], "GovernanceDAO")

    %{
      proposal_type: 4,
      title: "Freeze suspicious wallet #{wallet}",
      description:
        "Guardian detected suspicious activity and requests multisig review. Evidence: #{inspect(evidence)}",
      target_contract: Contracts.get(:governance_dao),
      call_data: freeze_call_data,
      wallet: wallet,
      evidence: evidence
    }
  end

  def submit_freeze_proposal(wallet, evidence) do
    proposal = freeze_wallet(wallet, evidence)
    Metrics.record_proposal()

    Hub.submit_event(%{
      type: :governance_action,
      priority: :immediate,
      agent_id: 0,
      data: Map.merge(proposal, %{summary: "Guardian proposed freeze for #{wallet}"})
    })

    proposal
  end
end
