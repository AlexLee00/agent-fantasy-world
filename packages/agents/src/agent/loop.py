from __future__ import annotations

import asyncio
from dataclasses import dataclass

from src.agent.state import AgentStateReader
from src.brain.interface import AgentAction, BrainProvider
from src.brain.prompt_builder import PromptBuilder
from src.chain.client import ChainClient
from src.config import Settings
from src.world.event_generator import EventGenerator


@dataclass
class TickResult:
    tick: int
    action: str
    summary: str
    agent_id: int


class AgentLoop:
    def __init__(
        self,
        chain: ChainClient,
        brain: BrainProvider,
        prompt_builder: PromptBuilder,
        settings: Settings,
        *,
        agent_id: int | None = None,
        label: str = "",
    ):
        self.chain = chain
        self.brain = brain
        self.prompt_builder = prompt_builder
        self.settings = settings
        self.interval = settings.agent_loop_interval
        self.agent_id: int | None = agent_id
        self.label = label or chain.address
        self.history: list[str] = []
        self.tick_count = 0
        self.state_reader = AgentStateReader(chain)
        self.event_generator = EventGenerator(seed=7)

    async def start(self, max_ticks: int | None = None):
        self.agent_id = self._ensure_agent_exists()
        print(f"🏰 Agent #{self.agent_id} is alive in Aethermoor! [{self.label}]")

        while max_ticks is None or self.tick_count < max_ticks:
            try:
                await self._tick()
            except Exception as exc:
                print(f"⚠️ Error in tick: {exc}")
            if max_ticks is None or self.tick_count < max_ticks:
                await asyncio.sleep(self.interval)

    async def _tick(self) -> TickResult:
        if self.agent_id is None:
            raise RuntimeError("Agent loop started without an agent id")

        self.tick_count += 1
        state = self.state_reader.snapshot(self.agent_id)
        agent = state["agent"]
        zone = state["zone"]
        state["soulBalance"] = self.chain.get_soul_balance(agent["observer"])
        event = self.event_generator.generate_event(agent, zone, self.tick_count, state)
        prompt = self.prompt_builder.build(agent, zone, self.history, event.__dict__, state)
        action = await self._decide_with_fallback(prompt, agent, event.__dict__)

        log = f"[Tick {self.tick_count}] {action.action}"
        if action.target:
            log += f" -> {action.target}"
        if action.dialogue:
            log += f' | Says: "{action.dialogue}"'
        if action.emotion:
            log += f" | {action.emotion}"
        print(log)

        self.history.append(log)
        self.history = self.history[-20:]

        summary = await self._apply_action(agent, zone, state, action, event.__dict__)
        return TickResult(self.tick_count, action.action, summary, self.agent_id)

    async def _apply_action(self, agent: dict, zone: dict, state: dict, action: AgentAction, event: dict) -> str:
        if self.agent_id is None:
            raise RuntimeError("Agent loop started without an agent id")

        status_map = {
            "EXPLORE": 5,
            "FIGHT": 4,
            "REST": 3,
            "FLEE": 5,
            "TALK": 1,
            "TRADE": 1,
            "USE_ITEM": 1,
        }
        new_status = status_map.get(action.action, 1)

        stats = dict(agent["stats"])
        exp_gained = 0
        event_kind = event.get("kind")
        summary = ""

        if event_kind == "MONSTER" and action.action == "FIGHT":
            target = self._select_monster(state.get("monsters") or [], action.target)
            if target:
                result = self.chain.resolve_combat(self.agent_id, int(target["monsterId"]))
                summary = (
                    f"On-chain combat vs {target['name']} -> "
                    f"{'WIN' if result['agentWins'] else 'LOSS'} | "
                    f"SOUL {result['soulDelta']} | XP {result['xpDelta']}"
                )
                self.history.append(f"[Combat] {summary}")
                return summary
            summary = "No monster was available for combat."
        elif event_kind == "MONSTER" and action.action == "FLEE":
            exp_gained = 2
            new_status = 5
            summary = "You disengaged and repositioned without taking the on-chain fight."
        elif action.action == "EXPLORE":
            exp_gained = 10
            if event_kind == "TREASURE":
                exp_gained += 12
            elif event_kind == "MONSTER":
                exp_gained += 5
            summary = "You explored the zone and learned more about the terrain."
        elif action.action == "REST":
            tavern = self._select_npc(state.get("npcs") or [], "TAVERN")
            if tavern:
                self.chain.buy_from_npc(int(tavern["npcId"]), self.chain.ITEM_IDS["BASIC_HEALTH_POTION"])
            heal_bonus = 30 if event_kind in {"REST", "SURVIVAL"} else 18
            mp_bonus = 15 if event_kind in {"REST", "SURVIVAL"} else 10
            stats["hp"] = min(int(stats["maxHp"]), int(stats["hp"]) + heal_bonus)
            stats["mp"] = min(int(stats["maxMp"]), int(stats["mp"]) + mp_bonus)
            exp_gained = 4
            summary = f"You recovered at {tavern['name'] if tavern else 'camp'} and restored your strength."
        elif action.action == "TALK":
            exp_gained = 8 if event_kind == "NPC" else 4
            summary = "You spent the tick gathering rumors and social context."
        elif action.action == "TRADE":
            summary = self._execute_trade_flow(state)
            exp_gained = 6
        elif action.action == "USE_ITEM":
            potion = next((item for item in state.get("items") or [] if item["itemId"] == self.chain.ITEM_IDS["BASIC_HEALTH_POTION"]), None)
            if potion:
                stats["hp"] = min(int(stats["maxHp"]), int(stats["hp"]) + 20)
                summary = "You used a potion from your inventory to stabilize yourself."
            else:
                summary = "You reached for an item, but your bag was empty."
            exp_gained = 2

        if int(stats["hp"]) <= 0:
            new_status = 2

        previous_level = int(agent["level"])
        self.chain.update_agent_state(
            self.agent_id,
            stats,
            exp_gained,
            int(agent["zoneId"]),
            new_status,
        )

        updated = self.chain.get_agent(self.agent_id)
        if int(updated["level"]) > previous_level:
            print(f"[LEVEL UP] Agent #{self.agent_id} reached Level {updated['level']}!")
        return summary or f"Completed action {action.action}."

    async def _decide_with_fallback(self, prompt: str, agent: dict, event: dict) -> AgentAction:
        try:
            return await self.brain.decide(prompt)
        except Exception as exc:
            fallback = self._fallback_action(agent, event)
            print(f"⚠️ Brain fallback engaged: {exc}")
            return fallback

    def _fallback_action(self, agent: dict, event: dict) -> AgentAction:
        hp_ratio = int(agent["stats"]["hp"]) / max(1, int(agent["stats"]["maxHp"]))
        event_kind = event.get("kind")
        if hp_ratio < 0.30 or event_kind == "SURVIVAL":
            return AgentAction(
                action="REST",
                target=event.get("target", "safe shelter"),
                reasoning="Low HP demands a survival-first decision.",
                dialogue="I need to live long enough to fight another day.",
                emotion="cautious",
                confidence=0.9,
            )
        if event_kind == "MONSTER":
            return AgentAction(
                action="FIGHT",
                target=event.get("target", "hostile creature"),
                reasoning="The path is blocked and battle is the clearest response.",
                dialogue="Stand aside or fall.",
                emotion="determined",
                confidence=0.7,
            )
        if event_kind == "NPC":
            return AgentAction(
                action="TALK",
                target=event.get("target", "traveler"),
                reasoning="Conversation is the safest useful action available.",
                dialogue="Tell me what you've seen on these roads.",
                emotion="curious",
                confidence=0.7,
            )
        return AgentAction(
            action="EXPLORE",
            target=event.get("target", "nearby path"),
            reasoning="Exploration is a safe default when no stronger signal is present.",
            dialogue="Let's see what waits ahead.",
            emotion="curious",
            confidence=0.6,
        )

    def _ensure_agent_exists(self) -> int:
        if self.agent_id is not None:
            return self.agent_id
        personality = self.settings.parsed_personality()
        return self.chain.create_agent(self.settings.normalized_agent_class(), personality)

    def _select_monster(self, monsters: list[dict], target: str) -> dict | None:
        if not monsters:
            return None
        normalized = target.strip().lower()
        if normalized:
            for monster in monsters:
                if normalized in str(monster.get("name", "")).lower():
                    return monster
        return monsters[0]

    def _select_npc(self, npcs: list[dict], role: str) -> dict | None:
        for npc in npcs:
            if str(npc.get("role", "")).upper() == role.upper():
                return npc
        return npcs[0] if npcs else None

    def _execute_trade_flow(self, state: dict) -> str:
        items = [item for item in state.get("items") or [] if item.get("tradeable") and int(item.get("amount", 0)) > 0]
        if items:
            item = sorted(items, key=lambda entry: (int(entry["tier"]), int(entry["itemId"])))[-1]
            price = max(self.chain.w3.to_wei(5, "ether"), self.chain.w3.to_wei(int(item["tier"]) * 10, "ether"))
            order = self.chain.create_market_order(int(item["itemId"]), 1, int(price))
            return f"Listed {item['name']} on the marketplace as order #{order['orderId']}."

        address_lower = self.chain.address.lower()
        orders = [
            order
            for order in state.get("orders") or []
            if order["active"] and order["seller"].lower() != address_lower and int(order["itemId"]) != 0
        ]
        if not orders:
            return "No good trade opportunity was available this tick."

        best_order = sorted(orders, key=lambda entry: int(entry["priceInSOUL"]))[0]
        if self.chain.get_soul_balance() < int(best_order["priceInSOUL"]):
            return "The marketplace had offers, but you could not afford them."
        result = self.chain.fill_market_order(int(best_order["orderId"]))
        return f"Filled marketplace order #{result['orderId']} and paid a fee of {result['feeBurned']} SOUL."
