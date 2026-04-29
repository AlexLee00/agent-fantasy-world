# AFW Next Implementation Roadmap and Design

This document translates the current AFW direction into an implementation roadmap.
It is optimized for the next engineering sessions, not for public marketing.

## Product Thesis

AFW is not a normal player-controlled Web3 RPG.

AFW is a living fantasy world where:

- AI agents are the primary inhabitants.
- Humans create, observe, fund, govern, and shape the world.
- The game loop is instant and mostly off-chain.
- Asset ownership and economic settlement are verifiable on-chain.
- The world expands through registries, user-generated content, and AI-assisted contribution.

The next work should focus on turning the current economic simulation into a believable, observable, stable world.

## Current Baseline

The project already has a strong foundation:

- 15 UUPS proxy contracts deployed on Base Sepolia.
- Elixir/OTP is the primary runtime.
- Python agent engine remains as reference.
- Settlement Hub separates game logic from blockchain settlement.
- Guardian Agent and Contribution Agent exist as GenServers.
- Phoenix LiveView dashboard exists.
- Brain Interface supports multiple provider tiers.
- 50 to 100 tick simulations have run without agent crashes.

The main gap is not contract count or feature count.
The main gap is reliability, observability, memory, and game feel.

## Guiding Decisions

1. Keep Elixir/OTP as the primary runtime.
   OTP supervision, GenServers, PubSub, and ETS are a strong fit for many autonomous agents.

2. The Settlement Hub remains the only write path to blockchain.
   Agent Loop must never call Writer directly for asset-changing actions.

3. Only assets and durable economic facts go on-chain.
   HP, movement, dialogue, mood, daily plans, and short-term memories stay off-chain.

4. Build a 2D living world before 3D.
   A polished 2D map with movement, speech bubbles, memories, and replay will prove the core faster than a full 3D client.

5. Treat the LLM as planner and narrator, not final authority.
   Deterministic game systems should validate actions, resolve outcomes, and protect balance.

6. Prioritize per-agent identity.
   Shared deployer-wallet behavior is acceptable for early tests but invalidates long-term economy analytics.

7. Every milestone must produce measurable simulation output.
   Each phase should end with JSON metrics, console logs, dashboard visibility, and a clear pass/fail result.

## Roadmap Overview

### Milestone 0: Settlement Reliability Recovery

Goal: Make the existing 3-agent Base Sepolia loop produce trustworthy confirmed settlements.

Priority: Immediate.

Target duration: 2 to 4 days.

Deliverables:

- Combat revert diagnosis at receipt block.
- BaseScan tx hash logging for every reverted on-chain combat tx.
- Contract role and address preflight checker.
- Marketplace stale order blacklist and active order refresh.
- Per-event discard categories and metrics.
- 50+ tick validation output in `logs/simulation_combat_debug.json`.

Acceptance criteria:

- 50+ ticks complete with 0 crashes.
- Guardian epoch completes with 0 timeout errors.
- REST count is greater than 5 in a 50 tick run.
- Marketplace stale order discard count is below 5.
- Combat revert reasons are no longer reported only as `unknown_revert`.
- If combat confirmed count remains 0, the root cause is identified with tx hashes and decoded revert evidence.

Primary files:

- `packages/agents_ex/lib/afw/chain/writer.ex`
- `packages/agents_ex/lib/afw/settlement/settler.ex`
- `packages/agents_ex/lib/afw/agent/loop.ex`
- `packages/agents_ex/lib/afw/settlement/metrics.ex`
- `packages/agents_ex/scripts/run_54tick_validation.exs`

### Milestone 1: Settlement System Hardening

Goal: Make Settlement Hub durable enough to be the bridge between game state and chain state.

Target duration: 1 week.

Design:

- Add a persistent event log.
- Keep ETS for hot optimistic state.
- Persist event lifecycle transitions to disk.
- Make settlement idempotent.
- Split retryable errors from deterministic rejects.
- Add per-contract gas policy.
- Add role/address/ABI preflight before simulation starts.

Proposed modules:

- `AFW.Settlement.EventStore`
- `AFW.Settlement.Preflight`
- `AFW.Settlement.ErrorClassifier`
- `AFW.Settlement.ReceiptDiagnostics`

Event lifecycle:

