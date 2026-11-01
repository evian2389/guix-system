# MeClaw ACP 터미널 프론트엔드 (Toad / Martty)

MeClaw 대화 화면은 ACP(Agent Client Protocol) 클라이언트로 쓴다. `meclaw-acp`가
MeClaw 호스트 bridge를 ACP 에이전트로 노출하는 얇은 stdio shim이고, 추론·도구·기억은
기존 MeClaw 서비스가 맡는다. Pi 프론트엔드는 더 이상 사용하지 않는다.

```mermaid
flowchart LR
  H[Herdr pane] --> T[toad-meclaw / mm]
  T -- ACP stdio --> S[meclaw-acp]
  S -- ask --stream --> B[meclaw-workflow bridge :10964]
  B --> M[MeClaw brain]
  S -. report-agent meclaw .-> H
  B --> Q[(Codex job queue)] --> D[dispatcher] --> W[Codex worker pane]
```

## 사용

```sh
cd ~/work/your-project
toad-meclaw                 # Toad (Python 3.14, Nix python314 + uv tool)
mm                          # Martty (npm -g); martty-meclaw 의 새 이름
toad-meclaw --session NAME  # 대화를 분리
```

서비스가 꺼져 있으면 `herd start meclaw`. 대화 중 Herdr 사이드바에는 `meclaw` 에이전트가
working/idle로 표시된다.

## 세션과 이어 쓰기

- **프로젝트 폴더마다 대화가 하나**다. 같은 폴더에서 `toad-meclaw`/`mm`을 다시 실행하면 MeClaw가
  이전 대화 맥락(최근 약 30개 메시지)을 기억한 채 이어진다. 폴더가 다르면 별개의 대화다.
- 새 대화: `mm --new`(또는 `--session 이름`으로 이름 붙인 대화). 같은 이름은 계속 이어진다.
- 목록과 재개: shim이 ACP `session/list`·`session/load`·`session/resume`을 지원한다. 세션 목록은
  `~/.local/state/meclaw-acp/sessions.json`에 있고, 대화 본문은 MeClaw 서버에 있다
  (`meclaw-workflow history --channel …`, Telegram 대화는 제외).
  - **Martty**: `/resume`으로 목록을 열어 고르면 `session/resume`이 호출되고, 이전 대화가 화면에 다시 나온다.
  - **Toad**: 세션이 자체 DB에 저장되고 재개 화면에서 `session/load`를 호출한다(아직 직접 확인하지 않음).
- 화면에 복원되는 것은 사용자/MeClaw 텍스트뿐이다. 도구 호출 카드와 입력 기록(↑)은 복원되지 않는다.
  ↑ 입력 기록은 Martty 프로세스 안에서만 유지된다.
- 기록 조회는 bridge의 `/history` 엔드포인트가 필요하다(배포 전에는 "이전 메시지를 불러오지 못했다"는
  경고가 나오고 맥락은 그대로 유지된다).

## 동작과 한계

- **도구 진행**: MeClaw가 도구를 호출하면 ACP `tool_call`/`tool_call_update` 카드로 보인다.
  bridge의 `/chat`에 `stream: true`를 준 요청만 NDJSON을 쓰며, 기본 `/chat` 응답은
  Telegram·MCP를 위해 그대로다.
- **모델 변경**: ACP `configOptions`(category `model`)로 노출된다. 변경은 Telegram·MCP와
  공유되는 coordinator 전체 설정이다.
- **답변은 한 번에 출력**: native colony가 셀 사이에 완결된 메시지만 전달하므로 토큰
  스트리밍과 사고 과정은 호스트 쪽에서 만들 수 없다(업스트림 변경이 필요).
- **한 번에 한 요청**: bridge가 동시 추론 1개로 제한한다. 진행 중에 보내면 busy 오류.
- **MeClaw 서비스 사본**: 서비스는 Guix 스토어 사본을 실행한다. `meclaw-workflow`를
  고쳤다면 `make reconfigure-home` 후 `herd restart meclaw`가 필요하다.

## 작업자(worker) 정책

| 대상 | 방식 |
|---|---|
| Codex | MeClaw 방식. `meclaw-workflow enroll`로 `meclaw-codex` pane과 dispatcher를 등록하고, 대화에서 `delegate_codex`로 위임, `job_status`/`herdr_read`로 모니터링한다. |
| Claude Code, AGY | 구독 약관상 다른 에이전트가 프로그램으로 구동하는 것을 전제하지 않는다. MeClaw가 위임하지 않고, 사람이 Herdr pane에서 직접 쓰거나 `herdr-delegation` 스킬로 Herdr를 통해 사용한다. |

