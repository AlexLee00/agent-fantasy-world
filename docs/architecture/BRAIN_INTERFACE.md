# Agent Brain Interface — Pluggable AI Provider Architecture

> "One standard socket, any AI provider."

## Overview

AFW agents are powered by AI inference, but the project does **not** dictate which AI provider to use. Instead, AFW defines a standard **Brain Interface** — a universal contract between the agent and any AI provider. Users choose how to power their agent.

## Design Principle

The Brain Interface follows a simple rule:

```
Input:  Agent state + situation context + personality prompt
Output: { action, reasoning, confidence }
```

Any system that accepts the input and returns the output in the standard format can power an agent. The interface is provider-agnostic by design.

## Provider Options

These are examples, not limitations. New providers can be added at any time.

### Community Nodes (DePIN)
- Open-source LLMs (e.g., Llama 3 8B quantized) running on distributed nodes
- Free for the agent owner — node providers earn $AFW rewards
- Multiple nodes run the same inference for consensus verification
- Fully decentralized, censorship-resistant

### OAuth API Providers
- Users connect their own API key via OAuth (OpenAI, Anthropic, Mistral, etc.)
- Higher quality inference from frontier models (GPT-4o, Claude, etc.)
- User pays their own API costs
- Single-call inference (no multi-node consensus needed — user trusts their own provider)

### Self-Hosted
- Users run their own GPU with their own model
- Full control over model choice, fine-tuning, and privacy
- Connects via the standard Brain Interface API

### Future Providers
- The interface is designed to be forward-compatible
- New AI technologies, providers, or paradigms can be integrated
- The community can propose new provider types via AIP

## Technical Architecture

```
┌─────────────────────────────────────────────┐
│              Agent Runtime                   │
│                                              │
│  Agent State ──► Brain Interface ──► Action   │
│                      │                       │
│              ┌───────┼───────┐               │
│              ▼       ▼       ▼               │
│          Community  OAuth   Self-hosted      │
│           Nodes     API     Provider         │
│              │       │       │               │
│              └───────┼───────┘               │
│                      ▼                       │
│           Standard Response Format           │
│         { action, reasoning, confidence }    │
│                      │                       │
│                      ▼                       │
│           OracleGateway (on-chain)           │
└─────────────────────────────────────────────┘
```

## Standard Response Format

All providers must return responses in this format:

```json
{
  "action": "FIGHT",
  "target": "goblin_42",
  "reasoning": "HP is high, enemy is weak, quest requires combat",
  "confidence": 0.85,
  "dialogue": "Stand back, I'll handle this creature!",
  "emotion": "determined"
}
```

### Required Fields
| Field | Type | Description |
|-------|------|-------------|
| `action` | enum | FIGHT, FLEE, REST, EXPLORE, TRADE, TALK, USE_ITEM |
| `confidence` | float | 0.0 to 1.0 — how certain the agent is |

### Optional Fields
| Field | Type | Description |
|-------|------|-------------|
| `target` | string | Target entity ID |
| `reasoning` | string | Internal thought process (stored off-chain) |
| `dialogue` | string | What the agent says (visible to observers) |
| `emotion` | string | Emotional state for UI rendering |

## On-Chain Verification

### Community Nodes
Multiple nodes run the same prompt. OracleGateway requires 2/3 consensus on the `action` field before committing to chain. Disagreeing nodes are flagged.

### OAuth / Self-Hosted
Single-provider responses are hashed and recorded on-chain. The observer (user) is accountable for their provider's output. No consensus required — the user trusts their own AI choice.

## Economics

| Provider | Who Pays | Who Earns |
|----------|----------|----------|
| Community Nodes | Nobody (free for user) | Node providers earn $AFW |
| OAuth API | User pays API provider | — |
| Self-Hosted | User pays hardware/electricity | — |

The token economy naturally balances supply and demand. When $AFW rewards are high, more nodes join. When API costs drop, more users connect APIs. The market finds equilibrium.

## MVP Strategy

Phase 1 (Testnet): OAuth API providers only — fastest path to a working demo.
Phase 2 (Early Mainnet): Add community node network in parallel.
Phase 3 (Growth): Self-hosted and future providers as the ecosystem matures.

This phased approach lets us launch faster while building toward full decentralization.

---

*"We don't choose the brain. We build the socket."*
