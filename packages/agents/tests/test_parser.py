from __future__ import annotations

import pytest

from src.agent.parser import parse_action_response


def test_valid_action_parsed():
    payload = """
    {
      "action": "REST",
      "target": "tavern",
      "reasoning": "Need to recover.",
      "dialogue": "A short break will help.",
      "emotion": "relaxed",
      "confidence": 0.8
    }
    """

    action = parse_action_response(payload)

    assert action.action == "REST"
    assert action.target == "tavern"
    assert action.confidence == 0.8


def test_invalid_json_raises():
    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_action_response("{bad json")


def test_unknown_action_defaults():
    action = parse_action_response('{"action":"SING","confidence":0.4}')

    assert action.action == "EXPLORE"
    assert action.confidence == 0.4


def test_confidence_clamped():
    high = parse_action_response('{"action":"EXPLORE","confidence":4}')
    low = parse_action_response('{"action":"EXPLORE","confidence":-1}')

    assert high.confidence == 1.0
    assert low.confidence == 0.0
