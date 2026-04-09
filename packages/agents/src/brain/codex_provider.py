from __future__ import annotations

from openai import AsyncOpenAI

from src.agent.parser import parse_action_response
from src.brain.codex_auth import CodexAuthStore
from src.brain.interface import AgentAction, BrainProvider, SYSTEM_PROMPT


class CodexOAuthProvider(BrainProvider):
    """
    Reuses the local `codex login` session.

    This is intentionally thin: AFW does not implement the Codex OAuth browser flow itself.
    Instead it consumes the credential material that the official Codex CLI stores locally.
    """

    def __init__(self, auth_file: str = "~/.codex/auth.json", model: str = "gpt-4o-mini"):
        self.store = CodexAuthStore(auth_file)
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
