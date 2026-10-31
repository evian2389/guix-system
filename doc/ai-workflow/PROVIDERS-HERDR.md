# ChatGPT + Claude Code + AGY 검토

2026-10-31 확인. 아래 구성으로 진행한다.

사용자 터미널은 Ghostty, 창 관리자는 Niri, 작업 세션은 Herdr를 기준으로 한다.
Ghostty는 Herdr의 표시/입력 계층이며 MicroClaw·SQLite·진화 워커의 인터페이스는
터미널 에뮬레이터에 의존하지 않는다. M1에서 터미널 설치나 기본 앱 변경은 수행하지 않는다.

| 역할 | 실행 경로 | M1 상태 |
|---|---|---|
| 주 조정자 | MicroClaw → openai-codex → 기존 ChatGPT 로그인 | 실제 추론 확인 |
| Fast 진화/평가 | 단일 Python 워커 → 도구 차단된 별도 MicroClaw 호출 → 같은 ChatGPT 모델 | 실제 후보 생성/평가 확인 |
| 구현 작업자 | Herdr의 `claude` kind → 공식 Claude Code CLI 로그인 | 바이너리/kind 확인, 작업별 위임 절차 준비 |
| 독립 검토자 | Herdr의 `agy` kind → Antigravity CLI Google 로그인 | 바이너리/kind 확인, 작업별 위임 절차 준비 |

[OpenAI의 OSS 계정 연결](https://developers.openai.com/siwc/token-sharing-open-source)은
ChatGPT 계정과 허용된 plan usage를 연결하는 공식 경로를 설명한다. 현재 배포는 새 OAuth
클라이언트를 구현하지 않고 [MicroClaw provider](https://github.com/microclaw/microclaw/blob/v0.11.1/site/docs/configuration.md)의
기존 Codex 로그인 지원을 사용한다. 두 인증 흐름을 같은 구현이라고 혼동하지 않는다.
실제 계정의 inference 성공까지 확인했으며, 구독을 무제한 API 사용으로 해석하지 않는다.

[Claude Code 구독 안내](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan)에
따라 Claude는 공식 CLI 로그인으로 사용한다. ANTHROPIC_API_KEY가 설정되면 구독 대신
API 인증을 사용할 수 있으므로 위임 환경의 인증 방식을 확인한다. Claude OAuth 토큰을
MicroClaw의 일반 Anthropic provider로 복사하지 않는다.

[AGY 공식 인증 안내](https://antigravity.google/docs/cli/install/)는 개인 Google 계정
로그인을 지원한다. 개인 구독과 API-key/enterprise 경로는 구분한다. M1에서는 사용자
Google 계정의 실제 AGY 추론/잔여 할당량까지 검사하지 않았다.

## Herdr 연결 경계

현재 `HERDR_ENV=1`, Herdr client/server 0.8.2 protocol 20 호환을 확인했다.
Herdr는 `claude`, `agy`, `gemini` kind를 제공하며 로컬 claude/agy 실행 파일도 있다.
M1은 위임 스킬과 운영 계약을 설치한다. 상주 Shepherd gateway에는 Herdr pane의
호출자 문맥이 없으므로, Web 요청에서 바로 pane을 제어할 수 있다고 가정하지 않는다.
HERDR_ENV 값을 임의로 주입하거나 사용자 focus를 조작하지 않는다.

지금 가능한 경로는 Herdr 안에서 MicroClaw headless를 실행하고 명시적으로 위임하는
방식이다. 작업마다 프로젝트 cwd, 변경 범위, 완료 조건과 검증 명령을 brief로 전달한다.
시작 전 `herdr agent list`, pane 생성/시작은 설치된 Herdr skill을 따른다.
기본 timeout은 검토 300000ms, 구현 540000ms이며 timeout은 실패 판정이 아니다.
blocked 상태의 승인/질문은 사용자에게 전달한다. 결과는 파일 diff와 테스트로 확인한다.

M2에서 Web→로컬 작업 queue→Herdr 내 dispatcher로 확장한다. dispatcher는 사용자
실행 세션에서만 동작하며, job-id·프로젝트 경로 allowlist·멱등성·결과 파일·timeout 후
재조회·명시적 취소를 구현한다. 전체 MicroClaw에 임의 pane 제어 권한을 주지 않는다.
한 번에 구현 또는 검토 작업자 1개만 선택한다. 진화 tick과 무거운 작업의 겹침 방지는
이 dispatcher의 busy lease로 구현한다. M1에서는 worker를 자동 기동하지 않는다.

동일 프로젝트에 Claude/AGY 동시 쓰기는 허용하지 않고 구현→검증→독립 검토 순서로
운영한다. 이후 병렬 작업이 필요하면 별도 worktree를 사용한다. Herdr가 프로세스
지속성을 제공해도 앱별 세션 재개와 PC 간 상태 동기화는 별도 기능이다.
