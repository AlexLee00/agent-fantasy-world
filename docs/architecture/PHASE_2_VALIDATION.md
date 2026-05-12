# Phase 2 Validation

Phase 2 starts the mixed economy layer: automated AFW reward calculation,
multisig-reviewable proposals, and Tier 4 node-provider readiness.

## Implemented First Slice

- Contribution Agent generates reward proposals instead of directly paying rewards by default.
- Reward proposals are persisted for multisig review.
- Invalid recipients such as GitHub-only identities are separated into `unresolvedRecipients`.
- Settlement Hub submission is gated by `CONTRIBUTION_AUTO_SUBMIT=false` by default.
- Dashboard exposes the latest Contribution Agent proposal summary.
- Distribution deployment now has a status checker for deployed addresses and `DISTRIBUTOR_ROLE` readiness.
- Distribution deployment grants `DISTRIBUTOR_ROLE` to the configured `DISTRIBUTION_EXECUTOR_ADDRESS` or multisig admin.

## Latest Dry Run

- Status: passed
- Checked at: 2026-05-12 06:23:34.617147Z
- Stored proposal count: 1
- Proposal status: needs_recipient_mapping
- Node recipients: 0
- Bounty recipients: 1
- Unresolved recipients: 1
- Internal artifact: docs/internal/phase2-runs/phase2_reward_dry_run_20260512T062323.740283Z.json

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_reward_dry_run.exs
```

Distribution readiness:

```bash
cd packages/contracts
ALLOW_MISSING_DISTRIBUTION=true NODE_ENV=development npx hardhat run scripts/check-distribution.ts --network base-sepolia
```

## Remaining Phase 2 Work

- Deploy or verify distribution pool addresses on Base Sepolia in `deployments.json`.
- Run `scripts/check-distribution.ts` without `ALLOW_MISSING_DISTRIBUTION=true` after deployment.
- Map GitHub contributors to payout addresses before enabling auto-submit.
- Register at least one real Tier 4 node endpoint and verify paid inference.
- Run the first multisig-approved reward distribution on testnet.
