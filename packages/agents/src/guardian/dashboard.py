from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def write_guardian_dashboard(path: str, payload: dict[str, Any]) -> Path:
    target = Path(path)
    if not target.is_absolute():
        target = Path.cwd() / target
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return target