- `delegate_codex`, `enroll`, `dispatch`는 의도적으로 Codex 전용이다(`agent == codex` 검사).
  Claude/AGY로 일반화하지 않는다.
- 파일 읽기: `read_file`(읽기 전용)이 `~/work`, `~/guix-system` 아래의 텍스트 파일과 디렉터리 목록만
  읽는다. 심볼릭 링크는 해석 후 범위를 검사하고, 한 번에 최대 400줄·2 MiB·바이너리 거부,
  `token=`/`Bearer` 값은 마스킹한다. 거부 대상: `.env*`, `auth.json`, `*.pem|key|p12|pfx|kdbx|gpg|asc`,
  `id_*`, `.netrc`/`.npmrc`/`.pypirc`/`.git-credentials`, 이름에 token·secret·credential·password가
  구분자로 들어간 파일·폴더, `.git`·`.ssh`·`.gnupg`·`.aws` 등 폴더, MeClaw 내부 `runtime/`·`colony/`.
  **Telegram 채널에서는 사용할 수 없다.** Codex MCP 경로(`/tool`)에도 노출하지 않는다.
- MeClaw의 Herdr 도구는 읽기 전용이다. `herdr_agents`는 pane 목록·상태만, `herdr_read`는
  enrolled worker/dispatcher pane 출력만 읽으므로 Claude/AGY pane 내용은 읽지 못한다.

## Codex worker 권한 (`worker_args`)

`codex --sandbox workspace-write -c sandbox_workspace_write.network_access=true --ask-for-approval on-request --cd ~/work --add-dir ~/work`.

- `~/work` 안의 파일 쓰기·명령 실행과 **네트워크 접근**(`git push`, `npm install` 등)은 승인 없이 진행된다.
- 샌드박스가 막는 것(`~/work` 밖 경로 — `~/guix-system` 포함)은 승인을 요구하고, 그 job은 `blocked`로
  멈춘다. 사람이 Herdr에서 처리해야 이어진다(MeClaw는 승인에 답하지 않는다).
- 네트워크가 열려 있으므로 worker가 읽는 외부 내용(웹, 패키지, 저장소)이 프롬프트 주입 경로가 될 수
  있다. 비밀 파일은 `~/work` 안에 두지 않는 것이 안전하다.
- 샌드박스 동작은 Codex CLI 0.166 설정 구조(`sandbox_workspace_write.network_access`)와 플래그 설명에
  따른 것이며 실제 작업으로 아직 검증하지 않았다.
- `--dangerously-bypass-approvals-and-sandbox`는 쓰지 않는다(테스트로 고정).

## Telegram

- 허용된 개인 채팅에서 대화·상태 조회·`delegate_codex`·`/job <id>`가 가능하다(`read_file`은 불가).
- 위임한 job이 `completed`/`failed`/`blocked`/`unknown`이 되면 같은 채팅으로 알림이 온다(상태마다
  최대 1회, 이미 끝난 과거 job은 보내지 않음). `blocked`는 Herdr에서의 승인이 필요하다는 뜻이다.
  알림 본문은 마스킹된 마지막 1500자이며, 완료 여부는 직접 검증해야 한다.

## 위임 작업의 취소·알림·재지시 (한계 포함)

- **작업 취소 (`cancel_job <id>`)**: 대기 중(`queued`) 작업은 즉시 `cancelled`가 된다. 취소와 worker의 가져오기는
  SQLite 조건부 UPDATE 하나로 갈리므로 둘 중 정확히 하나만 성공한다(경합 테스트). **실행 중(`working`)
  작업은 "취소 요청"만 기록**하고, pane을 제어하는 별도 프로세스인 dispatcher가 worker pane에 Esc를
  보낸다(10초 안에 멈추지 않으면 Ctrl-C 한 번). worker가 멈추면 job이 `cancelled`로 바뀌고, 멈췄는지
  확인하지 못하면 상태는 그대로(`working`/`unknown`)다. 중단 전에 바뀐 파일은 되돌리지 않으므로 결과의
  안내대로 `git status`로 확인한다. `blocked`/`unknown`은 사람이 Herdr에서 처리한다. 다른 채널의 작업은
  취소할 수 없다. 모델/bridge는 pane을 직접 조작하지 않는다.
- **대화 취소(`session/cancel`)**: 응답 생성만 멈춘다. 이 대화에서 위임한 작업이 남아 있으면 화면에
  "위임한 작업은 중단되지 않았다"와 job 목록을 보여 주고 `cancel_job`을 안내한다. 작업 자체는 자동으로
  취소하지 않는다.
