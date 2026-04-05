# GitHub 저장소 설정 가이드
# GitHub 생성 후 이 문서를 보고 수동으로 설정하세요

## 1. Organization & Repository 기본 설정

```
Organization: agent-fantasy-world
Repository: afw-core
Visibility: Public
License: MIT
Default Branch: main
```

### Settings → General
- [x] Issues 활성화
- [x] Discussions 활성화
- [x] Projects 활성화
- [ ] Wiki 비활성화 (docs/ 폴더로 대체)
- [x] Sponsorships 활성화
- [x] Squash merging 허용
- [ ] Merge commits 비허용
- [x] Rebase merging 허용
- [x] Delete branch on merge 활성화

---

## 2. Branch Protection Rules (main)

Settings → Branches → Add branch protection rule

### Branch name pattern: `main`

```
[x] Require a pull request before merging
    [x] Require approvals: 1명 (초기), 2명 (스마트컨트랙트)
    [x] Dismiss stale pull request approvals when new commits are pushed
    [x] Require review from Code Owners
    [ ] Require approval of the most recent reviewable push (초기엔 비활성)

[x] Require status checks to pass before merging
    [x] Require branches to be up to date before merging
    Required checks:
      - contracts
      - agents  
      - lint
      - security

[x] Require conversation resolution before merging

[x] Require signed commits

[ ] Include administrators (초기엔 비활성, 이후 활성화)

[x] Restrict pushes that create matching branches
    - 코어팀만 push 가능

[ ] Allow force pushes: 비활성화
[ ] Allow deletions: 비활성화
```

### Branch name pattern: `develop`

```
[x] Require a pull request before merging
    [x] Require approvals: 1명
    [x] Dismiss stale pull request approvals when new commits are pushed

[x] Require status checks to pass before merging
    Required checks:
      - contracts
      - agents
      - lint

[ ] Require signed commits (develop은 선택)
```

---

## 3. Security Settings

Settings → Security & analysis

```
[x] Dependency graph
[x] Dependabot alerts
[x] Dependabot security updates
[x] Secret scanning
[x] Push protection (시크릿 push 차단)
[x] Private vulnerability reporting
```

---

## 4. Labels 설정

기본 라벨 외 추가 라벨:

```bash
# 카테고리
bug             #d73a4a   버그
enhancement     #a2eeef   새 기능
documentation   #0075ca   문서
world-content   #e4e669   퀘스트/몬스터/에셋
aip             #7057ff   AFW Improvement Proposal
smart-contract  #0e8a16   스마트컨트랙트 관련

# 상태
needs-triage    #e4e669   분류 필요
in-progress     #0052cc   진행 중
needs-review    #fbca04   리뷰 필요
blocked         #ee0701   블록됨

# 우선순위
priority:critical #b60205
priority:high     #e11d48
priority:medium   #f97316
priority:low      #86efac

# 기여자 친화
good first issue  #7057ff  처음 기여자 추천
help wanted       #008672  도움 필요
```

---

## 5. GitHub Discussions 카테고리

Discussions 탭 → Manage discussions categories

```
📢 Announcements  — 공지 (코어팀만 작성)
💡 Ideas          — 아이디어 논의
📜 AIP Discussion — AIP 제안 토론
🌍 World Building — 세계관/콘텐츠 논의
🛠 Dev Help       — 개발 질문
🎮 Show & Tell    — 기여 작업 공유
🌐 General        — 일반 대화
```

---

## 6. GitHub Pages (문서 사이트)

Settings → Pages

```
Source: Deploy from a branch
Branch: main / docs
(추후 docs/ 폴더에 mkdocs 또는 Jekyll 설정)
```

---

## 7. Topics (태그)

Repository → About → Edit

```
blockchain, ethereum, polygon, solidity, web3,
ai-agent, fantasy-game, pixel-art, open-source,
gamefi, autonomous-agents, nft-game, dao,
aethermoor, defi
```

---

## 벤치마킹 레퍼런스

| 프로젝트 | 참고한 것 |
|---|---|
| [ethereum-optimism/optimism](https://github.com/ethereum-optimism/optimism) | 브랜치 전략, CONTRIBUTING 구조 |
| [MetaMask/metamask-extension](https://github.com/MetaMask/metamask-extension) | PR 리뷰 프로세스 |
| [ethereum/ethereum-org-website](https://github.com/ethereum/ethereum-org-website) | 기여자 온보딩, 리워드 |
| [Creative Commons](https://opensource.creativecommons.org) | 레포 가이드라인 |
| [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) | 스마트컨트랙트 보안 정책 |
