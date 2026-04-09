# AFW Contract Deployments

All contracts are deployed as UUPS proxies on Base Sepolia testnet.

## Network

| Property | Value |
|----------|-------|
| Network | Base Sepolia (testnet) |
| Chain ID | 84532 |
| RPC | https://sepolia.base.org |
| Explorer | https://sepolia.basescan.org |
| Deployer | `0x986d2BE27bF2629E92A14fe7E95913369f26BAdC` |
| Deploy date | 2026-04-09 |

## Core Contracts (Phase 1 — Issue #24)

| Contract | Proxy Address | Implementation | Verified |
|----------|--------------|----------------|----------|
| AFWToken | [`0xb70d8966e22f5bf5fE31FCC5C6D72eF403a20db1`](https://sepolia.basescan.org/address/0xb70d8966e22f5bf5fE31FCC5C6D72eF403a20db1) | [`0x9Adc...05ee`](https://sepolia.basescan.org/address/0x9Adc5e0B02fB4B3D71bb9242f9b2CdDb182605ee#code) | ✅ |
| SOULToken | [`0x12703AEc8ceE7F5AEB89B89fB46B86151e8E6da1`](https://sepolia.basescan.org/address/0x12703AEc8ceE7F5AEB89B89fB46B86151e8E6da1) | [`0x9b20...9A51`](https://sepolia.basescan.org/address/0x9b204D0Be6206aBcFF0B59cD5784621420409A51#code) | ✅ |
| AgentRegistry | [`0xe0843f593f88375F13397d82c85F34b35992AA8c`](https://sepolia.basescan.org/address/0xe0843f593f88375F13397d82c85F34b35992AA8c) | [`0x7703...B3e7`](https://sepolia.basescan.org/address/0x77036c5b88466de363b0D01C9D1521871A3BB3e7#code) | ✅ |
| WorldMap | [`0xa60CEc83A06564180d5e4529b4fA80167980894D`](https://sepolia.basescan.org/address/0xa60CEc83A06564180d5e4529b4fA80167980894D) | [`0x4F04...Db02`](https://sepolia.basescan.org/address/0x4F04ea25F1dAC5FE55491487C65a967A709Dcb02#code) | ✅ |
| EconomyEngine | [`0x9228A8a257c9812dB43a21FFbb8dA946f69CbD61`](https://sepolia.basescan.org/address/0x9228A8a257c9812dB43a21FFbb8dA946f69CbD61) | [`0x09c9...f2CC`](https://sepolia.basescan.org/address/0x09c916b5Ff887a77e11bc85118953EfDDbFDf2CC#code) | ✅ |
| QuestEngine | [`0x609879C70B73E02F6439851f15440E40D77dB980`](https://sepolia.basescan.org/address/0x609879C70B73E02F6439851f15440E40D77dB980) | [`0x627d...6083`](https://sepolia.basescan.org/address/0x627dBA6C99e11c0F3C6eeCd890aBF8b93bC96083#code) | ✅ |
| NodeRegistry | [`0x94256635a461eD938872DcA89293cd050E00B4cc`](https://sepolia.basescan.org/address/0x94256635a461eD938872DcA89293cd050E00B4cc) | [`0x044F...1f42`](https://sepolia.basescan.org/address/0x044F0814934A785307B0bEDaA58d425C66A71e5a#code) | ✅ |
| OracleGateway | [`0x045a8eeffbdD9E75D78ecDA532a46268d64c0a4A`](https://sepolia.basescan.org/address/0x045a8eeffbdD9E75D78ecDA532a46268d64c0a4A) | [`0x3cfF...e140`](https://sepolia.basescan.org/address/0x3cfF291039Dd3acfFf8D0d5F2449cfb50A09e140#code) | ✅ |
| GovernanceDAO | [`0x03388269b2FB4320D12B78d86585a36F4f8Ce481`](https://sepolia.basescan.org/address/0x03388269b2FB4320D12B78d86585a36F4f8Ce481) | [`0xd16C...9b6`](https://sepolia.basescan.org/address/0xd16C9409f2F244f519c609fb17116828eB1499b6#code) | ✅ |

## Game Economy Contracts (Phase 3 — Issue #25)

| Contract | Proxy Address | Implementation | Verified |
|----------|--------------|----------------|----------|
| ItemRegistry | [`0x6D6626d30CF0829E2e5e23B3da7b61f7c80252cb`](https://sepolia.basescan.org/address/0x6D6626d30CF0829E2e5e23B3da7b61f7c80252cb) | [`0x9052...0187`](https://sepolia.basescan.org/address/0x905200B696f4362bA9f47EFf83fC82D6e4520187#code) | ✅ |
| MonsterRegistry | [`0x2ffe61a58Ed0D86322E1da947f5Dd51c5a23Bd26`](https://sepolia.basescan.org/address/0x2ffe61a58Ed0D86322E1da947f5Dd51c5a23Bd26) | [`0x0431...4bA4`](https://sepolia.basescan.org/address/0x043158c0Ceca368e85040C4B465B4A81B83c4bA4#code) | ✅ |
| NPCRegistry | [`0xca2c72Ad2E291E13Aef2a35Acd9F523d7Ffc506E`](https://sepolia.basescan.org/address/0xca2c72Ad2E291E13Aef2a35Acd9F523d7Ffc506E) | [`0xF8a8...f006`](https://sepolia.basescan.org/address/0xF8a8742176f241c1fD4a054F981734a9bEb1f006#code) | ✅ |
| EventTreasury | [`0xcf3fB7465769d5eb9961acC7b19494930C24aC3B`](https://sepolia.basescan.org/address/0xcf3fB7465769d5eb9961acC7b19494930C24aC3B) | [`0xCc7f...Fabd`](https://sepolia.basescan.org/address/0xCc7feB2F4E78Fefe13cfa5e6BB4A71dE2B21Fabd#code) | ✅ |
| CombatResolver | [`0xB3Aa784961C9875800b8a70BAF0601e78dF02B36`](https://sepolia.basescan.org/address/0xB3Aa784961C9875800b8a70BAF0601e78dF02B36) | [`0xEC15...1f42`](https://sepolia.basescan.org/address/0xEC15dD50e2C3DdA55E9731FBa77710Cf4a3d1f42#code) | ✅ |
| Marketplace | [`0x304605a5e0e64D2A526084b534365B632D73828E`](https://sepolia.basescan.org/address/0x304605a5e0e64D2A526084b534365B632D73828E) | [`0x99eF...fe7`](https://sepolia.basescan.org/address/0x99eF7022952DfdD72B470e0879b862224bC83fe7#code) | ✅ |

## Proxy Pattern

All contracts use OpenZeppelin UUPS (Universal Upgradeable Proxy Standard):
- Proxy holds state, delegates calls to implementation
- Implementation can be upgraded via `upgradeToAndCall()`
- Upgrade restricted to `DEFAULT_ADMIN_ROLE` (multisig)
- `_disableInitializers()` in constructor prevents initialization attacks
- `uint256[50] private __gap` reserves storage for future upgrades

## Security Model

- **No emergency pause** — contracts protect themselves
- **Open registration** — anyone can register content within Balance table spec
- **Out-of-spec registration** — transaction reverts (no wallet freeze)
- **Exploit detection** — Guardian Agent monitors on-chain, proposes wallet freeze to multisig
- **Wallet freeze** — only via GovernanceDAO multisig vote

## Initial Seed Data

### Agent Classes (AgentRegistry)
| ID | Name |
|----|------|
| 1 | WARRIOR |
| 2 | MAGE |
| 3 | RANGER |
| 4 | HEALER |
| 5 | TANK |

### Agent Statuses (AgentRegistry)
| ID | Name |
|----|------|
| 1 | ALIVE |
| 2 | DEAD |
| 3 | RESTING |
| 4 | IN_COMBAT |
| 5 | TRAVELING |

### Danger Levels (WorldMap)
| ID | Name |
|----|------|
| 1 | SAFE |
| 2 | MEDIUM |
| 3 | DANGER |
| 4 | EXTREME |

### Zones (WorldMap)
| ID | Name | Danger | Level Range |
|----|------|--------|-------------|
| 1 | Lumenveil | SAFE | 1-10 |
| 2 | Graymarch | MEDIUM | 11-25 |
| 3 | Embervault | DANGER | 26-50 |
| 4 | Voidreach | EXTREME | 51-99 |

## JSON Reference

Machine-readable addresses: [`packages/contracts/deployments.json`](../packages/contracts/deployments.json)

---

*Note: This is a testnet deployment. Mainnet chain will be determined later (Polygon PoS, Base, or Arbitrum). Testnet choice does not determine mainnet choice — contracts are chain-agnostic.*
