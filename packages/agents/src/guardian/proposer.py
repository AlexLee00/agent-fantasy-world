from __future__ import annotations

from typing import Any

from src.chain.client import ChainClient


class GuardianProposer:
    def __init__(self, chain: ChainClient):
        self.chain = chain

    def build_freeze_proposal(self, wallet: str, reason: str, evidence: dict[str, Any]) -> dict[str, Any]:
        call_data = self.chain.governance_dao.functions.freezeWallet(wallet)._encode_transaction_data()
        return {
            "title": f"Freeze suspicious wallet {wallet[:8]}",
            "targetContract": self.chain.settings.governance_dao_address,
            "method": "freezeWallet",
            "wallet": wallet,
            "reason": reason,
            "evidence": evidence,
            "callData": call_data,
        }
