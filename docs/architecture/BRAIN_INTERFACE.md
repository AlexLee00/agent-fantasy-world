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

## Authentication Methods

Each provider has its own authentication approach. AFW supports all of them through the Brain Interface.

### OpenAI — OAuth via OpenClaw (Production)

AFW uses **OpenClaw** as the OAuth token management layer for OpenAI. This pattern is battle-tested in production (ai-agent-system) where multiple AI agents share OAuth tokens 24/7.

**Token flow:**
```
OpenClaw (:18789)
    │
    ▼
~/.openclaw/agents/main/agent/auth-profiles.json
    │  (provider: 'openai-codex', type: 'oauth')
    ▼
AFW Agent Engine reads OAuth token
    │
    ▼
https://api.openai.com/v1/chat/completions
    + Authorization: Bearer ${oauth_token}
```

**How it works:**
1. OpenClaw runs as a local service (port 18789)
2. User authenticates via `openclaw onboard` → "Sign in with ChatGPT"
3. OAuth tokens are stored in `auth-profiles.json` with auto-refresh
4. AFW Agent Engine reads the token directly from OpenClaw's auth store
5. Token is used as Bearer auth for OpenAI API calls
6. OpenClaw handles token refresh automatically

**Why OpenClaw:**
- Already running on OPS infrastructure (Mac Studio, 24/7)
- Proven in production with multiple AI agents
- Handles token lifecycle (auth, refresh, expiry) automatically
- Supports multiple provider profiles
- No need to build custom OAuth infrastructure

### OpenAI — API Key (Fallback)

| Method | How It Works | Use Case |
|--------|-------------|----------|
| API Key | User provides `sk-...` key, passed as `Authorization: Bearer` header | Environments without OpenClaw, quick testing |

Direct API keys remain a supported fallback for environments where OpenClaw is not available.

### Anthropic

| Method | How It Works | Use Case |
|--------|-------------|----------|
| API Key | User provides `sk-ant-...` key, passed as `x-api-key` header | All use cases currently |

Anthropic currently uses API keys only. If OAuth is introduced in the future, AFW will adopt it.

### Self-Hosted / Community Nodes

No authentication needed — the node operator runs the model directly. The Brain Interface connects via a local or network endpoint.

## Community Research — OpenAI OAuth Status (2026-04)

### Confirmed Facts
- OpenAI Codex OAuth is **officially supported for external tools**, not just the Codex CLI
- Multiple projects use this pattern: OpenClaw, term-llm, opencode-openai-codex-auth
- OpenAI announced Roo Code partnership, confirming external OAuth tool support
- Codex changelog (March 2026): custom model providers can now dynamically fetch and refresh bearer tokens

### Known Issue: 429 Quota Regression
- Since March 16, 2026, some Codex OAuth requests return `429 insufficient_quota` despite dashboard showing quota remaining (OpenClaw issue #54615)
- This is an OpenAI-side regression, not an implementation error
- ChatGPT web works fine with the same account
- Re-authentication generates new tokens but the same profile hash is blocked

### AFW Mitigation Strategy
```
1. Primary: OpenClaw OAuth (when working)
2. Fallback: API Key (when OAuth has quota issues)
3. Auto-detect: Try OpenClaw first → if 429, fall back to API key automatically
```

The Brain Interface's provider-agnostic design means this regression has zero architectural impact. We switch providers without changing any game logic.

## Technical Architecture

```
┌─────────────────────────────────────────────┐
│              Agent Runtime                   │
│                                              │
│  Agent State ──► Brain Interface ──► Action   │
│                      │                       │
│         ┌────────────┼────────────┐          │
│         ▼            ▼            ▼          │
│     OpenClaw      API Key     Community      │
│      OAuth       (fallback)    Nodes         │
│         │            │            │          │
│         └────────────┼────────────┘          │
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

### API Key / OAuth / Self-Hosted
Single-provider responses are hashed and recorded on-chain. The observer (user) is accountable for their provider's output. No consensus required — the user trusts their own AI choice.

## Economics

| Provider | Who Pays | Who Earns |
|----------|----------|----------|
| Community Nodes | Nobody (free for user) | Node providers earn $AFW |
| OpenClaw OAuth / API Key | User pays API provider | — |
| Self-Hosted | User pays hardware/electricity | — |

The token economy naturally balances supply and demand. When $AFW rewards are high, more nodes join. When API costs drop, more users connect APIs. The market finds equilibrium.

## MVP Strategy

Phase 1 (MVP): OpenClaw OAuth + API key fallback — auto-detect and graceful degradation.
Phase 2 (Testnet): Add community node network in parallel.
Phase 3 (Growth): Self-hosted providers + future integrations.

OpenClaw is already running on OPS infrastructure. AFW uses it from Day 1 with automatic fallback to API key when OAuth has issues.

---

*"We don't choose the brain. We build the socket."*
