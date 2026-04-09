from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path

from src.brain.anthropic_provider import AnthropicProvider
from src.brain.openai_provider import create_provider
from src.brain.prompt_fixtures import load_markdown_prompt_cases


def build_provider(provider_name: str, model: str, api_key: str):
    normalized = provider_name.strip().lower()
    if normalized == "anthropic":
        return AnthropicProvider(api_key=api_key, model=model)
    return create_provider(mode="key", api_key=api_key, model=model)


async def main():
    parser = argparse.ArgumentParser(description="Run AFW brain prompt fixtures against an LLM provider.")
    parser.add_argument("--provider", default="openai")
    parser.add_argument("--model", default="gpt-4o-mini")
    parser.add_argument("--api-key", required=True)
    parser.add_argument(
        "--fixtures",
        default=str(Path(__file__).resolve().parents[4] / "docs" / "internal" / "test_brain_prompts.md"),
    )
    args = parser.parse_args()

    provider = build_provider(args.provider, args.model, args.api_key)
    cases = load_markdown_prompt_cases(args.fixtures)

    for title, prompt in cases:
        action = await provider.decide(prompt)
        print(f"## {title}")
        print(json.dumps(action.model_dump(), ensure_ascii=False, indent=2))
        print()


if __name__ == "__main__":
    asyncio.run(main())
