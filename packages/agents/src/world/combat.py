from __future__ import annotations

import random
from dataclasses import dataclass


CLASS_MODIFIERS = {
    1: 1.0,  # Warrior
    2: 1.3,  # Mage
    3: 1.1,  # Ranger
    4: 0.6,  # Healer
    5: 0.8,  # Tank
}


@dataclass
class CombatOutcome:
    hp: int
    mp: int
    status: int
    exp_gained: int
    summary: str
    survived: bool
    event_resolved: bool


def compute_damage(attack: int, defense: int, class_modifier: float, rng: random.Random) -> int:
    base_damage = attack * class_modifier - defense * 0.5
    final_damage = int(round(base_damage * (0.8 + rng.random() * 0.4)))
    return max(1, final_damage)


class CombatResolver:
    def __init__(self, seed: int | None = None):
        self.random = random.Random(seed)

    def resolve(self, agent: dict, event: dict, action: str) -> CombatOutcome:
        monster = (event.get("metadata") or {}).get("monster") or {}
        stats = agent["stats"]
        hp = int(stats["hp"])
        mp = int(stats["mp"])

        if action == "FLEE":
            flee_success = int(stats["speed"]) + self.random.randint(0, 6) >= int(monster.get("speed", 0))
            if flee_success:
                return CombatOutcome(hp, mp, 4, 5, "You escaped the encounter.", True, True)

            chip_damage = max(1, int(monster.get("attack", 1)) // 3)
            hp = max(0, hp - chip_damage)
            survived = hp > 0
            return CombatOutcome(
                hp,
                mp,
                1 if not survived else 4,
                0,
                "You tried to flee but suffered a parting blow.",
                survived,
                False,
            )

        player_damage = compute_damage(
            int(stats["attack"]),
            int(monster.get("defense", 0)),
            CLASS_MODIFIERS.get(int(agent["agentClass"]), 1.0),
            self.random,
        )
        monster_hp = max(0, int(monster.get("hp", 1)) - player_damage)
        if monster_hp <= 0:
            return CombatOutcome(
                hp,
                mp,
                0,
                max(15, int(monster.get("level", 1)) * 8),
                f"You defeated the {monster.get('name', 'monster')}.",
                True,
                True,
            )

        retaliation = compute_damage(
            int(monster.get("attack", 1)),
            int(stats["defense"]),
            1.0,
            self.random,
        )
        hp = max(0, hp - retaliation)
        survived = hp > 0
        summary = f"You struck first, but the {monster.get('name', 'monster')} hit back for {retaliation} damage."
        return CombatOutcome(
            hp,
            mp,
            1 if not survived else 3,
            max(5, int(monster.get("level", 1)) * 3),
            summary,
            survived,
            False,
        )
