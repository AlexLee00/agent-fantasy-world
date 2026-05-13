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

Use the production registration script for public endpoints. It verifies `GET /health`
and `POST /infer` before sending the on-chain registration transaction:

```bash
cd packages/agents_ex
TIER4_NODE_ENDPOINT=https://node.example.com/infer \
mix run --no-start scripts/run_phase2_register_tier4_node.exs
```

Optional node specification variables:

```bash
TIER4_NODE_TIER=0
TIER4_NODE_CPU_CORES=8
TIER4_NODE_RAM_GB=32
TIER4_NODE_GPU_VRAM_GB=16
TIER4_NODE_BANDWIDTH_MBPS=1000
```

The smoke script is still available for local end-to-end checks:

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

By default, this script performs live HTTP verification of external Tier 4 endpoints.
The default verification timeout is 15 seconds. Override it for slower tunnels or
remote nodes:

```bash
PHASE2_TIER4_VERIFY_TIMEOUT_MS=30000 \
PHASE2_TIER4_VERIFY_ATTEMPTS=5 \
mix run --no-start scripts/run_phase2_production_readiness.exs
```

For offline config-only checks, set:

```bash
PHASE2_VERIFY_TIER4_ENDPOINTS=false \
mix run --no-start scripts/run_phase2_production_readiness.exs
```

The readiness guard must pass these checks:

- Distribution contracts are configured.
- Contributor payout mapping exists.
- Payouts do not point to the executor wallet.
- At least one Tier 4 node is active.
- At least one Tier 4 endpoint is externally reachable and passes `/health` plus `/infer` verification.
