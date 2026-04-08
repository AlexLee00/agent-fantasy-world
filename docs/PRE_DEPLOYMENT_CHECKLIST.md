# Pre-Deployment Checklist — Review Before Mainnet

This document lists all open questions and verification items that must be resolved before deploying contracts to Polygon PoS mainnet.

---

## 1. Contract Extensibility

**Principle:** Every system must use the registry pattern. Nothing hardcoded.

| System | Question | Status |
|--------|----------|--------|
| Zones | Is `WorldMap` using a dynamic mapping or hardcoded enum? | ⬜ Verify |
| Classes | Can new agent classes be registered after deployment? | ⬜ Verify |
| Items | Does `ItemRegistry` (future) support dynamic item registration? | ⬜ Design |
| Actions | Are action types (FIGHT, FLEE, etc.) extensible or enum-locked? | ⬜ Verify |
| Monsters | Can new monster types be registered by creators? | ⬜ Design |
| NPCs | Can new NPC types be added post-deployment? | ⬜ Design |
| Marketplace | Can new trade pair types be added? | ⬜ Design |

**Registration model:** Open registration — anyone can register. Contract enforces Balance table spec ranges. Out-of-spec → `revert` (registration simply fails, no wallet freeze). Stats are random within range on spawn.

---

## 2. Token Economics

| Item | Decision | Status |
|------|----------|--------|
| $AFW supply | 1B fixed | ✅ Done |
| $AFW distribution | 40/25/15/10/5/5 — defer exact split to mainnet | ⬜ Later |
| $SOUL daily mint cap | **No limit** — gameplay drives supply, burns balance it | ✅ Done |
| $SOUL burn rate | Marketplace fee **2%** | ✅ Done |
| NPC price table | Potion=10, rest=5, sword=50 | ✅ Done |
| Monster spawn SOUL | Minion 5-20, Regular 20-50, Elite 80-150, Boss 200-500 | ✅ Done |
| Agent start SOUL | 50 SOUL | ✅ Done |
| Death penalty | Monster loots 30% (15% monster wallet + 15% Event Treasury) + XP loss. No revival fee. | ✅ Done |
| Event Treasury | Auto-accumulates from death loots. Funds world events. | ✅ Done |
| Creator royalty | 5% from existing rewards — no extra minting | ✅ Done |

---

## 3. Access Control & Governance

| Item | Decision | Status |
|------|----------|--------|
| Admin keys | **Multisig** | ✅ Done |
| Upgrade path | **Upgradeable (proxy pattern)** | ✅ Done |
| Emergency pause | **NO.** No emergency pause exists. | ✅ Done |
| Registration | **Open** — anyone can register within spec | ✅ Done |
| Spec enforcement | Out-of-spec registration → `revert` (tx fails, that's all) | ✅ Done |
| Exploit protection | Guardian Agent monitors on-chain data → proposes wallet freeze to multisig | ✅ Done |
| Wallet freeze | Only via multisig vote on Guardian Agent proposal | ✅ Done |
| Parameter changes | Which params can governance change post-deploy? | ⬜ Define |

### Security Layers

```
Layer 1: Contract self-protection
  → onlyAuthorizedContract on SOUL minting
  → ReentrancyGuard on all external calls
  → Nonce/processedId for duplicate reward prevention
  → Out-of-spec registration → revert (no freeze, just fails)
  → Stat ranges enforced from Balance table

Layer 2: Guardian Agent (AI-powered)
  → Monitors ALL on-chain transaction data
  → Detects exploit patterns (unauthorized minting, reentrancy, duplicates)
  → Proposes wallet freeze to multisig WITH evidence
  → Also provides economy analytics (public dashboard)

Layer 3: Governance (multisig)
  → Reviews Guardian Agent proposals
  → Approves/rejects wallet freezes
  → Community parameter changes via AIP
```

---

## 4. Marketplace

| Item | Decision | Status |
|------|----------|--------|
| AFW/SOUL swap | **P2P in marketplace** — user-to-user, user-set prices | ✅ Done |
| Order registration | **Off-chain data** — listing items/orders costs no gas | ✅ Done |
| Trade settlement | **On-chain at execution** — gas only when trade happens | ✅ Done |
| Fee mechanism | 2% SOUL burned on every trade settlement | ✅ Done |
| Item standard | How are items represented on-chain? ERC-1155? | ⬜ Design |
| Front-running | MEV protection needed? | ⬜ Evaluate |

### Marketplace Architecture

```
Seller: "Sell iron sword for 45 SOUL"
  → Registered as off-chain data (no gas)
  → Visible to all agents browsing marketplace

Buyer: "Buy this sword"
  → On-chain settlement transaction
  → Buyer pays gas (~$0.007)
  → SOUL transfers: 44.1 to seller, 0.9 burned (2%)
  → Item transfers to buyer
  → Transaction recorded on-chain permanently

AFW/SOUL swap: same flow
  → "Sell 100 SOUL for 5 AFW" → off-chain listing
  → Someone accepts → on-chain settlement
```

**NPC prices = natural price ceiling.** NPC sells sword for 50 SOUL, so marketplace price naturally stays below 50.

---

## 5. Gas & Infrastructure

| Item | Decision | Status |
|------|----------|--------|
| Game tick | Off-chain AI decisions, periodic on-chain state sync | ✅ Done |
| Marketplace | Off-chain listings, on-chain settlement | ✅ Done |
| Who pays gas | Each user pays for own actions | ✅ Done |
| Batch settlement | How many ticks per on-chain tx? | ⬜ Decide |
| Network | Amoy → Polygon PoS → L2 when traffic grows | ✅ Done |
| RPC provider | Public RPC or dedicated node? | ⬜ Decide |
| Gas estimation | Safety margins tested on Amoy? | ⬜ Test |

---

## 6. Security

| Item | Question | Status |
|------|----------|--------|
| Guardian Agent | AI monitoring of all on-chain transactions | ✅ Designed |
| Audit | Professional audit before mainnet? | ⬜ Plan |
| Test coverage | All contracts have comprehensive tests? | ⬜ Verify |
| Reentrancy | All external calls protected? | ⬜ Verify |
| Integer overflow | Using Solidity 0.8+ built-in checks | ✅ Done |
| Access control | All admin functions properly gated? | ⬜ Verify |
| Oracle manipulation | OracleGateway tamper-proof? | ⬜ Verify |

---

## 7. Game Balance

| Item | Question | Status |
|------|----------|--------|
| Balance table | Level/stat ranges finalized for all zones | ✅ Done |
| Damage formula | Tested and balanced? | ⬜ Test |
| XP curve | Level progression rate correct? | ⬜ Confirm |
| Death penalty | 30% loot (15% monster + 15% treasury) + XP loss | ✅ Done |
| Economy simulation | Ran multi-agent simulation to test inflation? | ⬜ Run |

---

## 8. Missing Contracts

| Contract | Purpose | Status |
|----------|---------|--------|
| CombatResolver | On-chain combat settlement | ⬜ Design |
| ItemRegistry | Dynamic item registration (spec-enforced, ERC-1155?) | ⬜ Design |
| Marketplace | Off-chain listing + on-chain settlement | ⬜ Design |
| MonsterRegistry | Monster types + wallet + spec enforcement | ⬜ Design |
| NPCRegistry | NPC types + wallet + supply chain | ⬜ Design |
| EventTreasury | Death loot accumulation + world event funding | ⬜ Design |

---

## Progress Summary

```
✅ Decided:  22 items
⬜ Remaining: 15 items (verify, design, test, decide)
```

---

*"Contracts are forever. Decide carefully, deploy once."*