```text
submitted
  -> optimistic_applied
  -> queued
  -> settling
  -> confirmed
  -> reconciled

submitted
  -> optimistic_applied
  -> queued
  -> settling
  -> retrying
  -> settling
  -> confirmed

submitted
  -> optimistic_applied
  -> queued
  -> precheck_rejected
  -> rolled_back

submitted
  -> optimistic_applied
  -> queued
  -> settling
  -> reverted
  -> rolled_back
```

Minimum event record:

```elixir
%{
  id: binary(),
  type: atom(),
  priority: atom(),
  agent_id: integer(),
  data: map(),
  status: atom(),
  tx_hash: binary() | nil,
  revert_reason: binary() | nil,
  retry_count: integer(),
  created_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

Acceptance criteria:

- Restarting `mix phx.server` does not lose pending settlement events.
- Retried events keep the same event id.
- Reconciliation can explain every optimistic delta.
- `mix test` covers confirm, retry, reject, rollback, and restart recovery.

### Milestone 2: Per-Agent Wallet and Identity

Goal: Fix economy analytics by giving each agent an actual independent economic identity.

Target duration: 1 week.

Problem:

Current logs show multiple agents sharing the deployer wallet. This makes Gini, agent wealth, marketplace behavior, and Guardian anomaly detection inaccurate.

Design:

- Introduce an embedded wallet abstraction at the agent runtime layer.
- For testnet, use generated local keys stored in encrypted or local dev storage.
- Map `agent_id` to wallet address.
- Create or migrate agents with unique observers.
- Fund each wallet with controlled starting SOUL.
- Keep deployer as admin and faucet, not as every agent's observer.

Proposed modules:

- `AFW.Wallet.AgentWallet`
- `AFW.Wallet.LocalKeyStore`
- `AFW.Wallet.Faucet`

Acceptance criteria:

- Agent 22, 23, and 24 no longer share the same observer wallet.
- Marketplace orders show different buyer and seller addresses.
- Gini coefficient becomes meaningful.
- Guardian no longer sees false reconciliation mismatches caused by shared wallet accounting.

### Milestone 3: Agent Memory and Social Layer

Goal: Make agents feel like beings with history, not stateless action choosers.

Target duration: 1 to 2 weeks.

Design inspiration:

- Generative Agents: memory stream, reflection, planning.
- Concordia: Game Master as world arbiter.
- Voyager: skill library and self-improvement from feedback.
- Sophia-style RPG NPCs: relationships, emotion, and long-term context.

Proposed modules:

- `AFW.Memory.Store`
- `AFW.Memory.Reflection`
- `AFW.Memory.Retriever`
- `AFW.Agent.Goals`
- `AFW.Agent.Skills`
- `AFW.World.Director`
- `AFW.Social.Relationships`

Memory types:

- Observation: what the agent saw or experienced.
- Action: what the agent did.
- Outcome: what happened after the action.
- Reflection: compressed insight from several events.
- Relationship: affinity, trust, rivalry, debt, fear.
- Skill: reusable strategy that worked.

Agent cognitive loop:

```text
read world snapshot
  -> retrieve relevant memories
  -> build context
  -> choose intent
  -> validate with World Director
  -> execute off-chain game logic
  -> submit asset deltas to Settlement Hub
  -> record observation and outcome
  -> periodically reflect and update goals
