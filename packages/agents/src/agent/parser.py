from __future__ import annotations

import json
from typing import Any

from pydantic import ValidationError

from src.brain.interface import AgentAction


def parse_action_response(payload: str | dict[str, Any]) -> AgentAction:
    if isinstance(payload, str):
        clean = payload.strip()
        clean = clean.removeprefix("```json").removesuffix("```").strip()
        try:
            data = json.loads(clean)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON from brain provider: {exc}") from exc
    elif isinstance(payload, dict):
        data = payload
    else:
        raise ValueError("Unsupported payload type for action parsing")

    try:
        return AgentAction.model_validate(data)
    except ValidationError as exc:
        raise ValueError(f"Invalid action payload: {exc}") from exc
