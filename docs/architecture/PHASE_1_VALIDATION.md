# Phase 1 Validation

Phase 1 begins the Living World layer on top of the Phase 0 settlement baseline.

## Implemented First Slice

- Treasury-backed world events now use an off-chain lifecycle cooldown, so a high EventTreasury balance does not dominate every agent tick.
- Agent memory is available through an ETS-backed memory stream with optional JSONL persistence.
- Prompt construction includes relevant memories before the decision section.
- Phoenix LiveView renders a deterministic 2D Aethermoor map with agent position, action, class color, and HP ring.
- Agent inspect pages show recent runtime memories alongside the on-chain snapshot.
- A deterministic replay script validates map and memory output without requiring Base Sepolia writes.

## Latest Replay

- Status: passed
- Checked at: 2026-05-05 06:53:37.983206Z
- Ticks replayed: 20
- Agents rendered per tick: 5
- Internal artifact: docs/internal/phase1-runs/phase1_replay_20260505T065337.979620Z.json

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase1_replay.exs
```

## Remaining Phase 1 Work

- Replace the SVG map MVP with the approved Phaser-based interactive viewer.
- Add durable SQLite/embedding-backed memory retrieval once visual behavior is stable.
- Add click-to-inspect monologue and richer social memory surfaces.
