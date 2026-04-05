# AFW Open Source Development Guide
## 완전공개 프로젝트 운영 원칙

> 이 문서는 코어팀의 공개 프로젝트 운영 가이드입니다.
> 외부 기여자용 가이드는 CONTRIBUTING.md를 참고하세요.

---

## 1. 공개 vs 비공개 — 경계선

### GitHub에 올라가는 것 (공개)
- 모든 소스코드 + 테스트
- 아키텍처 문서, API 문서, Whitepaper
- CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
- CI/CD 설정, 빌드 설정 (hardhat.config.ts 등)
- `.env.example` (값 없이 키 이름만)
- Roadmap (GitHub Milestones / Projects)

### 로컬에만 두는 것 (비공개)
- `docs/internal/` — 인수인계, 진도체크, 내부 전략
- `specs/` — Claude Code / Codex 구현 지시서
- `.env` — 실제 키값, 토큰, RPC URL
- 개인 메모, 미팅 노트

### 판단 기준
> **"외부 기여자가 이걸 봤을 때 도움이 되는가?"**
> YES → GitHub / NO → 로컬

---

## 2. 계획은 공개로 — GitHub Issues가 곧 로드맵

완전공개 프로젝트에서 기획 문서를 비공개로 두면, 기여자가 뭘 해야 하는지 모릅니다.
기획 → Issue, 전략 → Discussion, 결정 → AIP 이렇게 흐릅니다.

### 기획 → GitHub Issue로 공개
```
❌ 나쁜 예: 비공개 노션에 "CombatResolver 요구사항" 작성
✅ 좋은 예: GitHub Issue #15 "feat: implement CombatResolver"
            → 요구사항, 인터페이스 스펙, 수용 기준을 Issue 본문에 작성
```

### 구현 지시서 → Issue 본문의 "Implementation Notes"
Claude Code에게 줄 spec은 로컬에 두되,
**외부 기여자도 구현할 수 있도록** 핵심 내용은 Issue에 공개합니다.
```
❌ 나쁜 예: spec 전체를 비공개로만 보관
✅ 좋은 예: Issue에 인터페이스 + 핵심 로직을 서술하고,
            상세 구현 힌트는 코드 주석으로
```

### 의사결정 → GitHub Discussions
```
"Solidity 버전을 0.8.24로 올려야 하나?"
→ Discussions > Ideas 카테고리에 올리고 커뮤니티 의견 수렴
→ 결정 나면 Issue 생성 → PR 진행
```

---

## 3. 코드 작성 원칙 — 기여자 친화적

### 언어 규칙
```
코드 + 주석:        영어 (글로벌 기여자 접근성)
커밋 메시지:        영어 (Conventional Commits)
GitHub Issues/PR:  영어 (기본), 한국어 Discussion은 OK
내부 문서:          한국어 OK (로컬 전용이니까)
```

### 커밋 메시지 컨벤션 (Conventional Commits)
```
feat(contracts): add CombatResolver with turn-based logic
fix(agents): resolve memory leak in personality scoring
docs: update architecture diagram for oracle flow
test(tokens): add edge case tests for daily mint limit
chore: upgrade OpenZeppelin to 5.7.0
ci: add slither static analysis to security workflow
```

### 코드 주석 — 내부 참조 금지
```solidity
// ❌ 나쁜 예
// 메티 spec v3에 따라 구현 (2026-04-05)
// Alex가 요청한 전투 로직

// ✅ 좋은 예
/// @notice Resolves combat between two agents using turn-based mechanics
/// @dev Damage formula: base_attack * class_modifier - target_defense
/// @param attackerId The attacking agent's ID
/// @param defenderId The defending agent's ID
```

---

## 4. PR 워크플로우 — 코어팀도 PR을 쓴다

완전공개 프로젝트에서 코어팀이 main에 직접 push하면 신뢰를 잃습니다.

```
1. feature 브랜치 생성    git checkout -b feature/combat-resolver develop
2. 코드 작성 + 테스트      Claude Code / Codex 가 구현
3. PR 생성                develop ← feature/combat-resolver
4. CI 통과 확인            자동 (GitHub Actions)
5. 코드 리뷰              코어팀 상호 리뷰 또는 셀프 리뷰
6. Squash merge           PR title이 커밋 메시지가 됨
7. 브랜치 자동 삭제        설정 완료됨
```

### 셀프 리뷰도 괜찮다
코어팀이 2명(Alex + Claude Code)이면, PR을 올린 후 본인이 리뷰하고 머지해도 됩니다.
중요한 건 **과정이 기록으로 남는 것**입니다. 외부 기여자가 "이 프로젝트는
어떤 과정으로 코드가 들어가는구나"를 볼 수 있으면 됩니다.

---

## 5. Issue 관리 — 기여자를 끌어들이는 방법

### 좋은 Issue의 조건
```
✅ 명확한 제목:     "feat: implement ItemRegistry contract"
✅ 배경 설명:       왜 이게 필요한지 1-2문장
✅ 수용 기준:       구체적으로 뭘 하면 완료인지
✅ 기술 힌트:       어디를 보면 되는지, 참고할 코드
✅ 라벨:           scope/contracts + priority/medium + good first issue
```

### `good first issue` 라벨을 적극 활용
외부 기여자가 처음 기여할 때 보는 곳입니다.
작고 명확한 작업을 골라서 `good first issue`를 달아두세요.
```
예시:
- "docs: add NatSpec comments to AFWToken.sol"
- "test: add edge case for zero-amount SOUL mint"
- "chore: add prettier config for Solidity files"
```

---

## 6. 흔한 실수 — 이것만 피하면 된다

| 실수 | 왜 문제인가 | 해결 |
|------|------------|------|
| `.env` 커밋 | 키 유출 → 해킹 | .gitignore + Secret scanning ON |
| 내부 문서 커밋 | 기여자 혼란, 비전문적 | docs/internal/ + .gitignore |
| main 직접 push | 과정 불투명 | PR 필수 (branch protection) |
| 한국어 주석 | 글로벌 기여 차단 | 코드/주석은 영어 |
| 거대한 PR | 리뷰 불가능 | 1 PR = 1 기능, 300줄 이하 |
| Issue 없이 코딩 | 맥락 없는 코드 | Issue first, then code |

---

## 7. 메티의 역할 — 오픈소스 컨텍스트에서

```
1. Alex와 전략 수립        → 결과를 GitHub Issue로 공개
2. 구현 지시서(spec) 작성   → 핵심은 Issue에, 상세는 로컬에
3. GitHub 관리             → Issue 생성, 라벨 관리, PR 리뷰 요청
4. 오픈소스 품질 관리       → 커밋 메시지, 문서 품질, 기여자 경험
```

---

*AFW Open Source Guide v1.0 — 2026-04-05*
*"Build in public, decide in public, grow in public"*
