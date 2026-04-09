from __future__ import annotations

from src.world.combat import CombatResolver, compute_damage


def build_agent():
    return {
        "agentClass": 0,
        "stats": {
            "hp": 100,
            "maxHp": 100,
            "mp": 50,
            "maxMp": 50,
            "attack": 20,
            "defense": 15,
            "speed": 10,
        },
    }


def build_monster_event():
    return {
        "kind": "MONSTER",
        "metadata": {
            "monster": {
                "name": "Goblin scout",
                "level": 3,
                "hp": 20,
                "attack": 8,
                "defense": 3,
                "speed": 6,
            }
        },
    }


def test_compute_damage_never_drops_below_one():
    assert compute_damage(1, 999, 1.0, __import__("random").Random(1)) == 1


def test_fight_can_resolve_monster_event():
    resolver = CombatResolver(seed=2)

    outcome = resolver.resolve(build_agent(), build_monster_event(), "FIGHT")

    assert outcome.exp_gained >= 5
    assert outcome.status in {0, 3}


def test_flee_returns_travel_or_death_status():
    resolver = CombatResolver(seed=3)

    outcome = resolver.resolve(build_agent(), build_monster_event(), "FLEE")

    assert outcome.status in {1, 4}
