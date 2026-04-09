# User Onboarding & Wallet Architecture

> "If the user has to know what a blockchain is, we failed."

## Core Principle

The barrier to entry is zero. A new user should go from "I heard about AFW" to "my agent is exploring Aethermoor" in under 60 seconds, with nothing more than a Google login.

## Rollout Strategy — Level 1 First

AFW launches with Level 1 only. Level 2 and 3 are added later when the user base and infrastructure are ready.

```
Phase 1 (Launch):   Level 1 only — Embedded Wallet for everyone
Phase 2 (Growth):   Add Level 2 — External wallet linking
Phase 3 (Maturity): Add Level 3 — Direct Web3 wallet support
```

This means at launch, every user gets the same simple experience. No MetaMask, no seed phrases, no gas fees. Just Google login and play.

## Three User Levels

### Level 1 — Casual Player (Phase 1 — Launch)

```
User experience:
  1. Visit afw.gg
  2. Click "Start playing"
  3. Sign in with Google / Apple / Email
  4. Name your agent, pick a class
  5. Watch your agent explore Aethermoor

What they never see:
  - Wallet addresses
  - Private keys or seed phrases
  - Gas fees
  - Transaction confirmations
  - Network selection
  - Token approvals
```

**How it works behind the scenes:**

- OAuth login creates an Embedded Wallet (server-managed, encrypted)
- Private key is encrypted at rest, HSM-backed, never exposed to user
- All game transactions are signed server-side on behalf of the user
- Gas fees are paid by AFW via Paymaster (ERC-4337)
- User interacts only with game UI, never with blockchain UI

**Direct external transfer is impossible** — Embedded Wallet is a smart contract wallet. Only the game backend can sign transactions through it. Users cannot open MetaMask and send tokens from it. All asset movements go through the game UI → Settlement Hub → blockchain. This eliminates the batch gap problem entirely for Level 1 users.

### Level 2 — Power Player (Phase 2 — After launch)

```
User experience:
  1. Already playing as Level 1
  2. Goes to Settings > "Connect external wallet"
  3. Links MetaMask / WalletConnect / D'CENT
  4. Can now withdraw SOUL/AFW to their own wallet
  5. Can trade on external marketplaces
  6. Game actions still use Embedded Wallet (seamless)
```

**How it works:**

- External wallet linked to Embedded Wallet via on-chain mapping
- User can transfer assets between Embedded and External wallets
- Game actions continue through Embedded Wallet (no UX change)
- External wallet gives full self-custody for withdrawals

**External wallet transfers:** When user transfers assets from their external wallet directly (e.g., via MetaMask), the Settlement Hub detects this via Transfer event subscription and reconciles the game state. This is acceptable because Level 2 users understand blockchain basics.

### Level 3 — Web3 Native (Phase 3 — Maturity)

```
User experience:
  1. Click "Connect wallet" on first visit
  2. Sign in directly with MetaMask / hardware wallet
  3. Full control from day one
  4. Direct contract interaction if desired
```

**How it works:**

- No Embedded Wallet created
- All transactions signed by user's own wallet
- User pays own gas (or opts into Paymaster)
- Full Web3 experience

**Direct transfers handled by:** Transfer event subscription + Reconciler (60-second sync). Level 3 users are Web3 native and understand blockchain confirmation times.

## Batch Gap Protection by Level

The Settlement Hub batches game events for efficiency. This creates a time gap between game action and on-chain confirmation. Each level handles this differently:

### Level 1 — No gap problem

```
User cannot bypass Settlement Hub:
  - Embedded Wallet is a smart contract wallet
  - Only game backend can sign transactions
  - No MetaMask, no direct transfers
  - All actions flow: Game UI → Settlement Hub → Blockchain
  - Optimistic state + pending locks work perfectly
  - Zero edge cases
```

### Level 2 — Managed gap (added later)

```
Game assets stay in Embedded Wallet:
  - Game actions: Embedded Wallet → Settlement Hub (no gap issue)
  - Withdrawals: Game UI → Hub → external wallet (Hub knows about it)
  - External direct transfers: detected via event subscription

Edge case: User sends SOUL from external wallet
  → Transfer event detected within seconds
  → Settlement Hub adjusts external wallet balance
  → Game state (Embedded Wallet) unaffected
  → No impact on gameplay
```

### Level 3 — User-managed gap (added later)

```
User signs all transactions directly:
  - Game actions go through Settlement Hub (with user signature)
  - Direct contract calls bypass Hub
  → Reconciler syncs every 60 seconds
  → Transfer event subscription for faster detection
  → Level 3 users understand and accept this

Display:
  SOUL: 50 (confirmed) + 15 (pending) = 65
  "Use only confirmed balance for external transfers"
```

## Embedded Wallet Architecture

```
User (browser)              AFW Backend              Blockchain
+----------------+    +---------------------+    +----------------+
|                |    |                     |    |                |
| Google OAuth   |--->| Auth Service        |    |                |
|                |    |   |                 |    |                |
| Game UI        |    |   v                 |    |                |
| (LiveView)     |    | Wallet Service      |    |                |
|                |    |   |                 |    |                |
| "Buy sword"    |--->|   | Embedded Wallet |    |                |
| click          |    |   | (encrypted key) |--->| Marketplace    |
|                |    |   |                 |    | .fillOrder()   |
|                |    |   | Paymaster       |--->| (gas paid)     |
|                |    |   |                 |    |                |
| "Success!"     |<---|   | Settlement Hub  |    |                |
|                |    |                     |    |                |
+----------------+    +---------------------+    +----------------+

User never sees: wallet address, private key, gas fee, tx hash
User only sees:  "Bought Iron Sword for 50 SOUL"
```

