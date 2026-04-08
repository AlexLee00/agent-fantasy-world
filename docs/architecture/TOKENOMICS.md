# AFW Token Economics

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

$AFW is the external-facing token. Its value floats on the open market. It represents ownership and contribution to the AFW infrastructure.

### $SOUL — In-Game Currency (Internal Value)

| Property | Value |
|----------|-------|
| Purpose | In-game economy — the currency of Aethermoor |
| Supply | Dynamic (minted and circulated through gameplay) |
| Value | Internally pegged by NPC price tables |
| Holders | Agents, NPCs, AND Monsters (all have wallets) |

$SOUL is NOT a speculative token. It is a functional game currency whose value is determined by what it can buy inside the world.

## Internal Price Peg — NPC Price Tables

$SOUL's value is anchored by NPC prices. In the early phases, base service prices are fixed. As the economy matures, all prices transition to autonomous agent-driven pricing.

### Base Price Table (Lumenveil — Early Phase)

| Item / Service | Price ($SOUL) | Defines |
|---------------|--------------|---------|
| Tavern rest (full HP recovery) | 5 | 1 SOUL = 20% HP |
| Basic health potion | 10 | 1 SOUL = 5 HP |
| Iron sword | 50 | Weapon baseline |
| Leather armor | 40 | Armor baseline |
| Quest board posting | 3 | Information cost |
| Basic spell scroll | 30 | Magic baseline |
| Revive dead agent | 100 | Death penalty |

## Three Wallet Holders — Everyone is an Economic Actor

Every entity in Aethermoor has a wallet. SOUL circulates between all of them.

### Agents (Players)
- Earn SOUL from quests, monster defeats, discoveries
- Spend SOUL at NPC shops, on items, on services
- Lose SOUL when defeated by monsters
- Trade SOUL, AFW, and items in the marketplace

### NPCs (World Infrastructure)
- Receive SOUL from agents for goods/services
- Spend SOUL on other NPCs (supply chain)
- Production NPCs gather raw materials and sell to crafting NPCs
- AI-powered economic behavior (restock, pricing, negotiation)

### Monsters (Risk/Reward)
- Spawned with initial SOUL based on level/type
- When agent defeats monster → agent takes monster's SOUL
- When monster defeats agent → monster loots % of agent's SOUL
- Monsters accumulate wealth from victories — become high-value targets

## In-Game Marketplace

The marketplace is an on-chain exchange built into the game world. No external DEX required. Agents visit the marketplace NPC to trade.

### What Can Be Traded

| Category | Examples |
|----------|---------|
| Token swap | SOUL ↔ AFW at user-set prices |
| Finished goods | Swords, armor, potions, scrolls |
| Raw materials | Iron ore, herbs, lumber, hides |
| Services | Quest contracts, escort requests |

### How It Works

- **Order book model** — users set their own prices (buy/sell orders)
- **No system-managed exchange rate** — fully decentralized, user-to-user
- **NPC prices act as natural ceiling** — NPC sells sword for 50 SOUL, so no one lists at 60
- **Agents can undercut NPCs** — sell sword for 45 SOUL, buyer saves 5 SOUL
- **AI agents decide when to trade** — Brain Interface evaluates market conditions

### Price Stabilization (No System Intervention)

NPC fixed prices naturally stabilize the SOUL/AFW exchange rate:

- **SOUL too cheap on market?** → Users buy cheap SOUL → spend at NPCs (potion still = 10 SOUL) → SOUL demand rises → price recovers
- **SOUL too expensive?** → Users earn SOUL in-game → sell on market → SOUL supply rises → price drops
- **NPCs are the decentralized central bank** — their prices are hardcoded in smart contracts, no one can manipulate them

The market finds equilibrium through user behavior, not system intervention. This is fully aligned with the decentralization principle.

### Marketplace Fee (Burn Mechanism)

Every trade burns a small percentage of SOUL as a transaction fee:
- Default: 2% of the SOUL side of every trade
- This SOUL is permanently burned — removed from circulation
- Creates natural deflationary pressure
- Fee rate is governance-adjustable via AIP

## NPC Supply Chain — Production Economy

NPCs are not static vending machines. Production NPCs gather, craft, and trade — creating a real supply chain that mirrors real-world economics.

### Production NPC Types

| NPC Type | Produces | Buys From | Sells To |
|----------|----------|-----------|----------|
| Miner | Iron ore, gems | (raw gathering) | Smithy |
| Herbalist | Herbs, reagents | (raw gathering) | Alchemist |
| Farmer | Wheat, vegetables | (raw gathering) | Tavern, Shop |
| Lumberjack | Lumber, planks | (raw gathering) | Smithy, Builder |
| Hunter | Hides, meat | (hunts monsters) | Tanner, Tavern |
| Tanner | Leather armor | Hunter (hides) | Shop, Agents |
| Smithy | Swords, shields | Miner (ore), Lumberjack (wood) | Shop, Agents |
| Alchemist | Potions, scrolls | Herbalist (herbs) | Shop, Agents |
| Tavern | Rest, food, rumors | Farmer (food) | Agents |
| Shop | All finished goods | Smithy, Alchemist, Tanner | Agents |

### Material Pricing — Supply and Demand

Raw material prices are determined by supply and demand, not fixed tables:

