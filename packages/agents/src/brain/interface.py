from __future__ import annotations

from abc import ABC, abstractmethod

from pydantic import BaseModel, field_validator

VALID_ACTIONS = {"EXPLORE", "FIGHT", "FLEE", "REST", "TALK", "TRADE", "USE_ITEM"}
VALID_EMOTIONS = {"determined", "cautious", "curious", "afraid", "relaxed", "angry"}

SYSTEM_PROMPT = """You are an AI agent living in Aethermoor, a fantasy world.
You must decide your next action based on your personality and situation.

Respond ONLY with a JSON object, no other text:
{
  "action": "EXPLORE" | "FIGHT" | "FLEE" | "REST" | "TALK" | "TRADE" | "USE_ITEM",
  "target": "what you're acting on",
  "reasoning": "1-2 sentence internal thought",
  "dialogue": "what you say out loud, in character",
  "emotion": "determined" | "cautious" | "curious" | "afraid" | "relaxed" | "angry",
  "confidence": 0.0 to 1.0
}

Your personality STRONGLY influences your decisions:
- High bravery = prefer FIGHT
- High greed = prioritize treasure/TRADE
- High curiosity = prefer EXPLORE
- Low HP + low bravery = FLEE or REST
- High sociability = prefer TALK"""


class AgentAction(BaseModel):
    action: str = "EXPLORE"
    target: str = ""
    reasoning: str = ""
    dialogue: str = ""
    emotion: str = "cautious"
    confidence: float = 0.5

    @field_validator("action", mode="before")
    @classmethod
    def normalize_action(cls, value: object) -> str:
        if not isinstance(value, str):
            return "EXPLORE"
        normalized = value.strip().upper()
        if normalized not in VALID_ACTIONS:
            return "EXPLORE"
        return normalized

    @field_validator("emotion", mode="before")
    @classmethod
    def normalize_emotion(cls, value: object) -> str:
        if not isinstance(value, str):
            return "cautious"
        normalized = value.strip().lower()
        if normalized not in VALID_EMOTIONS:
            return "cautious"
        return normalized

    @field_validator("confidence", mode="before")
    @classmethod
    def clamp_confidence(cls, value: object) -> float:
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            numeric = 0.5
        return max(0.0, min(1.0, numeric))


class BrainProvider(ABC):
    @abstractmethod
    async def decide(self, prompt: str) -> AgentAction:
        """Send prompt to LLM, return parsed AgentAction."""
