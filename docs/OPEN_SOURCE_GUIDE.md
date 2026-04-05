# AFW Open Source Development Guide

Operating principles for the core team running a fully open project.
For external contributor guidelines, see [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## 1. Public vs Private — The Boundary

### Goes on GitHub (Public)
- All source code + tests
- Architecture docs, API docs, Whitepaper
- CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
- CI/CD config, build config (hardhat.config.ts, etc.)
- `.env.example` (key names only, no values)
- Roadmap (GitHub Milestones / Projects)

### Stays local only (Private)
- `docs/internal/` — handover docs, progress tracking, internal strategy
- `specs/` — Claude Code / Codex implementation specs
- `.env` — actual keys, tokens, RPC URLs
- Personal notes, meeting notes

### Decision rule
> **"Would an external contributor find this useful?"**
> YES → GitHub / NO → local only

---

## 2. Plan in Public — GitHub Issues Are the Roadmap

In a fully open project, plans hidden in private docs are invisible to contributors.

### Planning → GitHub Issues
```
❌ Bad:  Write requirements in a private doc
✅ Good: GitHub Issue #15 "feat: implement CombatResolver"
         → Requirements, interface spec, acceptance criteria in the issue body
```

### Implementation specs → Issue body + local detail
Keep detailed specs for Claude Code locally, but publish key information
(interface, core logic, acceptance criteria) in the Issue so anyone can contribute.

### Decision-making → GitHub Discussions
Post in Discussions > Ideas, gather community input, then create Issue → PR.

---

## 3. Code Standards — Contributor-Friendly

### Language rules
```
Code + comments:       English (global contributor access)
Commit messages:       English (Conventional Commits)
GitHub Issues/PRs:     English
Internal docs:         Korean OK (local only)
```

### Commit message convention
```
feat(contracts): add CombatResolver with turn-based logic
fix(agents): resolve memory leak in personality scoring
docs: update architecture diagram
test(tokens): add edge case tests for daily mint limit
```

### Code comments — no internal references
```solidity
// ❌ Bad: Per internal spec v3 (2026-04-05)
// ✅ Good: /// @notice Resolves combat using turn-based mechanics
```

---

## 4. PR Workflow — Core Team Uses PRs Too

```
1. Create feature branch    git checkout -b feature/xxx develop
2. Write code + tests       Claude Code / Codex implements
3. Open PR                  develop ← feature/xxx
4. CI passes                Automatic (GitHub Actions)
5. Code review              Mutual or self-review
6. Squash merge             PR title becomes commit message
7. Branch auto-deleted      Already configured
```

Self-review is fine with a small core team. What matters is that the process is recorded.

---

## 5. Issue Management — Attracting Contributors

Use `good first issue` generously. Pick small, well-defined tasks:
- "docs: add NatSpec comments to AFWToken.sol"
- "test: add edge case for zero-amount SOUL mint"

---

## 6. Common Mistakes to Avoid

| Mistake | Solution |
|---------|----------|
| Committing `.env` | .gitignore + Secret scanning |
| Internal docs on GitHub | docs/internal/ + .gitignore |
| Direct push to main | PR required (branch protection) |
| Non-English comments | Code + comments in English |
| Huge PRs | 1 PR = 1 feature, <300 lines |
| Coding without Issue | Issue first, then code |

---

*AFW Open Source Guide v1.0 — "Build in public, decide in public, grow in public"*
