from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Any


ZONE_LEVEL_CAPS = {
    1: (1, 10),
    2: (11, 25),
    3: (26, 50),
    4: (51, 99),
}

LUMENVEIL_MINION_RANGE = {
    "hp": (20, 80),
    "attack": (5, 12),
    "defense": (3, 8),
    "speed": (3, 10),
    "reward": (5, 20),
}

LUMENVEIL_REGULAR_RANGE = {
    "hp": (80, 200),
    "attack": (12, 20),
    "defense": (8, 15),
    "speed": (5, 12),
    "reward": (20, 50),
}


@dataclass
class WorldEvent:
    kind: str
    title: str
    summary: str
    target: str = ""
    danger: str = "LOW"
    metadata: dict[str, Any] | None = None

    def as_prompt_block(self) -> str:
        lines = [
            f"Type: {self.kind}",
            f"Title: {self.title}",
            f"Danger: {self.danger}",
            f"Summary: {self.summary}",
        ]
        if self.target:
            lines.append(f"Focus: {self.target}")
        if self.metadata and self.kind == "MONSTER":
            monster = self.metadata.get("monster") or {}
            lines.append(
                "Threat Stats: "
                f"LV {monster.get('level')} | "
                f"HP {monster.get('hp')} | "
                f"ATK {monster.get('attack')} | "
                f"DEF {monster.get('defense')} | "
                f"SPD {monster.get('speed')}"
            )
        return "\n".join(lines)


