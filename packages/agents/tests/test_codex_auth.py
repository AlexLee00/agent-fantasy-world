from __future__ import annotations

import json
from pathlib import Path

from src.brain.codex_auth import CodexAuthStore


def test_codex_auth_store_prefers_openai_api_key(tmp_path: Path):
    path = tmp_path / "auth.json"
    path.write_text(
        json.dumps(
            {
                "auth_mode": "apikey",
                "OPENAI_API_KEY": "sk-test",
                "tokens": {"access_token": "access-test"},
            }
        ),
        encoding="utf-8",
    )

    store = CodexAuthStore(path)

    assert store.get_bearer_token() == "sk-test"
    assert store.auth_mode() == "apikey"


def test_codex_auth_store_uses_access_token_for_chatgpt_mode(tmp_path: Path):
    path = tmp_path / "auth.json"
    path.write_text(
        json.dumps(
            {
                "auth_mode": "chatgpt",
                "OPENAI_API_KEY": None,
                "tokens": {"access_token": "access-test", "refresh_token": "refresh-test"},
            }
        ),
        encoding="utf-8",
    )

    store = CodexAuthStore(path)

    assert store.get_bearer_token() == "access-test"
    assert store.auth_mode() == "chatgpt"
