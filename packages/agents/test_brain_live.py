#!/usr/bin/env python3
"""
AFW Brain Interface — Live Test
Tests that agent personality influences LLM decisions.

Usage:
  export OPENAI_API_KEY=sk-...   (or ANTHROPIC_API_KEY)
  cd packages/agents
  python3 test_brain_live.py
"""
import asyncio
import os
import sys

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))

from dotenv import load_dotenv
load_dotenv()

from brain.interface import AgentAction

OPENAI_KEY = os.environ.get("OPENAI_API_KEY", "")
ANTHROPIC_KEY = os.environ.get("ANTHROPIC_API_KEY", "")


def build_prompt(personality: dict, scenario: dict) -> str:
    p = personality
    s = scenario
    bravery_desc = "(very brave)" if p['bravery']>70 else "(cowardly)" if p['bravery']<30 else ""
    greed_desc = "(very greedy)" if p['greed']>70 else "(generous)" if p['greed']<30 else ""
    return f"""== YOUR IDENTITY ==
Class: Warrior | Level: {s['level']} | HP: {s['hp']}/{s['max_hp']} | MP: {s['mp']}/{s['max_mp']}
ATK: 20 | DEF: 15 | SPD: 10

== YOUR PERSONALITY ==
Bravery: {p['bravery']}/100 {bravery_desc}
Greed: {p['greed']}/100 {greed_desc}
Sociability: {p['sociability']}/100
Curiosity: {p['curiosity']}/100
Loyalty: {p['loyalty']}/100

== LOCATION == Lumenveil (SAFE zone)

== SITUATION ==
{s['situation']}

== DECIDE YOUR NEXT ACTION =="""


# ── Test Cases ─────────────────────────────────────────
TESTS = [
    {"name": "Brave vs Goblin", "expected": "FIGHT",
     "personality": {"bravery":90,"greed":30,"sociability":50,"curiosity":60,"loyalty":70},
     "scenario": {"level":3,"hp":80,"max_hp":100,"mp":50,"max_mp":50,
       "situation": "A lone goblin blocks the forest path. It hasn't noticed you. It guards a small pile of coins."}},
    {"name": "Coward vs Goblin", "expected": "FLEE",
     "personality": {"bravery":10,"greed":20,"sociability":50,"curiosity":20,"loyalty":40},
     "scenario": {"level":3,"hp":80,"max_hp":100,"mp":50,"max_mp":50,
       "situation": "A lone goblin blocks the forest path. It hasn't noticed you. It guards a small pile of coins."}},

    {"name": "Greedy + Low HP", "expected": "EXPLORE",
     "personality": {"bravery":40,"greed":95,"sociability":20,"curiosity":70,"loyalty":20},
     "scenario": {"level":5,"hp":15,"max_hp":100,"mp":10,"max_mp":50,
       "situation": "You are badly wounded. A tavern is to the west for rest. To the east, a glowing treasure chest behind rocks."}},

    {"name": "Cautious + Low HP", "expected": "REST",
     "personality": {"bravery":20,"greed":10,"sociability":80,"curiosity":30,"loyalty":90},
     "scenario": {"level":5,"hp":15,"max_hp":100,"mp":10,"max_mp":50,
       "situation": "You are badly wounded. A tavern is to the west for rest. To the east, a glowing treasure chest behind rocks."}},
]


async def run_test(test: dict, provider) -> bool:
    prompt = build_prompt(test["personality"], test["scenario"])
    result = await provider.decide(prompt)
    match = result.action == test["expected"]
    icon = "\u2705" if match else "\u274c"
    tag = "PASS" if match else "FAIL"

    print(f"\n{icon} [{tag}] {test['name']}")
    print(f"   Expected: {test['expected']} | Got: {result.action}")
    if result.dialogue:
        print(f'   Says: "{result.dialogue}"')
    if result.reasoning:
        print(f"   Thinks: {result.reasoning}")
    print(f"   Emotion: {result.emotion} | Confidence: {result.confidence}")
    return match


async def main():
    print("\n\U0001f3f0 AFW Brain Interface \u2014 Live Test")
    print("=" * 50)

    # Auto-detect provider
    if OPENAI_KEY:
        from brain.openai_provider import OpenAIKeyProvider
        provider = OpenAIKeyProvider(api_key=OPENAI_KEY)
        print(f"Provider: OpenAI (gpt-4o-mini)")
    elif ANTHROPIC_KEY:
        from brain.anthropic_provider import AnthropicProvider
        provider = AnthropicProvider(api_key=ANTHROPIC_KEY)
        print(f"Provider: Anthropic (claude-sonnet)")
    else:
        print("\n\u274c No API key found!")
        print("  export OPENAI_API_KEY=sk-...")
        print("  export ANTHROPIC_API_KEY=sk-ant-...")
        sys.exit(1)

    print(f"Tests: {len(TESTS)}")
    print("=" * 50)

    passed = 0
    for test in TESTS:
        try:
            if await run_test(test, provider):
                passed += 1
        except Exception as e:
            print(f"\n\u274c [ERROR] {test['name']}: {e}")

    print(f"\n{'=' * 50}")
    print(f"Result: {passed}/{len(TESTS)} passed")
    if passed == len(TESTS):
        print("\U0001f389 Brain Interface design validated!")
    else:
        print("\u26a0\ufe0f  Some tests failed \u2014 prompt tuning needed")


if __name__ == "__main__":
    asyncio.run(main())
