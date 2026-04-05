# Contributing to Agent Fantasy World 🏰

> *"이 세계를 만드는 데 모든 사람이 참여한다"*

AFW에 기여해주셔서 감사합니다! 이 문서는 기여 방법을 안내합니다.

---

## 📋 목차

- [행동 강령](#행동-강령)
- [기여 유형](#기여-유형)
- [시작하기](#시작하기)
- [개발 환경 설정](#개발-환경-설정)
- [Pull Request 프로세스](#pull-request-프로세스)
- [이슈 작성 가이드](#이슈-작성-가이드)
- [코딩 스타일](#코딩-스타일)
- [보상 시스템](#보상-시스템)
- [AIP 제안 프로세스](#aip-제안-프로세스)

---

## 행동 강령

이 프로젝트에 참여하는 모든 분은 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)를 따릅니다.

---

## 기여 유형

| 유형 | 방법 | 보상 |
|---|---|---|
| 🛠 **개발자** | 버그 수정, 기능 PR | $AFW 그랜트 |
| 📋 **기획자** | 퀘스트/몬스터 설계 | $SOUL 영구 로열티 (5%) |
| 🎨 **디자이너** | 에셋, UI 기여 | 로열티 + 온체인 크레딧 |
| 📊 **전략가** | AIP 제안, 거버넌스 | 거버넌스 영향력 |
| 🌐 **번역가** | 다국어 문서 | $AFW 그랜트 |
| 🐛 **테스터** | 버그 리포트 | 기여 뱃지 |

---

## 시작하기

### 1. 이슈 확인
- [Good First Issues](https://github.com/agent-fantasy-world/afw-core/labels/good%20first%20issue) — 처음 기여자에게 추천
- [Help Wanted](https://github.com/agent-fantasy-world/afw-core/labels/help%20wanted) — 도움이 필요한 이슈

### 2. 이슈 배정 요청
이슈 댓글에 "작업하겠습니다" 또는 "I'd like to work on this"를 남겨주세요.
중복 작업을 방지하기 위해 배정 후 작업을 시작해주세요.

### 3. 큰 변경사항은 먼저 논의
핵심 아키텍처, 토크노믹스, 스마트컨트랙트 변경은 PR 전에
[AIP 제안서](#aip-제안-프로세스)를 먼저 작성해주세요.

---

## 개발 환경 설정

### 필수 사항
- Node.js >= 20
- Python >= 3.11
- pnpm >= 9

### 설치

```bash
git clone https://github.com/agent-fantasy-world/afw-core
cd afw-core
pnpm install

# 스마트컨트랙트
cd packages/contracts
pnpm install
npx hardhat compile
npx hardhat test

# 에이전트 엔진
cd packages/agents
pip install -r requirements.txt
pytest

# 클라이언트
cd packages/client
pnpm dev
```

---

## Pull Request 프로세스

### 브랜치 전략

```
main        — 프로덕션 (직접 push 금지)
develop     — 개발 통합 브랜치 (PR 대상)
feat/XXX    — 새 기능
fix/XXX     — 버그 수정
docs/XXX    — 문서
world/XXX   — 퀘스트/몬스터/Zone 콘텐츠
```

### PR 체크리스트

PR 제출 전 확인사항:
- [ ] `develop` 브랜치 기준으로 작업했는가
- [ ] 테스트를 작성/업데이트했는가
- [ ] 스마트컨트랙트 변경 시 테스트 커버리지 95% 이상인가
- [ ] 문서를 업데이트했는가
- [ ] `pnpm lint` 통과했는가
- [ ] 시크릿/키/토큰을 커밋하지 않았는가

### 리뷰 프로세스

1. CI 자동 검사 통과 필수
2. 코어팀 또는 CODEOWNERS 최소 1명 승인 필요
3. 스마트컨트랙트 변경은 2명 승인 필요
4. 승인 후 Squash Merge

---

## 이슈 작성 가이드

### 버그 리포트
`.github/ISSUE_TEMPLATE/bug_report.md` 템플릿 사용

### 기능 요청
`.github/ISSUE_TEMPLATE/feature_request.md` 템플릿 사용

### 월드 콘텐츠 (퀘스트/몬스터)
`.github/ISSUE_TEMPLATE/world_content.md` 템플릿 사용

---

## 코딩 스타일

### Solidity
- solhint 규칙 준수
- NatSpec 주석 필수 (public/external 함수)
- 이벤트 이름: PascalCase
- 변수 이름: camelCase

### TypeScript/JavaScript
- ESLint + Prettier 설정 준수
- `pnpm lint` 통과 필수

### Python
- Black 포매터
- mypy 타입 검사
- 함수/클래스 docstring 필수

### 커밋 메시지 (Conventional Commits)
```
feat: 새 기능
fix: 버그 수정
docs: 문서 변경
test: 테스트 추가/수정
world: 퀘스트/몬스터/에셋 추가
refactor: 리팩터링
chore: 빌드/설정 변경
```

---

## 보상 시스템

### $AFW 그랜트 (개발 기여)
| 기여 | 보상 |
|---|---|
| 버그 수정 (Critical) | 5,000 $AFW |
| 버그 수정 (Major) | 1,000 $AFW |
| 핵심 기능 PR | 10,000 ~ 50,000 $AFW |
| 테스트 커버리지 향상 | 500 $AFW |
| 문서 개선 | 200 $AFW |

### $SOUL 로열티 (월드 콘텐츠)
퀘스트, 몬스터, Zone을 추가하고 Merge되면 해당 콘텐츠에서
발생하는 $SOUL 보상의 **5%가 영구적으로** 기여자에게 지급됩니다.

보상은 스마트컨트랙트로 자동 분배되며, 온체인에 기여자 주소가 영구 등재됩니다.

---

## AIP 제안 프로세스

AFW Improvement Proposal — 중요한 변경사항 제안 방식

```
1. docs/aip/AIP-0000-template.md 복사
2. 내용 작성 후 PR 제출 (docs/aip/ 폴더)
3. GitHub Discussions에서 7일 토론
4. 커뮤니티 투표 (3일)
5. 통과 시 구현 시작
```

AIP가 필요한 경우:
- 토크노믹스 변경
- 스마트컨트랙트 핵심 로직 변경
- 새 Zone 추가 (Community Zone)
- 거버넌스 규칙 변경

---

## 도움이 필요하신가요?

- **Discord**: https://discord.gg/afw
- **GitHub Discussions**: 질문과 아이디어
- **Twitter/X**: @AFWorld

모든 기여를 환영합니다. 코드를 못 짜도 괜찮습니다.
퀘스트 아이디어 하나도 이 세계를 만드는 소중한 기여입니다. 🏰
