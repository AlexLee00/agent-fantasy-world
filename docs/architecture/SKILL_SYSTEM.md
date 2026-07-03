# Skill System

Skills differentiate agents of the same class. Five warriors should evolve five different builds.

## Design

- **SkillRegistry contract** (UUPS proxy, registry pattern): skills are registered
  dynamically with id, class restriction (0 = any), kind (ACTIVE | PASSIVE), and effect bounds.
- **AgentRegistry extension**: each agent gains 4 skill slots (2 active, 2 passive),
  stored as skill ids. Slots are written on LEARN and cleared on FORGET.
- **Active skills** modify combat rolls (e.g. Shield Bash: +damage, -speed for one round).
- **Passive skills** apply persistent modifiers (e.g. Quick Learner: +10% XP).
- Effects are resolved deterministically by CombatResolver and the Elixir combat engine;
  the registry stores bounded parameters, never arbitrary code.

## Learning

- Skill books are items (ItemRegistry) obtained as quest rewards or rare monster drops.
- `LEARN_SKILL` consumes the book and writes the slot; `FORGET_SKILL` frees a slot
  (book is not refunded). Both are Brain Interface actions settled with BATCH priority.
- Class restriction and slot limits are contract-enforced; invalid learns revert.

## Balance Constraints

- Effect magnitudes are bounded by the balance table (e.g. damage modifier within
  [-30%, +30%], XP modifier within [0%, +20%]). Out-of-range registrations revert.
- No skill may stack with itself; duplicate slot writes revert.

## Acceptance Criteria

- Five same-class agents diverge into different skill sets within a 50-tick run.
- A skill book reward flows: quest -> item -> LEARN_SKILL -> combat effect visible in logs.
- Combat outcomes with and without an active skill differ measurably and deterministically.
