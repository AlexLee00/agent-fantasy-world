# AFW Token Economics — v2

> "$AFW rewards those who build the world. $SOUL is the lifeblood of those who live in it."

## Two-Token System

AFW operates on a dual-token model with distinct roles.

### $AFW — Infrastructure Token (External Value)

| Property | Value |
|----------|-------|
| Purpose | Reward infrastructure contributors |
| Supply | 1,000,000,000 (fixed, no inflation) |
| Value | Market-determined (traded in marketplace) |
| Distribution | System-automated based on contribution (see below) |

### $SOUL — In-Game Currency (Internal Value)

| Property | Value |
|----------|-------|
| Purpose | In-game economy — the currency of Aethermoor |
| Supply | Dynamic (no daily mint cap — gameplay drives supply) |
| Value | Internally pegged by NPC price tables |
| Holders | Agents, NPCs, Monsters (all have wallets) |

$SOUL is NOT a speculative token. It is a functional game currency whose value is determined by what it can buy inside the world.

---

## $AFW Distribution — System-Automated

All $AFW distribution is automated by smart contracts. No human decides "who gets how much." The **Contribution Agent** (an AI) evaluates contributions, and contracts execute the distribution.

### Allocation

| Category | Amount | Method |
|----------|--------|--------|
| Node Mining | 400,000,000 (40%) | Auto: proportional to compute contributed |
| Developer/Community | 250,000,000 (25%) | Auto: Contribution Agent evaluates via GitHub MCP + on-chain |
| Team/Foundation | 150,000,000 (15%) | 10% immediate + 90% vesting (monthly unlock) |
| Ecosystem/Partners | 100,000,000 (10%) | Auto: governance vote → contract executes |
| Initial Liquidity | 50,000,000 (5%) | Auto: locked in Marketplace LP at launch |
| Advisors | 50,000,000 (5%) | Vesting contract (2-year quarterly unlock) |

### Team/Foundation (15% = 150,000,000 AFW)

```
At mainnet launch:
  → 10% (15,000,000 AFW) immediately sent to team wallet
  → 90% (135,000,000 AFW) locked in VestingWallet contract
  → Monthly equal unlock over 4 years (2,812,500 AFW/month)
  → Cannot transfer before unlock (contract enforced)
```

### Advisors (5% = 50,000,000 AFW)

```
At mainnet launch:
  → 100% locked in VestingWallet contract
  → Quarterly equal unlock over 2 years (6,250,000 AFW/quarter)
  → Wallet addresses registered at launch
```

### Node Mining (40% = 400,000,000 AFW)

```
Continuous distribution:
  → NodeRewardPool contract holds allocation
  → Each epoch (1 week), pool distributes to active nodes
  → Distribution proportional to:
      - Inference requests processed (on-chain count)
      - Uptime percentage
      - Response quality score
  → Contribution Agent reads NodeRegistry data
  → Calculates per-node rewards
  → Submits distribution proposal → multisig approves → auto-pay
```

### Developer/Community (25% = 250,000,000 AFW)

```
Continuous distribution:
  → BountyPool contract holds allocation
  → Contribution Agent evaluates via:

      GitHub MCP (on-chain agent reads GitHub directly):
        github:list_commits    → commit count, code volume
        github:search_issues   → PRs merged, issues resolved
        github:get_pull_request → code quality, review status

      On-chain data:
        MonsterRegistry  → creator content usage count
        QuestEngine      → quest completion by players
        Marketplace      → liquidity contribution

  → AI calculates contribution scores per epoch
  → Submits reward proposal → multisig approves → auto-pay
```

### Ecosystem/Partners (10% = 100,000,000 AFW)

```
Governance-driven:
  → EcosystemTreasury contract holds allocation
  → Community proposes usage via AIP (governance proposal)
  → AFW holders vote
  → If approved → contract auto-executes
```

### Initial Liquidity (5% = 50,000,000 AFW)

```
At mainnet launch:
  → Sent to Marketplace liquidity pool
  → Locked for minimum 1 year
  → Provides AFW/SOUL trading depth from day 1
```

### Contribution Agent

The Contribution Agent is an AI agent (same Brain Interface as game agents) that evaluates contributions.

```
Application Supervisor
  ├── Game Agent GenServer      ← "I fight and explore"
  ├── Guardian GenServer        ← "I monitor security"
  └── Contribution GenServer    ← "I evaluate contributions"
```

It reads two data sources:
1. **GitHub MCP** — PR merges, commits, issues, code reviews
2. **On-chain data** — node uptime, content usage, marketplace activity

It produces a reward proposal each epoch:
```json
{
  "epoch": 42,
  "rewards": [
    {"address": "0xNode1...", "amount": 12000, "reason": "1,243 inferences, 99.2% uptime"},
    {"address": "0xDev1...", "amount": 8000, "reason": "3 PRs merged, CombatResolver bug fix"},
    {"address": "0xCreator1...", "amount": 3000, "reason": "Monster type used 342 times"}
  ]
}
```

Multisig reviews and approves. Contract distributes automatically.

---

## Internal Price Peg — NPC Price Tables

$SOUL's value is anchored by NPC prices. Base service prices are fixed in early phases.

### Base Price Table (Lumenveil — Early Phase)

| Item / Service | Price ($SOUL) | Defines |
|---------------|--------------|---------|
| Tavern rest (full HP recovery) | 5 | 1 SOUL = 20% HP |
| Basic health potion | 10 | 1 SOUL = 5 HP |
| Iron sword | 50 | Weapon baseline |
| Leather armor | 40 | Armor baseline |
| Quest board posting | 3 | Information cost |
| Basic spell scroll | 30 | Magic baseline |

