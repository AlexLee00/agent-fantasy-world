from __future__ import annotations

import json
import threading
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from eth_account.signers.local import LocalAccount
from web3 import Web3
from web3.contract import Contract

from src.config import Settings


class ChainClient:
    CLASS_LABELS = {
        1: "Warrior",
        2: "Mage",
        3: "Ranger",
        4: "Healer",
        5: "Tank",
    }

    STATUS_LABELS = {
        1: "ALIVE",
        2: "DEAD",
        3: "RESTING",
        4: "IN_COMBAT",
        5: "TRAVELING",
    }

    ITEM_IDS = {
        "BASIC_HEALTH_POTION": 1,
        "IRON_SWORD": 2,
        "LEATHER_ARMOR": 3,
        "FIRE_SWORD": 4,
        "STEEL_SHIELD": 5,
    }

    _account_locks: dict[str, threading.Lock] = {}
    _lock_guard = threading.Lock()

    def __init__(self, settings: Settings):
        self.settings = settings
        self.w3 = Web3(Web3.HTTPProvider(settings.rpc_url))
        if not self.w3.is_connected():
            raise RuntimeError(f"Unable to connect to RPC at {settings.rpc_url}")

        self.account: LocalAccount = self.w3.eth.account.from_key(settings.private_key)
        self.address = self.account.address

        self.agent_registry = self._contract(settings.agent_registry_address, self._load_abi("AgentRegistry"))
        self.world_map = self._contract(settings.world_map_address, self._load_abi("WorldMap"))
        self.soul_token = self._contract(settings.soul_token_address, self._load_abi("SOULToken"))
        self.economy_engine = self._contract(settings.economy_engine_address, self._load_abi("EconomyEngine"))
        self.quest_engine = self._contract(settings.quest_engine_address, self._load_abi("QuestEngine"))
        self.governance_dao = self._contract(settings.governance_dao_address, self._load_abi("GovernanceDAO"))
        self.monster_registry = self._contract(settings.monster_registry_address, self._load_abi("MonsterRegistry"))
        self.npc_registry = self._contract(settings.npc_registry_address, self._load_abi("NPCRegistry"))
        self.item_registry = self._contract(settings.item_registry_address, self._load_abi("ItemRegistry"))
        self.combat_resolver = self._contract(settings.combat_resolver_address, self._load_abi("CombatResolver"))
        self.marketplace = self._contract(settings.marketplace_address, self._load_abi("Marketplace"))
        self.event_treasury = self._contract(settings.event_treasury_address, self._load_abi("EventTreasury"))

        self._danger_labels: dict[int, str] = {}
        self._class_labels: dict[int, str] = {}
        self._status_labels: dict[int, str] = {}

    def create_agent(self, agent_class: int, personality: list[int]) -> int:
        class_id = self._normalize_class_id(agent_class)
        receipt = self._send_transaction(self.agent_registry.functions.createAgent(class_id, personality))
        events = self.agent_registry.events.AgentCreated().process_receipt(receipt)
        if not events:
            raise RuntimeError("AgentCreated event not found in transaction receipt")
        return int(events[0]["args"]["agentId"])

    def get_agent(self, agent_id: int) -> dict[str, Any]:
        result = self.agent_registry.functions.getAgent(agent_id).call()
        return self._parse_agent(result)

    def get_all_agents(self) -> list[dict[str, Any]]:
        total_agents = int(self.agent_registry.functions.totalAgents().call())
        return [self.get_agent(agent_id) for agent_id in range(1, total_agents + 1)]

    def get_zone(self, zone_id: int) -> dict[str, Any]:
        result = self.world_map.functions.getZone(zone_id).call()
        zone = self._parse_zone(result)
        zone["dangerLabel"] = self._danger_label(int(zone["dangerId"]))
        return zone

    def get_soul_balance(self, address: str | None = None) -> int:
        target = Web3.to_checksum_address(address or self.address)
        return int(self.soul_token.functions.balanceOf(target).call())

    def get_treasury_balance(self) -> int:
        return int(self.event_treasury.functions.balance().call())

    def get_total_supply_snapshot(self) -> dict[str, int]:
        return {
            "totalSupply": int(self.soul_token.functions.totalSupply().call()),
            "totalMinted": int(self.soul_token.functions.totalMinted().call()),
            "totalBurned": int(self.soul_token.functions.totalBurned().call()),
        }

    def update_agent_state(
        self,
        agent_id: int,
        new_stats: dict[str, int],
        exp_gained: int,
        new_zone: int,
        new_status: int,
    ) -> Any:
        stats_tuple = self._stats_tuple(new_stats)
        return self._send_transaction(
            self.agent_registry.functions.updateAgentState(
                agent_id,
                stats_tuple,
                int(exp_gained),
                int(new_zone),
                int(new_status),
            )
        )

    def spawn_monster(self, type_id: int, zone_id: int) -> int:
        receipt = self._send_transaction(self.monster_registry.functions.spawnMonster(int(type_id), int(zone_id)))
        events = self.monster_registry.events.MonsterSpawned().process_receipt(receipt)
        if not events:
            raise RuntimeError("MonsterSpawned event not found in receipt")
        return int(events[0]["args"]["monsterId"])

    def resolve_combat(self, agent_id: int, monster_id: int) -> dict[str, Any]:
        receipt = self._send_transaction(self.combat_resolver.functions.resolveCombat(int(agent_id), int(monster_id)))
        events = self.combat_resolver.events.CombatSettled().process_receipt(receipt)
        if not events:
            raise RuntimeError("CombatSettled event not found in receipt")
        args = events[0]["args"]
        return {
            "agentId": int(args["agentId"]),
            "monsterId": int(args["monsterId"]),
            "agentWins": bool(args["agentWins"]),
            "soulDelta": int(args["soulDelta"]),
            "xpDelta": int(args["xpDelta"]),
            "txHash": receipt["transactionHash"].hex(),
        }

    def buy_from_npc(self, npc_id: int, item_id: int) -> dict[str, Any]:
        price_entry = self.get_npc_price(npc_id, item_id)
        if not price_entry["available"]:
            raise RuntimeError(f"NPC {npc_id} item {item_id} is not available")
        self._ensure_erc20_approval(self.soul_token, self.settings.npc_registry_address, int(price_entry["price"]))
        receipt = self._send_transaction(self.npc_registry.functions.buyFromNPC(int(npc_id), int(item_id)))
        events = self.npc_registry.events.NPCPurchase().process_receipt(receipt)
        if not events:
            raise RuntimeError("NPCPurchase event not found in receipt")
        args = events[0]["args"]
        return {
            "npcId": int(args["npcId"]),
            "buyer": args["buyer"],
            "itemId": int(args["itemId"]),
            "price": int(args["price"]),
            "txHash": receipt["transactionHash"].hex(),
        }

    def create_market_order(self, item_id: int, amount: int, price: int) -> dict[str, Any]:
        if int(item_id) == 0:
            raise RuntimeError("AFW orders are not used in the agent engine flow")
        self._ensure_item_approval(self.settings.marketplace_address)
        receipt = self._send_transaction(
            self.marketplace.functions.createOrder(int(item_id), int(amount), int(price))
        )
        events = self.marketplace.events.OrderCreated().process_receipt(receipt)
        if not events:
            raise RuntimeError("OrderCreated event not found in receipt")
        args = events[0]["args"]
        return {
            "orderId": int(args["orderId"]),
            "seller": args["seller"],
            "itemId": int(args["itemId"]),
            "amount": int(args["amount"]),
            "priceInSOUL": int(args["priceInSOUL"]),
            "txHash": receipt["transactionHash"].hex(),
        }

    def fill_market_order(self, order_id: int) -> dict[str, Any]:
        order = self.get_market_order(order_id)
        if not order["active"]:
            raise RuntimeError(f"Order {order_id} is not active")
        self._ensure_erc20_approval(self.soul_token, self.settings.marketplace_address, int(order["priceInSOUL"]))
        receipt = self._send_transaction(self.marketplace.functions.fillOrder(int(order_id)))
        events = self.marketplace.events.OrderFilled().process_receipt(receipt)
        if not events:
            raise RuntimeError("OrderFilled event not found in receipt")
        args = events[0]["args"]
        return {
            "orderId": int(args["orderId"]),
            "buyer": args["buyer"],
            "feeBurned": int(args["feeBurned"]),
            "txHash": receipt["transactionHash"].hex(),
        }

    def get_market_order(self, order_id: int) -> dict[str, Any]:
        return self._parse_order(self.marketplace.functions.orders(int(order_id)).call(), order_id)

    def get_active_orders(self) -> list[dict[str, Any]]:
        total_orders = int(self.marketplace.functions.totalOrders().call())
        orders = [self.get_market_order(order_id) for order_id in range(1, total_orders + 1)]
        return [order for order in orders if order["active"]]

    def get_monsters_in_zone(self, zone_id: int) -> list[dict[str, Any]]:
        total_monsters = int(self.monster_registry.functions.totalMonsters().call())
        monsters: list[dict[str, Any]] = []
        for monster_id in range(1, total_monsters + 1):
            monster = self._parse_monster(self.monster_registry.functions.getMonster(monster_id).call(), monster_id)
            if monster["zoneId"] != int(zone_id) or not monster["alive"]:
                continue
            monster_type = self.get_monster_type(monster["typeId"])
            monster["name"] = monster_type["name"]
            monster["dangerLevel"] = monster_type["dangerLevel"]
            monsters.append(monster)
        return monsters

    def get_monster_in_zone(self, zone_id: int) -> dict[str, Any] | None:
        monsters = self.get_monsters_in_zone(zone_id)
        return monsters[0] if monsters else None

    def get_monster_type(self, type_id: int) -> dict[str, Any]:
        return self._parse_monster_type(self.monster_registry.functions.getMonsterType(int(type_id)).call(), type_id)

    def get_npcs_in_zone(self, zone_id: int) -> list[dict[str, Any]]:
        total_npcs = int(self.npc_registry.functions.totalNPCs().call())
        npcs: list[dict[str, Any]] = []
        for npc_id in range(1, total_npcs + 1):
            npc = self._parse_npc(self.npc_registry.functions.npcs(int(npc_id)).call(), npc_id)
            if npc["zoneId"] != int(zone_id) or not npc["active"]:
                continue
            npc_type = self.get_npc_type(npc["typeId"])
            npc["name"] = npc_type["name"]
            npc["role"] = npc_type["role"]
            npcs.append(npc)
        return npcs

    def get_npc_in_zone(self, zone_id: int, role: str | None = None) -> dict[str, Any] | None:
        for npc in self.get_npcs_in_zone(zone_id):
            if role is None or npc["role"].upper() == role.upper():
                return npc
        return None

    def get_npc_type(self, type_id: int) -> dict[str, Any]:
        return self._parse_npc_type(self.npc_registry.functions.npcTypes(int(type_id)).call(), type_id)

    def get_npc_price(self, npc_id: int, item_id: int) -> dict[str, Any]:
        raw = self._normalize(self.npc_registry.functions.npcPrices(int(npc_id), int(item_id)).call())
        return {
            "itemId": int(raw[0]),
            "price": int(raw[1]),
            "available": bool(raw[2]),
        }

    def get_agent_items(self, agent_address: str | None = None) -> list[dict[str, Any]]:
        holder = Web3.to_checksum_address(agent_address or self.address)
        total_item_types = int(self.item_registry.functions.totalItemTypes().call())
        items: list[dict[str, Any]] = []
        for item_id in range(1, total_item_types + 1):
            balance = int(self.item_registry.functions.balanceOf(holder, item_id).call())
            if balance <= 0:
                continue
            item_type = self._parse_item_type(self.item_registry.functions.itemTypes(item_id).call(), item_id)
            items.append({**item_type, "amount": balance})
        return items

    def get_all_item_types(self) -> list[dict[str, Any]]:
        total_item_types = int(self.item_registry.functions.totalItemTypes().call())
        return [
            self._parse_item_type(self.item_registry.functions.itemTypes(item_id).call(), item_id)
            for item_id in range(1, total_item_types + 1)
        ]

    def get_combat_logs(self, from_block: int, to_block: int | str = "latest") -> list[dict[str, Any]]:
        logs = self.combat_resolver.events.CombatSettled().get_logs(from_block=from_block, to_block=to_block)
        results: list[dict[str, Any]] = []
        for entry in logs:
            args = entry["args"]
            results.append(
                {
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "agentId": int(args["agentId"]),
                    "monsterId": int(args["monsterId"]),
                    "agentWins": bool(args["agentWins"]),
                    "soulDelta": int(args["soulDelta"]),
                    "xpDelta": int(args["xpDelta"]),
                }
            )
        return results

    def get_market_logs(self, from_block: int, to_block: int | str = "latest") -> list[dict[str, Any]]:
        logs = self.marketplace.events.OrderFilled().get_logs(from_block=from_block, to_block=to_block)
        results: list[dict[str, Any]] = []
        for entry in logs:
            args = entry["args"]
            results.append(
                {
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "orderId": int(args["orderId"]),
                    "buyer": args["buyer"],
                    "feeBurned": int(args["feeBurned"]),
                }
            )
        return results

    def get_npc_purchase_logs(self, from_block: int, to_block: int | str = "latest") -> list[dict[str, Any]]:
        logs = self.npc_registry.events.NPCPurchase().get_logs(from_block=from_block, to_block=to_block)
        results: list[dict[str, Any]] = []
        for entry in logs:
            args = entry["args"]
            results.append(
                {
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "npcId": int(args["npcId"]),
                    "buyer": args["buyer"],
                    "itemId": int(args["itemId"]),
                    "price": int(args["price"]),
                }
            )
        return results

    def get_soul_transfer_logs(self, from_block: int, to_block: int | str = "latest") -> list[dict[str, Any]]:
        logs = self.soul_token.events.Transfer().get_logs(from_block=from_block, to_block=to_block)
        results: list[dict[str, Any]] = []
        for entry in logs:
            args = entry["args"]
            results.append(
                {
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "from": args["from"],
                    "to": args["to"],
                    "value": int(args["value"]),
                }
            )
        return results

    def get_treasury_logs(self, from_block: int, to_block: int | str = "latest") -> list[dict[str, Any]]:
        deposits = self.event_treasury.events.TreasuryDeposited().get_logs(from_block=from_block, to_block=to_block)
        triggers = self.event_treasury.events.WorldEventTriggered().get_logs(from_block=from_block, to_block=to_block)
        results: list[dict[str, Any]] = []
        for entry in deposits:
            args = entry["args"]
            results.append(
                {
                    "kind": "TREASURY_DEPOSIT",
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "amount": int(args["amount"]),
                    "newBalance": int(args["newBalance"]),
                }
            )
        for entry in triggers:
            args = entry["args"]
            results.append(
                {
                    "kind": "WORLD_EVENT",
                    "blockNumber": int(entry["blockNumber"]),
                    "transactionHash": entry["transactionHash"].hex(),
                    "thresholdId": int(args["thresholdId"]),
                    "eventType": args["eventType"],
                    "amount": int(args["amount"]),
                }
            )
        return sorted(results, key=lambda item: item["blockNumber"])

    def register_item_type(
        self,
        name: str,
        category: str,
        tier: int,
        min_stat: int,
        max_stat: int,
        tradeable: bool,
    ) -> int:
        receipt = self._send_transaction(
            self.item_registry.functions.registerItemType(name, category, int(tier), int(min_stat), int(max_stat), bool(tradeable))
        )
        events = self.item_registry.events.ItemTypeRegistered().process_receipt(receipt)
        if not events:
            raise RuntimeError("ItemTypeRegistered event not found in receipt")
        return int(events[0]["args"]["itemId"])

    def register_monster_type(
        self,
        name: str,
        danger_level: int,
        min_hp: int,
        max_hp: int,
        min_atk: int,
        max_atk: int,
        min_def: int,
        max_def: int,
        min_soul: int,
        max_soul: int,
    ) -> int:
        receipt = self._send_transaction(
            self.monster_registry.functions.registerMonsterType(
                name,
                int(danger_level),
                int(min_hp),
                int(max_hp),
                int(min_atk),
                int(max_atk),
                int(min_def),
                int(max_def),
                int(min_soul),
                int(max_soul),
            )
        )
        events = self.monster_registry.events.MonsterTypeRegistered().process_receipt(receipt)
        if not events:
            raise RuntimeError("MonsterTypeRegistered event not found in receipt")
        return int(events[0]["args"]["typeId"])

    def register_npc_type(self, name: str, role: str, zone_id: int) -> int:
        receipt = self._send_transaction(self.npc_registry.functions.registerNPCType(name, role, int(zone_id)))
        events = self.npc_registry.events.NPCTypeRegistered().process_receipt(receipt)
        if not events:
            raise RuntimeError("NPCTypeRegistered event not found in receipt")
        return int(events[0]["args"]["typeId"])

    def spawn_npc(self, type_id: int, zone_id: int, initial_soul: int) -> int:
        receipt = self._send_transaction(self.npc_registry.functions.spawnNPC(int(type_id), int(zone_id), int(initial_soul)))
        events = self.npc_registry.events.NPCSpawned().process_receipt(receipt)
        if not events:
            raise RuntimeError("NPCSpawned event not found in receipt")
        return int(events[0]["args"]["npcId"])

    def set_npc_price(self, npc_id: int, item_id: int, price: int) -> None:
        self._send_transaction(self.npc_registry.functions.setPrice(int(npc_id), int(item_id), int(price)))

    def fund_address(self, address: str, amount_wei: int) -> str:
        tx_hash = self._send_native_transfer(address, amount_wei)
        return tx_hash.hex()

    def ensure_oracle_role(self, address: str | None = None) -> bool:
        return self._ensure_role(self.agent_registry, "ORACLE_ROLE", address or self.address)

    def ensure_minter_role(self, address: str | None = None) -> bool:
        return self._ensure_role(self.soul_token, "MINTER_ROLE", address or self.address)

    def ensure_burner_role(self, address: str | None = None) -> bool:
        return self._ensure_role(self.soul_token, "BURNER_ROLE", address or self.address)

    def ensure_quest_role(self, address: str | None = None) -> bool:
        return self._ensure_role(self.economy_engine, "QUEST_ROLE", address or self.address)

    def mint_soul(self, to: str, amount_wei: int, reason: str = "agent_bootstrap", ref_id: int = 0) -> Any:
        return self._send_transaction(
            self.soul_token.functions.mint(
                Web3.to_checksum_address(to),
                int(amount_wei),
                reason,
                int(ref_id),
            )
        )

    def ensure_initial_soul(self, minimum_tokens: int = 50) -> bool:
        minimum_wei = self.w3.to_wei(minimum_tokens, "ether")
        if self.get_soul_balance() >= minimum_wei:
            return False
        self.ensure_minter_role()
        self.mint_soul(self.address, minimum_wei, "agent_bootstrap", 0)
        return True

    def _ensure_role(self, contract: Contract, role_name: str, target_address: str) -> bool:
        target = Web3.to_checksum_address(target_address)
        role = getattr(contract.functions, role_name)().call()
        has_role = contract.functions.hasRole(role, target).call()
        if has_role:
            return False
        self._send_transaction(contract.functions.grantRole(role, target))
        return True

    def _contract(self, address: str, abi: list[dict[str, Any]]) -> Contract:
        return self.w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)

    def _load_abi(self, name: str) -> list[dict[str, Any]]:
        chain_abi_path = Path(__file__).resolve().parent / "abis" / f"{name}.json"
        contracts_artifact_path = Path(__file__).resolve().parents[3] / "contracts" / "artifacts" / "src"
        matches = list(contracts_artifact_path.glob(f"**/{name}.sol/{name}.json"))
        if matches:
            return json.loads(matches[0].read_text(encoding="utf-8"))["abi"]
        return json.loads(chain_abi_path.read_text(encoding="utf-8"))

    def _send_transaction(self, function_call: Any) -> Any:
        with self._account_lock():
            nonce = self.w3.eth.get_transaction_count(self.address, "pending")
            tx_defaults: dict[str, Any] = {
                "from": self.address,
                "nonce": nonce,
                "chainId": self.w3.eth.chain_id,
            }

            gas_price = self.w3.eth.gas_price
            if gas_price:
                tx_defaults["gasPrice"] = int(gas_price * 2)

            gas_estimate = self.w3.eth.estimate_gas(function_call.build_transaction(tx_defaults))
            transaction = function_call.build_transaction(
                {
                    **tx_defaults,
                    "gas": max(int(gas_estimate * 15 // 10), gas_estimate + 100_000),
                }
            )

            signed = self.account.sign_transaction(transaction)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            return self.w3.eth.wait_for_transaction_receipt(tx_hash)

    def _send_native_transfer(self, to: str, amount_wei: int) -> Any:
        with self._account_lock():
            nonce = self.w3.eth.get_transaction_count(self.address, "pending")
            gas_price = int(self.w3.eth.gas_price * 2)
            tx = {
                "from": self.address,
                "to": Web3.to_checksum_address(to),
                "value": int(amount_wei),
                "nonce": nonce,
                "chainId": self.w3.eth.chain_id,
                "gas": 21_000,
                "gasPrice": gas_price,
            }
            signed = self.account.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            self.w3.eth.wait_for_transaction_receipt(tx_hash)
            return tx_hash

    def _ensure_erc20_approval(self, token_contract: Contract, spender: str, amount: int) -> None:
        current = int(token_contract.functions.allowance(self.address, Web3.to_checksum_address(spender)).call())
        if current >= amount:
            return
        self._send_transaction(token_contract.functions.approve(Web3.to_checksum_address(spender), int(amount)))

    def _ensure_item_approval(self, operator: str) -> None:
        approved = bool(self.item_registry.functions.isApprovedForAll(self.address, Web3.to_checksum_address(operator)).call())
        if approved:
            return
        self._send_transaction(self.item_registry.functions.setApprovalForAll(Web3.to_checksum_address(operator), True))

    def _account_lock(self) -> threading.Lock:
        with self._lock_guard:
            if self.address not in self._account_locks:
                self._account_locks[self.address] = threading.Lock()
            return self._account_locks[self.address]

    def _stats_tuple(self, new_stats: dict[str, int]) -> tuple[int, int, int, int, int, int, int]:
        return (
            int(new_stats["hp"]),
            int(new_stats["maxHp"]),
            int(new_stats["mp"]),
            int(new_stats["maxMp"]),
            int(new_stats["attack"]),
            int(new_stats["defense"]),
            int(new_stats["speed"]),
        )

    def _normalize(self, value: Any) -> Any:
        if hasattr(value, "_asdict"):
            return {key: self._normalize(item) for key, item in value._asdict().items()}
        if isinstance(value, Mapping):
            return {key: self._normalize(item) for key, item in value.items()}
        if isinstance(value, (list, tuple)):
            return [self._normalize(item) for item in value]
        return value

    def _parse_agent(self, value: Any) -> dict[str, Any]:
        raw = self._normalize(value)
        personality = raw[7]
        stats = raw[8]
        class_id = int(raw[2])
        status_id = int(raw[3])
        return {
            "agentId": int(raw[0]),
            "observer": raw[1],
            "classId": class_id,
            "agentClass": class_id,
            "className": self._class_label(class_id),
            "statusId": status_id,
            "status": status_id,
            "statusName": self._status_label(status_id),
            "level": int(raw[4]),
            "experience": int(raw[5]),
            "zoneId": int(raw[6]),
            "personality": {
                "bravery": int(personality[0]),
                "greed": int(personality[1]),
                "sociability": int(personality[2]),
                "curiosity": int(personality[3]),
                "loyalty": int(personality[4]),
            },
            "stats": {
                "hp": int(stats[0]),
                "maxHp": int(stats[1]),
                "mp": int(stats[2]),
                "maxMp": int(stats[3]),
                "attack": int(stats[4]),
                "defense": int(stats[5]),
                "speed": int(stats[6]),
            },
            "createdAt": int(raw[9]),
            "lastActionBlock": int(raw[10]),
            "personalityHash": raw[11],
        }

    def _parse_zone(self, value: Any) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "zoneId": int(raw[0]),
            "name": raw[1],
            "koreanName": raw[2],
            "dangerId": int(raw[3]),
            "requiredNodes": int(raw[4]),
            "maxAgents": int(raw[5]),
            "isUnlocked": bool(raw[6]),
            "connections": [int(item) for item in raw[7]],
            "unlockedAt": int(raw[8]),
        }

    def _parse_monster_type(self, value: Any, type_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "typeId": int(type_id),
            "name": raw[0],
            "dangerLevel": int(raw[1]),
            "minHP": int(raw[2]),
            "maxHP": int(raw[3]),
            "minATK": int(raw[4]),
            "maxATK": int(raw[5]),
            "minDEF": int(raw[6]),
            "maxDEF": int(raw[7]),
            "minSOUL": int(raw[8]),
            "maxSOUL": int(raw[9]),
            "creator": raw[10],
            "active": bool(raw[11]),
        }

    def _parse_monster(self, value: Any, monster_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "monsterId": int(monster_id),
            "typeId": int(raw[0]),
            "hp": int(raw[1]),
            "atk": int(raw[2]),
            "def": int(raw[3]),
            "soulBalance": int(raw[4]),
            "zoneId": int(raw[5]),
            "alive": bool(raw[6]),
        }

    def _parse_npc_type(self, value: Any, type_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "typeId": int(type_id),
            "name": raw[0],
            "role": raw[1],
            "zoneId": int(raw[2]),
            "creator": raw[3],
            "active": bool(raw[4]),
        }

    def _parse_npc(self, value: Any, npc_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "npcId": int(npc_id),
            "typeId": int(raw[0]),
            "soulBalance": int(raw[1]),
            "zoneId": int(raw[2]),
            "active": bool(raw[3]),
        }

    def _parse_item_type(self, value: Any, item_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "itemId": int(item_id),
            "name": raw[0],
            "category": raw[1],
            "tier": int(raw[2]),
            "minStat": int(raw[3]),
            "maxStat": int(raw[4]),
            "creator": raw[5],
            "tradeable": bool(raw[6]),
        }

    def _parse_order(self, value: Any, order_id: int) -> dict[str, Any]:
        raw = self._normalize(value)
        return {
            "orderId": int(order_id),
            "seller": raw[0],
            "itemId": int(raw[1]),
            "amount": int(raw[2]),
            "priceInSOUL": int(raw[3]),
            "active": bool(raw[4]),
            "createdAt": int(raw[5]),
        }

    def _normalize_class_id(self, class_id: int) -> int:
        if 0 <= class_id <= 4:
            return class_id + 1
        return class_id

    def _class_label(self, class_id: int) -> str:
        if class_id not in self._class_labels:
            try:
                value = self.agent_registry.functions.classRegistry(class_id).call()
                name = self._normalize(value)[1]
                self._class_labels[class_id] = name or self.CLASS_LABELS.get(class_id, "Unknown")
            except Exception:
                self._class_labels[class_id] = self.CLASS_LABELS.get(class_id, "Unknown")
        return self._class_labels[class_id]

    def _status_label(self, status_id: int) -> str:
        if status_id not in self._status_labels:
            try:
                value = self.agent_registry.functions.statusRegistry(status_id).call()
                name = self._normalize(value)[1]
                self._status_labels[status_id] = name or self.STATUS_LABELS.get(status_id, "UNKNOWN")
            except Exception:
                self._status_labels[status_id] = self.STATUS_LABELS.get(status_id, "UNKNOWN")
        return self._status_labels[status_id]

    def _danger_label(self, danger_id: int) -> str:
        if danger_id not in self._danger_labels:
            try:
                value = self.world_map.functions.dangerLevels(danger_id).call()
                name = self._normalize(value)[1]
                self._danger_labels[danger_id] = name or "UNKNOWN"
            except Exception:
                self._danger_labels[danger_id] = "UNKNOWN"
        return self._danger_labels[danger_id]
