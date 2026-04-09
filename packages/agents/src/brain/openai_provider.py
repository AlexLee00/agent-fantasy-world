from __future__ import annotations

from typing import Any

from openai import AsyncOpenAI

from src.agent.parser import parse_action_response
from src.brain.interface import AgentAction, BrainProvider, SYSTEM_PROMPT


class OpenAIKeyProvider(BrainProvider):
    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        if not api_key:
            raise ValueError("OpenAI API key is required")
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model

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


class OpenAIOAuthProvider(BrainProvider):
    def __init__(self, access_token: str, model: str = "gpt-4o-mini"):
        if not access_token:
            raise ValueError("OpenAI OAuth access token is required")
        self.client = AsyncOpenAI(api_key=access_token)
        self.model = model

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


class OpenAIOAuthHelper:
    AUTH_URL = "https://auth.openai.com/authorize"
    TOKEN_URL = "https://auth.openai.com/token"

    def __init__(self, client_id: str, client_secret: str, redirect_uri: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri

    def get_auth_url(self, state: str = "") -> str:
        import urllib.parse

        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "code",
            "scope": "openai.chat",
            "state": state,
        }
        return f"{self.AUTH_URL}?{urllib.parse.urlencode(params)}"

    async def exchange_code_for_token(self, code: str) -> dict[str, Any]:
        import httpx

        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "code": code,
                    "redirect_uri": self.redirect_uri,
                },
            )
            response.raise_for_status()
            return response.json()

    async def exchange_code(self, code: str) -> str:
        data = await self.exchange_code_for_token(code)
        return data["access_token"]

    async def refresh_token_payload(self, refresh_token: str) -> dict[str, Any]:
        import httpx

        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "refresh_token": refresh_token,
                },
            )
            response.raise_for_status()
            return response.json()

    async def refresh_token(self, refresh_token: str) -> str:
        data = await self.refresh_token_payload(refresh_token)
        return data["access_token"]


class OpenAIProvider(OpenAIKeyProvider):
    """Backwards-compatible default provider alias."""


def create_provider(
    mode: str = "key",
    api_key: str = "",
    access_token: str = "",
    model: str = "gpt-4o-mini",
) -> BrainProvider:
    if mode == "oauth" and access_token:
        return OpenAIOAuthProvider(access_token=access_token, model=model)
    if api_key:
        return OpenAIKeyProvider(api_key=api_key, model=model)
    raise ValueError("Provide either api_key or access_token")
