from __future__ import annotations

from pathlib import Path


def load_markdown_prompt_cases(path: str | Path) -> list[tuple[str, str]]:
    source = Path(path)
    lines = source.read_text(encoding="utf-8").splitlines()
    cases: list[tuple[str, str]] = []

    current_title: str | None = None
    current_body: list[str] = []
    collecting = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("# TEST "):
            if current_title and current_body:
                cases.append((current_title, "\n".join(current_body).strip()))
            current_title = stripped.removeprefix("# ").strip()
            current_body = []
            collecting = False
            continue

        if current_title is None:
            continue

        if stripped.startswith("# EXPECTED RESULTS SUMMARY"):
            if current_title and current_body:
                cases.append((current_title, "\n".join(current_body).strip()))
            break

        if stripped == "" and not collecting:
            continue

        if stripped.startswith("You are an AI agent"):
            collecting = True

        if collecting:
            current_body.append(line)

    if current_title and current_body and all(title != current_title for title, _ in cases):
        cases.append((current_title, "\n".join(current_body).strip()))

    return cases
