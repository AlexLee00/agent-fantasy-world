from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class CodexAuthStore:
    def __init__(self, path: str | Path = "~/.codex/auth.json"):
        self.path = Path(path).expanduser()

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            raise FileNotFoundError(f"Codex auth file not found: {self.path}")
        return json.loads(self.path.read_text(encoding="utf-8"))

    def get_bearer_token(self) -> str:
        data = self.load()
        direct_api_key = data.get("OPENAI_API_KEY")
        if direct_api_key:
            return direct_api_key

        tokens = data.get("tokens")
        if not isinstance(tokens, dict):
            raise ValueError("Codex auth file does not contain token payload")

        access_token = tokens.get("access_token")
        if not access_token:
            raise ValueError("Codex auth file does not contain an access token")

        return access_token

    def auth_mode(self) -> str:
        data = self.load()
        return str(data.get("auth_mode") or "unknown")
