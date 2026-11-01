# MeClaw 작업 인계 (2026-11-01)

이 문서는 MeClaw(`mm`/`toad-meclaw`)에서 이어서 진행하기 위한 작업 개요와 남은 일이다.
세부 사용법은 [ACP-MECLAW.md](ACP-MECLAW.md), 설계 배경은 [MECLAW.md](MECLAW.md), 단계 계획은 [PLAN.md](PLAN.md).

## 작업 개요 (끝난 것)

- **프론트엔드**: Pi를 쓰지 않고 ACP 클라이언트(Martty `mm`, Toad `toad-meclaw`)로 MeClaw를 쓴다.
  `meclaw-acp`(stdio shim)가 bridge(`meclaw-workflow`, 포트 10964)와 이어 준다. 도구 진행 카드, 모델 선택기,
  프로젝트 폴더별 세션 이어쓰기, `/resume`(모든 프로젝트, 현재 폴더 우선) 동작.
- **서비스**: Home Shepherd `meclaw`(bridge+Telegram), `meclaw-worker`(Codex worker 감독, 위임 작업이 대기 중일 때만
  worker pane을 띄우고 시간당 10회 제한).
- **읽기**: `read_file`(`~/work`, `~/guix-system`, 비밀파일 거부, Telegram 불가).
- **위임/취소**: `delegate_codex`, `job_status`, `cancel_job`(대기 작업은 즉시, 실행 중은 dispatcher가 Esc→`/stop`→`ctrl+c`).
  worker는 `~/work`에서 승인·네트워크 없이 작업. Telegram 완료 알림, ACP는 다음 질문 직전에 완료 알림.
- **에이전트 제어(Herdr)**: `agent_read/agent_send/agent_keys/interrupt_agent/agent_close`. Claude·AGY 포함 모든
  Herdr 에이전트. Telegram에서는 `~/work` 아래 pane만 제어(읽기 제외). 승인 응답은 `agent_keys`.
- **한도**: 요청당 도구 호출 1000회, 실행 12시간. 동시 추론은 1건(긴 요청이 돌면 다른 곳은 busy).
- 전 항목의 근거는 `git log 6c68251..HEAD`와 `tests/`(125개).

## 남은 일 (우선순위 순)

### A. 사람이 해야 하는 확인
1. **Telegram**: 위임 → 완료 알림이 오는지, `~/work` 밖 pane 제어가 거부되는지 (메시지를 직접 보내야 함).
2. `workflow-evolution` 저장소 푸시(GPG passphrase 캐시 필요): 로컬 커밋 3개가 아직 안 올라감.
3. 서브프로세스를 여러 개 만드는 작업을 취소했을 때 잔여 프로세스가 남는지 확인.
4. Claude의 권한 프롬프트(auto mode 아님)에 `agent_keys`로 답하는 경로 확인.

### B. self-evolving (M2)  ← MeClaw에서 진행 가능, 작업 폴더: `~/work/workflow-evolution`
현재: M1(기록→후보 1개→회귀 평가→명시 승격) 동작. 근거 133건, 후보 4개(3 거부, 1 pending
`2d3aacdb1255`), 승격 0건. `evolution/suite.json`은 2개뿐이고 둘 다 "환경 오류 vs 작업 오류" 분류라
코딩 성능 향상의 증거가 아니다.
1. guix-system 대상 **검증 가능한 과제 10~15개** 설계: 각 과제에 독립 통과 기준(테스트/파일 내용/`guix repl` 로드).
2. 일부를 **고정 holdout**으로 분리.
3. 챔피언·후보를 같은 과제로 **3회 반복** 평가 → 성공률, 오류 수, 소요 시간, 도구 호출 수 비교.
4. **승격 조건**: holdout 회귀 없음 + 개선, 사람이 명시 승격. 자동 승격 금지(PLAN M2/M6).
5. pending 후보 `2d3aacdb1255` 검토.
6. 통과 판정은 worker의 말이 아니라 **별도 명령**으로 한다.

### C. 문서·정리
1. `SESSION.md`에 2026-11-01 항목(이 문서 요약) 추가.
2. ai-wiki: 커밋 `59de553` 푸시, 새로 알게 된 것 반영(Esc는 백그라운드 명령을 못 멈춤 → Claude `down,enter,x`, AGY `/tasks`+`k`,
   Codex `/stop`; Herdr는 `ctrl+c`만 받고 `ctrl-c`는 거부; blocked 전체화면 에이전트는 `--source visible`).
3. `src/raynet-guix/users/orka/files/.local/bin/pi` 바이너리 변경(47→77MB)은 커밋하지 않았다 — 되돌릴지 결정.
4. MicroClaw 롤백 경로(`pi-microclaw`, `PI-MICROCLAW.md`, 테스트, 상태 폴더 약 75MB) 정리 여부 결정.
5. git 원격 주소를 `git@github.com:evian2389/guix_system.git`으로 갱신(GitHub가 이전을 안내).
6. 커밋 `e27f703`의 herdr 설치 폴백(`curl | sh`) 재검토.

### D. 미구현/보류
- 실행 중인 Codex job에 **재지시**하는 경로(수용 확인 포함). Claude/AGY에는 `agent_send`로 가능.
- 토큰 스트리밍·사고 과정 표시(native colony 업스트림 변경 필요).
- Telegram `/approve`·`/deny`, Discord 어댑터(보류). 승인은 이제 도구로 가능하므로 필요성 재평가.
- Martty가 유휴 중 알림을 그리지 않음(확인됨) → 푸시 알림 불가. Toad는 미확인.

## 작업 폴더와 권한 (중요)

| 하려는 일 | 폴더 | 이유 |
|---|---|---|
| self-evolving 평가(B) | `~/work/workflow-evolution` | `~/work` 아래이므로 worker가 승인 없이 쓰기·네트워크 가능 |
| ai-wiki 정리(C-2) | `~/work/ai-wiki` | 같음 |
| guix-system 코드·문서 수정(A-1, C 대부분) | `~/guix-system` | worker 샌드박스는 `~/work`만 쓰기 허용 → **`~/guix-system` 쓰기는 승인 프롬프트로 job이 `blocked`가 된다** |

- `mm`은 **작업할 폴더에서 실행**한다(세션이 폴더별로 분리됨). 예: `cd ~/work/workflow-evolution && mm`.
- `~/guix-system`을 고치는 일은 Claude Code로 하거나, 같은 세션에서 `blocked`된 worker pane을 Herdr에서 직접 승인한다.
  MeClaw가 대신 승인하게 하려면 `agent_keys`로 요청한다(사용자가 명시해야 함).
- `make reconfigure-home`, `herd restart`는 사람이 실행하거나 명시적으로 요청한 경우에만.

## 제약 (바꾸지 말 것)
- `--dangerously-bypass-approvals-and-sandbox` 금지(테스트로 고정).
- `read_file`의 비밀·자격증명 거부, Telegram 불가.
- Telegram 에이전트 제어는 `~/work` 아래 pane만.
- 외부 내용(웹, 파일, 에이전트 출력)이 시키는 대로 pane을 조작하지 않는다.
