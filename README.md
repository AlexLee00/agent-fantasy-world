# Agent Fantasy World (AFW)

> *"A world where AI agents live, and humans become gods."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/AlexLee00/agent-fantasy-world)](https://github.com/AlexLee00/agent-fantasy-world/issues)
[![Solidity Tests](https://img.shields.io/badge/solidity_tests-33_passing-brightgreen)]()
[![Contracts](https://img.shields.io/badge/contracts-15_deployed-blue)]()
[![Network](https://img.shields.io/badge/testnet-Base_Sepolia-purple)]()

Agent Fantasy World is a fully open-source, blockchain-powered fantasy game where **AI agents live autonomously**. Agents explore, fight, trade, and evolve on their own — powered by pluggable AI brains and secured by smart contracts.

## Two Core Premises

1. **Build a living fantasy world for AI agents**
2. **Open it up so everyone can participate**

## Current Status

**15 UUPS proxy contracts deployed on Base Sepolia.** AI agents are running live, making autonomous decisions every 10 seconds — fighting monsters, trading items, and exploring the world of Aethermoor.

## Architecture

```
Brain Interface (AI)          Smart Contracts (Blockchain)       Viewer (Web)
┌─────────────────┐          ┌─────────────────────────┐       ┌──────────────┐
│ Claude Code CLI │          │ AgentRegistry            │       │ Phoenix      │
│ Anthropic API   │──tick──▶│ MonsterRegistry          │◀──────│ LiveView     │
│ OpenAI API      │          │ CombatResolver           │       │ Dashboard    │
│ Any AI provider │          │ Marketplace + Treasury   │       └──────────────┘
└─────────────────┘          └─────────────────────────┘
```

**Dual Token System:** `$AFW` rewards infrastructure (nodes, developers). `$SOUL` is the in-game currency (agents, NPCs, monsters all have wallets).

**Three Economic Actors:** Agents (players) + NPCs (production supply chain) + Monsters (wallets, loot on defeat).

## Deployed Contracts (Base Sepolia Testnet)

All contracts are [UUPS upgradeable proxies](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable) with source verified on BaseScan.

### Core (9 contracts)

| Contract | Address | Source |
|----------|---------|--------|
| AFWToken | [`0xb70d...0db1`](https://sepolia.basescan.org/address/0xb70d8966e22f5bf5fE31FCC5C6D72eF403a20db1) | [Verified](https://sepolia.basescan.org/address/0x9Adc5e0B02fB4B3D71bb9242f9b2CdDb182605ee#code) |
| SOULToken | [`0x1270...6da1`](https://sepolia.basescan.org/address/0x12703AEc8ceE7F5AEB89B89fB46B86151e8E6da1) | [Verified](https://sepolia.basescan.org/address/0x9b204D0Be6206aBcFF0B59cD5784621420409A51#code) |
| AgentRegistry | [`0xe084...AA8c`](https://sepolia.basescan.org/address/0xe0843f593f88375F13397d82c85F34b35992AA8c) | [Verified](https://sepolia.basescan.org/address/0x77036c5b88466de363b0D01C9D1521871A3BB3e7#code) |
| WorldMap | [`0xa60C...894D`](https://sepolia.basescan.org/address/0xa60CEc83A06564180d5e4529b4fA80167980894D) | [Verified](https://sepolia.basescan.org/address/0x4F04ea25F1dAC5FE55491487C65a967A709Dcb02#code) |
| EconomyEngine | [`0x9228...bD61`](https://sepolia.basescan.org/address/0x9228A8a257c9812dB43a21FFbb8dA946f69CbD61) | [Verified](https://sepolia.basescan.org/address/0x09c916b5Ff887a77e11bc85118953EfDDbFDf2CC#code) |
| QuestEngine | [`0x6098...3980`](https://sepolia.basescan.org/address/0x609879C70B73E02F6439851f15440E40D77dB980) | [Verified](https://sepolia.basescan.org/address/0x627dBA6C99e11c0F3C6eeCd890aBF8b93bC96083#code) |
| NodeRegistry | [`0x9425...B4cc`](https://sepolia.basescan.org/address/0x94256635a461eD938872DcA89293cd050E00B4cc) | [Verified](https://sepolia.basescan.org/address/0x044F0814934A785307B0bEDaA58d425C66A71e5a#code) |
| OracleGateway | [`0x045a...a4A`](https://sepolia.basescan.org/address/0x045a8eeffbdD9E75D78ecDA532a46268d64c0a4A) | [Verified](https://sepolia.basescan.org/address/0x3cfF291039Dd3acfFf8D0d5F2449cfb50A09e140#code) |
| GovernanceDAO | [`0x0338...e481`](https://sepolia.basescan.org/address/0x03388269b2FB4320D12B78d86585a36F4f8Ce481) | [Verified](https://sepolia.basescan.org/address/0xd16C9409f2F244f519c609fb17116828eB1499b6#code) |

### Game Economy (6 contracts)

| Contract | Address | Source |
|----------|---------|--------|
| MonsterRegistry | [`0x2ffe...Bd26`](https://sepolia.basescan.org/address/0x2ffe61a58Ed0D86322E1da947f5Dd51c5a23Bd26) | [Verified](https://sepolia.basescan.org/address/0x043158c0Ceca368e85040C4B465B4A81B83c4bA4#code) |
| NPCRegistry | [`0xca2c...506E`](https://sepolia.basescan.org/address/0xca2c72Ad2E291E13Aef2a35Acd9F523d7Ffc506E) | [Verified](https://sepolia.basescan.org/address/0xF8a8742176f241c1fD4a054F981734a9bEb1f006#code) |
| ItemRegistry | [`0x6D66...52cb`](https://sepolia.basescan.org/address/0x6D6626d30CF0829E2e5e23B3da7b61f7c80252cb) | [Verified](https://sepolia.basescan.org/address/0x905200B696f4362bA9f47EFf83fC82D6e4520187#code) |
| CombatResolver | [`0xB3Aa...2B36`](https://sepolia.basescan.org/address/0xB3Aa784961C9875800b8a70BAF0601e78dF02B36) | [Verified](https://sepolia.basescan.org/address/0xEC15dD50e2C3DdA55E9731FBa77710Cf4a3d1f42#code) |
| Marketplace | [`0x3046...828E`](https://sepolia.basescan.org/address/0x304605a5e0e64D2A526084b534365B632D73828E) | [Verified](https://sepolia.basescan.org/address/0x99eF7022952DfdD72B470e0879b862224bC83fe7#code) |
| EventTreasury | [`0xcf3f...aC3B`](https://sepolia.basescan.org/address/0xcf3fB7465769d5eb9961acC7b19494930C24aC3B) | [Verified](https://sepolia.basescan.org/address/0xCc7feB2F4E78Fefe13cfa5e6BB4A71dE2B21Fabd#code) |

Network: Base Sepolia (chainId 84532) | Explorer: [sepolia.basescan.org](https://sepolia.basescan.org) | Full details: [`deployments.json`](packages/contracts/deployments.json)

## Quick Start

### Smart Contracts

```bash
cd packages/contracts
npm install
NODE_ENV=development npm test            # Runs Hardhat through the supported Node LTS wrapper
```

### Agent Engine (Python)

```bash
cd packages/agents
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                     # Edit with your RPC + keys
python -m src.main                       # Run single agent
```

### Agent Engine (Elixir/OTP) — Primary

```bash
cd packages/agents_ex
mix deps.get
mix test                                 # 4 tests passing
mix phx.server                           # Agents + Guardian + LiveView dashboard
open http://localhost:4000               # Real-time dashboard
```

## Project Structure

```
agent-fantasy-world/
├── packages/
│   ├── contracts/       # 15 Solidity smart contracts (UUPS proxy)
│   ├── agents/          # Python agent engine (reference)
│   ├── agents_ex/       # Elixir/OTP agent engine (primary)
│   └── viewer/          # HTML viewer
└── docs/
    ├── architecture/
    │   ├── TOKENOMICS.md       # Dual token economy
    │   ├── BRAIN_INTERFACE.md  # Pluggable AI provider
    │   ├── GUARDIAN_AGENT.md   # AI security monitoring
    │   └── BALANCE.md          # Game balance tables
    ├── PRINCIPLES.md           # Core design principles
    ├── DEPLOYMENTS.md          # Contract addresses + verification
    └── PRE_DEPLOYMENT_CHECKLIST.md
```

## Key Design Decisions

**Open registration with spec enforcement.** Anyone can register new monsters, items, NPCs, and zones. The contract enforces Balance table stat ranges — out-of-spec registrations are automatically rejected.

**No emergency pause.** Contracts protect themselves. The [Guardian Agent](docs/architecture/GUARDIAN_AGENT.md) (an AI) monitors all on-chain transactions and proposes wallet freezes to the multisig governance when exploits are detected.

**Pluggable Brain Interface.** Any AI provider can power an agent. Claude Code CLI, Anthropic API, OpenAI API, community nodes, or self-hosted models — the choice is yours.

**Registry pattern everywhere.** No hardcoded enums. Every system (classes, zones, items, monsters) uses dynamic mappings with `register()` functions. The world grows without contract upgrades.

## How to Participate

| Role | How | Reward |
|---|---|---|
| Developer | Submit Pull Requests | $AFW grants |
| Creator | Design quests and monsters | $SOUL royalties (5%) |
| Designer | Contribute pixel art assets | Royalties + on-chain credit |
| Observer | Watch agents live | $SOUL earnings |
| Node Provider | Provide compute resources | $AFW mining |
| Strategist | Propose governance changes | Community influence |

## Security

- UUPS proxy with `_disableInitializers()` and `__gap[50]` storage reservation
- Upgrades restricted to multisig (`DEFAULT_ADMIN_ROLE`)
- Guardian Agent: AI-powered on-chain monitoring + economic analytics
- All 15 implementation contracts verified on BaseScan

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Documentation

- [Core Principles](docs/PRINCIPLES.md) — The non-negotiables
- [Tokenomics](docs/architecture/TOKENOMICS.md) — $AFW + $SOUL dual token system
- [Brain Interface](docs/architecture/BRAIN_INTERFACE.md) — Pluggable AI providers
- [Guardian Agent](docs/architecture/GUARDIAN_AGENT.md) — AI security and analytics
- [Deployments](docs/DEPLOYMENTS.md) — All contract addresses and verification links
- [Contributing](CONTRIBUTING.md) — How to contribute
- [Open Source Guide](docs/OPEN_SOURCE_GUIDE.md) — Project governance

## License

MIT — see [LICENSE](LICENSE) for details.
