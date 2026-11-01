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

`codex --sandbox workspace-write --ask-for-approval on-request --cd ~/work --add-dir ~/work`.

- `~/work` 안의 파일 쓰기·명령 실행은 승인 없이 진행된다. (아래 샌드박스 동작은 Codex CLI 0.166
  플래그 설명에 따른 것이며 실제 작업으로 아직 검증하지 않았다.)
- 샌드박스가 막는 것(네트워크, `~/work` 밖 경로 — `~/guix-system` 포함)은 승인을 요구하고, 그
  job은 `blocked`로 멈춘다. 사람이 Herdr에서 처리해야 이어진다(MeClaw는 승인에 답하지 않는다).
- 네트워크가 필요한 작업(`git push`, `npm install` 등)을 무인으로 돌리려면 `worker_args`에
  `-c sandbox_workspace_write.network_access=true`를 넣는 별도 결정이 필요하다. 기본은 꺼 둔다.
- `--dangerously-bypass-approvals-and-sandbox`는 쓰지 않는다(테스트로 고정).

## Telegram

- 허용된 개인 채팅에서 대화·상태 조회·`delegate_codex`·`/job <id>`가 가능하다(`read_file`은 불가).
- 위임한 job이 `completed`/`failed`/`blocked`/`unknown`이 되면 같은 채팅으로 알림이 온다(상태마다
  최대 1회, 이미 끝난 과거 job은 보내지 않음). `blocked`는 Herdr에서의 승인이 필요하다는 뜻이다.
  알림 본문은 마스킹된 마지막 1500자이며, 완료 여부는 직접 검증해야 한다.

## 문제 해결

- **Herdr 서버를 다시 시작하면 dispatcher와 worker가 함께 종료된다**(pane 번호도 바뀐다). Home
  서비스 `meclaw-worker`(`meclaw-workflow supervise`)가 15초마다 확인해서 `meclaw-codex` worker가 없으면
  `meclaw-worker` workspace에 하나를 띄우고 dispatcher를 다시 붙인다. 시간당 최대 3회만 띄우므로
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
