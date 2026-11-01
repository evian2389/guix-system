# 스킬 후보의 코딩 과제 평가 (M2)

기존 `workflow-evolution evaluate`는 모델에게 짧은 분류 질문을 던져 글자가 맞는지만 보는 텍스트 평가이며
코딩 성능은 측정하지 못한다. M2는 실제 코드 변경 과제로 후보 스킬(`local-workflow`)을 챔피언과 비교한다.
승격(`promote`)은 사람이 하며, 이 평가는 자동 승격하지 않는다.

## 명령 (`workflow-evolution`)

| 명령 | 동작 |
|---|---|
| `evaluate-tasks <후보> [--budget N]` | 평가 계획을 만들고 N회(기본 `task_step_budget`)까지 실행 |
| `evaluate-step [--budget N]` | 진행 중인 모든 평가를 이어서 실행. 할 일이 없으면 모델 호출 없음 (mcron이 사용) |
| `task-status` | 후보별 진행률, 적격 여부, 오늘 사용량 |

결과는 후보 폴더(`evolution/archive/<id>/`)의 `tasks-run.json`(시도별 기록, 매 시도마다 저장)과 끝났을 때
`evaluation-tasks.json`(보고서)이다.

## 방식
- **과제**: `evolution/m2/tasks.json`의 개선 과제 9개(개발 5, holdout 4)를 챔피언·후보 각각 `task_repeats`(3)회.
  `evolution/m2/regression/`의 회귀 모음은 성공률에는 넣지 않고 후보가 더 많이 깨뜨리면 거부.
- **스킬 전달**: 매번 붙여 넣지 않는다. 시도마다 임시 `HOME`을 만들어 그 안의 `~/.agents/skills/local-workflow/SKILL.md`에
  해당 팔의 스킬만 두면 Codex가 운영과 똑같이 스스로 찾아 읽는다(인증은 실제 `CODEX_HOME`).
- **격리**: 기준 커밋(`baseline.json`의 head)을 `git archive`로 새로 풀고, 최소 환경변수만 넘기고, `workspace-write`
  샌드박스에 네트워크를 끈다. 판정은 작업자가 볼 수 없는 평가자 테스트(`evolution/m2/tests`, `regression/tests`)로 한다.
- **holdout 잠금**: 시작과 매 단계마다 `holdout.lock`(과제·테스트·지원 코드 해시)을 검증하고, 바뀌었으면 거부.
  챔피언·후보·과제·설정 중 하나라도 바뀌면 이어 하지 않는다.
- **저비용 모델**: 기본 `gpt-6-luna`, 추론 `low`. 시도 1회가 약 10초, 입력 토큰 약 7만(대부분 캐시), 출력 약 700.
  설정(`evolution/config.json`): `task_model`, `task_effort`, `task_repeats`, `task_timeout`(초),
  `task_step_budget`(한 번에 실행할 시도 수), `task_daily_attempts`(하루 상한, 기본 18).

## 적격(eligible) 조건 (모두 만족)
1. 오류(시간 초과·환경 오류)가 전체 시도의 20% 이하.
2. 회귀 모음을 깨뜨린 시도 수가 챔피언보다 많지 않다.
3. 개발 과제 합계가 나빠지지 않았다.
4. 어떤 holdout 과제도 챔피언보다 나빠지지 않았고, holdout 합계가 개선되었다.

`config.json`의 `require_task_eval: true`이면 `promote`가 일치하는 적격 `evaluation-tasks.json`을 요구한다
(텍스트 평가는 "나빠지지 않음"만 요구). 증거 해시가 하나라도 다르면 다시 평가해야 한다.

## mcron
`~/.config/cron/evolve-eval.guile`가 3시간마다 `evaluate-step`을 실행한다(로그 `~/.local/state/evolve-eval.log`).
평가 **시작**은 사람이 `evaluate-tasks`로 하고, 이후는 cron이 하루 상한 안에서 이어서 끝낸다.
mcron 서비스는 파일을 시작할 때 읽으므로 새 파일은 `herd restart mcron` 후 적용된다.

## 한계
- 과제가 작은 Makefile/Python 변경 9개라 큰 차이만 가려낸다. 반복 3회는 통계적 확신을 주지 못한다.
- 스킬(`local-workflow`)의 효과만 본다. 모델이나 다른 스킬 변경은 평가하지 않는다.
- 참조 해법이 있어 테스트가 만족 가능함은 확인했지만, 작업자가 테스트를 맞추는 편법을 쓸 가능성은 샌드박스와
  별도 테스트 위치로만 줄였다.
