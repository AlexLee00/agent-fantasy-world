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

### API Providers (OpenAI, Anthropic, etc.)
- Users connect their own API key or OAuth token to power their agent
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

## Authentication & Provider Priority

The Brain Interface supports multiple authentication methods with automatic fallback. The priority order is determined by availability and reliability.

### MVP Provider Priority

```
1st: Claude Code CLI     → Subscription auth, no API key needed, proven in ai-agent-system
2nd: OpenClaw OAuth      → OpenAI Codex OAuth token (when 429 regression is resolved)
3rd: API Key             → Direct OPENAI_API_KEY or ANTHROPIC_API_KEY
4th: Community Nodes     → Future (DePIN network)
```

### Claude Code CLI (Primary — MVP)

AFW uses the **Claude Code CLI** as the primary brain provider. This is the same pattern used in ai-agent-system where Claude Code powers multiple AI agents 24/7.

**How it works:**
```
/opt/homebrew/bin/claude -p --output-format json \
  --model sonnet \
  --max-turns 1 \
  --system-prompt "You are an AI agent in Aethermoor..." \
  "Agent state + situation prompt"
```

**Why Claude Code CLI:**
- Already authenticated on the local machine (Claude Pro/Max subscription)
- No API key or OAuth token management needed
- No quota/rate limit issues (subscription-based, not API credit-based)
- Proven in production: ai-agent-system uses `claude-code/sonnet` as primary route
- Returns structured JSON via `--output-format json`
- Handles model selection, context, and response formatting

**Reference implementation:** `ai-agent-system/packages/core/lib/llm-fallback.js` → `_callClaudeCode()`

**Runtime profile pattern from ai-agent-system:**
```javascript
primary_routes:  ['claude-code/sonnet', 'openai-oauth/gpt-5.4']
fallback_routes: ['local/qwen2.5-7b', 'google-gemini-cli/gemini-2.5-flash']
```

### OpenClaw OAuth (Secondary — when OpenAI 429 is resolved)

OpenClaw manages OpenAI Codex OAuth tokens. This pattern is battle-tested in ai-agent-system.

**Token flow:**
```
OpenClaw (:18789) → auth-profiles.json → Bearer token → api.openai.com
```

**Current status:** OpenAI 429 quota regression since March 16, 2026 (OpenClaw #54615). OpenClaw OAuth path is architecturally correct but blocked by OpenAI-side issue. Will activate when resolved.

### API Key (Fallback)

| Provider | Header | Use Case |
|----------|--------|----------|
| OpenAI | `Authorization: Bearer sk-...` | When Claude Code and OpenClaw unavailable |
| Anthropic | `x-api-key: sk-ant-...` | Direct Anthropic API access |

### Self-Hosted / Community Nodes

No authentication needed — the node operator runs the model directly.

## Technical Architecture

```
┌─────────────────────────────────────────────┐
│              Agent Runtime                   │
│                                              │
│  Agent State ──► Brain Interface ──► Action   │
│                      │                       │
│       ┌──────────────┼──────────────┐        │
│       ▼              ▼              ▼        │
│  Claude Code    OpenClaw OAuth   API Key     │
│   CLI (1st)     OpenAI (2nd)    fallback     │
│       │              │              │        │
│       └──────────────┼──────────────┘        │
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

## Community Research — OAuth Status (2026-04)

### OpenAI OAuth
- Codex OAuth officially supported for external tools
- Known 429 regression since March 16, 2026 (OpenClaw #54615)
- Multiple projects affected: OpenClaw, term-llm, opencode-openai-codex-auth

### Claude Code
- Claude Code CLI works as a non-interactive inference endpoint
- Subscription-based auth avoids API quota issues entirely
- ai-agent-system uses `claude-code/sonnet` as primary route in production

### AFW Strategy
Claude Code CLI bypasses the OpenAI 429 issue completely. When OpenAI fixes the regression, OpenClaw OAuth becomes the secondary provider automatically. The Brain Interface's pluggable design means zero code changes needed.

## On-Chain Verification

### Community Nodes
Multiple nodes run the same prompt. OracleGateway requires 2/3 consensus on the `action` field before committing to chain. Disagreeing nodes are flagged.

### CLI / OAuth / API Key / Self-Hosted
Single-provider responses are hashed and recorded on-chain. The observer (user) is accountable for their provider's output. No consensus required — the user trusts their own AI choice.

## Economics

| Provider | Who Pays | Who Earns |
|----------|----------|----------|
| Community Nodes | Nobody (free for user) | Node providers earn $AFW |
| Claude Code CLI | User pays Claude subscription | — |
| OpenClaw OAuth / API Key | User pays API provider | — |
| Self-Hosted | User pays hardware/electricity | — |

## MVP Strategy

Phase 1 (MVP): Claude Code CLI primary + API key fallback.
Phase 2 (Testnet): Add OpenClaw OAuth (when OpenAI 429 resolved) + community nodes.
Phase 3 (Growth): Self-hosted providers + future integrations.

---

*"We don't choose the brain. We build the socket."*
