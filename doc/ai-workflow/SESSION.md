# M1 실행 결과 — 2026-10-31

M1 완료. 장기 최종 목표는 PLAN.md의 M2–M6에서 계속 진행한다.

## 적용한 구성

- MicroClaw 0.11.1 + 기존 ChatGPT/Codex 로그인 + gpt-6.1-sol.
- Guix Home Shepherd gateway 자동 시작 및 mcron 30분 간격 관찰 처리.
- AfterToolCall → 별도 SQLite 증거 → 후보 1개 → 회귀 평가 → 명시적 승격/rollback.
- task skill과 고정 meta-skill 분리. SOUL/정책 자동 변경 제외.
- 자동 제안 하루 1회, 동시 진화 워커 1개, 실패 요청도 예산에 포함.
- Reflector/end-of-turn 자동 skill review 비활성화. 별도 DB 서버와 GPU 상주 모델 없음.
- Ghostty + Niri + Herdr를 사용자 UI 기준으로 문서화.

배포 명령 `make reconfigure-home NON_GUIX_UPDATES=0` 종료 코드 0.
Guix Home, 추가 profile, Stow까지 실행했고 관련 없는 비 Guix 일괄 업그레이드는
생략했다. 최종 generation: `/gnu/store/zklyqq9n35zplhbwa9mxsbbg0aq209c7-home`.
서비스 교체 후 microclaw와 mcron을 재시작했다.

## 확인한 증거

| 요구 사항 | 검사 및 결과 |
|---|---|
| ChatGPT 연결 | `codex login status`: Logged in using ChatGPT; MicroClaw 실제 응답 `MICROCLAW_READY` |
| 런타임 스킬 주입 | 실제 `activate_skill(local-workflow)` 실행 후 검증 규칙 응답, run `38a13a75-c29a-48d0-8fdf-21c629cabb3b` |
| 실제 실패 수집 | 존재하지 않는 `/tmp/microclaw-m1-final-missing-fixture.txt`의 read_file 오류를 hook이 기록; run `4b7c2f33-6c63-45f9-8860-8cc5391cedfb` |
| 자동 Fast 경로 | `tick`으로 후보 `3030765bdf0b` 생성; 재호출은 daily proposal budget exhausted |
| baseline/challenger 평가 | 환경 오류 분류와 작업 실패 판정 2개 fixture; 양쪽 모두 2/2, eligible=false, 실제 4회 추론·11.877초 |
| 보관과 선택 | 후보 2개 rejected 상태로 아카이브 유지; champion 변경 없음 |
| 승격/rollback 조건 | 단위 검사에서 개선 시 승격/rollback, 회귀·미평가·증거 변경 시 거부 검증 |
| 테스트 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_microclaw_evolve.py`: 13개 통과 |
| 설정 | `microclaw --config ~/.local/share/microclaw-workflow/gateway.json config check`: Config OK |
| 서비스 | Shepherd microclaw/mcron 실행; `herd schedule mcron`에 매시 00/30분 microclaw-evolution |
| HTTP | `/health`: ok=true, version=0.11.1; `/api/auth/status`: has_password=true, using_default_password=false |
| 배포 일치 | 예약 작업이 참조하는 store의 microclaw-evolve와 소스 SHA256 일치 |
| 변경 형식 | `git diff --check` 통과 |

실제 평가 아카이브는 `~/.local/share/microclaw-workflow/evolution/archive/3030765bdf0b/`.
현재 champion SHA256:
`fd192e10fa0c11f4128dd4e0b83ad0660f5587d74466b6b9a7d43687e19836b9`.
첫 후보 `f86dd22b8f63`은 이전 연결용 fixture 평가 기록이다. 최종 후보는 당시 trace,
meta-skill, baseline, 후보, 점수와 출력·호출 수·지연을 함께 보관한다.

## 해석과 다음 반복

점수 향상은 관측되지 않았다. 동점 후보를 거부한 것이 이번 선택 규칙의 정상 동작이다.
M1은 작동하는 개선 기반이며, 실제 프로젝트 성능 향상이나 완전한 MetaSkill-Evolve
재현을 주장하지 않는다. Slow meta-skill 자기개선은 M3에서 구현한다.

Herdr 0.8.2 client/server 호환과 claude/agy kind, 로컬 실행 파일은 확인했다.
Claude/AGY를 실제 자동 작업자로 기동하거나 계정별 추론까지 검증하지 않았다.
M1의 위임 스킬은 Herdr 안에서 명시적으로 실행하는 계약이며, Web gateway에서
Herdr로 자동 연결하는 dispatcher는 M2의 구현 항목이다.

M2의 첫 작업은 guix-system 실제 과제 10개 이상과 고정 holdout을 작성하는 것이다.
그 뒤 반복 평가를 통해 후보를 선택하고, Herdr dispatcher의 작업·결과 계약과 busy
lease를 붙인다. MicroClaw 기본 도구/스킬 설명으로 요청당 약 12k 입력 토큰이 관측되어,
실제 비용·컨텍스트 감소도 M2에서 측정한다. 별도 벡터/그래프 서버는 아직 필요하지 않다.

작업 전부터 있던 채널·패키지·zeroclaw 전환 변경은 유지했다. 이번 변경을 commit/push하지 않았다.
