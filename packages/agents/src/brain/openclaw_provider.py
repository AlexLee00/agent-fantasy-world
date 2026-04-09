from __future__ import annotations

from openai import AsyncOpenAI

from src.agent.parser import parse_action_response
from src.brain.interface import AgentAction, BrainProvider, SYSTEM_PROMPT
from src.brain.openclaw_auth import OpenClawAuthStore


class OpenClawOAuthProvider(BrainProvider):
    """
    Primary AFW auth path.

    Reuses the OAuth access token stored by OpenClaw for the `openai-codex`
    provider instead of asking AFW users to manage a separate API key.
    """

    def __init__(
        self,
        auth_file: str = "~/.openclaw/agents/main/agent/auth-profiles.json",
        provider: str = "openai-codex",
        profile_key: str = "",
        model: str = "gpt-4o-mini",
    ):
        self.store = OpenClawAuthStore(auth_file, provider=provider, profile_key=profile_key)
        self.model = model
        self.client = AsyncOpenAI(api_key=self.store.get_bearer_token())

    async def decide(self, prompt: str) -> AgentAction:
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.7,
            max_tokens=300,
        )
        raw = response.choices[0].message.content or "{}"
        return parse_action_response(raw)
