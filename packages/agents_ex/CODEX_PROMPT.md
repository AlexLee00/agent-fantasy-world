# Codex Task: agent-fantasy-world 50-tick 실주행 검증 및 Writer 최적화

## Context
Elixir/OTP 온체인 RPG 에이전트 시스템. Base Sepolia 테스트넷에서 3 에이전트(Warrior/Mage/Ranger) 자율 행동.

## 방금 완료한 변경 (이미 mix compile + mix test 통과)

### 1. FIGHT cooldown 강화 — `lib/afw/agent/loop.ex`
- `@fight_cooldown_ticks 3` 모듈 속성 추가
- `normalize_decision/4`에서 최근 10틱 윈도우 참조:
  - `ticks_since_fight < 3` → FIGHT 차단
  - 10틱 내 FIGHT 2회 초과 → FIGHT 차단
  - 기존 조건(HP ≤ 0.7, fight_count ≥ 1 in last 5)도 유지

### 2. REST 오프체인 전환 — `lib/afw/agent/loop.ex`
- `rest/1`에서 `Client.buy_from_npc()` 호출 제거
- REST가 더 이상 온체인 tx를 발생시키지 않음

### 온체인/오프체인 행동 맵
| Action  | On-chain write?         |
|---------|------------------------|
| FIGHT   | ✅ resolve_combat (cooldown 제한) |
| REST    | ❌ off-chain (변경됨)   |
| TRADE   | ✅ create/fill order (드묾) |
| TALK    | ❌ off-chain            |
| EXPLORE | ❌ off-chain            |

## 요청 작업

### Task 1: 50틱 실주행 후 결과 리포트
`mix run --no-halt` 또는 기존 실행 스크립트로 Base Sepolia 실주행.
50틱 완주 후 아래 메트릭 수집:
- 총 소요 시간, 평균 tick 시간
- 행동 분포 (FIGHT/EXPLORE/TALK/REST/TRADE 각 비율)
- 크래시/에러 발생 여부
- 온체인 tx 횟수 (FIGHT + TRADE)

### Task 2: tick 15초 미만 미달 시 Writer 최적화
병목이 Writer의 receipt polling이면:
- `@receipt_poll_ms` 2000 → 1500 또는 1000으로 줄이기 (lib/afw/chain/writer.ex)
- `@max_receipt_polls` 30 → 20으로 줄이기
- gas estimation 결과를 ETS 캐시에 짧은 TTL(3초)로 캐싱

병목이 RPC 지연이면:
- `config/runtime.exs`의 `rpc_urls`에 Alchemy/Infura Base Sepolia 엔드포인트 추가
- Pool.request에서 가장 빠른 RPC를 우선 사용하도록 latency-aware 로직 추가

### Task 3: 행동 로그 포맷
각 tick 결과를 아래 형식으로 stdout에 출력:
```
[tick 1] Warrior: EXPLORE → "Explored toward the frontier" (0.8s)
[tick 1] Mage: TALK → "Talked with innkeeper" (0.1s)
[tick 1] Ranger: FIGHT → "Defeated Goblin Scout" (12.3s, tx: 0xabc...)
```

## 핵심 파일 위치
- `packages/agents_ex/lib/afw/agent/loop.ex` — tick 실행 + FIGHT cooldown
- `packages/agents_ex/lib/afw/brain/prompt_builder.ex` — LLM 프롬프트
- `packages/agents_ex/lib/afw/chain/writer.ex` — GenServer 온체인 쓰기
- `packages/agents_ex/lib/afw/chain/reader.ex` — 병렬 읽기 + ETS 캐시
- `packages/agents_ex/lib/afw/chain/cache.ex` — ETS TTL 캐시
- `packages/agents_ex/lib/afw/chain/pool.ex` — 다중 RPC 라운드로빈
- `packages/agents_ex/config/runtime.exs` — RPC URLs, 에이전트 설정

## 목표
- [ ] 50틱 완주 (크래시 없이)
- [ ] 평균 tick 시간 15초 미만
- [ ] FIGHT 비율 ≤ 20%
- [ ] 행동 다양성: EXPLORE + TALK ≥ 50%
