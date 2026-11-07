# ai-wiki "usable milestones" — orch 인계 메모 (2026-11-07)

새 Claude Code 세션을 `~/work/ai-wiki`에서 열고 **이 파일을 읽은 뒤** 오케스트레이터로 이어받는다.
(이전 세션은 작업 폴더가 `~/guix-system`이라 `orch agent adopt orchestrator --current`가
`E_PANE_MISSING: pane is outside the task worktree`로 실패했다. 오케스트레이터 pane은 작업 폴더 안에 있어야 한다.)

## 시작

```bash
cd ~/work/ai-wiki && claude
# 첫 프롬프트: "~/guix-system/doc/ai-workflow/AIWIKI-ORCH-HANDOFF.md 를 읽고 오케스트레이터로 M0부터 진행해줘.
#               herdr-orchestrator 스킬을 따르고, 각 phase는 내가 LGTM 하기 전에 멈춰."
orch preflight                                   # READY 여야 함
orch agent adopt orchestrator --current
orch agent start operator --profile operator.codex --split down
```

- 이미 만든 것: orch 작업 `20261107-152040-ai-wiki-usable-milestones-m0-m3` (상태는 RAM:
  `/run/user/1000/herdr-orch/…`, `~/work/ai-wiki/.orchestration`은 그 심볼릭 링크),
  프로필 `operator.codex` = `codex -a never -s workspace-write -c sandbox_workspace_write.network_access=true`
  (승인 질문 없음, 쓰기는 작업 폴더로 제한, 네트워크 허용). `--yolo`/샌드박스 해제는 쓰지 않기로 했다.
- `orch bootstrap --resume`은 BOOTSTRAP.json이 없어 실패한다. 위의 수동 단계를 쓴다.
- 기본 operator 프로필(`operator.default`)은 opencode인데 이 컴퓨터에 없다. `reviewer`는 기본적으로 오케스트레이터가 겸한다.
- `orch` 래퍼 문법 오류는 고쳤다(`files/.local/bin/orch`, guix-system에 미커밋).

- **M2/M3 선행 조사 결과**: `AIWIKI-M2-M3-RESEARCH.md` (MeClaw 대화 기록 위치, MCP 연결 방법, 미확인 항목). M2/M3 시작 전에 읽는다.

## 목표와 비목표

**목표**: ai-wiki를 에이전트(MeClaw, Codex, Claude Code)가 "쓸 수 있는" 상태로 만든다. 읽기 도구가 먼저, 임베딩은 나중.
**비목표**: 시맨틱 검색/링크 추천/harness 검증(계획서 Phase 2) — 사용 가능해진 뒤. 위키에 대한 에이전트 직접 쓰기(항상 dream agent 경유).
**안티 목표**: 사용자의 미커밋 작업을 덮어쓰거나 버리는 것, push, 비밀 값 커밋.

## 현재 상태 (확인된 것)

- ai-wiki: `main`이 `origin/main`과 동일. docs/는 OKF v0.2 번들(`scripts/okf-normalize.py`, `docs/log.md` 자동 기록).
  사용 방법: `docs/pkm/okf-bundle-workflow.md`.
- **사용자의 미커밋 작업(건드리지 말고 M0에서 그대로 커밋)**: `README.md`, `.gitignore`(`**/target/` 추가),
  `docs/superpowers/plans/2026-05-18-rig-helixdb-integration.md`, `meta/todo.md`, 미추적 `agents/rig-knowledge-manager/`
  (Rust 559줄, Phase 1 구현), `docs/helixdb/wiki-graph-schema.md`.
- 계획서의 Phase 1(항목 1–6)은 완료·검증(2026-10-10, 로컬 HelixDB v3). Phase 2(7–10), Phase 3(11–13)은 미착수.
- MeClaw는 ai-wiki와 연동되어 있지 않다. 공유 스킬 저장소: `~/work/workflow-evolution/skills/`
  (`local-workflow`, `herdr-delegation`, `workflow-evidence`)를 MeClaw/Codex/Claude Code/AGY가 같이 읽는다.

## 마일스톤 (사용자 승인)

| | 내용 | 완료 기준 |
|---|---|---|
| **M0** 기반 정리 | Phase 1 작업이 빌드·테스트되는지 확인하고 커밋(`target/` 제외). `.orchestration`을 `.gitignore`에 추가 | `cargo build`와 기존 테스트 통과, `okf-normalize.py` 변경 0건, 커밋됨(push 안 함) |
| **M1** 위키 읽기 도구 | 임베딩/HelixDB 없이 **파일 기반** stdio MCP 서버. 도구: 검색(경로·제목·태그·본문), 문서 가져오기, 관련 문서, harness 조회, 인덱스 목록. 결과 개수/길이 제한과 원본 경로 포함. 계획서 11–12번 | 픽스처 테스트 통과, `docs/`에서 실제 질의 성공, 사용 문서, HelixDB 없이 동작 |
| **M2** 입력 경로 | **먼저 조사**: MeClaw 세션이 어디에 저장되는지. 그 기록을 `~/.claude/session-digests` 형식으로 변환해 dream agent 입력에 추가. dream agent의 MCP 사용은 선택(파일 기반 폴백 유지, 13번) | 샘플 세션 1개가 digest로 변환되어 dream agent가 읽음 |
| **M3** 에이전트 연결 | 공유 스킬 `ai-wiki`(`workflow-evolution/skills/ai-wiki/`): `docs/index.md`에서 한 단계씩 읽기, 쓰기는 dream agent 경유. MCP 등록을 `guix-system`으로 선언(Codex/Claude/MeClaw — **MeClaw의 MCP 등록 방법은 아직 모른다, 먼저 조사**). 프로젝트 목적 문서 틀(방향 이탈 방지) | 각 에이전트가 위키 질의 1건 성공, 선언이 guix-system에 커밋됨 |

M1의 구현 위치(제 판단, 바꿔도 됨): 기존 크레이트 `agents/rig-knowledge-manager`의 파서를 재사용하는 새 서브커맨드/크레이트.

## 제약

- **push 금지** (사용자가 직접). 커밋은 phase 단위로.
- 설정·설치는 `guix-system`으로 선언한다(CLAUDE.md의 Rule 1/2). 일회성 설치 금지.
- 문서는 OKF frontmatter 규칙을 따르고 변경 후 `scripts/okf-normalize.py --apply`.
- 각 phase는 `allowed_paths`를 좁게 주고 `--require-test`를 넣는다. LGTM은 사용자 확인 후에만, 자동 진행 금지.
- 사용자는 한국어로 소통한다. 비밀(토큰, 키)을 로그나 문서에 남기지 않는다.
