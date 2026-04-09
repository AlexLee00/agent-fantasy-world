from __future__ import annotations

import json
from pathlib import Path

from src.brain.openclaw_auth import OpenClawAuthStore


def test_openclaw_auth_store_uses_last_good_provider_profile(tmp_path: Path):
    path = tmp_path / "auth-profiles.json"
    path.write_text(
        json.dumps(
            {
                "lastGood": {"openai-codex": "openai-codex:default"},
                "profiles": {
                    "openai-codex:default": {
                        "type": "oauth",
                        "provider": "openai-codex",
                        "access": "token-123",
                        "accountId": "acct-1",
                        "expires": "2099-01-01T00:00:00Z",
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    store = OpenClawAuthStore(path)

    assert store.get_bearer_token() == "token-123"
    assert store.get_account_id() == "acct-1"
    assert store.get_expiry() == "2099-01-01T00:00:00Z"


def test_openclaw_auth_store_falls_back_to_matching_profile(tmp_path: Path):
    path = tmp_path / "auth-profiles.json"
    path.write_text(
        json.dumps(
            {
                "lastGood": {},
                "profiles": {
                    "other": {"type": "oauth", "provider": "other", "access": "skip"},
                    "openai-codex:secondary": {
                        "type": "oauth",
                        "provider": "openai-codex",
                        "access": "token-456",
                    },
                },
            }
        ),
        encoding="utf-8",
    )

    store = OpenClawAuthStore(path)

    assert store.get_bearer_token() == "token-456"


def test_openclaw_auth_store_honors_explicit_profile_key(tmp_path: Path):
    path = tmp_path / "auth-profiles.json"
    path.write_text(
        json.dumps(
            {
                "lastGood": {"openai-codex": "openai-codex:default"},
                "profiles": {
                    "openai-codex:default": {
                        "type": "oauth",
                        "provider": "openai-codex",
                        "access": "token-default",
                    },
                    "openai-codex:custom": {
                        "type": "oauth",
                        "provider": "openai-codex",
                        "access": "token-custom",
                    },
                },
            }
        ),
        encoding="utf-8",
    )

    store = OpenClawAuthStore(path, profile_key="openai-codex:custom")

    assert store.get_bearer_token() == "token-custom"
