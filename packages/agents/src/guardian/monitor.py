from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from src.chain.client import ChainClient


@dataclass
class GuardianEventBatch:
    from_block: int
    to_block: int
    soul_transfers: list[dict[str, Any]]
    combats: list[dict[str, Any]]
    market_fills: list[dict[str, Any]]
    npc_purchases: list[dict[str, Any]]
    treasury: list[dict[str, Any]]
    role_grants: list[dict[str, Any]]


class GuardianMonitor:
    def __init__(self, chain: ChainClient):
        self.chain = chain
        self.cursor_block = max(0, int(chain.w3.eth.block_number) - 250)

    def poll(self, from_block: int | None = None, to_block: int | None = None) -> GuardianEventBatch:
        start = self.cursor_block if from_block is None else int(from_block)
        end = int(to_block or self.chain.w3.eth.block_number)

        batch = GuardianEventBatch(
            from_block=start,
            to_block=end,
            soul_transfers=self.chain.get_soul_transfer_logs(start, end),
            combats=self.chain.get_combat_logs(start, end),
            market_fills=self.chain.get_market_logs(start, end),
            npc_purchases=self.chain.get_npc_purchase_logs(start, end),
            treasury=self.chain.get_treasury_logs(start, end),
            role_grants=self._get_role_grants(start, end),
        )
        self.cursor_block = end + 1
        return batch

    def _get_role_grants(self, from_block: int, to_block: int) -> list[dict[str, Any]]:
        watched = [
            ("AgentRegistry", self.chain.agent_registry),
            ("SOULToken", self.chain.soul_token),
            ("EconomyEngine", self.chain.economy_engine),
            ("GovernanceDAO", self.chain.governance_dao),
            ("MonsterRegistry", self.chain.monster_registry),
        ]
        grants: list[dict[str, Any]] = []
        for contract_name, contract in watched:
            try:
                logs = contract.events.RoleGranted().get_logs(from_block=from_block, to_block=to_block)
            except Exception:
                continue
            for entry in logs:
                args = entry["args"]
                grants.append(
                    {
                        "contract": contract_name,
                        "blockNumber": int(entry["blockNumber"]),
                        "transactionHash": entry["transactionHash"].hex(),
                        "role": args["role"].hex() if hasattr(args["role"], "hex") else str(args["role"]),
                        "account": args["account"],
                        "sender": args["sender"],
                    }
                )
        return sorted(grants, key=lambda item: item["blockNumber"])
