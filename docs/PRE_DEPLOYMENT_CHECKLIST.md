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

### Key question:
If any of these are enums or fixed arrays, they need to be refactored to mappings with `register()` functions before mainnet.

---

## 2. Token Economics

| Item | Question | Status |
|------|----------|--------|
| $AFW supply | Is 1B fixed supply correct? Once deployed, cannot change | ⬜ Confirm |
| $AFW distribution | 40/25/15/10/5/5 split finalized? | ⬜ Confirm |
| $SOUL mint rate | Daily mint cap — what's the number? | ⬜ Decide |
| $SOUL burn rate | Marketplace fee 2% — confirmed? | ⬜ Confirm |
| NPC price table | Base prices (potion=10, rest=5, revive=100) finalized? | ⬜ Confirm |
| Monster spawn SOUL | Initial SOUL per monster type — finalized? | ⬜ Confirm |
| Agent start SOUL | Starting amount (50 SOUL?) — confirmed? | ⬜ Confirm |
| Revival cost | 100 SOUL — how much burned vs goes to NPC? | ⬜ Decide |
| Creator royalty | 5% from existing rewards — mechanism verified? | ⬜ Verify |

---

## 3. Access Control & Governance

| Item | Question | Status |
|------|----------|--------|
| Admin keys | Who holds deployer/admin role? Multisig? | ⬜ Decide |
| Upgrade path | Are contracts upgradeable (proxy) or immutable? | ⬜ Decide |
| Parameter changes | Which params can governance change post-deploy? | ⬜ Define |
| Emergency pause | Can contracts be paused in emergency? By whom? | ⬜ Decide |
| Zone registration | Who can register new zones? AIP vote? | ⬜ Decide |
| Monster registration | Who can register new monster types? | ⬜ Decide |
| NPC registration | Who can register new NPC types? | ⬜ Decide |

---

## 4. Marketplace

| Item | Question | Status |
|------|----------|--------|
| Order book | On-chain order book or off-chain matching? | ⬜ Decide |
| Fee mechanism | 2% burn on which side (SOUL only? both?) | ⬜ Decide |
| Item trading | How are items represented on-chain? ERC-1155? | ⬜ Design |
| AFW/SOUL pair | AMM pool or order book? | ⬜ Decide |
| Front-running | MEV protection needed? | ⬜ Evaluate |

---

## 5. Gas & Infrastructure

| Item | Question | Status |
|------|----------|--------|
| Off-chain/on-chain split | Which actions go on-chain? Finalized? | ⬜ Confirm |
| Batch settlement | How many ticks per on-chain tx? | ⬜ Decide |
| State channel | Needed for high-frequency agent updates? | ⬜ Evaluate |
| RPC provider | Public RPC or dedicated node? | ⬜ Decide |
| Gas estimation | Safety margins tested on Amoy? | ⬜ Test |

---

## 6. Security

| Item | Question | Status |
|------|----------|--------|
| Audit | Professional audit before mainnet? | ⬜ Plan |
| Test coverage | All contracts have comprehensive tests? | ⬜ Verify |
| Reentrancy | All external calls protected? | ⬜ Verify |
| Integer overflow | Using SafeMath / Solidity 0.8+ checks? | ⬜ Verify |
| Access control | All admin functions properly gated? | ⬜ Verify |
| Oracle manipulation | OracleGateway tamper-proof? | ⬜ Verify |

---

## 7. Game Balance

| Item | Question | Status |
|------|----------|--------|
| Balance table | Level/stat ranges finalized for all zones? | ⬜ Confirm |
| Damage formula | Tested and balanced? | ⬜ Test |
| XP curve | Level progression rate correct? | ⬜ Confirm |
| Death penalty | 30% SOUL loot to monster — balanced? | ⬜ Playtest |
| Economy simulation | Ran multi-agent simulation to test inflation? | ⬜ Run |

---

## 8. Missing Contracts

| Contract | Purpose | Status |
|----------|---------|--------|
| CombatResolver | On-chain combat settlement | ⬜ Design |
| ItemRegistry | Dynamic item registration | ⬜ Design |
| Marketplace | On-chain order book for trading | ⬜ Design |
| MonsterRegistry | Monster types + wallet management | ⬜ Design |
| NPCRegistry | NPC types + wallet + supply chain | ⬜ Design |

---

## Decision Process

Each item above should be resolved through one of:
1. **Confirm** — we already decided, just need to verify implementation
2. **Decide** — needs a decision from Alex (Product Owner)
3. **Design** — needs spec from Meti, then implementation
4. **Test** — needs testing on Amoy before mainnet
5. **Evaluate** — needs research before deciding

**Rule: No item can be ⬜ when we deploy to mainnet. Every box must be ✅.**

---

*"Contracts are forever. Decide carefully, deploy once."*