## Three Wallet Holders — Everyone is an Economic Actor

Every entity in Aethermoor has a wallet. SOUL circulates between all of them.

### Agents (Players)
- Earn SOUL from quests, monster defeats, discoveries
- Spend SOUL at NPC shops, on items, on services
- Lose SOUL + XP when defeated by monsters
- Trade SOUL, AFW, and items in the marketplace

### NPCs (World Infrastructure)
- Receive SOUL from agents for goods/services
- Spend SOUL on other NPCs (supply chain)
- Production NPCs gather raw materials and sell to crafting NPCs
- AI-powered economic behavior (restock, pricing, negotiation)

### Monsters (Risk/Reward)
- Spawned with initial SOUL based on level/type
- When agent defeats monster, agent takes monster's SOUL
- When monster defeats agent, monster loots agent's SOUL (split with Event Treasury)
- Monsters accumulate wealth from victories — become high-value targets

## Monster Wallet Economy

### Spawn Capital

| Type | Level Range | Initial SOUL |
|------|------------|-------------|
| Minion | 1-5 | 5-20 |
| Regular | 6-10 | 20-50 |
| Elite | 21-25 | 80-150 |
| Zone Boss | Zone cap | 200-500 |
| World Boss | 99 | 3000-5000 |

### Combat Loot Flow

**Agent wins:** Agent receives ALL of the monster's current SOUL balance.

**Monster wins (Agent dies):**
```
Agent's SOUL x 30% = total loot
  |-- 50% -> Monster wallet (15% of agent's SOUL)
  |-- 50% -> Event Treasury contract (15% of agent's SOUL)

Agent also loses:
  - Random % of XP (level down possible)
  - Auto-revive at nearest tavern (no SOUL cost for revival)
```

## Event Treasury — Community Event Funding

The Event Treasury is a smart contract that accumulates SOUL from combat deaths. No individual controls it.

### Event Thresholds

| Treasury Balance | Event Triggered |
|-----------------|----------------|
| 1,000 SOUL | Mini event — rare monster spawns with bonus loot |
| 5,000 SOUL | Zone event — zone boss powered up, extra rewards |
| 10,000 SOUL | World Boss summon — Treasury SOUL is the reward pool |

## In-Game Marketplace

Off-chain listing + on-chain settlement. P2P trading.

- **Order registration** — off-chain data (gas = 0)
- **Trade execution** — on-chain settlement (gas on buyer)
- **AFW/SOUL swap** — P2P in marketplace, user-set prices
- **2% SOUL burn** on every trade settlement
- **NPC prices = natural ceiling** — no system intervention needed

## NPC Supply Chain — Production Economy

| NPC Type | Produces | Buys From | Sells To |
|----------|----------|-----------|----------|
| Miner | Iron ore, gems | (raw gathering) | Smithy |
| Herbalist | Herbs, reagents | (raw gathering) | Alchemist |
| Farmer | Wheat, vegetables | (raw gathering) | Tavern, Shop |
| Smithy | Swords, shields | Miner, Lumberjack | Shop, Agents |
| Alchemist | Potions, scrolls | Herbalist | Shop, Agents |
| Tavern | Rest, food, rumors | Farmer | Agents |
| Shop | All finished goods | Crafters | Agents |

## SOUL Circulation — Complete Flow

```
[Mint] Monster spawn -> Monster wallet (initial SOUL)
[Mint] Quest reward -> Agent wallet
[Mint] Zone init -> NPC wallets (starting capital)

Agent <-- buys goods --> Shop NPC <-- supply chain --> Production NPCs
  |
  |-- trades in Marketplace <--> Other Agents (SOUL/AFW/Items)
  |                                  |-- 2% fee burned
  |
  |-- fights monster
        |-- Agent wins -> takes ALL monster's SOUL
        |-- Monster wins -> loots 30% of agent's SOUL
                              |-- 50% -> Monster wallet
                              |-- 50% -> Event Treasury -> triggers world events
```

## Brain Interface & Token Economics

| Tier | Cost to User | How User Benefits |
|------|-------------|-------------------|
| Tier 1 (Free) | Free — AFW provides basic LLM | Immediate participation, earns $SOUL |
| Tier 2 (API Key) | User pays API provider | Smarter agent, more $SOUL |
| Tier 3 (OpenClaw) | User pays (cloud or hardware) | Full control, cost optimization |
| Tier 4 (Node) | User pays hardware/electricity | Earns $AFW for GPU contribution |

See [Brain Interface Architecture](BRAIN_INTERFACE.md) for full details.

## Gas Fee Strategy

| Off-Chain (free) | On-Chain (gas needed) |
|-----------------|----------------------|
| AI brain decisions (every tick) | Combat result settlement |
| Movement and pathfinding | Marketplace trades |
| NPC dialogue and events | Level up / death |
| 99% of game logic | 1% of events |

Each participant pays for their own on-chain actions.

| Phase | Network | When |
|-------|---------|------|
| Testnet | Base Sepolia | Now |
| Launch | Polygon PoS or Base | When stable |
| Scale | L2 / rollup | When traffic demands it |

## Economic Evolution Roadmap

### Phase 1 — Controlled Economy (MVP)
Base and material prices fixed. Simple NPC buy/sell. Establish baseline.

### Phase 2 — Mixed Economy (Growth)
Base services stay fixed. Material prices become dynamic. NPC AI-driven purchasing.

### Phase 3 — Autonomous Economy (Mature)
All prices determined by agents. Full AI autonomous economic actors. No central price control.

## Creator Royalties

5% royalty on $SOUL generated by their content. From existing reward, not additional minting.

---

*"$AFW is the foundation. $SOUL is the heartbeat."*
