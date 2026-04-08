# AFW Token Economics — Draft v1

> "$AFW rewards those who build the world. $SOUL is the lifeblood of those who live in it."

## Two-Token System

AFW operates on a dual-token model with distinct roles.

### $AFW — Infrastructure Token (External Value)

| Property | Value |
|----------|-------|
| Purpose | Reward infrastructure contributors |
| Supply | 1,000,000,000 (fixed, no inflation) |
| Value | Market-determined (traded in marketplace) |
| Recipients | Node providers, developers, governance participants |

**Who earns $AFW:**
- **Node providers** — contribute GPU/compute to run AI inference for agents
- **Developers** — contribute code, content, and improvements to the project
- **Governance participants** — stake $AFW to vote on AIPs
- **Content creators** — earn $AFW grants for accepted content

### $SOUL — In-Game Currency (Internal Value)

| Property | Value |
|----------|-------|
| Purpose | In-game economy — the currency of Aethermoor |
| Supply | Dynamic (no daily mint cap — gameplay drives supply) |
| Value | Internally pegged by NPC price tables |
| Holders | Agents, NPCs, Monsters (all have wallets) |

$SOUL is NOT a speculative token. It is a functional game currency whose value is determined by what it can buy inside the world.

## Internal Price Peg — NPC Price Tables

$SOUL's value is anchored by NPC prices. Base service prices are fixed in early phases. As the economy matures, all prices transition to autonomous agent-driven pricing.

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
- When agent defeats monster → agent takes monster's SOUL
- When monster defeats agent → monster loots agent's SOUL (split with Event Treasury)
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

**Agent wins:**
- Agent receives ALL of the monster's current SOUL balance
- Monster dies, wallet emptied
- If monster had accumulated SOUL from previous victories, agent gets all of it

**Monster wins (Agent dies):**
```
Agent's SOUL x 30% = total loot
  ├── 50% → Monster wallet (15% of agent's SOUL)
  └── 50% → Event Treasury contract (15% of agent's SOUL)

Agent also loses:
  - Random % of XP (level down possible)
  - Auto-revive at nearest tavern (no SOUL cost for revival)
```

The death penalty is losing SOUL + XP. There is no additional revival fee — the 30% loot IS the penalty. Double punishment is avoided.

**Emergent Boss Example:**
```
Goblin spawns with 15 SOUL
  → defeats Agent A → gets 15% of A's SOUL → wallet: 33
  → defeats Agent B → gets 15% of B's SOUL → wallet: 53
  → defeats Agent C → gets 15% of C's SOUL → wallet: 71

This goblin is now worth 71 SOUL to whoever kills it.
Meanwhile, Event Treasury accumulated the other 50% from all 3 deaths.
```

## Event Treasury — Community Event Funding

The Event Treasury is a smart contract that accumulates SOUL from combat deaths. No individual controls it — the code manages it.

### How It Works

Every time a monster defeats an agent, 50% of the looted SOUL goes to the Event Treasury contract. This SOUL accumulates until thresholds are reached, automatically triggering world events.

### Event Thresholds

| Treasury Balance | Event Triggered |
|-----------------|----------------|
| 1,000 SOUL | Mini event — rare monster spawns with bonus loot |
| 5,000 SOUL | Zone event — zone boss powered up, extra rewards |
| 10,000 SOUL | World Boss summon — Treasury SOUL is the reward pool |

### World Boss Cycle

When Treasury reaches 10,000 SOUL → World Boss spawns → all agents can participate → defeating the World Boss distributes Treasury SOUL among participants → Treasury resets to 0 → cycle restarts.

This creates a natural event cycle: more combat deaths = faster Treasury fills = more frequent world events. Player activity directly creates content.

**No system intervention** — the Treasury is a smart contract with hardcoded thresholds. Nobody decides when to trigger events. The code does.

## In-Game Marketplace

The marketplace is an on-chain exchange built into the game world. No external DEX required.

### What Can Be Traded

| Category | Examples |
|----------|---------|
| Token swap | SOUL ↔ AFW at user-set prices |
| Finished goods | Swords, armor, potions, scrolls |
| Raw materials | Iron ore, herbs, lumber, hides |
| Services | Quest contracts, escort requests |

### How It Works

- **Order book model** — users set their own prices
- **No system-managed exchange rate** — fully decentralized, user-to-user
- **NPC prices act as natural ceiling** — NPC sells sword for 50 SOUL, no one lists at 60
- **Agents can undercut NPCs** — sell sword for 45 SOUL
- **AI agents decide when to trade** — Brain Interface evaluates market

### Price Stabilization (No System Intervention)

NPC fixed prices naturally stabilize the SOUL/AFW exchange rate:

- **SOUL too cheap?** → Buy cheap SOUL on market → spend at NPCs → demand rises → price recovers
- **SOUL too expensive?** → Earn SOUL in-game → sell on market → supply rises → price drops
- **NPCs are the decentralized central bank** — prices hardcoded in smart contracts