```

Acceptance criteria:

- PromptBuilder includes relevant memory summaries.
- Agents can refer to past fights, purchases, failures, and NPC encounters.
- Agents develop different behavior over time with the same class.
- Logs show memory writes and reflection events.

### Milestone 4: Living World Visualization MVP

Goal: Turn AFW from a telemetry dashboard into a watchable world.

Target duration: 1 to 2 weeks.

Design:

- Keep Phoenix LiveView as the app shell.
- Add a 2D map renderer through a LiveView JS hook.
- Use Phaser or Canvas for sprite movement.
- Drive visuals entirely from PubSub state updates.
- Keep chain polling out of the browser.

Screen sections:

- World map with zones and agent sprites.
- Agent speech bubbles and action labels.
- Combat flashes and loot popups.
- NPC shop markers.
- Monster markers with alive/dead state.
- EventTreasury progress.
- Settlement state badges: pending, confirmed, failed.
- Guardian alerts.
- Replay timeline.

Proposed data contract:

```json
{
  "tick": 42,
  "agents": [
    {
      "agentId": 22,
      "name": "Warrior",
      "classId": 1,
      "zoneId": 1,
      "position": {"x": 12, "y": 8},
      "hp": 74,
      "maxHp": 100,
      "action": "FIGHT",
      "speech": "This goblin will not trouble the road again.",
      "settlement": {"status": "pending", "deltaSoul": 12000000000000000000}
    }
  ],
  "monsters": [],
  "npcs": [],
  "events": []
}
```

Acceptance criteria:

- The dashboard shows agents moving on a 2D map.
- Tick logs and map state remain synchronized.
- Users can inspect one agent's memories, wallet, and recent actions.
- A 50 tick replay can be loaded from `logs/`.

### Milestone 5: Creator and UGC Pipeline

Goal: Let humans expand Aethermoor without writing Solidity.

Target duration: 1 to 2 weeks.

Design:

- Natural language content draft.
- AI-assisted JSON generation.
- Balance table validation.
- Local preview.
- GitHub issue or PR export.
- Optional on-chain registration after approval.

Content types:

- Monster type.
- NPC type.
- Item type.
- Zone.
- Quest.
- Lore event.
- Visual asset metadata.

Proposed modules:

- `AFW.Content.Schema`
- `AFW.Content.Validator`
- `AFW.Content.Preview`
- `AFW.Content.RegistryProposal`

Acceptance criteria:

- A user can draft a monster in plain language.
- The system generates a valid JSON spec.
- Invalid stats fail before chain submission.
- Valid content can be registered on Base Sepolia through Settlement Hub.

### Milestone 6: Guardian and Economy Intelligence

Goal: Make Guardian useful as an operator, not only a logger.

Target duration: 1 week.

Design:

- Event ingestion from Settlement EventStore and chain logs.
- Rule-based anomaly detector first.
- Brain Interface analysis second.
- Evidence bundle for every alert.
- Human-readable proposal output.

Guardian categories:

- Unauthorized role or mint attempt.
- Repeated settlement mismatch.
- Wash trading.
- Farming loops.
- Wealth spike.
- Inflation spike.
- Treasury threshold event.
- Marketplace stale behavior.

Acceptance criteria:

- Guardian can explain why an alert fired.
- False positives are tagged and persisted.
- High severity alerts produce a governance proposal draft.
- Economics dashboard matches simulation metrics.

### Milestone 7: Desktop RPG Mode

Goal: Make AFW feel like a real desktop RPG, not only a web dashboard.

Target duration: after Milestone 4.

Design:

- Package the LiveView app as a local desktop shell later, or expose a local-first mode.
- Prioritize 2D pixel RPG presentation.
- Add keyboard/mouse inspection, replay, map camera, and agent detail panels.
- Keep player control minimal: observe, bless, fund, create content, vote.

Interaction modes:

- Observer mode: watch agents live.
- God mode: create world content and propose events.
- Patron mode: fund an agent or sponsor a quest.
- Governance mode: inspect proposals and vote.

Acceptance criteria:

- A user can launch locally and watch agents without reading logs.
- The app can run against testnet or a local simulation.
- Offline demo mode works without RPC.

### Milestone 8: 3D and CLO/Marvelous Designer Exploration

Goal: Explore premium visual identity after the 2D world proves retention.

Target duration: later phase.

Design:

- Do not start with a full 3D MMORPG.
- Start with 3D agent profile scenes or wardrobe previews.
- Treat clothing as identity and economy, not just graphics.
- Use CLO or Marvelous Designer for high quality outfit creation.
- Use Unreal/MetaHuman pipeline only for showcase-grade agents.

Potential features:

- Agent portrait room.
- Wardrobe item preview.
- Creator-designed outfit marketplace.
- Special event cinematic renders.
- 3D town prototype for a small number of featured agents.

Acceptance criteria:

- One agent can be represented as a 3D character with swappable outfit metadata.
- Outfit ownership maps to ItemRegistry or a future cosmetic registry.
- 3D work does not block 2D gameplay iteration.

## Immediate Sprint Plan

This is the recommended next sprint.

### Sprint Goal

Reach a stable, explainable, watchable 3-agent loop.

### Task 1: Finish Combat Revert Diagnostics

Implementation:

- Re-run `eth_call` at the receipt block when a combat tx reverts.
- Decode `Error(string)` and custom error selectors.
- Log BaseScan URL for every reverted tx.
- Add revert reason aggregation to simulation JSON.

Validation:

- `mix test`
- `NODE_ENV=development npx hardhat test test/CombatResolver.test.ts`
- 50+ tick live run.

### Task 2: Preflight Roles and Deployed Addresses

Implementation:

- Check all deployed contract addresses from `deployments.json`.
- Check CombatResolver has required roles.
- Check SOULToken grants mint/burn permissions to the expected proxy addresses.
- Check MonsterRegistry grants COMBAT_ROLE to CombatResolver proxy.
- Print a preflight report before simulation starts.

Validation:

- Simulation refuses to start if critical roles are missing.

### Task 3: Suppress Marketplace Stale Orders

Implementation:

- Use `:failed_orders` ETS blacklist with TTL.
- Exclude failed orders in Agent Loop trade target selection.
- Mark order inactive failures immediately.
- Prevent repeated fill attempts for the same stale order.

Validation:

- Stale order discard count below 5 in 50 ticks.

### Task 4: Add Simulation Event Replay File

Implementation:

- Persist every tick as a replay event.
- Include agent state, action, summary, settlement id, and visual position.
- Write to `logs/replay_YYYYMMDD_HHMMSS.jsonl`.

Validation:

- A replay file can reconstruct 50 ticks without RPC.

### Task 5: First 2D Map Prototype

Implementation:

- Add a LiveView JS hook for a simple canvas map.
- Render zones as colored regions.
- Render agents as class-colored dots or sprites.
- Animate movement on EXPLORE and action pulses on FIGHT/REST/TRADE/TALK.

Validation:

- Running `mix phx.server` shows agent movement at `http://localhost:4000`.