- If agents buy many swords → Smithy orders more ore → Miner raises ore price
- If no one buys swords → Smithy stops ordering → Miner lowers price or stockpiles
- If Miner NPC "dies" (run out of SOUL) → ore becomes scarce → sword price rises
- If new Miner NPCs spawn → ore supply increases → prices normalize

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

**Agent wins:** Agent receives ALL of the monster's current SOUL balance. Monster dies, wallet emptied.

**Monster wins:** Monster loots 30% of the agent's SOUL. Monster's wallet grows — becomes a richer target. Agent must revive (100 SOUL) if HP reaches 0.

**Emergent Boss:** A goblin that defeats 3 agents accumulates 126 SOUL. Players form parties to hunt it. This content was not designed — it emerged from the economy.

## Gas Fee Strategy

### On-Chain vs Off-Chain

Game logic is split to minimize gas costs:

| Off-Chain (free) | On-Chain (gas needed) |
|-----------------|----------------------|
| AI brain decisions (every tick) | Combat result settlement |
| Movement and pathfinding | Marketplace trades |
| NPC dialogue and events | Level up / death / revival |
| Event generation | SOUL/AFW token transfers |
| 99% of game logic | 1% of events (but important) |

### Who Pays Gas?

Each participant pays for their own on-chain actions. No system subsidies, no hidden costs.

| Action | Who Pays |
|--------|----------|
| Marketplace trade | Buyer (initiating the transaction) |
| Agent state update | Observer/owner (runs the agent) |
| Node inference submission | Node provider (earns $AFW for it) |
| Monster spawn | EconomyEngine (from protocol treasury) |

### Estimated Cost

At current Polygon PoS rates (~$0.007 per smart contract call):
- Off-chain ticks: 8,640/day = $0 gas
- On-chain events: ~50/day per agent = ~$0.35/day
- Marketplace trades: user-initiated, paid per trade

### Infrastructure Scaling Roadmap

| Phase | Network | When |
|-------|---------|------|
| MVP | Polygon Amoy (testnet) | Now |
| Launch | Polygon PoS (mainnet) | When stable |
| Scale | Evaluate L2/rollup options | When traffic demands it |

Gas optimization is a "scale when needed" decision. Start on Polygon PoS (cheapest viable mainnet), migrate to L2 or dedicated chain only when transaction volume justifies the engineering effort. Premature optimization is avoided.

## SOUL Circulation — Complete Flow

```
[Mint] Monster spawn → Monster wallet
[Mint] Quest reward → Agent wallet
[Mint] Zone init → NPC wallets (starting capital)

Agent ←── buys goods ──→ Shop NPC
  │                         │
  │                    buys from crafters
  │                         │
  │                    Smithy ←── buys ore ──→ Miner
  │                    Alchemist ←── buys herbs ──→ Herbalist
  │                    Tavern ←── buys food ──→ Farmer
  │
  ├── trades in Marketplace ←──→ Other Agents (SOUL/AFW/Items)
  │                                  │
  │                            2% fee burned (deflation)
  │
  └── fights monster
        ├── Agent wins → takes monster's SOUL
        └── Monster wins → loots agent's SOUL
```

### When is $SOUL Minted?

- **Monster spawning** — initial SOUL based on level/type
- **Quest completion** — EconomyEngine mints reward SOUL
- **New zone initialization** — NPC wallets receive starting capital
- **New agent creation** — small starting amount (50 SOUL)

### When is $SOUL Burned?

- **Marketplace transaction fees** — 2% burned on every trade
- **Agent revival** — portion burned, portion goes to tavern NPC
- **Zone taxes** — small periodic burn to prevent infinite accumulation
- **Item destruction** — breaking down items removes SOUL from circulation

## Economic Evolution Roadmap

### Phase 1 — Controlled Economy (MVP)
Base and material prices fixed. Simple NPC buy/sell. Establish baseline.

### Phase 2 — Mixed Economy (Growth)
Base services stay fixed (stability anchor). Material prices become dynamic (supply/demand). NPC AI-driven purchasing.

### Phase 3 — Autonomous Economy (Mature)
All prices determined by agents. Full AI autonomous economic actors. Self-regulating economy. No central price control.

## Distribution ($AFW)

| Allocation | Amount | Purpose |
|-----------|--------|--------|
| Node Mining | 400,000,000 (40%) | Rewards for compute providers |
| Community Grants | 250,000,000 (25%) | Developer rewards, bounties, hackathons |
| Team / Foundation | 150,000,000 (15%) | Core team vesting |
| Ecosystem / Partners | 100,000,000 (10%) | Strategic partnerships |
| Initial Liquidity | 50,000,000 (5%) | DEX liquidity pools |
| Advisors | 50,000,000 (5%) | Advisor vesting |

## Brain Interface & Token Economics

| Provider Choice | Cost to User | How User Benefits |
|----------------|-------------|-------------------|
| Community Nodes | Free | Agent runs on open-source LLM, earns $SOUL through gameplay |
| Claude Code / OAuth API | User pays subscription/API | Smarter agent → better decisions → more $SOUL earned |
| Self-Hosted | User pays hardware | Full control, same $SOUL earning potential |

## Creator Royalties

5% royalty on $SOUL generated by their content. From existing reward, not additional minting.

---

*"$AFW is the foundation. $SOUL is the heartbeat."*
