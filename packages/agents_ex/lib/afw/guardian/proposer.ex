defmodule AFW.Guardian.Proposer do
  @moduledoc "Builds GovernanceDAO freeze proposals from Guardian findings."

  alias AFW.Chain.Contracts

  def freeze_wallet(wallet, evidence) do
    %{
      title: "Freeze suspicious wallet #{wallet}",
      target_contract: Contracts.get(:governance_dao),
      method: "freezeWallet",
      wallet: wallet,
      evidence: evidence
    }
  end
end
