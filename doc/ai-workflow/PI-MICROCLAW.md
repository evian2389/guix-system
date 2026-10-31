# Pi ↔ MicroClaw 실험용 터미널 연결

2026-10-31. Pi Rust 0.1.15 / MicroClaw 0.11.1 / Herdr 0.8.2에서 확인했다.

```text
Ghostty → Herdr pane → Pi TUI (frontend tools off)
                         ↓ loopback Chat Completions adapter
                     MicroClaw run --session (Terra 6.1)
                         ↓
                     공용 skills / 실행 DB / workflow-evolution
```

## 사용

프로젝트 폴더에서 실행한다. Pi에 별도 모델/구독을 연결할 필요는 없다.

```sh
cd ~/work/your-project
~/.local/bin/pi-microclaw
# 같은 프로젝트의 별도 backend 대화
~/.local/bin/pi-microclaw --session issue-123
# 터미널 UI 없이 동일 경로 검사
~/.local/bin/pi-microclaw --session smoke --prompt 'Reply with exactly: READY'
```

기본 backend 세션 키는 `pi-<프로젝트 절대 경로 SHA256 앞 12자리>-default`다.
같은 프로젝트와 --session 이름으로 다시 실행하면 MicroClaw 문맥을 재사용한다.
프로젝트 이동/이름 변경은 다른 세션이 된다. PC 간 대화 DB 동기화는 이 기능에 포함하지 않는다.

Pi의 `/new`는 frontend 대화만 초기화한다. **backend까지 새 대화로 시작하려면 launcher를
재실행하면서 다른 --session을 사용한다.** Pi의 /model로 backend 모델을 바꾸지 않는다.
실제 모델은 기존 MicroClaw gateway.json 설정을 따른다.

Herdr에서는 사용 가능한 shell pane에 launcher를 실행한다.

```sh
herdr pane run <pane-id> '~/.local/bin/pi-microclaw --session issue-123'
# UI가 열린 후
herdr agent rename <pane-id> microclaw-ui
herdr agent prompt microclaw-ui '작업 요청' --wait --timeout 300000
```

실제 Pi 프로세스와 표준 `pane report-agent` 상태 보고를 함께 사용하여
Herdr의 foreground 검사와 working/idle 감지를 통과한다. 이름은 해당 pane의 agent
점유자가 바뀌면 해제된다. 기존 다른 pane은 조작하지 않는다.

## 구현과 격리

- Python 표준 라이브러리 HTTP 어댑터가 실행 중에만 `127.0.0.1:10962`를 연다.
  서버를 부팅 서비스로 상주시켜 두지 않는다. PC당 동시 launcher는 1개다.
- API 토큰은 실행마다 새로 생성하고 mode 0700/0600의 임시 Pi profile 파일로 전달한다.
  stdout, shell argv, Git에 넣지 않으며 종료 시 임시 profile을 삭제한다.
- 기존 Pi profile의 OAuth 토큰은 읽거나 복사하지 않는다. 설치된 Pi는 기존 Anthropic
  토큰 만료 때문에 초기 실행에 실패했으므로 `PI_CODING_AGENT_DIR`/`PI_CONFIG_PATH`를
  전용 임시 profile로 지정했다. 기존 사용자 인증이나 default provider는 바꾸지 않는다.
- 영속 frontend 세션과 시드 모델 설정은 `~/.local/state/pi-microclaw/agent`에 둔다.
  기존 Herdr Pi integration 파일이 있으면 전용 profile에서 참조한다.
- Guix에서 기존 Pi ELF를 직접 실행할 수 없어 원본을 유지한 채
  `~/.local/libexec/pi-microclaw/pi`에 복사하여 loader/rpath를 patch한다.
  glibc/GCC 경로와 원본 SHA가 바뀌면 다시 생성한다. 최초 실행에 `guix build patchelf`가
  필요하며 현재 캐시에는 있다. 일반 Pi release를 덮어쓰거나 업그레이드하지 않는다.
