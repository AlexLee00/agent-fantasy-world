# Tier 4 Node Operator Runbook

Tier 4 nodes provide community inference capacity for AFW agents and earn AFW rewards through `NodeRewardPool`.

## What A Node Must Expose

Each node exposes two HTTP endpoints:

- `GET /health` returns node status.
- `POST /infer` accepts `{ "prompt": "...", "event": {...} }` and returns `{ "action": {...} }`.

The action object must follow the Brain Interface format:

```json
{
  "action": "EXPLORE",
  "confidence": 0.91,
  "reasoning": "The area is safe enough to scout.",
  "dialogue": "I will scout the next path.",
  "emotion": "focused"
}
```

## Run A Node Locally

```bash
cd packages/agents_ex
TIER4_NODE_BACKEND=afw-basic TIER4_NODE_PORT=18791 mix run --no-start scripts/run_tier4_node.exs
```

Health check:

```bash
curl http://127.0.0.1:18791/health
```

Inference check:

```bash
curl -X POST http://127.0.0.1:18791/infer \
  -H 'content-type: application/json' \
  -d '{"prompt":"Choose one safe AFW action.","event":{"target":"lumenveil"}}'
```

## Run A Public Node

Set `TIER4_NODE_PUBLIC_URL` to the public base URL that external AFW clients can reach.

```bash
cd packages/agents_ex
TIER4_NODE_BACKEND=afw-basic \
TIER4_NODE_PORT=18791 \
TIER4_NODE_PUBLIC_URL=https://node.example.com \
mix run --no-start scripts/run_tier4_node.exs
```

The registered endpoint should be:

```text
https://node.example.com/infer
```

## Backend Selection

Supported `TIER4_NODE_BACKEND` values:

- `afw-basic`
- `claude-code`
- `openai`
- `anthropic`
- `openclaw`

`node` is intentionally not allowed as a backend because it would recursively call Tier 4 nodes.

## Register On Base Sepolia

The current smoke script registers the operator wallet if it is not already registered:

```bash
cd packages/agents_ex
TIER4_NODE_ENDPOINT=https://node.example.com/infer \
mix run --no-start scripts/run_phase2_tier4_node_smoke.exs
```

Important: the current `NodeRegistry` contract does not expose an endpoint update function. If a wallet was already registered with a local URL, use a fresh operator wallet for the public node or add an upgrade/migration in a later phase.

## Contributor Payout Map

Contribution rewards require identity-to-wallet mapping before auto-submit is enabled.

Example file:

```bash
packages/agents_ex/config/contribution_recipients.example.json
```

Use it with:

```bash
CONTRIBUTION_RECIPIENT_MAP_PATH=packages/agents_ex/config/contribution_recipients.json \
mix run --no-start scripts/run_phase2_production_readiness.exs
```

Do not map production rewards to the deployer/executor wallet unless that wallet is the actual contributor-owned payout wallet.

## Production Readiness

Run:

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase2_production_readiness.exs
```

The readiness guard must pass these checks:

- Distribution contracts are configured.
- Contributor payout mapping exists.
- Payouts do not point to the executor wallet.
- At least one Tier 4 node is active.
- At least one Tier 4 endpoint is externally reachable.
