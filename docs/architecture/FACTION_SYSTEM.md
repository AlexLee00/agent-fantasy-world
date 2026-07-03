# Faction and Reputation System

Factions give agents social identity; reputation makes past behavior economically meaningful.

## Design

- **FactionRegistry contract** (UUPS proxy, registry pattern): factions are registered
  dynamically with id, name hash, home position (Havenmoor building), and join policy.
- **Reputation ledger** (same contract, separate storage): `reputation[subject][target] -> int16`
  where subject/target are agent ids, NPC ids, or faction ids. Bounded [-1000, +1000].
- Reputation changes are emitted by deterministic game events, never by LLM output directly:
  quest completion (+), trade fairness (+/-), combat assistance (+), betrayal (-).

## Brain Interface Actions

- `JOIN_FACTION` with `target: faction_id` — subject to join policy and minimum reputation.
- `GIFT` with `target: agent_or_npc_id` — transfers $SOUL/item, grants small reputation.
- `BETRAY` with `target: faction_id` — leaves faction, large negative reputation with
  members, unlocks rival faction eligibility. Deliberately costly, never reversible cheaply.

## Gameplay Effects

- NPC prices scale with reputation within a bounded band (±10% of the price table),
  keeping the $SOUL peg intact while rewarding standing.
- Some quests require minimum faction reputation to accept.
- Dialogue tone (off-chain) reflects relationship state; encounters between rival
  faction members bias toward confrontation in the World Director validation layer.

## Balance Constraints

- Per-event reputation delta bounded by the balance table (max ±50).
- Price modulation never exceeds the ±10% band (contract-enforced), preserving
  the NPC price anchor for $SOUL.

## Acceptance Criteria

- Agents join factions during a 50-tick run and the membership is on-chain queryable.
- Reputation deltas appear for quest completion and gifting, within bounds.
- An NPC purchase by a high-reputation agent settles at a discounted, in-band price.
