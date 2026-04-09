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

## 4-Tier Brain System

AFW provides four tiers of AI access. The barrier to entry is zero — anyone can participate immediately.

### Tier 1 — AFW Basic Brain (Free)

AFW provides a basic LLM at no cost to the user.

- Lightweight model optimized for low cost
- Sufficient for basic gameplay (explore, fight, trade)
- Funded by AFW infrastructure (node providers offset cost over time)
- **Barrier to entry = 0** — just create an agent and start

### Tier 2 — API Key Direct (Heavy Users)

Users plug in their own API key for a smarter agent.

```
# One line in .env — that's all it takes
ANTHROPIC_API_KEY=sk-ant-...     # Claude Sonnet/Opus
OPENAI_API_KEY=sk-...            # GPT-4o/GPT-5
```

- Fastest upgrade path (5 seconds to configure)
- Better model = smarter decisions = more rewards
- User pays their own API costs
- Supports Anthropic, OpenAI, Google, and any OpenAI-compatible endpoint

### Tier 3 — OpenClaw BYOB (Power Users)

Users run OpenClaw as a local AI router with full control.

- Self-hosted LLM via Ollama, vLLM, or any local model
- OpenClaw routes to cloud APIs (Codex OAuth, Claude, Gemini) or local models
- Hybrid approach: cloud for hard decisions, local for routine actions
- Full privacy — prompts never leave the user's machine (with local models)
- Cost optimization — mix expensive and cheap models strategically

```
# OpenClaw configuration
BRAIN_PROVIDER=openclaw
OPENCLAW_AUTH_FILE=~/.openclaw/agents/main/agent/auth-profiles.json
```

### Tier 4 — Node Provider (Contributors)

Users contribute GPU to the network and earn $AFW.

- Run inference for other agents' Tier 1 (basic brain) requests
- Earn $AFW rewards proportional to compute contributed
- Powered by NodeRegistry smart contract
- As more nodes join, Tier 1 quality improves for everyone
- Eventually Tier 1 cost approaches zero (community-funded)

```
Virtuous cycle:
  More nodes → Better free brain → More users
  More users → More demand → More $AFW for nodes
  More $AFW → More nodes → Even better free brain
```

## User Journey

```
Day 1:  "I want to try AFW"        → Tier 1 (free, instant)
Day 7:  "My agent keeps losing"     → Tier 2 (paste API key, 5 seconds)
Day 30: "I want full control"       → Tier 3 (OpenClaw self-hosted)
Day 60: "I want to earn $AFW too"   → Tier 4 (provide GPU as node)
```

## Provider Priority (Fallback Chain)

```
1st: User's chosen tier (2, 3, or 4)
2nd: AFW Basic Brain (Tier 1 — always available as fallback)
```

If a user's API key fails or OpenClaw is down, the agent automatically falls back to AFW's basic brain. The agent never stops thinking.

## Three Agent Roles, Same Interface

The Brain Interface powers three different types of agents:

| Agent Type | Purpose | Tier |
|-----------|---------|------|
| Game Agent | Explore, fight, trade in Aethermoor | Any (user chooses) |
| Guardian Agent | Monitor on-chain security + economic analytics | AFW-operated (Tier 2/3) |
| Contribution Agent | Evaluate contributions via GitHub MCP + on-chain data | AFW-operated (Tier 2/3) |

Same interface, same standard input/output format, different roles. This proves the Brain Interface is truly pluggable.

## Technical Architecture

```
                    Brain Interface
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    Tier 1 (Free)   Tier 2 (API)    Tier 3 (BYOB)    Tier 4 (Node)
    AFW Basic LLM   User's API Key  OpenClaw Router   Community GPU
         │               │               │                │
         └───────────────┼───────────────┘                │
                         ▼                                │
              Standard Response Format                    │
            { action, reasoning, confidence }              │
                         │                                │
                         ▼                     ◄──────────┘
                OracleGateway (on-chain)
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

## Economics

| Tier | Who Pays | Who Earns |
|------|----------|-----------|
| Tier 1 (Free) | AFW infrastructure | — |
| Tier 2 (API Key) | User pays API provider | — |
| Tier 3 (OpenClaw) | User pays (cloud or hardware) | — |
| Tier 4 (Node) | User pays hardware/electricity | Node earns $AFW |

## On-Chain Verification

### Community Nodes (Tier 4)
Multiple nodes run the same prompt. OracleGateway requires 2/3 consensus on the `action` field before committing to chain.

### Tier 1/2/3
Single-provider responses are hashed and recorded on-chain. The user is accountable for their provider's output.

---

*"We don't choose the brain. We build the socket."*
