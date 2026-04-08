# Pre-Deployment Checklist — Review Before Mainnet

This document lists all open questions and verification items that must be resolved before deploying contracts to Polygon PoS mainnet. Contracts are immutable once deployed — every decision here is permanent.

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

**Registration model:** Open registration — anyone can register new content (zones, monsters, items, NPCs). BUT the contract enforces Balance table specs. Out-of-spec registrations are auto-rejected and the wallet is frozen.

### Key question:
If any of these are enums or fixed arrays, they need to be refactored to mappings with `register()` functions before mainnet.

---

## 2. Token Economics

| Item | Decision | Status |
|------|----------|--------|
| $AFW supply | 1B fixed — confirmed | ✅ Done |
| $AFW distribution | 40/25/15/10/5/5 — defer exact split to mainnet | ⬜ Later |
| $SOUL daily mint cap | **No limit** — natural gameplay emission, burns balance it | ✅ Done |
| $SOUL burn rate | Marketplace fee **2%** — confirmed | ✅ Done |
| NPC price table | Potion=10, rest=5, sword=50 — confirmed | ✅ Done |
| Monster spawn SOUL | Minion 5-20, Regular 20-50, Elite 80-150, Boss 200-500 | ✅ Done |
| Agent start SOUL | 50 SOUL | ✅ Done |
| Death penalty | **No SOUL burn for revival.** Monster loots 30% → 15% to monster wallet, 15% to Event Treasury. Agent loses XP (random %). | ✅ Done |
| Event Treasury | Auto-accumulates from death loots. Funds world events (bosses, seasons). On-chain contract, no human control. | ✅ Done |
| Creator royalty | 5% from existing rewards — no extra minting | ✅ Done |

---

## 3. Access Control & Governance

| Item | Decision | Status |
|------|----------|--------|
| Admin keys | **Multisig** — multiple signers required | ✅ Done |
| Upgrade path | **Upgradeable (proxy pattern)** — bug fixes possible | ✅ Done |
| Emergency pause | **NO emergency pause.** Instead: contract auto-freezes wallets that violate registration specs | ✅ Done |
| Registration | **Open registration** — anyone can register content | ✅ Done |
| Spec enforcement | Contract checks Balance table ranges. Out-of-spec → reject + freeze wallet | ✅ Done |
| Wallet unfreeze | Governance multisig vote only | ✅ Done |
| Parameter changes | Which params can governance change post-deploy? | ⬜ Define |

### Auto-Protection System (replaces emergency pause)

```
Registration attempt:
  → Contract checks stat ranges against Balance table
  → Within spec? → Accept, wallet active
  → Out of spec? → Reject transaction + freeze wallet

Spawn (monster/NPC/item):
  → Stats are RANDOM within the registered type's range
  → Range enforced by contract, not by caller
  → Nobody can create ATK 9999 anything

Wallet freeze triggers:
  → Out-of-spec registration attempt
  → Abnormal SOUL transfer patterns
  → Contract call rule violations

Wallet unfreeze:
  → Governance multisig vote only
```

This is fully decentralized. No human triggers the pause — the code protects itself.

---

## 4. Marketplace

| Item | Question | Status |
|------|----------|--------|
| Order book | On-chain order book or off-chain matching? | ⬜ Decide |
| Fee mechanism | 2% burn on SOUL side of every trade | ✅ Done |
| Item trading | How are items represented on-chain? ERC-1155? | ⬜ Design |
| AFW/SOUL pair | User-set prices in marketplace (order book) | ✅ Done |
| Front-running | MEV protection needed? | ⬜ Evaluate |

---

## 5. Gas & Infrastructure

| Item | Decision | Status |
|------|----------|--------|
| Off-chain/on-chain split | 99% off-chain, 1% on-chain (combat/trade/level) | ✅ Done |
| Who pays gas | Each user pays for own actions | ✅ Done |
| Batch settlement | How many ticks per on-chain tx? | ⬜ Decide |
| Network | Amoy → Polygon PoS → L2 when traffic grows | ✅ Done |
| RPC provider | Public RPC or dedicated node? | ⬜ Decide |
| Gas estimation | Safety margins tested on Amoy? | ⬜ Test |

---

## 6. Security

| Item | Question | Status |
|------|----------|--------|
| Audit | Professional audit before mainnet? | ⬜ Plan |
| Test coverage | All contracts have comprehensive tests? | ⬜ Verify |
| Reentrancy | All external calls protected? | ⬜ Verify |
| Integer overflow | Using Solidity 0.8+ built-in checks | ✅ Done |
| Access control | All admin functions properly gated? | ⬜ Verify |
| Oracle manipulation | OracleGateway tamper-proof? | ⬜ Verify |
| Auto-freeze | Wallet freeze on spec violation implemented? | ⬜ Implement |

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
| ItemRegistry | Dynamic item registration (spec-enforced) | ⬜ Design |
| Marketplace | On-chain order book for trading | ⬜ Design |
| MonsterRegistry | Monster types + wallet + spec enforcement | ⬜ Design |
| NPCRegistry | NPC types + wallet + supply chain | ⬜ Design |
| EventTreasury | Death loot accumulation + world event funding | ⬜ Design |

---

## Progress Summary

```
✅ Decided:  17 items
⬜ Remaining: 20 items (verify, design, test, decide)
```

---

*"Contracts are forever. Decide carefully, deploy once."*
