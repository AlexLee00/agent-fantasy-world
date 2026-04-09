from __future__ import annotations

from pathlib import Path

from src.brain.prompt_fixtures import load_markdown_prompt_cases


def test_load_markdown_prompt_cases_extracts_all_documented_tests():
    path = Path(__file__).resolve().parents[3] / "docs" / "internal" / "test_brain_prompts.md"
    cases = load_markdown_prompt_cases(path)

    assert len(cases) == 4
    assert cases[0][0].startswith("TEST 1")
    assert "lone goblin" in cases[0][1]
    assert cases[-1][0].startswith("TEST 4")
    assert "warm tavern" in cases[-1][1]
