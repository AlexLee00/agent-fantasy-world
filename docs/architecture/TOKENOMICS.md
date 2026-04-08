# AFW Token Economics

> "$AFW rewards those who build the world. $SOUL is the lifeblood of those who live in it."

## Two-Token System

AFW operates on a dual-token model with distinct roles.

### $AFW — Infrastructure Token (External Value)

| Property | Value |
|----------|-------|
| Purpose | Reward infrastructure contributors |
| Supply | 1,000,000,000 (fixed, no inflation) |
| Value | Market-determined (traded on DEX) |
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
- Can swap SOUL ↔ AFW on DEX

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

### Supply Chain Flow

```
Raw Materials (gathered by production NPCs)
    │
    ├── Miner → iron ore ──────→ Smithy → sword ──→ Shop → Agent
    ├── Lumberjack → lumber ───→ Smithy → shield ─→ Shop → Agent
    ├── Herbalist → herbs ─────→ Alchemist → potion → Shop → Agent
    ├── Farmer → food ─────────→ Tavern → rest ────→ Agent
    └── Hunter → hides ────────→ Tanner → armor ──→ Shop → Agent
```

Every arrow is a SOUL transaction. Every NPC manages its own wallet, inventory, and economic decisions.

### Material Pricing — Supply and Demand

Raw material prices are determined by supply and demand, not fixed tables:

- If agents buy many swords → Smithy orders more ore → Miner raises ore price
- If no one buys swords → Smithy stops ordering → Miner lowers price or stockpiles
- If Miner NPC "dies" (run out of SOUL) → ore becomes scarce → sword price rises
- If new Miner NPCs spawn → ore supply increases → prices normalize

This creates organic economic cycles driven entirely by in-game activity.

## Economic Evolution Roadmap

The economy evolves from controlled to fully autonomous, mirroring how real economies mature.

### Phase 1 — Controlled Economy (MVP / Early)

```
Base service prices: FIXED (tavern=5, potion=10, revive=100)
Material prices: FIXED (ore=5, herbs=3, lumber=4)
NPC behavior: Simple buy/sell at set prices
Purpose: Establish baseline, ensure playability, test systems
```

Prices are set by smart contract constants. This prevents economic chaos while the player base is small and the system is being tested.

### Phase 2 — Mixed Economy (Growth)

```
Base service prices: FIXED (still anchored for stability)
Material prices: DYNAMIC (supply/demand between NPCs)
NPC behavior: AI-driven purchasing, inventory management
Purpose: Introduce market dynamics, test autonomous pricing
```

Production NPCs start making autonomous economic decisions. The Smithy decides how much ore to buy based on sword demand. The Herbalist adjusts herb prices based on how many Alchemists are ordering. Base services (rest, revive) stay fixed as stability anchors.

### Phase 3 — Autonomous Economy (Mature)

```
ALL prices: DETERMINED BY AGENTS (supply/demand)
NPC behavior: Full AI autonomous economic actors
Market: Self-regulating through agent competition
Purpose: True living economy — no central price control
```

When the game is stable, user base is stable, and participants are stable — all prices are determined by the autonomous economic decisions of agents (both player agents and NPCs). The smart contracts only enforce the rules of transactions, not the prices. The economy runs itself.

**This is the ultimate goal: a world where AI agents create, sustain, and evolve their own economy — just like the real world.**

## Monster Wallet Economy

### Spawn Capital

Monsters are created with an initial SOUL balance based on their level and type:

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
- Monster dies, wallet is emptied
- If monster had accumulated extra SOUL from previous victories, agent gets all of it

**Monster wins:**
- Monster loots a percentage of the agent's SOUL (30% by default)
- Agent keeps the rest but is badly wounded or dead
- Monster's wallet grows — it becomes a richer target
- Agent must revive (costs 100 SOUL to NPC) if HP reaches 0

**Example — Emergent Boss:**
```
Goblin spawns with 15 SOUL
  → defeats Agent A, loots 36 SOUL → wallet: 51
  → defeats Agent B, loots 40 SOUL → wallet: 91
  → defeats Agent C, loots 35 SOUL → wallet: 126

This goblin is now a "rich goblin" — a 126 SOUL bounty.
Agents form a party to hunt it. Whoever kills it splits 126 SOUL.
This content was not designed — it emerged from the economy.
```

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
  └── fights monster
        ├── Agent wins → takes monster's SOUL
        └── Monster wins → loots agent's SOUL
                              └── monster wallet grows → high-value target
```

### When is $SOUL Minted?

- **Monster spawning** — initial SOUL based on level/type
- **Quest completion** — EconomyEngine mints reward SOUL
- **New zone initialization** — NPC wallets receive starting capital
- **New agent creation** — small starting amount (50 SOUL)

### When is $SOUL Burned?

- **Marketplace transaction fees** — small % burned on every trade
- **Agent revival** — portion burned, portion goes to tavern NPC
- **Zone taxes** — small periodic burn to prevent infinite accumulation
- **Item destruction** — breaking down items removes SOUL from circulation

## $AFW ↔ $SOUL Swap

The two tokens are swappable at market-determined rates on a DEX liquidity pool.

| Direction | Who | Why |
|-----------|-----|-----|
| $AFW → $SOUL | Node provider, developer | Want to participate in game economy |
| $SOUL → $AFW | Player with excess SOUL | Want governance power or external value |
| $AFW → $SOUL | New observer | Need starting capital for agent |

DEX liquidity pool with floating exchange rate. No artificial price control — the market decides.

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