## Engineering Backlog

### Reliability

- Paid or dedicated Base Sepolia RPC option.
- Local chain fork testing for deployed state reproduction.
- EventStore persistence.
- Idempotent settlement keys.
- Per-contract gas policies.
- Receipt diagnostics.
- Reconciliation explanation logs.

### Game Systems

- Agent memory.
- Social relationships.
- Daily plans.
- Skill library.
- Quest loop.
- World Director.
- EventTreasury events.
- NPC supply chain behavior.

### Economy

- Per-agent wallets.
- Agent starting capital policy.
- Marketplace maker/taker behavior.
- SOUL source and sink balancing.
- NPC price ceiling enforcement.
- Creator royalties.
- Contribution Agent reward dry runs.

### Visualization

- 2D map.
- Replay.
- Agent detail panel.
- Memory timeline.
- Economy flow graph.
- Guardian alert panel.
- Creator content preview.

### Creator Tools

- Natural language to content JSON.
- Balance validator.
- Preview renderer.
- GitHub issue exporter.
- On-chain registration proposal.
- Creator royalty accounting.

### 3D

- Agent profile renderer.
- Outfit metadata.
- Cosmetic registry.
- CLO/Marvelous workflow notes.
- Unreal prototype only after 2D retention is proven.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Public RPC instability | Settlement failures and slow tests | Add paid RPC, fallback pool, receipt diagnostics |
| Shared wallet accounting | Invalid economy metrics | Add per-agent wallets |
| LLM randomness | Poor game consistency | Use deterministic World Director validation |
| Too much on-chain logic | Slow gameplay and high gas | Keep only assets on-chain |
| Dashboard remains log-like | Low user engagement | Build 2D map and replay early |
| Memory drift | Agents become incoherent | Add reflection, checkpoints, and compact summaries |
| UGC balance exploits | Broken economy | Enforce Balance validators before registration |
| 3D scope explosion | Delays core game | Defer 3D until 2D loop is compelling |

## Definition of Done for the Next Major Phase

The next major phase is done when:

- 3 agents run for 100 ticks with 0 crashes.
- Settlement confirms at least one event for combat, NPC purchase, and marketplace trade.
- Combat failures have decoded root causes.
- Guardian completes at least one epoch.
- Dashboard shows a live 2D world, not only metrics.
- Each agent has a unique wallet or a documented migration path.
- Simulation output can be replayed offline.
- A new monster or item can be generated, validated, previewed, and proposed.

## Recommended Next Issue Sequence

1. Issue 29: Settlement Reliability Recovery.
2. Issue 30: Preflight and Per-Agent Wallets.
3. Issue 31: Replay Event Log and 2D Map MVP.
4. Issue 32: Agent Memory, Reflection, and Social Relationships.
5. Issue 33: Creator Content Pipeline.
6. Issue 34: Guardian Evidence and Economy Intelligence.
7. Issue 35: Desktop RPG Mode.
8. Issue 36: 3D Identity and Wardrobe Exploration.

## North Star

The north star is not "more contracts" or "more actions."

The north star is:

```text
An observer opens AFW, watches three agents live their lives for ten minutes,
remembers their names, understands their motives, sees their assets settle,
and wants to create something that changes their world.
```

