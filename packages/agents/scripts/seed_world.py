from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.chain.client import ChainClient
from src.config import Settings


ITEM_TYPES = [
    ("Basic Health Potion", "POTION", 1, 0, 5, True),
    ("Iron Sword", "WEAPON", 1, 2, 8, True),
    ("Leather Armor", "ARMOR", 1, 2, 7, True),
    ("Fire Sword", "WEAPON", 2, 8, 18, True),
    ("Steel Shield", "ARMOR", 2, 6, 16, True),
]

MONSTER_TYPES = {
    1: [
        ("Goblin Scout", 1, 30, 70, 8, 12, 3, 8, 5, 20),
        ("Forest Wolf", 1, 50, 90, 10, 15, 4, 8, 6, 18),
    ],
    2: [
        ("Dark Archer", 2, 100, 200, 15, 22, 8, 14, 20, 50),
        ("Stone Golem", 2, 150, 280, 13, 20, 10, 18, 25, 50),
    ],
    3: [
        ("Fire Drake", 3, 250, 500, 25, 35, 15, 24, 80, 150),
        ("Shadow Knight", 3, 300, 550, 22, 38, 18, 28, 90, 150),
    ],
    4: [
        ("Void Wyrm", 4, 600, 1500, 40, 70, 30, 50, 220, 450),
        ("Abyssal Lord", 4, 800, 1800, 50, 75, 35, 55, 260, 500),
    ],
}

NPC_TYPES = [
    ("Lumenveil Tavern", "TAVERN", 1),
    ("Lumenveil Shop", "SHOP", 1),
    ("Lumenveil Smithy", "SMITHY", 1),
    ("Graymarch Tavern", "TAVERN", 2),
    ("Graymarch Shop", "SHOP", 2),
    ("Embervault Tavern", "TAVERN", 3),
    ("Embervault Shop", "SHOP", 3),
    ("Voidreach Tavern", "TAVERN", 4),
    ("Voidreach Shop", "SHOP", 4),
]

NPC_PRICES = {
    "TAVERN": {
        1: 5,
    },
    "SHOP": {
        1: 10,
        2: 50,
        3: 40,
        4: 75,
        5: 60,
    },
    "SMITHY": {
        2: 50,
        4: 75,
        5: 60,
    },
}


def main() -> None:
    settings = Settings()
    chain = ChainClient(settings)
    chain.ensure_minter_role()

    total_item_types = int(chain.item_registry.functions.totalItemTypes().call())
    if total_item_types == 0:
        for item in ITEM_TYPES:
            item_id = chain.register_item_type(*item)
            print(f"Registered item type #{item_id}: {item[0]}")
    else:
        print(f"Item types already present: {total_item_types}")

    total_monster_types = int(chain.monster_registry.functions.totalMonsterTypes().call())
    if total_monster_types == 0:
        for zone_id, types in MONSTER_TYPES.items():
            for monster in types:
                type_id = chain.register_monster_type(*monster)
                print(f"Registered monster type #{type_id} for zone {zone_id}: {monster[0]}")
    else:
        print(f"Monster types already present: {total_monster_types}")

    total_npc_types = int(chain.npc_registry.functions.totalNPCTypes().call())
    if total_npc_types == 0:
        for npc in NPC_TYPES:
            type_id = chain.register_npc_type(*npc)
            print(f"Registered NPC type #{type_id}: {npc[0]}")
    else:
        print(f"NPC types already present: {total_npc_types}")

    total_monsters = int(chain.monster_registry.functions.totalMonsters().call())
    if total_monsters < 20:
        for zone_id, types in MONSTER_TYPES.items():
            for type_offset in range(len(types)):
                type_id = zone_id * 2 - 1 + type_offset
                for _ in range(3):
                    monster_id = chain.spawn_monster(type_id, zone_id)
                    print(f"Spawned monster #{monster_id} in zone {zone_id}")
    else:
        print(f"Monsters already spawned: {total_monsters}")

    total_npcs = int(chain.npc_registry.functions.totalNPCs().call())
    if total_npcs == 0:
        for type_id, npc in enumerate(NPC_TYPES, start=1):
            npc_id = chain.spawn_npc(type_id, npc[2], chain.w3.to_wei(100, "ether"))
            role = npc[1]
            for item_id, price in NPC_PRICES.get(role, {}).items():
                chain.set_npc_price(npc_id, item_id, chain.w3.to_wei(price, "ether"))
            print(f"Spawned NPC #{npc_id}: {npc[0]}")
    else:
        print(f"NPCs already spawned: {total_npcs}")


if __name__ == "__main__":
    main()
