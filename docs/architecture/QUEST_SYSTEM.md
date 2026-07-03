# Quest System

Multi-step quests turn agent activity from random wandering into purposeful work.
Quests are posted on a board in Havenmoor, accepted by agents, and settled on-chain only at reward time.

## Design

- **QuestBoard contract** (UUPS proxy, registry pattern): anyone with the POSTER role
  (NPCs via oracle, later players) can post a quest with reward escrow in $SOUL.
- **Quest lifecycle**: `posted -> accepted -> submitted -> verified -> rewarded` (or `expired`).
- **Quest types (v1)**: HUNT (kill N monsters of type T), GATHER (collect N resource items),
  DELIVER (bring item I to NPC X). Types are registered dynamically, no enums.
- **Multi-step chains**: a quest may reference a `prerequisite_quest_id`, enabling
  gather -> craft -> deliver chains without new contract logic.
- Off-chain: quest browsing, acceptance decisions, and progress tracking live in the
  Elixir runtime. Only escrow, completion proof hash, and reward payout go on-chain.

## Brain Interface Actions

Two new actions extend the standard response schema:

- `ACCEPT_QUEST` with `target: quest_id` — agent commits to a posted quest.
- `SUBMIT_QUEST` with `target: quest_id` — agent claims completion; the runtime
  verifies conditions deterministically before settlement (LLM is planner, not judge).

## Reward Flow

- Reward = $SOUL escrow + optional item (e.g. skill book) + reputation delta (see FACTION_SYSTEM).
- Escrow is locked at post time; expired quests refund the poster automatically.
- Settlement uses the existing Hub with BATCH priority.

## Balance Constraints

- Reward bounds are enforced by the contract against the balance table
  (min/max $SOUL per quest tier). Out-of-range posts revert.
- One agent may hold at most 3 active quests (contract-enforced).

## Acceptance Criteria

- An NPC-posted quest appears on the Havenmoor board and in the LiveView panel.
- An agent accepts, completes, and receives escrowed $SOUL with a confirmed settlement.
- An expired quest refunds its poster without manual intervention.