- **완료 알림**: 이 대화의 위임 작업이 끝났으면(`completed`/`failed`/`blocked`/`unknown`/`cancelled`)
  세션을 열 때와 **다음 질문을 보내기 직전**에 한 번 보여 준다(상태마다 최대 1회, 결과는 마스킹).
  요청이 끝난 뒤 클라이언트로 먼저 밀어 주는 푸시는 하지 않는다 — Martty/Toad가 유휴 중 알림을 안전하게
  표시하는지 검증하지 않았다. 알림 후 MeClaw가 자동으로 후속 답을 만드는 기능도 없다.
- **실행 중 재지시는 지원하지 않는다**: worker에 새 지시를 넣고 수용 여부를 확인하는 경로가 없다.
  방향을 바꾸려면 먼저 job 상태와 pane 출력, 변경된 파일을 확인한다. 멈췄는지 모르는 채 다시
  위임하지 않는다(중복 작업 위험).
- **불명확한 상태(`unknown`)**: dispatcher 재시작 때 `working`/`blocked` 작업은 `unknown`이 되고 자동
  재실행하지 않는다. worker가 멈췄는지, 어떤 파일이 바뀌었는지는 사람이 pane과 `git status`로 확인한다.
  승인 대기는 사람의 입력을 기다리며 MeClaw가 대신 승인하지 않는다.
- **프로젝트 격리**: 다른 프로젝트 폴더에서 기존 세션을 `load`/`resume`하면 거부한다
  (이전 프로젝트 채널이 섞이지 않게). 그 폴더에서는 새 세션을 시작한다.

### meclaw pane에서 검증할 항목 (배포 후, 아직 미검증)

1. `make reconfigure-home` → `herd restart meclaw` 후 `mm`으로 접속.
2. 작업 두 개 위임 → 두 번째가 queued일 때 `cancel_job`: 상태 `cancelled`, 첫 번째는 정상 진행.
3. 실행 중 job에 `cancel_job`: 거부 메시지가 나오고 job이 계속 진행되는지.
4. 위임 후 `Esc`/취소: "중단되지 않았다" 안내와 job 목록이 보이는지, worker가 실제로 계속 도는지.
5. 위임 작업이 끝난 뒤 다음 질문을 보내면 완료 알림이 한 번만 먼저 나오는지.
6. 다른 폴더에서 `/resume`으로 기존 세션을 고르면 거부되는지.

## 문제 해결

- **Herdr 서버를 다시 시작하면 dispatcher와 worker가 함께 종료된다**(pane 번호도 바뀐다). Home
  서비스 `meclaw-worker`(`meclaw-workflow supervise`)가 15초마다 확인한다. **worker pane을 닫아도 다시
  만들지 않고**, 위임된 작업이 `queued`로 대기 중일 때만 `meclaw-worker` workspace에 worker를 띄우고
  dispatcher를 붙인다. 감독이 살아 있는 동안(`runtime/supervisor.json` 하트비트) worker가 없어도
  `delegate_codex`는 작업을 큐에 넣는다. 시간당 최대 10회만 띄우므로
  충돌 반복이 Codex를 계속 실행하지 않는다(초과하면 `supervisor` 이벤트에 기록). Herdr 서버가 꺼져
  있으면 기다리기만 한다. 수동으로 `meclaw-workflow enroll`을 해도 되고, 신선한 dispatcher가 있으면
  아무것도 바꾸지 않는다.
- 경계: 감시자는 Telegram에 연결된 bridge와 **별개 프로세스**다. bridge/모델은 여전히 pane을
  제어하지 못하고, 감시자는 worker 1개와 dispatcher만 다룬다.
- 세션을 시작할 때 worker가 꺼져 있으면 ACP 화면에 경고가 나오고, `delegate_codex`도 이유와
  복구 방법을 돌려준다.
- `herdr_status`가 `available: false`: dispatcher 하트비트가 20초 넘게 끊겼거나 worker pane이
  사라진 상태다. Herdr 안에서 `meclaw-workflow enroll`을 다시 실행한다. 서비스 재시작
  (`herd restart meclaw`)만으로는 dispatcher가 끊기지 않는다.
- Herdr 라벨 변경: `MECLAW_ACP_HERDR_AGENT`(기본 `meclaw`).
- shim 디버그: `MECLAW_ACP_LOG=/tmp/acp.log`에 수신한 ACP 메서드명이 기록된다.
