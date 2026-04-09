from __future__ import annotations

import json
import secrets
import threading
import time
import webbrowser
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from src.brain.openai_provider import OpenAIOAuthHelper, OpenAIOAuthProvider
from src.config import Settings


@dataclass
class OAuthCallbackResult:
    code: str
    state: str


def generate_state_token() -> str:
    return secrets.token_urlsafe(24)


def parse_callback_url(callback_url: str) -> OAuthCallbackResult:
    parsed = urlparse(callback_url)
    params = parse_qs(parsed.query)
    code = params.get("code", [""])[0]
    state = params.get("state", [""])[0]
    if not code:
        raise ValueError("OAuth callback did not include a code")
    if not state:
        raise ValueError("OAuth callback did not include a state")
    return OAuthCallbackResult(code=code, state=state)


class OAuthTokenStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> dict[str, Any] | None:
        if not self.path.exists():
            return None
        return json.loads(self.path.read_text(encoding="utf-8"))

    def save(self, payload: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def wait_for_local_callback(redirect_uri: str, expected_state: str, timeout_seconds: int = 180) -> OAuthCallbackResult:
    parsed = urlparse(redirect_uri)
    if parsed.hostname not in {"127.0.0.1", "localhost"}:
        raise ValueError("Experimental OAuth flow only supports localhost redirect URIs")

    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or 80
    expected_path = parsed.path or "/"
    result: dict[str, OAuthCallbackResult] = {}
    error: dict[str, str] = {}

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            request_path = urlparse(self.path)
            if request_path.path != expected_path:
                self.send_response(404)
                self.end_headers()
                return

            try:
                callback = parse_callback_url(f"http://{host}:{port}{self.path}")
                if callback.state != expected_state:
                    raise ValueError("OAuth state mismatch")
                result["value"] = callback
                body = (
                    "<html><body><h1>AFW OAuth complete</h1>"
                    "<p>You can close this window and return to the terminal.</p></body></html>"
                )
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(body.encode("utf-8"))
            except Exception as exc:
                error["value"] = str(exc)
                body = f"<html><body><h1>AFW OAuth failed</h1><p>{exc}</p></body></html>"
                self.send_response(400)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(body.encode("utf-8"))

        def log_message(self, format: str, *args):
            return

    server = HTTPServer((host, port), CallbackHandler)
    thread = threading.Thread(target=server.handle_request, daemon=True)
    thread.start()

    deadline = time.time() + timeout_seconds
    try:
        while time.time() < deadline:
            if "value" in result:
                return result["value"]
            if "value" in error:
                raise ValueError(error["value"])
            time.sleep(0.1)
        raise TimeoutError("Timed out waiting for OAuth callback")
    finally:
        server.server_close()


async def ensure_experimental_openai_oauth(settings: Settings) -> OpenAIOAuthProvider:
    if not settings.openai_oauth_client_id or not settings.openai_oauth_client_secret:
        raise ValueError("OPENAI_OAUTH_CLIENT_ID and OPENAI_OAUTH_CLIENT_SECRET are required for oauth mode")

    token_store = OAuthTokenStore(settings.openai_oauth_token_path)
    stored = token_store.load()
    if stored and stored.get("access_token"):
        return OpenAIOAuthProvider(stored["access_token"], settings.openai_model)

    helper = OpenAIOAuthHelper(
        client_id=settings.openai_oauth_client_id,
        client_secret=settings.openai_oauth_client_secret,
        redirect_uri=settings.openai_oauth_redirect_uri,
    )
    state = generate_state_token()
    auth_url = helper.get_auth_url(state=state)

    print("   Experimental OpenAI OAuth flow starting")
    print("   This flow is not guaranteed to be supported by the current OpenAI platform.")
    print(f"   Redirect URI: {settings.openai_oauth_redirect_uri}")
    print(f"   Auth URL: {auth_url}")

    opened = webbrowser.open(auth_url)
    if not opened:
        print("   Browser did not open automatically. Open the URL above manually.")

    callback = wait_for_local_callback(settings.openai_oauth_redirect_uri, state)
    payload = await helper.exchange_code_for_token(callback.code)
    token_store.save(payload)
    return OpenAIOAuthProvider(payload["access_token"], settings.openai_model)
