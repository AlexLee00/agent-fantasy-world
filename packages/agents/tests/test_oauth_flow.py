from __future__ import annotations

from pathlib import Path

from src.brain.oauth_flow import OAuthTokenStore, generate_state_token, parse_callback_url


def test_generate_state_token_changes():
    assert generate_state_token() != generate_state_token()


def test_parse_callback_url_extracts_code_and_state():
    result = parse_callback_url("http://localhost:8080/callback?code=abc123&state=xyz789")

    assert result.code == "abc123"
    assert result.state == "xyz789"


def test_token_store_round_trip(tmp_path: Path):
    store = OAuthTokenStore(tmp_path / "oauth.json")
    payload = {"access_token": "token", "refresh_token": "refresh", "expires_in": 3600}

    store.save(payload)

    assert store.load() == payload
