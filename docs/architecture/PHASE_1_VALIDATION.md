# Phase 1 Validation

Phase 1 begins the Living World layer on top of the Phase 0 settlement baseline.

## Implemented First Slice

- Treasury-backed world events now use an off-chain lifecycle cooldown, so a high EventTreasury balance does not dominate every agent tick.
- Agent memory is available through an ETS-backed memory stream with optional JSONL persistence.
- Agent memory is durable through SQLite and can use Ollama `/api/embed` when `MEMORY_EMBEDDING_PROVIDER=ollama`.
- Prompt construction includes relevant memories before the decision section.
- Phoenix LiveView renders a Phaser 4 Aethermoor map with agent position, action, class color, HP ring, and click-to-inspect navigation.
- Phaser markers render speech bubbles and action-state animations for FIGHT, REST, TRADE, TALK, and EXPLORE.
- The Phaser viewer loads the first Tiled JSON map from `/assets/maps/aethermoor_overview.tmj`.
- TALK actions are captured in an off-chain dialogue transcript and shown on dashboard/agent inspect views.
- Agent inspect pages show recent runtime memories alongside the on-chain snapshot.
- A deterministic replay script validates map and memory output without requiring Base Sepolia writes.
- The Phoenix endpoint serves LiveView client JS from local Mix dependencies and loads Phaser 4 from the official CDN package path.

## Latest Replay

- Status: passed
- Checked at: 2026-05-05 09:10:29.526524Z
- Ticks replayed: 20
- Agents rendered per tick: 5
- Internal artifact: docs/internal/phase1-runs/phase1_replay_20260505T091029.517649Z.json
- Viewer standard: Phaser 4 LiveView hook
- Memory store: ETS hot path + SQLite durable replay + local/Ollama embedding adapter
- Map source: /assets/maps/aethermoor_overview.tmj

## Command

```bash
cd packages/agents_ex
mix run --no-start scripts/run_phase1_replay.exs
```

## Remaining Phase 1 Work

- Add sprite assets and animated action states.
- Replace deterministic local embeddings with a verified local Ollama model in developer setup.
- Add richer social memory surfaces and multi-agent dialogue transcripts.
