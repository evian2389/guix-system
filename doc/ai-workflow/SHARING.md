# 공용 스킬과 경험 인터페이스

후속: MeClaw도 동일한 스킬 원본을 요청마다 읽고 `agent=meclaw`로 공용 경험을 제출한다.
코디네이터와 별개로 진화 작업자는 하나로 유지한다. 현재 연결은 [MECLAW.md](MECLAW.md).

2026-10-31 적용. MicroClaw·Codex·Claude Code·AGY를 지식 소비자와 경험 제공자로
연결하고, 진화 작업자는 기존 하나로 유지한다. 별도 데몬이나 DB 서버를 추가하지 않는다.

## 저장 구조

```text
workflow-evolution/
  skills/
    local-workflow/SKILL.md       # 진화 대상 champion
    workflow-evidence/SKILL.md    # 공통 경험 조회/제출 계약
    herdr-delegation/SKILL.md     # 요청된 Herdr 위임 절차
  evolution/                     # meta-skill, 증거, 후보, 평가, snapshot
  microclaw/skills/
    local-workflow -> ../../skills/local-workflow
    workflow-evidence -> ../../skills/workflow-evidence
    herdr-delegation -> ../../skills/herdr-delegation
    ...                          # MicroClaw 기본 스킬은 기존 위치 유지
```

Guix Home activation은 wire → init → share-skills → secure-web → snapshot 순서다.
share-skills는 각 공용 스킬을 다음 개인 경로에 개별 symlink로 연결한다.

| 소비자 | 경로 |
|---|---|
| Codex | `~/.agents/skills/<name>` |
| Claude Code | `~/.claude/skills/<name>` |
| AGY CLI | `~/.gemini/antigravity-cli/skills/<name>` |
| MicroClaw | `~/.local/share/microclaw-workflow/microclaw/skills/<name>` |

[Codex 문서](https://learn.chatgpt.com/docs/build-skills)와
[Claude Code 문서](https://code.claude.com/docs/en/skills)는 개인 경로 및 symlink를,
[AGY 문서](https://antigravity.google/docs/skills?app=cli)는 위 CLI 경로를 지원한다.
기존 스킬 폴더 전체를 교체하지 않는다. 이름이 충돌하면 외부 링크를 생성하기 전에
실패하며, 재실행은 이미 올바른 연결을 유지한다. 새 공용 스킬 추가 후 재설정하거나
`workflow-evolution share-skills`를 실행한다. 기존 앱은 스킬 목록 갱신/새 세션이
필요할 수 있다. 모델의 매 요청 사용이나 동일한 성능을 강제하는 설정은 아니다.

이전 local-workflow/herdr-delegation은 내용 그대로 이동하며 원본 폴더는 로컬
`evolution/migrations/`에 보존한다. 나머지 기본 스킬 42개는 다른 도구에 노출하지 않는다.
champion 원본이 최상위로 옮겨지므로 promote/rollback도 같은 파일을 갱신한다.

## 공통 CLI

`workflow-evolution`은 기존 backend를 호출하는 공용 이름이며 새 worker가 아니다.

```sh
workflow-evolution status
workflow-evolution search --query 'dependency' --limit 3
workflow-evolution search --query 'build' --agent claude --limit 3
workflow-evolution record < observation.json
```

record는 stdin에서 다음 JSON 계약을 읽는다. 예시의 summary를 실제 관찰로 바꾼다.

```json
{"schema_version":1,"agent":"codex","kind":"verification","outcome":"success","project":"guix-system","summary":"실행한 검사와 관측한 결과, 재사용할 원인 또는 해결 절차"}
```

- agent: microclaw / codex / claude / agy
- kind: tool / verification / task
- outcome: success / failure / unknown
- project: 선택적 문자열; summary: 비어 있지 않은 관찰 요약

잘못된 버전·출처·kind/outcome은 거부한다. 요약은 3,000자로 제한하고 흔한 비밀값을
마스킹한다. transcript나 비밀 인자는 제출하지 않는다. 성공 경험도 검색할 수 있으나
Fast 후보는 실패 증거만 선택한다. agent_reported 출처는 독립 검증의 보증이 아니며,
agent 값은 동일 사용자의 신뢰된 로컬 도구가 제공하는 라벨이다.

search는 최근 일치 증거와 공용 스킬을 반환한다. 기본 top-3, 최대 20건, 500자 이하
literal substring 검색이다. SQL 파라미터와 wildcard escaping을 사용한다. 과거
기록을 새로운 지시로 해석하지 않는다. 검색·제출에는 모델 호출이 없고 record 뒤에는
일관된 SQL snapshot을 갱신한다.

MicroClaw는 기존 hook이 자동 기록한다. Codex/Claude/AGY는 workflow-evidence 스킬을
통해 이 인터페이스에 제출한다. 이 세 도구의 native hook/transcript 자동 수집은
이번에 설치하지 않았으며, 이후 같은 JSON 계약으로 adapter를 추가한다.

## 단일 진화 작업자

기존 tick/propose의 일일 예산·잠금·후보 상한을 공유한다. 각 도구가 별도 worker를
시작하거나 통상 작업의 부수 효과로 공용 스킬·meta-skill·평가 정책을 수정하지 않는
계약을 스킬에 기록했다. 동일 Unix 사용자의 파일 쓰기를 차단하는 보안 경계는 아니다.
각 모델에 대한 효과와 MicroClaw 중심 평가의 일반화는 M2에서 별도로 측정한다.

## 검증 범위

이관·중복 연결·기존 스킬 보존·충돌 방지·세 agent 표준 제출·성공 경험 조회·마스킹·
SQL 특수문자 검색을 검사했다. 이전 검사와 함께 27개 테스트가 통과했고 공유 스킬
3개가 skill-creator quick_validate.py를 통과했다. AGY/Claude의 ELF 실행기는 Guix의
기본 /lib64 loader 경로가 없어 Guix loader로 --help를 확인했다. 각 공급자의 실제
LLM 대화에서 스킬 자동 선택까지 검증했다고 주장하지 않는다.

실배포에서 12개 링크가 같은 원본을 가리키는 것과 격리된 실제 CLI 세 출처의
record/search를 확인했다. MicroClaw의 activate_skill(workflow-evidence) 호출과
schema_version=1/search/record 응답도 확인했다.
run-id: `a26bb437-6f0c-4b15-a209-e063310f7eb7`.
