from __future__ import annotations


class WorldContextBuilder:
    def surroundings_for_zone(self, zone: dict) -> str:
        if int(zone.get("zoneId", 0)) == 1:
            return (
                "You are in a peaceful village. You see a tavern, a shop, a smithy, "
                "and a mage tower in the distance. Other agents may be nearby."
            )
        return "The terrain is unfamiliar, and you scan the area for threats and opportunities."

    def situation_for_zone(self, agent: dict, zone: dict, event: dict | None = None) -> str:
        hp = int(agent["stats"]["hp"])
        max_hp = max(1, int(agent["stats"]["maxHp"]))
        hp_ratio = hp * 100 // max_hp
        if event and event.get("kind") == "SURVIVAL":
            return str(event.get("summary") or "")
        if event and event.get("kind") == "MONSTER":
            return (
                f"{event.get('summary')} Decide whether to fight, flee, or reposition. "
                "Reckless actions may cost your life."
            )
        if event and event.get("kind") == "NPC":
            return f"{event.get('summary')} Conversation, rumors, and social choices matter here."
        if event and event.get("kind") == "TREASURE":
            return f"{event.get('summary')} Opportunity is close, but greed can still attract danger."
        if event and event.get("kind") == "REST":
            return f"{event.get('summary')} This is a good chance to recover before pressing onward."

        if int(zone.get("zoneId", 0)) == 1 and hp_ratio <= 25:
            return (
                "You are badly wounded from recent travel. A warm tavern nearby offers rest and safety, "
                "but the village outskirts may still hide treasure, rumors, or danger."
            )
        if int(zone.get("zoneId", 0)) == 1:
            return (
                "A fork in the road leads toward a quiet forest path, the tavern, and the market square. "
                "You sense a small opportunity ahead, but you must choose whether to seek danger, safety, or company."
            )
        return "You must weigh survival, curiosity, and opportunity before acting."

    def personality_guidance(self, agent: dict) -> str:
        personality = agent["personality"]
        bravery = int(personality["bravery"])
        greed = int(personality["greed"])
        sociability = int(personality["sociability"])
        curiosity = int(personality["curiosity"])

        lines: list[str] = ["Your personality STRONGLY influences your decisions."]
        if bravery >= 75:
            lines.append("High bravery means you naturally prefer to FIGHT or EXPLORE rather than FLEE.")
        elif bravery <= 25:
            lines.append("Low bravery means you prefer to FLEE or REST instead of taking obvious risks.")

        if greed >= 75:
            lines.append("High greed means treasure and rewards can outweigh caution.")
        elif greed <= 25:
            lines.append("Low greed means treasure alone is not enough to justify danger.")

        if sociability >= 75:
            lines.append("High sociability means you are drawn to TALK, taverns, townsfolk, and safe company.")
        if curiosity >= 75:
            lines.append("High curiosity means unexplored paths and mysteries strongly pull you toward EXPLORE.")

        return " ".join(lines)

    def event_for_prompt(self, event: dict | None) -> str:
        if not event:
            return "No major event has appeared yet. Stay alert for danger, opportunity, or allies."
        metadata = event.get("metadata") or {}
        lines = [
            f"Type: {event.get('kind', 'UNKNOWN')}",
            f"Title: {event.get('title', 'Unknown event')}",
            f"Danger: {event.get('danger', 'LOW')}",
            f"Summary: {event.get('summary', '')}",
        ]
        target = event.get("target")
        if target:
            lines.append(f"Focus: {target}")
        monster = metadata.get("monster")
        if monster:
            lines.append(
                "Threat Stats: "
                f"LV {monster.get('level')} | "
                f"HP {monster.get('hp')} | "
                f"ATK {monster.get('attack')} | "
                f"DEF {monster.get('defense')} | "
                f"SPD {monster.get('speed')}"
            )
        if metadata.get("force_survival"):
            lines.append("Constraint: Survival comes before ambition. Avoid lethal risks.")
        npc = metadata.get("npc")
        if isinstance(npc, dict):
            lines.append(
                "NPC: "
                f"{npc.get('name', 'Unknown')} | "
                f"Role {npc.get('role', 'NPC')} | "
                f"SOUL {npc.get('soulBalance', 0)}"
            )
        orders = metadata.get("orders")
        if isinstance(orders, list):
            lines.append(f"Marketplace: {len(orders)} active orders currently exist.")
        return "\n".join(lines)
