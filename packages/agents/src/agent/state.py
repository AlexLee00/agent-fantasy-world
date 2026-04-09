from __future__ import annotations

from src.chain.client import ChainClient


class AgentStateReader:
    def __init__(self, chain: ChainClient):
        self.chain = chain

    def snapshot(self, agent_id: int) -> dict:
        agent = self.chain.get_agent(agent_id)
        zone = self.chain.get_zone(int(agent["zoneId"]))
        return {
            "agent": agent,
            "zone": zone,
            "monsters": self.chain.get_monsters_in_zone(int(agent["zoneId"])),
            "npcs": self.chain.get_npcs_in_zone(int(agent["zoneId"])),
            "items": self.chain.get_agent_items(agent["observer"]),
            "orders": self.chain.get_active_orders(),
            "treasuryBalance": self.chain.get_treasury_balance(),
        }
