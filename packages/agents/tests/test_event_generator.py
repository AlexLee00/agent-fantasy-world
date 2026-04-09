from __future__ import annotations

from src.world.event_generator import EventGenerator


def build_agent(hp: int = 100, max_hp: int = 100, level: int = 1):
    return {
        "level": level,
        "agentClass": 0,
        "stats": {
            "hp": hp,
            "maxHp": max_hp,
            "mp": 50,
            "maxMp": 50,
            "attack": 20,
            "defense": 15,
            "speed": 10,
        },
        "personality": {
            "bravery": 70,
            "greed": 30,
            "sociability": 50,
            "curiosity": 80,
            "loyalty": 60,
        },
    }


def build_zone(zone_id: int = 1):
    return {"zoneId": zone_id, "name": "Lumenveil", "dangerLabel": "SAFE"}


def test_low_hp_forces_survival_event():
    generator = EventGenerator(seed=1)

    event = generator.generate_event(build_agent(hp=20, max_hp=100), build_zone(), 1)

    assert event.kind == "SURVIVAL"
    assert event.metadata["force_survival"] is True


def test_monster_event_follows_lumenveil_balance_ranges():
    generator = EventGenerator(seed=1)
    event = generator._monster_event(build_agent(level=3), build_zone(), 1)
    monster = event.metadata["monster"]

    assert event.kind == "MONSTER"
    assert 1 <= monster["level"] <= 10
    assert 20 <= monster["hp"] <= 80
    assert 5 <= monster["attack"] <= 12
    assert 3 <= monster["defense"] <= 8
    assert 3 <= monster["speed"] <= 10

