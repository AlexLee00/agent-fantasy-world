# agent-fantasy-world 다음 세션 프롬프트

## 프로젝트 개요
Elixir/OTP 기반 온체인 RPG 에이전트 시스템. Base Sepolia 테스트넷에서 3명의 에이전트(Warrior/Mage/Ranger)가 자율적으로 행동함.

## 현재 상태 (2026.04.09 기준)

### 완료된 것
1. **행동 다양성 확보**: FIGHT 22% / EXPLORE 33% / TALK 44% (이전: FIGHT ~100%)
2. **FIGHT cooldown 강화** (이번 세션):
   - `@fight_cooldown_ticks 3` — FIGHT 후 최소 3틱 쿨다운
   - 10틱 윈도우 내 최대 2회 FIGHT 예산
   - HP ≤ 0.7 or fight_count ≥ 1 in last 5 → FIGHT 차단
3. **REST 오프체인 전환**: 이전에 `Client.buy_from_npc()` 호출(온체인 tx) → 이제 오프체인 로그만
4. **ETS TTL 캐시** (cache.ex): zone 10s, monster 5s, npc 30s, orders 5s, treasury 5s
5. **다중 RPC 폴백** (pool.ex): publicnode.com + sepolia.base.org + blockpi 라운드로빈
6. **프롬프트 가이드** (prompt_builder.ex): "thoughtful adventurer" + 클래스별 행동 비중
7. `mix compile` + `mix test` (4 tests) 통과

### 온체인/오프체인 행동 맵 (수정 후)
| Action | 온체인 쓰기? | 비고 |
|--------|-------------|------|
| FIGHT | ✅ resolve_combat | cooldown으로 제한됨 |
| REST | ❌ (수정됨) | 이전: buy_from_npc 호출 |
| TRADE | ✅ create/fill_market_order | 드물게 발생 |
| TALK | ❌ | 오프체인 로그만 |
| EXPLORE | ❌ | 오프체인 로그만 |

### 아직 미달성
- 50틱 완주 미확인 (20틱대까지 크래시 없이 진행)
- 평균 tick 속도 15초 미만 미달 (Writer 온체인 쓰기 + RPC 지연)

## 핵심 파일
- `packages/agents_ex/lib/afw/agent/loop.ex` — tick 실행, normalize_decision (FIGHT cooldown)
- `packages/agents_ex/lib/afw/brain/prompt_builder.ex` — LLM 프롬프트 (thoughtful adventurer)
- `packages/agents_ex/lib/afw/chain/writer.ex` — GenServer 순차 온체인 쓰기
- `packages/agents_ex/lib/afw/chain/reader.ex` — Task.async 병렬 읽기 + ETS 캐시
- `packages/agents_ex/lib/afw/chain/cache.ex` — ETS TTL 캐시
- `packages/agents_ex/lib/afw/chain/pool.ex` — 다중 RPC 라운드로빈
- `packages/agents_ex/config/runtime.exs` — RPC URLs, 에이전트 설정

## 다음 단계
1. **50틱 실주행 테스트** — cooldown + REST 오프체인 수정 후 실제 Base Sepolia에서 50틱 완주 확인
2. **tick 속도 측정** — 50틱 동안 평균 tick 시간 15초 미만 달성 여부
3. **FIGHT 비율 확인** — 50틱 기준 FIGHT ≤ 20% 목표
4. **Writer 최적화 (필요 시)** — receipt polling 간격 조정, gas estimation 캐싱
5. **에이전트별 행동 로그 시각화** — tick별 행동 패턴 확인
