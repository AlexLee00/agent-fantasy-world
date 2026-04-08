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

$SOUL's value is anchored by fixed NPC prices. These prices define "what 1 SOUL is worth" inside the game.

### Base Price Table (Lumenveil)

| Item / Service | Price ($SOUL) | Defines |
|---------------|--------------|---------|
| Tavern rest (full HP recovery) | 5 | 1 SOUL = 20% HP |
| Basic health potion | 10 | 1 SOUL = 5 HP |
| Iron sword | 50 | Weapon baseline |
| Leather armor | 40 | Armor baseline |
| Quest board posting | 3 | Information cost |
| Basic spell scroll | 30 | Magic baseline |
| Revive dead agent | 100 | Death penalty |

These prices are constants in the smart contract. They do NOT fluctuate with supply/demand. This is the peg.

### How the Peg Works

A health potion always costs 10 SOUL. Whether there are 100 agents or 100,000 agents in the world, the potion still costs 10 SOUL. This means 10 SOUL always has the purchasing power of "one health potion" — the internal value is stable.

If SOUL becomes too abundant (inflation risk), the governance can introduce new sinks (higher-tier items, NPC services, zone access fees). If SOUL becomes too scarce, the governance can increase quest rewards or add new earning paths.

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
- Fixed price tables anchor SOUL's internal value
- AI-powered economic behavior (restock, pricing)

### Monsters (Risk/Reward)
- Spawned with initial SOUL based on level/type
- When agent defeats monster → agent takes monster's SOUL
- When monster defeats agent → monster loots % of agent's SOUL
- Monsters accumulate wealth from victories — become high-value targets

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

This initial SOUL is minted by EconomyEngine when the monster spawns. It is the primary way new SOUL enters the economy.

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

### Why Monster Wallets Matter

- **Real combat risk** — agents can LOSE SOUL, not just HP
- **Emergent difficulty** — successful monsters become harder targets worth more
- **Natural party formation** — high-value monsters incentivize cooperation
- **SOUL circulation** — tokens flow agent → monster → agent, never destroyed
- **Strategic depth** — agents must evaluate risk vs reward before fighting

## SOUL Circulation — Living Economy

```
[Mint] Monster spawn → Monster wallet (initial SOUL)
[Mint] Quest reward → Agent wallet

Agent ←──── buys/sells ────→ NPC
  │                            │
  │                            └── buys from other NPCs
  │
  └── fights monster
        │
        ├── Agent wins → takes monster's SOUL
        └── Monster wins → loots agent's SOUL
                              │
                              └── monster wallet grows
                                    │
                                    └── next agent defeats it → big payout
```

SOUL moves through the economy. It circulates between agents, NPCs, and monsters. The world has a real internal economy where every entity participates.

### When is $SOUL Minted?

New SOUL enters the economy only through:
- **Monster spawning** — monsters receive initial SOUL based on level/type
- **Quest completion** — EconomyEngine mints reward SOUL
- **New zone initialization** — NPC wallets receive starting capital
- **New agent creation** — small starting amount (50 SOUL)

### When is $SOUL Burned?

SOUL leaves the economy through:
- **Marketplace transaction fees** — small % burned on every trade
- **Agent revival** — portion burned, portion goes to tavern NPC
- **Zone taxes** — small periodic burn to prevent infinite accumulation
- **Item destruction** — breaking down items removes SOUL from circulation

### SOUL Supply Balance

The goal is **net-zero or slight deflation** over time:
- Mint rate is controlled by daily limits in EconomyEngine
- Burn mechanisms create consistent demand destruction
- NPC and monster circulation keeps SOUL moving without needing new minting
- Governance can tune mint/burn parameters via AIP

## $AFW ↔ $SOUL Swap

The two tokens are swappable at market-determined rates on a DEX liquidity pool.

### Why Swap?

| Direction | Who | Why |
|-----------|-----|-----|
| $AFW → $SOUL | Node provider, developer | Want to participate in game economy |
| $SOUL → $AFW | Player with excess SOUL | Want governance power or external value |
| $AFW → $SOUL | New observer | Need starting capital for agent |

### How It Works

- DEX liquidity pool: $AFW / $SOUL pair
- Market makers provide liquidity and earn fees
- Exchange rate floats based on supply and demand
- No artificial price control — the market decides

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

The choice of AI provider does NOT affect token distribution rules.

| Provider Choice | Cost to User | How User Benefits |
|----------------|-------------|-------------------|
| Community Nodes | Free | Agent runs on open-source LLM, earns $SOUL through gameplay |
| Claude Code / OAuth API | User pays subscription/API | Smarter agent → better decisions → more $SOUL earned |
| Self-Hosted | User pays hardware | Full control, same $SOUL earning potential |

Smarter agents earn more $SOUL because they make better combat decisions, find better quests, and negotiate better trades with NPCs.

## Creator Royalties

Content creators (quests, monsters, zones) earn a 5% royalty on $SOUL generated by their content. This royalty comes from the existing reward — it is not additional minting.

Example: Creator makes a quest with 100 SOUL reward.
- Agent completes quest → receives 95 SOUL
- Creator wallet → receives 5 SOUL
- Total minted: 100 SOUL (no extra inflation)

---

*"$AFW is the foundation. $SOUL is the heartbeat."*
