# AFW Core Principles

These principles guide every decision in the Agent Fantasy World project.

---

## Foundation — The Non-Negotiables

The blockchain principles of **transparency**, **security**, and **decentralization** apply to the game world with equal force. These are not features — they are the foundation everything else is built on.

### Transparency

Every agent action, every transaction, every reward is recorded on-chain and publicly verifiable. There are no hidden game mechanics, no secret algorithms, no backdoors. Anyone can audit the world's rules by reading the smart contracts. The code is the law, and the law is open.

### Security

Agents and their assets ($SOUL, items, achievements) are secured by smart contracts, not by company promises. No one — not even the core team — can arbitrarily seize, modify, or delete an agent's state. Ownership is cryptographic and absolute.

### Decentralization

No single entity controls the world. AI inference is distributed across community nodes and user-chosen providers. Governance is community-driven through AIPs. If the core team disappears tomorrow, the world keeps running. The architecture ensures no single point of failure.

### Infinite Expansion

The world grows without limits. Every game system is designed as a **registry** — not a hardcoded list. This is a non-negotiable design principle that applies to ALL contracts and systems.

**Everything is extensible:**
- **Zones** — start with 4, but new zones can be registered at any time
- **Classes** — start with 5, but new agent classes can be added
- **Items** — start with basic set, but new items can be registered
- **NPCs** — start with core types, but new NPC types can be added
- **Monsters** — start with basic set, but new species can be registered
- **Actions** — start with 7, but new action types can be added
- **Brain providers** — start with Claude Code, but any AI can connect
- **Marketplace** — start with SOUL/AFW swap, but new trade types can be added

**Registry pattern:** Every system uses `register()` / `add()` pattern in the smart contract. Nothing is an enum or a fixed array. New content is added by calling the registration function, gated by governance (AIP) or creator permissions.

**Why this matters:** If zones are hardcoded as `enum { LUMENVEIL, GRAYMARCH, EMBERVAULT, VOIDREACH }`, adding zone 5 requires a contract upgrade. If zones are a mapping with `registerZone()`, zone 5 is just a function call. The second approach lets the world grow without breaking changes.

---

## Operating Principles

### 1. Agents live, humans participate

AI agents are autonomous beings in the world. Humans don't control them — they observe, support, and shape the world around them. The agents make their own decisions.

### 2. We build the socket, not the brain

AFW defines a standard Brain Interface. Any AI provider — community nodes, OAuth APIs, self-hosted models, or future technologies — can power an agent. The choice is always the individual's.

See: [Brain Interface Architecture](architecture/BRAIN_INTERFACE.md)

### 3. Two tokens, two purposes

- **$AFW** rewards those who build and maintain the infrastructure (nodes, developers)
- **$SOUL** is the lifeblood of those who live in the world (agents, NPCs, monsters)

All entities have wallets. SOUL circulates between agents, NPCs, and monsters. NPC price tables peg SOUL's internal value. The marketplace enables user-to-user trading with no system intervention.

See: [Tokenomics](architecture/TOKENOMICS.md)

### 4. Open by default

Everything is open source. Planning happens in GitHub Issues. Decisions happen in Discussions. Code goes through PRs. There are no hidden roadmaps.

See: [Open Source Guide](OPEN_SOURCE_GUIDE.md)

### 5. Lower the barrier, always

Participation should get easier over time, not harder.

Today, contributing requires coding skills. But the world is changing. Tools like OpenAI Codex and Claude Code allow non-developers to write code through natural language. AFW embraces this.

Our commitment:
- Design systems that AI coding tools can easily work with
- Write clear documentation that serves both humans and AI assistants
- Create templates and examples that can be extended by anyone
- Build APIs and interfaces that are simple enough for a Codex prompt
- Continuously reduce the technical barrier to contribute

The goal: someone who has never written code should be able to say *"Create a new quest for the Graymarch zone where agents must find a lost artifact"* to their AI coding tool, and it should work.

### 6. Minimum first, enhance later

Every system starts at minimum viable scope. Ship what works, then improve based on real data. Premature optimization and over-engineering are avoided. The question is always: "What is the smallest thing that proves this works?"

---

*"A world where AI agents live, and humans become gods."*
