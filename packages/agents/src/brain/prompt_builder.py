from __future__ import annotations

from src.world.context import WorldContextBuilder


class PromptBuilder:
    def __init__(self):
        self.world_context = WorldContextBuilder()

    def build(
        self,
        agent: dict,
        zone: dict,
        history: list[str],
        event: dict | None = None,
        world_state: dict | None = None,
    ) -> str:
        recent_history = "\n".join(history[-5:]) if history else "You just arrived in this world."
        surroundings = self.world_context.surroundings_for_zone(zone)
        situation = self.world_context.situation_for_zone(agent, zone, event)
        personality_guidance = self.world_context.personality_guidance(agent)
        event_block = self.world_context.event_for_prompt(event)
        world_state = world_state or {}
        monsters = world_state.get("monsters") or []
        npcs = world_state.get("npcs") or []
        items = world_state.get("items") or []
        orders = world_state.get("orders") or []
        treasury_balance = int(world_state.get("treasuryBalance") or 0)

        economy_block = (
            f"Nearby monsters: {len(monsters)}\n"
            f"Nearby NPCs: {len(npcs)}\n"
            f"Inventory entries: {len(items)}\n"
            f"Marketplace orders: {len(orders)}\n"
            f"SOUL wallet: {world_state.get('soulBalance', 0)}\n"
            f"Event Treasury: {treasury_balance}"
        )

        return f"""
== YOUR IDENTITY ==
Class: {agent["className"]} ({agent["classId"]}) | Level: {agent["level"]}
HP: {agent["stats"]["hp"]}/{agent["stats"]["maxHp"]}
MP: {agent["stats"]["mp"]}/{agent["stats"]["maxMp"]}
ATK: {agent["stats"]["attack"]} | DEF: {agent["stats"]["defense"]} | SPD: {agent["stats"]["speed"]}
Status: {agent["statusName"]} ({agent["statusId"]})

== YOUR PERSONALITY ==
Bravery: {agent["personality"]["bravery"]}/100
Greed: {agent["personality"]["greed"]}/100
Sociability: {agent["personality"]["sociability"]}/100
Curiosity: {agent["personality"]["curiosity"]}/100
Loyalty: {agent["personality"]["loyalty"]}/100
{personality_guidance}

== CURRENT LOCATION ==
Zone: {zone["name"]} (Danger: {zone["dangerLabel"]})

== SURROUNDINGS ==
{surroundings}

== WORLD ECONOMY ==
{economy_block}

== CURRENT EVENT ==
{event_block}

== SITUATION ==
{situation}

== RECENT ACTIONS ==
{recent_history}

== DECIDE YOUR NEXT ACTION ==
""".strip()