- Pi 내장 도구·skill·prompt template을 끄고 사용자 최신 메시지만 MicroClaw에 전달한다.
  Pi system prompt와 frontend 과거 대화를 중복 주입하지 않는다. 실제 문맥·스킬·도구
  실행은 MicroClaw가 소유한다. 모델 호출을 하는 상위 조정 에이전트는 추가하지 않았다.
- 임시 MicroClaw 설정은 기존 data_dir/model/policy를 유지하고 작업 경로만 프로젝트
  절대 경로 및 `working_dir_isolation: direct`로 지정한다. 파일 접근 symlink 검사를
  끄지 않는다. Telegram/Web gateway 설정 파일 자체는 변경하지 않는다.
- HTTP 요청은 bearer 인증, 최대 1 MiB, 텍스트 100k자, backend 동시 1개로 제한한다.
  이미 완료된 동일 frontend turn의 HTTP 재시도는 메모리 캐시로 중복 실행을 피한다.
  프로세스 재시작·실행 중 취소의 exactly-once 보장은 아니다.
- timeout 기본 600초(최대 3600). 클라이언트 연결 종료/서버 종료 시 어댑터 소유의
  MicroClaw subprocess group을 종료한다. 다른 gateway나 에이전트는 종료하지 않는다.

Guix Home activation은 `pi-microclaw setup`으로 전용 profile과 관측 hook을 준비한다.
실제 UI/어댑터는 사용자가 launcher를 실행할 때 시작된다.

## 진행 표시와 승인 전달

Pi에는 `[MicroClaw] 시작: read_file`, `완료`, `오류`, `승인 필요`와 응답 준비 상태가
실행 도중 표시된다. `setup`이 MicroClaw data root에 설치하는 `pi-microclaw-progress`
hook이 도구 메타데이터만 임시 JSONL 파일에 기록하고, 어댑터가 이를 SSE로 전달한다.
추가 LLM 호출이나 상주 데몬은 없다. hook은 승인/차단/도구 입력 패치를 하지 않으며,
어댑터 실행 환경의 이벤트 경로가 없으면 아무것도 기록하지 않는다. 기존 evolution
hook은 유지된다. hook을 명시적으로 끈 설정에서는 launcher가 진행 표시 요구를 알리고 종료한다.

CLI 실행 완료 후 같은 chat의 `pending_approval_tool:<chat_id>`를 SQLite read-only로
조회한다. 1시간 이내의 네이티브 pending marker가 있을 때만 Herdr에 `blocked`를 보고하고
Pi에 MicroClaw의 승인 카드를 표시한다. 응답 텍스트에 승인이라는 단어가 있다는 이유로
승인 상태를 만들지 않는다. 입력은 사용자가 Pi 창에서 직접 한다.

- `1`: 이번 승인 후 재개.
- `2`: 해당 대화에서 그 도구를 계속 허용하는 MicroClaw의 standing grant.
- `3`: 거절. 다른 지시도 이전 승인을 허용하지 않는다.

어댑터는 다음 사용자 메시지 원문만 같은 backend 세션에 보내며 자체 승인 메시지를
생성하지 않는다. 승인은 MicroClaw의 다음 turn을 재개하는 의미이며, 특정 명령의
해시에만 묶인 일회성 실행 허가를 구현한 것은 아니다. Herdr의 `agent prompt`는
blocked 에이전트에 입력하지 않으므로 이때 사용자는 Pi 입력창에서 답한다.

MicroClaw 0.11.1의 headless 채널은 Web/Work 채널의 일반 high-risk 확인 조건과 다르다.
따라서 `high_risk_tool_user_confirmation_required`가 true이면 Pi 임시 설정의
`bash_dangerous_patterns`에 `(?s).+`를 추가한다. 모든 비어 있지 않은 bash 명령을
**기존 네이티브 승인 경로**로 보내기 위한 설정이다. control-chat 권한은 추가하지 않고,
gateway 설정 파일도 바꾸지 않는다. 명시적인 false와 사용자 지정 기존 패턴은 보존한다.
write_file/edit_file 등 upstream에서 medium risk인 도구마다 확인 창을 추가하지는 않는다.