### Marketplace Fee (Burn Mechanism)

- 2% of the SOUL side of every trade is permanently burned
- Creates natural deflationary pressure
- Fee rate is governance-adjustable via AIP

## NPC Supply Chain — Production Economy

### Production NPC Types

| NPC Type | Produces | Buys From | Sells To |
|----------|----------|-----------|----------|
| Miner | Iron ore, gems | (raw gathering) | Smithy |
| Herbalist | Herbs, reagents | (raw gathering) | Alchemist |
| Farmer | Wheat, vegetables | (raw gathering) | Tavern, Shop |
| Lumberjack | Lumber, planks | (raw gathering) | Smithy, Builder |
| Hunter | Hides, meat | (hunts monsters) | Tanner, Tavern |
| Tanner | Leather armor | Hunter (hides) | Shop, Agents |
| Smithy | Swords, shields | Miner, Lumberjack | Shop, Agents |
| Alchemist | Potions, scrolls | Herbalist | Shop, Agents |
| Tavern | Rest, food, rumors | Farmer | Agents |
| Shop | All finished goods | Crafters | Agents |

### Material Pricing — Supply and Demand

Raw material prices are dynamic, determined by supply and demand between NPCs.

## SOUL Circulation — Complete Flow

```
[Mint] Monster spawn → Monster wallet (initial SOUL)
[Mint] Quest reward → Agent wallet
[Mint] Zone init → NPC wallets (starting capital)

Agent ←── buys goods ──→ Shop NPC ←── supply chain ──→ Production NPCs
  │
  ├── trades in Marketplace ←──→ Other Agents (SOUL/AFW/Items)
  │                                  └── 2% fee burned
  │
  └── fights monster
        ├── Agent wins → takes ALL monster's SOUL
        └── Monster wins → loots 30% of agent's SOUL
                              ├── 50% → Monster wallet
                              └── 50% → Event Treasury
                                          └── triggers world events
```

### When is $SOUL Minted?

- **Monster spawning** — initial SOUL based on level/type
- **Quest completion** — EconomyEngine mints reward SOUL
- **New zone initialization** — NPC wallets receive starting capital
- **New agent creation** — small starting amount (50 SOUL)
- No daily mint cap — gameplay naturally regulates supply

### When is $SOUL Burned?

- **Marketplace transaction fees** — 2% burned on every trade
- **Item destruction** — breaking down items removes SOUL from circulation
- **Zone taxes** — small periodic burn to prevent infinite accumulation

## Gas Fee Strategy

### On-Chain vs Off-Chain

| Off-Chain (free) | On-Chain (gas needed) |
|-----------------|----------------------|
| AI brain decisions (every tick) | Combat result settlement |
| Movement and pathfinding | Marketplace trades |
| NPC dialogue and events | Level up / death |
| Event generation | SOUL/AFW token transfers |
| 99% of game logic | 1% of events |

### Who Pays Gas?

Each participant pays for their own on-chain actions. No system subsidies.

| Action | Who Pays |
|--------|----------|
| Marketplace trade | Buyer |
| Agent state update | Observer/owner |
| Node inference submission | Node provider (earns $AFW) |
| Monster spawn | EconomyEngine (protocol treasury) |

### Infrastructure Scaling

| Phase | Network | When |
|-------|---------|------|
| MVP | Polygon Amoy (testnet) | Now |
| Launch | Polygon PoS (mainnet) | When stable |
| Scale | L2 / rollup | When traffic demands it |

## Economic Evolution Roadmap

### Phase 1 — Controlled Economy (MVP)
Base and material prices fixed. Simple NPC buy/sell. Establish baseline.

### Phase 2 — Mixed Economy (Growth)
Base services stay fixed. Material prices become dynamic. NPC AI-driven purchasing.

### Phase 3 — Autonomous Economy (Mature)
All prices determined by agents. Full AI autonomous economic actors. No central price control.

## Distribution ($AFW)

| Allocation | Amount | Purpose |
|-----------|--------|--------|
| Node Mining | 400,000,000 (40%) | Rewards for compute providers |
| Community Grants | 250,000,000 (25%) | Developer rewards, bounties, hackathons |
| Team / Foundation | 150,000,000 (15%) | Core team vesting |
| Ecosystem / Partners | 100,000,000 (10%) | Strategic partnerships |
| Initial Liquidity | 50,000,000 (5%) | Marketplace liquidity pools |
| Advisors | 50,000,000 (5%) | Advisor vesting |

## Brain Interface & Token Economics

| Provider Choice | Cost to User | How User Benefits |
|----------------|-------------|-------------------|
| Community Nodes | Free | Agent on open-source LLM, earns $SOUL |
| Claude Code / OAuth API | User pays subscription | Smarter agent → more $SOUL |
| Self-Hosted | User pays hardware | Full control, same earning |

## Creator Royalties

5% royalty on $SOUL generated by their content. From existing reward, not additional minting.

---

*"$AFW is the foundation. $SOUL is the heartbeat."*
