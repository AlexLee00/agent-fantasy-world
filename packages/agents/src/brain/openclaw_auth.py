from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class OpenClawAuthStore:
    def __init__(
        self,
        path: str | Path = "~/.openclaw/agents/main/agent/auth-profiles.json",
        provider: str = "openai-codex",
        profile_key: str = "",
    ):
        self.path = Path(path).expanduser()
        self.provider = provider
        self.profile_key = profile_key

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            raise FileNotFoundError(f"OpenClaw auth file not found: {self.path}")
        return json.loads(self.path.read_text(encoding="utf-8"))

    def get_profile(self) -> dict[str, Any]:
        data = self.load()
        profiles = data.get("profiles") or {}
        if not isinstance(profiles, dict):
            raise ValueError("OpenClaw auth file has invalid profiles payload")

        if self.profile_key:
            profile = profiles.get(self.profile_key)
            if self._is_valid_profile(profile):
                return profile
            raise ValueError(f"OpenClaw profile not found or invalid: {self.profile_key}")

        last_good = data.get("lastGood") or {}
        preferred_key = last_good.get(self.provider)
        preferred = profiles.get(preferred_key) if preferred_key else None
        if self._is_valid_profile(preferred):
            return preferred

        for profile in profiles.values():
            if self._is_valid_profile(profile):
                return profile

        raise ValueError(f"No valid OpenClaw OAuth profile found for provider {self.provider}")

    def get_bearer_token(self) -> str:
        profile = self.get_profile()
        access_token = profile.get("access")
        if not access_token:
            raise ValueError("OpenClaw profile does not contain an access token")
        return str(access_token)

    def get_account_id(self) -> str | None:
        profile = self.get_profile()
        account_id = profile.get("accountId")
        return str(account_id) if account_id else None

    def get_expiry(self) -> str | None:
        profile = self.get_profile()
        expires = profile.get("expires")
        return str(expires) if expires else None

    def _is_valid_profile(self, profile: Any) -> bool:
        return (
            isinstance(profile, dict)
            and profile.get("type") == "oauth"
            and profile.get("provider") == self.provider
            and bool(profile.get("access"))
        )