class EventGenerator:
    def __init__(self, seed: int | None = None):
        self.random = random.Random(seed)

    def generate_event(self, agent: dict, zone: dict, tick_count: int, world_state: dict | None = None) -> WorldEvent:
        hp = int(agent["stats"]["hp"])
        max_hp = max(1, int(agent["stats"]["maxHp"]))
        hp_ratio = hp / max_hp
        world_state = world_state or {}
        monsters = list(world_state.get("monsters") or [])
        npcs = list(world_state.get("npcs") or [])
        items = list(world_state.get("items") or [])
        orders = list(world_state.get("orders") or [])

        if hp_ratio < 0.30:
            return self._survival_event(agent, zone)

        if monsters:
            monster = self.random.choice(monsters)
            return self._onchain_monster_event(zone, monster)
        if npcs:
            npc = self.random.choice(npcs)
            return self._onchain_npc_event(zone, npc)
        if items or orders:
            return self._trade_event(zone, items, orders)

        roll = self.random.random()
        if roll < 0.35:
            return self._monster_event(agent, zone, tick_count)
        if roll < 0.60:
            return self._npc_event(zone)
        if roll < 0.82:
            return self._treasure_event(zone)
        return self._rest_event(zone)

    def _survival_event(self, agent: dict, zone: dict) -> WorldEvent:
        hp = int(agent["stats"]["hp"])
        max_hp = int(agent["stats"]["maxHp"])
        return WorldEvent(
            kind="SURVIVAL",
            title="Critical condition",
            summary=(
                f"You are badly wounded at {hp}/{max_hp} HP in {zone['name']}. "
                "Your immediate priority is survival: safety, recovery, and avoiding lethal risk."
            ),
            target="nearest safe shelter",
            danger="CRITICAL",
            metadata={"force_survival": True},
        )

    def _monster_event(self, agent: dict, zone: dict, tick_count: int) -> WorldEvent:
        monster = self._build_monster(agent, zone, tick_count)
        return WorldEvent(
            kind="MONSTER",
            title=f"{monster['name']} blocks your path",
            summary=(
                f"A hostile {monster['name']} emerges nearby in {zone['name']}. "
                "It looks ready to attack if you advance."
            ),
            target=monster["name"],
            danger="HIGH",
            metadata={"monster": monster},
        )

    def _onchain_monster_event(self, zone: dict, monster: dict[str, Any]) -> WorldEvent:
        metadata = {
            "monster": {
                "monsterId": int(monster["monsterId"]),
                "name": monster.get("name", "Unknown monster"),
                "level": int(monster.get("dangerLevel", 1)),
                "hp": int(monster["hp"]),
                "attack": int(monster["atk"]),
                "defense": int(monster["def"]),
                "speed": 0,
                "soulReward": int(monster["soulBalance"]),
            }
        }
        return WorldEvent(
            kind="MONSTER",
            title=f"{monster.get('name', 'Monster')} roams {zone['name']}",
            summary=f"A live monster is present in {zone['name']}. Real combat can be resolved on-chain right now.",
            target=monster.get("name", "Monster"),
            danger="HIGH",
            metadata=metadata,
        )

    def _npc_event(self, zone: dict) -> WorldEvent:
        npc_options = [
            ("Tavern keeper", "A tavern keeper waves you over, eager to trade rumors for a story."),
            ("Traveling merchant", "A traveling merchant lays out charms, maps, and odd curiosities."),
            ("Village scout", "A village scout returns from patrol with fresh news about the roads."),
        ]
        target, summary = self.random.choice(npc_options)
        return WorldEvent(
            kind="NPC",
            title=f"You meet {target.lower()}",
            summary=summary,
            target=target,
            danger="LOW",
            metadata={"npc": target},
        )

    def _onchain_npc_event(self, zone: dict, npc: dict[str, Any]) -> WorldEvent:
        role = str(npc.get("role") or "NPC").upper()
        return WorldEvent(
            kind="NPC",
            title=f"{npc.get('name', 'NPC')} the {role.lower()}",
            summary=f"{npc.get('name', 'An NPC')} is available in {zone['name']} as a {role.lower()}.",
            target=npc.get("name", "NPC"),
            danger="LOW",
            metadata={"npc": npc},
        )

    def _trade_event(self, zone: dict, items: list[dict], orders: list[dict]) -> WorldEvent:
        inventory_count = sum(int(item.get("amount", 0)) for item in items)
        return WorldEvent(
            kind="TRADE",
            title="The market is active",
            summary=(
                f"The trade economy in {zone['name']} is open. "
                f"You hold {inventory_count} item units and there are {len(orders)} active market orders."
            ),
            target="marketplace",
            danger="LOW",
            metadata={"items": items, "orders": orders},
        )

    def _treasure_event(self, zone: dict) -> WorldEvent:
        treasure_options = [
            ("Forgotten satchel", "A weathered satchel peeks out from tall grass near the road."),
            ("Glowing chest", "A faintly glowing chest rests under mossy stones, almost hidden from sight."),
            ("Runed cache", "A runed cache hums with old magic and the promise of valuable salvage."),
        ]
        target, summary = self.random.choice(treasure_options)
        return WorldEvent(
            kind="TREASURE",
            title=target,
            summary=summary,
            target=target,
            danger="MEDIUM",
            metadata={"reward_hint": "SOUL or useful supplies"},
        )

    def _rest_event(self, zone: dict) -> WorldEvent:
        rest_options = [
            ("Quiet campfire", "A small campfire crackles nearby, offering warmth and a moment to recover."),
            ("Safe tavern table", "An empty tavern table and hot meal promise rest, gossip, and comfort."),
            ("Shrine bench", "A shrine bench beneath old trees offers peace and a chance to gather yourself."),
        ]
        target, summary = self.random.choice(rest_options)
        return WorldEvent(
            kind="REST",
            title=target,
            summary=summary,
            target=target,
            danger="LOW",
            metadata={"rest_bonus": True, "zoneName": zone["name"]},
        )

    def _build_monster(self, agent: dict, zone: dict, tick_count: int) -> dict[str, Any]:
        zone_id = int(zone["zoneId"])
        level_floor, level_cap = ZONE_LEVEL_CAPS.get(zone_id, (1, 10))
        agent_level = int(agent["level"])
        monster_level = max(level_floor, min(level_cap, agent_level + (tick_count % 2)))

        if zone_id == 1 and monster_level <= 5:
            stat_range = LUMENVEIL_MINION_RANGE
            monster_type = "Minion"
            names = ["Goblin scout", "Wild boar", "Bandit runt", "Slime wisp"]
        else:
            stat_range = LUMENVEIL_REGULAR_RANGE
            monster_type = "Regular"
            names = ["Goblin raider", "Wolf pack leader", "Bandit enforcer", "Ruin crawler"]

        hp = self.random.randint(*stat_range["hp"])
        attack = self.random.randint(*stat_range["attack"])
        defense = self.random.randint(*stat_range["defense"])
        speed = self.random.randint(*stat_range["speed"])
        reward = self.random.randint(*stat_range["reward"])

        return {
            "name": self.random.choice(names),
            "type": monster_type,
            "level": monster_level,
            "hp": hp,
            "maxHp": hp,
            "attack": attack,
            "defense": defense,
            "speed": speed,
            "soulReward": reward,
            "zoneId": zone_id,
        }
