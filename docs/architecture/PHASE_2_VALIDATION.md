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

## Latest Dry Run

- Status: passed
- Checked at: 2026-05-12 11:19:47.070817Z
- Stored proposal count: 1
- Proposal status: needs_recipient_mapping
- Node recipients: 0
- Bounty recipients: 1
- Unresolved recipients: 1
- Internal artifact: docs/internal/phase2-runs/phase2_reward_dry_run_20260512T111936.301188Z.json

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_reward_dry_run.exs
```

Distribution readiness:

```bash
cd packages/contracts
NODE_ENV=development npx hardhat run scripts/check-distribution.ts --network base-sepolia
```

## Remaining Phase 2 Work

- Map GitHub contributors to payout addresses before enabling auto-submit.
- Register at least one real Tier 4 node endpoint and verify paid inference.
- Run the first multisig-approved reward distribution on testnet.