### Key Management

| Component | Where | Security |
|-----------|-------|----------|
| Private key | Server HSM (encrypted) | AES-256, never in plaintext |
| Session token | User browser (httpOnly cookie) | OAuth session, auto-expire |
| Signing | Server-side only | User never touches key |
| Backup | Encrypted cold storage | Disaster recovery |

### What Embedded Wallet CAN do (auto-signed):
- Game actions: FIGHT, REST, EXPLORE, TALK
- NPC purchases (under 100 SOUL limit)
- Combat result settlement
- Accept quest rewards

### What Embedded Wallet CANNOT do without user confirmation:
- Transfer SOUL/AFW to another user (requires PIN/biometric)
- Marketplace listing above threshold (requires confirmation)
- Agent deletion
- Wallet export (Level 2 migration only)

## Gas Fee Abstraction (Paymaster)

Users never pay gas. AFW covers all gas fees via ERC-4337 Paymaster.

```
How Paymaster works:

1. User clicks "Buy sword" in game UI
2. Backend creates UserOperation (not a regular transaction)
3. Paymaster signs the gas sponsorship
4. Bundler submits to blockchain
5. AFW pays gas from protocol treasury
6. User pays 0 gas, sees only "Bought sword for 50 SOUL"
```

### Gas Cost Management

| Strategy | How |
|----------|-----|
| Settlement Hub batching | 10 events in 1 tx = 90% gas savings |
| Off-chain game logic | HP, movement, dialogue = 0 gas |
| Paymaster sponsorship | AFW treasury pays gas |
| Deferred settlement | Non-urgent events batch every 5 min |
| L2 base cost | Base tx = ~$0.001 |

Estimated gas cost per user per month: ~$0.50 (covered by AFW treasury).

## Session Key Pattern

For agent autonomous actions, the Embedded Wallet issues a Session Key with limited permissions.

```
Session Key permissions:
  ALLOWED:
    AgentRegistry.updateAgentState()
    CombatResolver.resolveCombat()
    NPCRegistry.buyFromNpc() [limit: 100 SOUL per tx]

  BLOCKED:
    SOULToken.transfer()       -- no direct token sends
    AFWToken.transfer()        -- no direct token sends
    Marketplace.createOrder()  -- user must confirm
    Any admin/upgrade function -- never

  EXPIRY: 24 hours (auto-renew while user is active)
```

The Settlement Hub uses Session Keys for all agent game actions. No user interaction needed for routine gameplay.

## User Actions That Require Confirmation

Some actions require explicit user approval, even with Embedded Wallet:

```
Level 1 (PIN or biometric):
  - Send SOUL/AFW to another user
  - List item on marketplace above 500 SOUL
  - Delete agent

Level 2 (added later — wallet signature):
  - Withdraw to external wallet
  - Connect/disconnect external wallet
  - Large marketplace trades

Level 3 (added later — direct signature):
  - Everything is user-signed by default
```

## Security Model

```
Threats and mitigations:

1. Server compromise
   -> Keys encrypted with HSM, not in application memory
   -> Even with DB access, keys are unusable without HSM

2. Session hijack
   -> httpOnly cookies, short expiry
   -> Rate limiting on sensitive actions
   -> PIN/biometric for asset transfers

3. Rogue admin
   -> Embedded Wallet cannot call admin functions
   -> Session Keys have hard-coded permission boundaries
   -> Guardian Agent monitors all wallet activity

4. User wants self-custody (Phase 2+)
   -> Level 2: link external wallet, transfer assets out
   -> Embedded Wallet is a convenience, not a prison
```

## Migration Path (Phase 2+)

```
Level 1 -> Level 2:
  Settings > Connect Wallet > MetaMask
  -> Embedded Wallet linked to external
  -> Assets transferable between both
  -> Game still uses Embedded (seamless)

Level 1 -> Level 3:
  Settings > Export Wallet > Enter PIN
  -> Reveals encrypted key backup
  -> User imports into MetaMask
  -> Embedded Wallet deactivated
  -> Full self-custody from this point
```

## Integration with Settlement Hub

```
Level 1 user clicks "Attack goblin":

1. Game UI sends action to backend
2. Backend -> Settlement Hub (optimistic state update)
3. User sees "Victory! +15 SOUL" instantly
4. Settlement Hub batches the event
5. Hub -> Embedded Wallet signs tx (Session Key)
6. Hub -> Paymaster sponsors gas
7. Hub -> Writer sends to blockchain
8. Tx confirms -> lock released -> state confirmed
9. User sees checkmark (or never notices the delay)
```

## Technology Options

| Solution | Pros | Cons |
|----------|------|------|
| Privy | Best DX, social login built-in | Vendor dependency |
| Web3Auth | Decentralized key sharding | More complex setup |
| Thirdweb | Full-stack, Paymaster included | Less customizable |
| Custom (ERC-4337) | Full control, no vendor lock | Most development effort |

Decision deferred to mainnet preparation phase. Testnet uses deployer key.

## Future: Account Abstraction (ERC-4337)

The full vision uses ERC-4337 smart contract wallets:

- Each user gets a smart contract wallet (not an EOA)
- Wallet enforces Session Key permissions on-chain
- Paymaster sponsorship is native to the protocol
- Social recovery: lost access? Friends help recover
- Batched transactions: multiple game actions in 1 tx

This is the end state. Embedded Wallet is the bridge to get there.

---

*"The best wallet is the one you forget exists."*
