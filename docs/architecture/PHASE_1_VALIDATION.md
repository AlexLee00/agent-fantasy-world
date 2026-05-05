# Phase 1 Validation

Phase 1 begins the Living World layer on top of the Phase 0 settlement baseline.

## Implemented First Slice

- Treasury-backed world events now use an off-chain lifecycle cooldown, so a high EventTreasury balance does not dominate every agent tick.
- Agent memory is available through an ETS-backed memory stream with optional JSONL persistence.
- Prompt construction includes relevant memories before the decision section.
- Phoenix LiveView renders a Phaser 4 Aethermoor map with agent position, action, class color, HP ring, and click-to-inspect navigation.
- Agent inspect pages show recent runtime memories alongside the on-chain snapshot.
- A deterministic replay script validates map and memory output without requiring Base Sepolia writes.
- The Phoenix endpoint serves LiveView client JS from local Mix dependencies and loads Phaser 4 from the official CDN package path.

## Latest Replay

- Status: passed
- Checked at: 2026-05-05 06:59:40.236696Z
- Ticks replayed: 20
- Agents rendered per tick: 5
- Internal artifact: docs/internal/phase1-runs/phase1_replay_20260505T065940.232917Z.json
- Viewer standard: Phaser 4 LiveView hook

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase1_replay.exs
```

## Remaining Phase 1 Work

- Add durable SQLite/embedding-backed memory retrieval once visual behavior is stable.
- Add click-to-inspect monologue and richer social memory surfaces.
- Add Tiled-authored maps and sprite assets; current Phase 1 viewer uses generated zone geometry as the first integration slice.
