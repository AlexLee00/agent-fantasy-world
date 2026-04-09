from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass

from src.agent.parser import parse_action_response
from src.brain.interface import AgentAction, BrainProvider, SYSTEM_PROMPT


@dataclass
class ClaudeCodeExecutionResult:
    result: str
    session_id: str | None = None
    duration_ms: int | None = None
    model: str | None = None
    usage: dict | None = None


def resolve_claude_code_model(model: str) -> str:
    normalized = str(model or "sonnet").strip()
    normalized = normalized.removeprefix("claude-code/").strip()
    return normalized or "sonnet"


def build_claude_code_args(
    *,
    model: str,
    system_prompt: str,
    user_prompt: str,
    session_name: str = "",
    settings_file: str = "",
    agent: str = "",
) -> list[str]:
    args = [
        "-p",
        "--output-format",
        "json",
        "--max-turns",
        "1",
        "--model",
        resolve_claude_code_model(model),
        "--tools",
        "",
        "--permission-mode",
        "default",
        "--no-session-persistence",
    ]
    if agent:
        args.extend(["--agent", agent])
    if session_name:
        args.extend(["--name", session_name])
    if settings_file:
        args.extend(["--settings", settings_file])
    if system_prompt:
        args.extend(["--system-prompt", system_prompt])
    args.append(user_prompt or "")
    return args


def parse_claude_code_output(output: str, stderr: str = "", resolved_model: str = "sonnet") -> ClaudeCodeExecutionResult:
    clean = str(output or "").strip()
    if not clean:
        detail = f": {str(stderr).strip()[:160]}" if stderr else ""
        raise ValueError(f"Claude Code empty response{detail}")

    try:
        parsed = json.loads(clean)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Claude Code JSON parse failed: {clean[:160]}") from exc

    if parsed.get("is_error") or "Not logged in" in str(parsed.get("result") or ""):
        raise ValueError(str(parsed.get("result") or "Claude Code execution failed"))

    usage = parsed.get("usage")
    normalized_usage = None
    if isinstance(usage, dict):
        normalized_usage = {
            "input_tokens": int(usage.get("input_tokens") or 0),
            "output_tokens": int(usage.get("output_tokens") or 0),
        }

    model_usage = parsed.get("modelUsage")
    used_model = resolved_model
    if isinstance(model_usage, dict) and model_usage:
        used_model = next(iter(model_usage.keys()))

    duration_ms = parsed.get("duration_ms")
    return ClaudeCodeExecutionResult(
        result=str(parsed.get("result") or ""),
        session_id=parsed.get("session_id"),
        duration_ms=int(duration_ms) if duration_ms is not None else None,
        model=used_model,
        usage=normalized_usage,
    )


class ClaudeCodeProvider(BrainProvider):
    def __init__(
        self,
        *,
        cli_path: str = "/opt/homebrew/bin/claude",
        model: str = "sonnet",
        timeout_ms: int = 45000,
        session_name: str = "",
        settings_file: str = "",
        agent: str = "",
    ):
        self.cli_path = cli_path
        self.model = resolve_claude_code_model(model)
        self.timeout_ms = timeout_ms
        self.session_name = session_name
        self.settings_file = settings_file
        self.agent = agent

    async def decide(self, prompt: str) -> AgentAction:
        args = build_claude_code_args(
            model=self.model,
            system_prompt=SYSTEM_PROMPT,
            user_prompt=prompt,
            session_name=self.session_name,
            settings_file=self.settings_file,
            agent=self.agent,
        )
        env = {
            **os.environ,
            "CLAUDE_CODE_NAME": self.session_name or os.environ.get("CLAUDE_CODE_NAME", ""),
            "CLAUDE_CODE_SETTINGS": self.settings_file or os.environ.get("CLAUDE_CODE_SETTINGS", ""),
        }

        process = await asyncio.create_subprocess_exec(
            self.cli_path,
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
        )

        try:
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=self.timeout_ms / 1000)
        except asyncio.TimeoutError as exc:
            process.kill()
            await process.communicate()
            raise TimeoutError(f"Claude Code timed out after {self.timeout_ms}ms") from exc

        output_text = stdout.decode("utf-8", errors="replace")
        error_text = stderr.decode("utf-8", errors="replace")
        parsed = parse_claude_code_output(output_text, error_text, self.model)
        return parse_action_response(parsed.result)
