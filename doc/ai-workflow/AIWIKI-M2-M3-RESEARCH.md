# M2/M3 선행 조사: MeClaw 세션 저장 위치와 MCP 연결 (2026-11-07)

`AIWIKI-ORCH-HANDOFF.md`의 M2(입력 경로)와 M3(에이전트 연결)가 "먼저 조사"로 남겨 둔 항목의 결과.
읽기 전용으로 확인했고, **대화 내용은 읽지 않았다**(구조와 개수만). `확인`/`추정`/`미확인`을 구분해 적는다.

## M2: MeClaw 대화 기록은 어디에 있나

| 대상 | 위치 | 상태 |
|---|---|---|
| ACP 세션 목록 | `~/.local/state/meclaw-acp/sessions.json` | **확인**: `{ "mc-<12hex>": { channel, cwd, updated(epoch float), title(null) } }` |
| 대화 본문 | `~/work/workflow-evolution/meclaw/colony/colony.db` 의 `message_log` | **확인**(구조): 열 `id, trace_id, parent_message_id, correlation_id, ttl, from_path, to_path, reply_to, headers(json: context, hop), body_kind, body_payload, created_at`. 882행, `body_kind` = inline 875 / blob 7 |
| 큰 본문 | `colony/blobs/*.json` | **확인**: `body_kind=blob`일 때 참조되는 것으로 보임(**추정**) |
| 흐름 | `@external→/brain`(사용자 입력 172), `/brain→/router`, `/router→/sink`(출력 186), `/evaluator…` | **확인**(경로별 개수) |

- 실행 DB는 Git에서 제외된다(`workflow-evolution` README). DB는 사용 중(WAL)이므로 `sqlite3` read-only URI나 backup API로 읽는다. 이 컴퓨터에는 `sqlite3` CLI가 없고 Python `sqlite3`는 있다.
- **미확인**: `session id(mc-…)`와 `trace_id`의 대응 관계(`headers.context`에 있을 가능성), `body_payload`의 JSON 형식, 한 "대화 턴"을 어떻게 묶을지.
  → M2 첫 phase에서 **복사본으로** 확인하고 내용은 로그/문서에 남기지 않는다.
- dream agent 입력 형식은 `~/.claude/session-digests/<id>.json`(`scripts/session-digest.sh` 참고). 어댑터가 같은 형식으로 쓰면 dream agent는 수정 없이 읽는다(**추정**, 형식 확인 필요).
- 개인정보: 대화에는 사적 내용이 섞일 수 있다. 어댑터는 요약 입력만 만들고 원문 보관/전송을 하지 않는 것을 기본으로 한다.

## M3: MeClaw / Codex / Claude에 위키 MCP를 어떻게 붙이나

**MeClaw (업스트림 `mmeyerlein/meclaw` docs/cell-types.md, 확인)**
- colony에는 `mcp` 셀(MCP provider 브리지)이 있고 전송은 `http`(JSON-RPC)와 `stdio`(자식 프로세스) 두 가지다.
  `stdio`는 `sandbox` 프로필을 지원한다(GH #96, 선택). 위키 서버는 우리가 만든 로컬 바이너리이므로 `stdio`가 자연스럽다.
- 그러나 현재 colony는 `brain/router/evaluator/sink` 네 셀이고(`colony/main/config.json`) 토폴로지는 Guix 시드가 관리한다.
  `MECLAW.md`: "Future seed migrations must be explicit". → `mcp` 셀 추가는 **토폴로지 변경 = 명시적 시드 마이그레이션**이다.
- **미확인**: `mcp` 셀의 `stdio` 명령/인자를 지정하는 정확한 `params` 키 이름(발췌에서 잘림, docs/cell-types.md 1115행 이후와 config.md 참고), `network:mcp` 같은 capability 필요 여부.
- 대안(**제안**): 현재 방식 그대로, MeClaw 호스트 어댑터(`meclaw-workflow` 브리지, 이미 `workflow_search` 등 허용 목록 도구를 노출)에 `wiki_search/wiki_get`을 허용 도구로 추가하고 내부에서 위키 서버를 호출한다.
  upstream 토폴로지를 건드리지 않아 더 단순하다. 둘 중 무엇이 나은지는 M3 초반에 짧은 스파이크로 정한다.

**Codex (확인)**: `home-services/meclaw.scm`이 이미 Codex MCP 항목을 `~/.codex/config.toml`에 설치한다(`MECLAW.md`). 같은 방식으로 위키 MCP 블록을 선언하면 된다.
**Claude Code (미확인)**: `claude mcp add` 또는 프로젝트 `.mcp.json`. Guix로 선언하려면 `home-services/claude-code.scm`을 확장한다. 정확한 방법은 M3에서 확인.

## 권장 순서 (제안)

1. M1이 끝나기 전에도 가능한 것: M2 첫 phase(복사본으로 `message_log` 읽어 턴 묶기 + digest 형식 확정) — ai-wiki와 파일이 겹치지 않는다.
2. M1 후: Codex MCP 블록(가장 단순) → Claude → MeClaw(스파이크 후).
3. MeClaw 쪽 변경은 토폴로지/시드 변경이므로 사용자 확인 후 진행.
