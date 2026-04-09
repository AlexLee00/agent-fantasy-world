# Settlement Hub — Game-to-Blockchain Bridge

> "Games move at the speed of thought. Blockchains move at the speed of consensus."

## Problem

Blockchain transactions take seconds to confirm. Games need instant feedback. Without a bridge, every agent action would stall waiting for on-chain confirmation.

## Solution: Settlement Hub

The Settlement Hub is a GenServer that sits between the Game Engine (off-chain) and the Blockchain (on-chain). It is the **only path** between game logic and smart contracts.

```
Game Engine (instant)          Settlement Hub          Blockchain (seconds)
+------------------+    +---------------------+    +-------------------+
| Agent decisions   |    | Optimistic State    |    | Smart Contracts   |
| HP changes        |-->| Pending Locks       |-->| SOUL transfers    |
| Movement          |    | Event Queue         |    | Item ownership    |
| Damage calc       |    | Batch Policy        |    | Agent state       |
| NPC dialogue      |    | Reconciliation      |    | Combat results    |
+------------------+    +---------------------+    +-------------------+
        0ms                   manages gap              2-30 seconds
```

## Core Principle: Only Assets Go On-Chain

The Settlement Hub enforces a strict rule: **only asset changes are submitted to the blockchain.**

### On-Chain (asset movements)
- SOUL token transfers (combat loot, NPC purchases, marketplace trades)
- Item ownership changes (ERC-1155 transfers)
- Agent creation and death
- AFW token distribution
- Combat results that involve SOUL movement

### Off-Chain (game logic)
- HP changes (reflected in next combat result)
- Position and movement
- AI decisions and reasoning
- NPC dialogue
- Damage calculations
- Emotion and personality state
- Exploration discoveries

## Two Settlement Paths

The Hub handles two fundamentally different types of actions:

### Path A — Agent Autonomous Actions (Batched)

Agent AI decides to fight, rest, explore. These are batched for efficiency.

```
Agent AI decides "FIGHT" -->  Game Engine calculates result
  --> Settlement Hub receives asset change event
  --> Optimistic state updated (user sees "+15 SOUL" instantly)
  --> Event queued with priority
  --> Batch settles after 30 seconds
  --> User sees checkmark when confirmed

No user interaction needed. Session Key signs automatically.
```

### Path B — User Direct Actions (Immediate)

User clicks "send SOUL" or "list item on marketplace." These settle immediately.

```
User clicks "Send 30 SOUL to friend" --> Settlement Hub receives
  --> Validates: 30 <= spendable balance (confirmed only)
  --> Embedded Wallet signs transaction
  --> Transaction sent immediately (no batching)
  --> UI shows "Processing..." (2-5 seconds)
  --> Transaction confirmed --> "Sent! checkmark"

User waits for confirmation. No optimistic state needed.
```

### Why Two Paths?

| | Agent Actions (Path A) | User Actions (Path B) |
|---|---|---|
| Initiated by | AI brain (automatic) | Human click (intentional) |
| User waiting? | No (watching game) | Yes (clicked a button) |
| Batch? | Yes (30s-5min) | No (immediate) |
| Optimistic state? | Yes (instant feedback) | No (wait for confirm) |
| Signed by | Session Key (limited) | Embedded Wallet (with PIN) |
| Examples | FIGHT, REST, EXPLORE | Send SOUL, list on market |

## Wallet Integration

At launch, AFW uses Level 1 only (Embedded Wallet). See [Wallet Architecture](WALLET_ONBOARDING.md).

### Level 1 (Launch) — Embedded Wallet

```
All actions flow through Settlement Hub:

Agent game actions:
  Game UI --> Settlement Hub --> Session Key signs --> Blockchain
  (batched, optimistic state, user sees instant results)

User asset actions:
  "Send SOUL" button --> Settlement Hub --> Embedded Wallet signs --> Blockchain
  (immediate, user confirms with PIN, waits for on-chain confirmation)

Direct blockchain bypass: IMPOSSIBLE
  Embedded Wallet = smart contract wallet
  Only game backend can sign transactions
  No MetaMask, no external access
  Zero batch gap issues
```

### Level 2 (Later) — External Wallet Added

```
Game actions: unchanged (Embedded Wallet, through Hub)
Withdrawals: Game UI --> Hub --> External Wallet transfer
External transfers: detected via Transfer event subscription
  --> Hub adjusts balance within seconds
  --> Game state unaffected (game assets in Embedded Wallet)
```

### Level 3 (Later) — Direct Web3

```
Game actions: through Hub (user signs each batch via wallet)
Direct transfers: user can bypass Hub
  --> Reconciler detects within 60 seconds
  --> Hub corrects optimistic state
  --> Acceptable for Web3-native users
```

## Spendable Balance

The Hub tracks two balances per agent:

```
Confirmed balance: on-chain verified (can spend freely)
Pending balance: optimistic, waiting for settlement (locked)

Display to user:
  SOUL: 50 (confirmed) + 15 (pending) = 65 total

Spending rules:
  Agent game actions: can use confirmed + pending (optimistic)
  User direct sends: can ONLY use confirmed (safe)
  Marketplace listings: can ONLY use confirmed items
```

## Three Core Mechanisms

### 1. Optimistic State

