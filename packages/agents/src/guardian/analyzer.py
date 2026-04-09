from __future__ import annotations

from collections import Counter, defaultdict
from datetime import UTC, datetime
from typing import Any

from src.chain.client import ChainClient
from src.guardian.monitor import GuardianEventBatch


class GuardianAnalyzer:
    def __init__(self, chain: ChainClient):
        self.chain = chain
        self.allowed_mint_targets = {
            chain.settings.economy_engine_address.lower(),
            chain.settings.quest_engine_address.lower(),
            chain.settings.combat_resolver_address.lower(),
            chain.settings.soul_token_address.lower(),
        }

    def analyze(self, batch: GuardianEventBatch) -> dict[str, Any]:
        agents = self.chain.get_all_agents()
        supply = self.chain.get_total_supply_snapshot()
        wealth = [self.chain.get_soul_balance(agent["observer"]) for agent in agents]
        combat_counter = Counter("win" if event["agentWins"] else "loss" for event in batch.combats)
        latest_treasury_balance = self.chain.get_treasury_balance()
        anomalies = self._detect_anomalies(batch)

        next_event = "WORLD_BOSS at 10000"
        if latest_treasury_balance < 1_000 * 10**18:
            next_event = "MINI at 1000"
        elif latest_treasury_balance < 5_000 * 10**18:
            next_event = "ZONE at 5000"

        return {
            "timestamp": datetime.now(UTC).isoformat(),
            "economy": {
                "totalSOULMinted": supply["totalMinted"],
                "totalSOULBurned": supply["totalBurned"],
                "circulatingSOUL": supply["totalSupply"],
                "inflationRate": self._inflation_rate(supply),
                "npcVolume": sum(event["price"] for event in batch.npc_purchases),
                "marketFills": len(batch.market_fills),
            },
            "agents": {
                "totalActive": len([agent for agent in agents if int(agent["statusId"]) != 2]),
                "averageLevel": round(sum(int(agent["level"]) for agent in agents) / max(1, len(agents)), 2),
                "wealthGini": round(self._gini(wealth), 4),
                "wealthByAgent": {
                    str(agent["agentId"]): self.chain.get_soul_balance(agent["observer"])
                    for agent in agents
                },
            },
            "combat": {
                "totalFights": len(batch.combats),
                "agentWinRate": round(combat_counter["win"] / max(1, len(batch.combats)), 4),
                "totalDeaths": combat_counter["loss"],
                "monsterKillCount": combat_counter["win"],
            },
            "treasury": {
                "balance": latest_treasury_balance,
                "nextEvent": next_event,
                "recentEvents": [event for event in batch.treasury if event["kind"] == "WORLD_EVENT"][-5:],
            },
            "anomalies": anomalies,
            "recentCombatLog": batch.combats[-10:],
            "recentMarketLog": batch.market_fills[-10:],
            "recentNPCLog": batch.npc_purchases[-10:],
        }

    def _detect_anomalies(self, batch: GuardianEventBatch) -> list[dict[str, Any]]:
        anomalies: list[dict[str, Any]] = []
        seen_monster_rewards: set[int] = set()
        tx_event_counter: defaultdict[str, int] = defaultdict(int)

        for transfer in batch.soul_transfers:
            tx_event_counter[transfer["transactionHash"]] += 1
            minted = transfer["from"] == "0x0000000000000000000000000000000000000000"
            if minted:
                tx = self.chain.w3.eth.get_transaction(transfer["transactionHash"])
                tx_to = str(tx["to"] or "").lower()
                if tx_to not in self.allowed_mint_targets:
                    anomalies.append(
                        {
                            "severity": "high",
                            "pattern": "UNAUTHORIZED_MINT_FLOW",
                            "txHash": transfer["transactionHash"],
                            "details": f"Mint-like transfer routed through unexpected target {tx_to}",
                        }
                    )
            if transfer["value"] >= 10_000 * 10**18:
                anomalies.append(
                    {
                        "severity": "medium",
                        "pattern": "ABNORMAL_TOKEN_FLOW",
                        "txHash": transfer["transactionHash"],
                        "details": f"Large SOUL transfer detected: {transfer['value']}",
                    }
                )

        for combat in batch.combats:
            tx_event_counter[combat["transactionHash"]] += 1
            if combat["agentWins"]:
                if combat["monsterId"] in seen_monster_rewards:
                    anomalies.append(
                        {
                            "severity": "high",
                            "pattern": "DUPLICATE_REWARD_CLAIM",
                            "txHash": combat["transactionHash"],
                            "details": f"Monster {combat['monsterId']} appears to have paid out more than once.",
                        }
                    )
                seen_monster_rewards.add(combat["monsterId"])

        for role_grant in batch.role_grants:
            tx_event_counter[role_grant["transactionHash"]] += 1
            if role_grant["sender"].lower() != self.chain.settings.governance_dao_address.lower() and role_grant["sender"].lower() != self.chain.address.lower():
                anomalies.append(
                    {
                        "severity": "medium",
                        "pattern": "ROLE_ESCALATION_ATTEMPT",
                        "txHash": role_grant["transactionHash"],
                        "details": f"{role_grant['contract']} granted a role to {role_grant['account']}",
                    }
                )

        for tx_hash, event_count in tx_event_counter.items():
            if event_count >= 6:
                anomalies.append(
                    {
                        "severity": "low",
                        "pattern": "REENTRANCY_LIKE_EVENT_DENSITY",
                        "txHash": tx_hash,
                        "details": f"{event_count} tracked events happened in a single transaction.",
                    }
                )

        return anomalies

    def _inflation_rate(self, supply: dict[str, int]) -> float:
        total_minted = max(1, supply["totalMinted"])
        return round((supply["totalMinted"] - supply["totalBurned"]) / total_minted, 4)

    def _gini(self, values: list[int]) -> float:
        clean = [max(0, int(value)) for value in values]
        if not clean:
            return 0.0
        ordered = sorted(clean)
        total = sum(ordered)
        if total == 0:
            return 0.0
        weighted_sum = sum((index + 1) * value for index, value in enumerate(ordered))
        return (2 * weighted_sum) / (len(ordered) * total) - (len(ordered) + 1) / len(ordered)
