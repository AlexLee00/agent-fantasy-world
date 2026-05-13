# Phase 2 Validation

Phase 2 starts the mixed economy layer: automated AFW reward calculation,
multisig-reviewable proposals, and Tier 4 node-provider readiness.

## Implemented First Slice

- Contribution Agent generates reward proposals instead of directly paying rewards by default.
- Reward proposals are persisted for multisig review.
- Invalid recipients such as GitHub-only identities are separated into `unresolvedRecipients`.
- Settlement Hub submission is gated by `CONTRIBUTION_AUTO_SUBMIT=false` by default.
- Dashboard exposes the latest Contribution Agent proposal summary.
- Distribution deployment has a status checker for deployed addresses and `DISTRIBUTOR_ROLE` readiness.
- Distribution deployment grants `DISTRIBUTOR_ROLE` to the configured `DISTRIBUTION_EXECUTOR_ADDRESS` or multisig admin.
- Distribution suite is deployed on Base Sepolia and implementation contracts are verified on BaseScan.

## Distribution Deployment

- TeamVestingWallet proxy: `0xD695cAa4019CbB31D09A2bBDa77610AB7c46Ce1d`
- AdvisorVestingWallet proxy: `0x26fc7b7C4Bbca8460210A2A60abf6Eb9334ffBc8`
- NodeRewardPool proxy: `0x245d6B2c28bc5bE937044BA63f4B6a4173AF5deb`
- BountyPool proxy: `0xDB14E947d94fc78496474DACB147c328d3cFbE43`
- EcosystemTreasury proxy: `0xE1C284837Ae11229B3FFe35e7ECEB9e398467d46`
- AFWDistributor proxy: `0x3C22765d87b8E053f1d755842d522Cc7D007DeDe`

Implementation contracts are verified on BaseScan:

- TeamVestingWallet implementation: `0xb6475435bAF2CfD798e36baA7226D3F0aF3dCbb6`
- AdvisorVestingWallet implementation: `0x2dAEec73DB9cbeADa4eF94cB807F418B6b2B9895`
- NodeRewardPool implementation: `0x32BB22b8EEdc7B9dB00d6d18243a3D75de65FF2f`
- BountyPool implementation: `0x3D4119c6Ad9f71F652c162815c74C484752f7983`
- EcosystemTreasury implementation: `0xC5aFFD23841F47C466d11eEcabA79cCd2712516E`
- AFWDistributor implementation: `0x894c69fda7D0DDB6743d1D92496E79e7aaa3681B`

Readiness check:

- Status: passed
- Missing contracts: 0
- NodeRewardPool executor `DISTRIBUTOR_ROLE`: true
- NodeRewardPool AFWDistributor `DISTRIBUTOR_ROLE`: true
- BountyPool executor `DISTRIBUTOR_ROLE`: true
- BountyPool AFWDistributor `DISTRIBUTOR_ROLE`: true


## Distribution Execution

- Status: executed
- Fund AFWDistributor tx: `0xd65316af59243a810f4bfa00dfb1233b09d965907adb8ba12eedef9d317eb5de`
- Execute distribution tx: `0xfea29eb2fe37f395309ac7e731bc756afdddc4da0a4b1972759795f362e93be5`
- Team and marketplace liquidity wallet balance: `65,000,000 AFW`
- TeamVestingWallet balance: `135,000,000 AFW`
- AdvisorVestingWallet balance: `50,000,000 AFW`
- NodeRewardPool balance: `400,000,000 AFW`
- BountyPool balance: `250,000,000 AFW`
- EcosystemTreasury balance: `100,000,000 AFW`

## Tier 4 Node Smoke

- Status: passed
- Registered operator: `0x986d2be27bf2629e92a14fe7e95913369f26badc`
- Test endpoint: `http://127.0.0.1:18791/infer`
- Verified response action: `EXPLORE`
- Operator runbook: `docs/architecture/TIER4_NODE_OPERATOR.md`

## Public Tier 4 Endpoint Closure

