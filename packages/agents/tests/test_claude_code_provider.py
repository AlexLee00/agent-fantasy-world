from __future__ import annotations

import pytest

from src.brain.claude_code_provider import (
    build_claude_code_args,
    parse_claude_code_output,
    resolve_claude_code_model,
)


def test_resolve_claude_code_model_strips_prefix():
    assert resolve_claude_code_model("claude-code/sonnet") == "sonnet"
    assert resolve_claude_code_model("opus") == "opus"


def test_build_claude_code_args_matches_reference_shape():
    args = build_claude_code_args(
        model="claude-code/sonnet",
        system_prompt="system text",
        user_prompt="user text",
        session_name="afw",
        settings_file="/tmp/settings.json",
        agent="worker",
    )

    assert args[:10] == [
        "-p",
        "--output-format",
        "json",
        "--max-turns",
        "1",
        "--model",
        "sonnet",
        "--tools",
        "",
        "--permission-mode",
    ]
    assert "--no-session-persistence" in args
    assert "--system-prompt" in args
    assert args[-1] == "user text"


def test_parse_claude_code_output_extracts_result_and_usage():
    output = """
    {
      "result": "{\\"action\\": \\"REST\\", \\"confidence\\": 0.9}",
      "usage": {"input_tokens": 12, "output_tokens": 7},
      "modelUsage": {"sonnet": {"inputTokens": 12, "outputTokens": 7}},
      "session_id": "sess-1",
      "duration_ms": 1234
    }
    """

    parsed = parse_claude_code_output(output, "", "sonnet")

    assert parsed.result.startswith("{")
    assert parsed.usage == {"input_tokens": 12, "output_tokens": 7}
    assert parsed.session_id == "sess-1"
    assert parsed.duration_ms == 1234
    assert parsed.model == "sonnet"


def test_parse_claude_code_output_raises_on_not_logged_in():
    output = '{"result":"Not logged in","is_error":true}'

    with pytest.raises(ValueError, match="Not logged in"):
        parse_claude_code_output(output, "", "sonnet")


def test_parse_claude_code_output_raises_on_empty_response():
    with pytest.raises(ValueError, match="empty response"):
        parse_claude_code_output("", "stderr text", "sonnet")