진화 이력의 `approval_required`는 `outcome=unknown`, `failed=0`으로 보관하여
실패 기반 스킬 개선 후보에서 제외한다. 초기화 시 같은 error_type으로 저장된 기존
실패도 재분류하며 관찰 행은 삭제하지 않는다.

## 현재 한계

- text-only. 이미지·client tool 정의가 들어오면 명시적으로 거부한다.
- 도구 메타데이터는 실시간 전달하며 최종 답변은 headless 실행 종료 후 전달한다.
  모델 토큰 단위 스트리밍과 도구 원문 transcript는 제공하지 않는다.
- 승인은 네이티브 텍스트 카드와 다음 사용자 입력으로 전달한다. 별도 버튼, 실행 중
  임의 승인 resolve API, 자동 승인은 구현하지 않는다. native ACP 0.11.1도 tool/approval
  이벤트를 클라이언트에 전달하지 않아 이번 연결의 대체 경로로 사용하지 않았다.
- launcher 재시작 직후 기존 승인 marker의 자동 복원/알림은 아직 없다. 같은 --session의
  native pending marker는 backend에 남으며 다음 사용자 입력은 upstream 규칙대로 처리된다.
  자동 세션 재기동도 후속 과제다.
- usage는 runtime의 iteration 로그에서 합산한 관측치이며 공급자 청구의 보증은 아니다.
  token 수치가 없으면 0으로 표시될 수 있다. frontend에는 backend 내부 tool transcript가 없다.

## 검증 결과

- 진화 29개 + 어댑터 17개 = 46개 unittest 통과.
- 실제 Pi→adapter→MicroClaw 호출: PI_MICROCLAW_READY 및 PI_NATIVE_READY 응답.
- Herdr `agent prompt --wait`가 working 활동을 관측하고 idle까지 정상 대기.
- 첫 turn에 저장한 code를 다음 turn에서 동일하게 회상.
- 프로젝트의 상대 경로 README.md를 실제 read_file로 읽고 `# ai-workflow` 반환.
- 최초 workspace symlink 거부를 재현한 뒤 direct 설정으로 해결. 보안 검사 유지.
- 인증 거부, busy 거부, JSON/SSE 응답, 성공한 요청 재시도 캐시, subprocess 취소/timeout,
  기존 OAuth 보존, 색상 로그 usage 해석, 프로젝트 root 및 policy 보존을 검사했다.
- 도구 실행 종료 전에 SSE가 실제 flush되는지, 관측 hook의 도구 입력/결과 비저장,
  chat별 승인 조회/만료/읽기 전용, 승인 대기 blocked 및 승인/거절 원문 전달·재시도 캐시,
  bash 확인 활성/명시적 비활성, 승인 대기의 진화 실패 제외와 이전 이력 재분류를 검사했다.
- live Pi에서 README read_file 시작/완료 표시 및 결과 `ai-workflow`를 확인했다.
  무해한 `printf MICROCLAW_APPROVAL_READY` 요청으로 native 승인 카드와 Herdr blocked를
  확인했고 답하지 않은 상태로 남겼다. live 승인 이후 실행/거절 완료는 아직 검사하지 않았다.

다음 반복은 사용자 승인/거절 후 재개를 live로 확인하고, launcher 재시작 시 pending
상태 복원과 세션 수명 관리부터 진행한다. 승인 버튼용 Pi extension은 API 호환성을
검증한 뒤 별도 선택한다.

실제 UI는 이번 세션에서 생성한 Herdr pane `w11:p3`에 있다. public ID는 해당 Herdr
server 세션의 핸들이므로 다른 PC/새 server에서 재사용하지 않는다.