- Status: passed
- Durable public endpoint: `https://alex-macstudio.tail319c21.ts.net/infer`
- Hosting mode: macOS `launchd` service plus Tailscale Funnel
- Testnet operator: `0x6cc7180C260b6f4923467C823d6fE3A057B5a314`
- Operator funding tx: `0x1c1c890a8e5c5839d8f52235ec93c97dd733da44eea4909e89723bf874caceb5`
- NodeRegistry registration tx: `0xde52e4c5e48d7e1c2970aba51252983c244e37d3362468dce4060a5c46e68189`
- Verified endpoint checks: `GET /health`, `POST /infer`

This closes the Phase 2 Base Sepolia readiness blocker with a testnet operator
wallet and a durable externally reachable endpoint.

## First Reward Distribution

- Status: passed
- Epoch: `1778586993`
- NodeRewardPool tx: `0x1949c3be6c78cbe550a524fa58e4a9a4b3933b98322cf2bd02933d49966596d2`
- BountyPool tx: `0xe223b97968d1d900cc3e395c2019fc302dbcdcd0c71574f3414f0ca71d97c420`
- Node rewards distributed: `1,000 AFW`
- Bounty rewards distributed: `999.999999999999934464 AFW`
- Settlement confirmed events: `2`
- Settlement failed events: `0`

## Latest Dry Run

- Status: passed
- Checked at: 2026-05-13 12:10:17.447891Z
- Stored proposal count: 1
- Proposal status: ready_for_multisig_review
- Node recipients: 1
- Bounty recipients: 2
- Unresolved recipients: 0
- Internal artifact: docs/internal/phase2-runs/phase2_reward_dry_run_20260513T121006.039908Z.json

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_reward_dry_run.exs
```

Distribution readiness:

```bash
cd packages/contracts
NODE_ENV=development npm run hardhat -- run scripts/check-distribution.ts --network base-sepolia
```

Production readiness guard:

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_production_readiness.exs
```

Public Tier 4 node registration:

```bash
cd packages/agents_ex
TIER4_NODE_ENDPOINT=https://node.example.com/infer \
mix run --no-start scripts/run_phase2_register_tier4_node.exs
```

The registration script verifies `GET /health` and `POST /infer` before sending the
on-chain `NodeRegistry.registerNode` transaction. The production readiness guard now
performs the same live endpoint verification by default.

Tier 4 provider check:

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_tier4_provider_check.exs
```

The provider check reads on-chain nodes, prioritizes the configured durable
endpoint, skips failed stale endpoints, and returns a Brain Interface action.

Contribution rewards verify Tier 4 node endpoints before scoring by default.
Set `CONTRIBUTION_VERIFY_NODE_ENDPOINTS=false` only for offline dry runs.

Current production readiness status:

- Status: passed on Base Sepolia testnet
- Artifact: `docs/internal/phase2-runs/phase2_production_readiness_20260513T120759.188457Z.json`
- Contributor payout map: configured for the testnet operator wallet
- Tier 4 endpoint: externally reachable and verified
- Active NodeRegistry set: 1 active node, `https://alex-macstudio.tail319c21.ts.net/infer`

## NodeRegistry Maintenance

- NodeRegistry was upgraded on Base Sepolia to support endpoint updates, self-deactivation, slasher deactivation, and active node pruning.
- New implementation: `0xCbbED537faD3a67B883cD7e475889b5cC6065bA2`
- Verified source: `https://sepolia.basescan.org/address/0xCbbED537faD3a67B883cD7e475889b5cC6065bA2#code`
- Stale endpoints removed from the active set:
  - `http://127.0.0.1:18791/infer`
  - `https://calm-clowns-peel.loca.lt/infer`
- Temporary deployer `SLASHER_ROLE` was revoked after cleanup.

## Phase 2 Close Notes

- Phase 2 is closed for Base Sepolia validation.
- The public endpoint now uses Tailscale Funnel with a persistent MagicDNS hostname.
- Mainnet production must still replace the testnet operator wallet with contributor-owned payout addresses.