The game shows results immediately, before on-chain confirmation.

```
Agent #22 defeats goblin --> Game instantly shows:
  "Victory! +15 SOUL"
  SOUL display: 50 (confirmed) + 15 (pending) = 65

The 15 SOUL is not yet on-chain. But the player sees it immediately.
```

Optimistic State is stored in ETS (in-memory, fast). It represents what the game *believes* will be true after settlement.

### 2. Pending Locks

SOUL and items that are "pending settlement" cannot be spent by user direct actions.

```
Agent #22 has:
  50 SOUL (confirmed, spendable for everything)
  15 SOUL (pending, game actions only)

User tries to send 60 SOUL to friend:
  --> Denied. Only 50 confirmed SOUL available for direct transfers.

Agent AI tries to buy 60 SOUL sword from NPC:
  --> Allowed. Game actions can use optimistic balance.
```

### 3. Reconciliation

Periodically, the Hub compares optimistic state with actual on-chain state.

```
Every 60 seconds:
  on_chain_balance = Reader.get_soul_balance(agent)
  optimistic_balance = OptimisticState.get(agent, :soul)

  if mismatch:
    --> Correct optimistic state to match on-chain
    --> Log discrepancy for Guardian Agent
    --> Broadcast correction to LiveView
```

On-chain is always the source of truth. Optimistic state is a fast cache that occasionally needs correction.

## Event Queue and Batch Policy

Not all events need immediate settlement. The Hub batches events by urgency.

### Priority Levels

| Priority | Settle When | Examples |
|----------|-------------|----------|
| IMMEDIATE | Next block | Agent death, World Boss kill, user direct send |
| NORMAL | Within 30 seconds | Combat results, NPC purchases |
| BATCH | Every 5 minutes | Marketplace settlements, accumulated NPC sales |
| DEFERRED | Every 30 minutes | Stat snapshots, leaderboard updates |

### Batch Optimization

Multiple events of the same type are combined into fewer transactions.

```
3 agents each buy from NPC tavern (5 SOUL each):
  Without batching: 3 transactions
  With batching: 1 multicall transaction (15 SOUL total)
```

## Settlement Lifecycle

```
1. Game Event occurs (e.g., agent defeats monster)
   |
2. Settlement Hub receives event
   |
3. Optimistic State updated immediately
   |  --> Player sees result instantly
   |  --> Pending lock placed on transferred assets
   |
4. Event enters queue with priority
   |
5. Batch Policy triggers settlement
   |  --> Writer sends transaction to blockchain
   |
6a. Transaction CONFIRMED
   |  --> Pending lock released
   |  --> Optimistic state --> confirmed state
   |  --> LiveView updated
   |
6b. Transaction FAILED
   |  --> Optimistic state rolled back
   |  --> Pending lock released
   |  --> Player notified: "Settlement failed, retrying..."
   |  --> Event re-queued for retry (max 3 attempts)
   |
7. Reconciliation verifies consistency
```

## OTP Architecture

```
Application Supervisor
  +-- AgentSupervisor (DynamicSupervisor)
  |     +-- Agent #22 GenServer
  |     +-- Agent #23 GenServer
  |     +-- Agent #24 GenServer
  |
  +-- SettlementHub GenServer          <-- the bridge
  |     +-- ETS: optimistic_state      (fast reads)
  |     +-- ETS: pending_locks         (double-spend prevention)
  |     +-- ETS: event_queue           (batched events)
  |     +-- Timer: reconciliation      (periodic on-chain check)
  |
  +-- Chain.Writer GenServer           (nonce management, tx signing)
  +-- Chain.Reader module              (parallel reads, stateless)
  +-- Chain.Cache ETS                  (RPC response cache)
  |
  +-- Guardian GenServer               (security monitoring)
  +-- Contribution GenServer           (contribution evaluation)
  +-- Phoenix.Endpoint                 (LiveView dashboard)
```

## Player-Facing Display

LiveView shows settlement status transparently:

```
Agent #22 -- Warrior (Lumenveil)
  HP: 78/80
  SOUL: 50 confirmed + 15 pending = 65 total
  Items: Iron Sword (confirmed), Health Potion (settling...)

  Recent:
  [00:12] Defeated Goblin Scout --> +15 SOUL (settling...)
  [00:02] Rested at Tavern --> HP full (off-chain)
  [settled] Bought potion from Shop --> -10 SOUL checkmark
```

## Why This Matters

- **Players see instant results** — no waiting for blockchain
- **Blockchain sees only assets** — minimal gas, maximum efficiency
- **Double-spending impossible** — pending locks enforce correctness
- **User direct actions are safe** — confirmed balance only
- **Failures are graceful** — rollback + retry, never corrupt state
- **Scales naturally** — batch more aggressively as agents increase
- **Level 1 has zero edge cases** — Embedded Wallet cannot bypass Hub

## Future: L2 / App Chain

When AFW moves to its own L2 or app chain:
- Settlement Hub becomes thinner (faster confirmation = less batching)
- Optimistic state window shrinks (30s to 2s)
- Pending locks release faster
- Same architecture, same code, just faster settlement

The Hub is designed to gracefully shrink as the underlying chain gets faster.

---

*"The game is instant. The blockchain is permanent. The Hub bridges both."*
