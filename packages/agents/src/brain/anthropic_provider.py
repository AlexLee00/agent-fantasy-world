from __future__ import annotations

import httpx

from src.agent.parser import parse_action_response
from src.brain.interface import AgentAction, BrainProvider, SYSTEM_PROMPT


class AnthropicProvider(BrainProvider):
    def __init__(self, api_key: str, model: str = "claude-sonnet-4-20250514"):
        if not api_key:
            raise ValueError("Anthropic API key is required")
        self.api_key = api_key
        self.model = model

    async def decide(self, prompt: str) -> AgentAction:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self.api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": self.model,
                    "max_tokens": 300,
                    "system": SYSTEM_PROMPT,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=30.0,
            )
            response.raise_for_status()
        data = response.json()
        raw = data["content"][0]["text"]
        return parse_action_response(raw)
