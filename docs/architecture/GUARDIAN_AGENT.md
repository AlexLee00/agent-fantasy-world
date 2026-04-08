# Guardian Agent — On-Chain Security & Analytics

> "The same Brain Interface that powers game agents also protects the world."

## Overview

The Guardian Agent is an AI agent that monitors ALL on-chain transaction data in real-time. It uses the same Brain Interface as game agents but with a different purpose: security monitoring and economic analytics.

## Dual Role

### 1. Security Monitoring

The Guardian Agent watches for exploit attempts and proposes wallet freezes to the multisig governance.

**What it monitors:**
- Unauthorized SOUL/AFW minting attempts (function calls without proper role)
- Reentrancy attack patterns (recursive contract calls)
- Duplicate reward claims (same quest/monster ID claimed twice)
- Abnormal token flow patterns learned from historical data
- Flash loan-style attacks on the marketplace
- Contract interaction sequences that match known exploit patterns

**What it does when it detects an issue:**
```
Guardian Agent detects anomaly
  → Submits a "freeze wallet" proposal to multisig
  → Includes evidence: tx hash, pattern description, severity score
  → Multisig reviews and votes
  → If approved → target wallet is frozen
  → If rejected → false positive logged for AI learning
```

The Guardian Agent CANNOT freeze wallets directly. It can only propose. Humans (multisig) decide. This keeps decentralization intact.

**How it differs from hardcoded rules:**
- Hardcoded: "block if > 1000 SOUL in 1 minute" → breaks for legitimate whales
- Guardian AI: "this pattern matches known exploit signatures AND deviates from this wallet's history" → smarter, adaptive

### 2. On-Chain Analytics

The Guardian Agent analyzes the full on-chain transaction dataset to provide insights on the world economy.

**Economic health monitoring:**
- SOUL supply tracking (total minted vs burned vs circulating)
- Inflation/deflation rate per zone
- NPC supply chain health (are NPCs running out of SOUL?)
- Marketplace price trends (SOUL/AFW rate, item prices)
- Agent wealth distribution (Gini coefficient of the world)

**Gameplay analytics:**
- Most active zones and least active zones
- Popular vs unpopular quest types
- Monster defeat rates by level/type
- Average agent lifespan and death causes
- Event Treasury fill rate and world event frequency

**Predictive insights:**
- Economy overheating warnings (too much SOUL being minted)
- Supply shortage predictions (ore running low → sword prices will rise)
- Zone congestion forecasts
- Suggested governance parameter adjustments (backed by data)

### Public Dashboard

All Guardian Agent analytics are published to a public dashboard. Anyone can view the world's economic health. Full transparency — no hidden data.

```
Guardian Agent reads on-chain data
  → Analyzes patterns (security + economics)
  → Publishes to public analytics dashboard
  → Flags security issues to multisig
  → Suggests governance actions (with data evidence)
```

## Architecture

The Guardian Agent uses the same infrastructure as game agents:

```
On-chain events → Guardian Agent reads transaction data
                        │
                  Brain Interface (same as game agents)
                        │
              ┌─────────┼─────────┐
              ▼                   ▼
     Security Analysis    Economic Analytics
              │                   │
              ▼                   ▼
     Multisig proposals    Public dashboard
```

**Why this works:**
- Same Brain Interface = no new infrastructure needed
- AI-powered = adapts to new attack patterns without code changes
- Proposal-only = cannot take unilateral action
- Public analytics = full transparency
- Extensible = new analysis modules can be added

## Contract Security Design

The Guardian Agent is a second layer of defense. The first layer is the contract design itself:

### First Layer: Contract Self-Protection
- All SOUL minting functions: `onlyAuthorizedContract` modifier
- ReentrancyGuard on all external calls
- Nonce/processedId for duplicate reward prevention
- Out-of-spec registration: automatic `revert` (no wallet freeze needed)
- Stats within Balance table range enforced on-chain

### Second Layer: Guardian Agent
- Monitors for exploits that bypass first-layer protections
- Detects patterns too complex for hardcoded rules
- Proposes wallet freezes to multisig with evidence
- Provides ongoing economic health analysis

### Third Layer: Governance
- Multisig reviews Guardian proposals
- Community can propose parameter changes via AIP
- All decisions are transparent and on-chain

---

*"In a world of AI agents, even the guardian is an agent."*
