# PKM 시스템 구축 계획 (OKF + Neovim + GitBook)

출처: `PKM-system-concept.md`. 조사일 2026-11-07.
상태: **구현됨** (2026-11-07). 최종 구조와 사용법은 ai-wiki `docs/pkm/okf-bundle-workflow.md`가 기준이다.
이 문서는 당시 조사/결정 기록이며, 결정: 번들=`ai-wiki/docs`, 비공개(GitBook 제외), BigQuery 보류, OKF 도구는 `non-guix-packages.sh`의 `uv tool install`.

## 1. 조사 결과 (개념 노트와 달라지는 점)

| 개념 노트의 가정 | 실제 확인 결과 |
| --- | --- |
| Google "공식 툴체인"이 DB/소스코드를 크롤링해 OKF 문서를 자동 생성 | 공식 저장소(`GoogleCloudPlatform/open-knowledge-format`, Apache-2.0)의 reference agent는 **BigQuery 데이터셋 전용 proof of concept**다. 입력은 `--dataset <project>.<dataset>`, 웹 보강 pass는 seed URL 기반. 일반 소스코드/노트용 크롤러가 아니다. |
| 자동 빌드가 핵심 | 저장소가 스스로 "핵심은 포맷(SPEC.md)이고 agent는 예시"라고 밝힌다. 포맷 v0.2: 마크다운 + YAML frontmatter, 필수 키는 `type` 하나. 예약 파일명 `index.md`, `log.md`, `references/` 관례. |
| 쓸 수 있는 도구 | (a) SPEC.md 자체, (b) `visualize` 서브커맨드: 번들을 force-directed 그래프 단일 HTML로 렌더(백엔드 없음), (c) BigQuery용 enrich agent(Gemini API 키 + GCP 인증 필요, BigQuery 쿼리 과금 발생). |
| GitBook 연동 | GitHub 저장소 ↔ GitBook Git Sync는 일반 기능으로 가능하나, 이번 조사에서 직접 확인하지 않았다(유료/공개 범위/데이터 외부 반출 이슈 확인 필요). |

결론: "Neovim으로 OKF 번들 작성/편집 + 그래프 시각화 + git"은 바로 가능. "구글 툴체인으로 지식 자동 빌드"는
BigQuery 같은 데이터 소스가 있을 때만 의미가 있다. 개인 노트용 자동 생성은 별도 에이전트(예: 기존 `ai-wiki` dream agent)가 맞다.

## 2. 이미 있는 것 (중복 정리 필요)

- `~/notes` (agenda.org, inbox.org, journal, meetings, `iwe`/마크다운 LSP 흔적)와 `nvim-notes` 설정, Neorg 플러그인.
- `~/work/ai-wiki`: frontmatter 스키마가 있는 마크다운 위키 + 야간 dream agent. OKF와 개념이 가장 겹친다.
- LazyVim `lang.markdown` extra 활성화(marksman, render-markdown 포함).
- Guix: `python 3.12`, `uv` 설치됨. OKF 도구는 `requires-python >= 3.11`이라 호환.

## 3. 결정이 필요한 것 (사용자 확인 후 진행)

1. **번들 위치**: 새 `~/pkm` (권장, 신규 git 저장소) / 기존 `~/notes` 흡수 / `ai-wiki` 확장.
2. **GitBook 사용 여부**: 공개 문서용인가, 비공개 개인 지식인가. 개인 지식이면 외부 SaaS 동기화는 보류 권장.
3. **Google enrich agent 사용 여부**: BigQuery 소스가 실제로 있는가(없으면 설치 불필요).
4. **디스크 정책**: 메일과 달리 노트는 SSD에 두는 것이 정상. 맞는지 확인.
5. **Arch(회사 PC) 이식 범위**: 업무 지식 번들도 같은 방식인지.

## 4. 단계별 실행 계획

### 단계 A — 번들 골격 (결정 1 이후, 되돌리기 쉬움)
- `~/pkm` 생성, `git init`, SPEC v0.2에 맞는 구조: `index.md`, `log.md`, `references/`, 개념 디렉터리.
- `type` 필수 frontmatter 템플릿(`status`, `tags`, `generated`/`verified` 선택).
- 노트 신규 생성 스크립트(템플릿 채우기), `index.md` 갱신 스크립트.

### 단계 B — Neovim 편집 환경 (guix-system `nvim` 설정, 플러그인은 lazy.nvim)
- 기존 `lang.markdown` extra 활용: marksman(링크 이동/보완), render-markdown.
- 링크 그래프 탐색용 스펙 하나(`lua/plugins/pkm.lua`): 번들 디렉터리 감지, `[[`/상대 링크 완성, 백링크 검색(telescope/grep).
- 키맵: 신규 노트, 오늘 로그(`log.md` 항목), 번들 검색.

### 단계 C — 시각화/검증 (외부 코드 설치 필요 → 사용자 승인 필요)
- `reference_agent visualize --bundle ~/pkm`로 `viz.html` 생성. 설치는 저장소 clone 후 `uv`/venv 또는 `uv tool install`.
- **차단됨**: 자동 모드 분류기가 외부 git에서의 `uv tool install`을 거부했다. 승인되거나 사용자가 직접 `!` 로 실행하기 전에는 진행하지 않는다.
- 설치 후 `non-guix-packages.sh`에 재현 가능한 한 줄로 반영(가능하면 커밋 해시 고정).
- 검증: SPEC 필수 키(`type`) 점검용 간단한 스크립트(공식 validator가 없으면 자체 작성).

### 단계 D — 자동 보강 (결정 3이 "예"일 때만)
- BigQuery용 `enrich` 실행 레시피, `GEMINI_API_KEY`/ADC 자격 증명은 `pass`로 분리, 설정 파일에 비밀 금지.
- 비용: BigQuery 쿼리 바이트 과금 + Gemini 호출. 먼저 `--concept` 단일 개념으로 소규모 시험.

### 단계 E — 게시 (결정 2가 "예"일 때만)
- GitHub 저장소 푸시 → GitBook Git Sync 연결. 외부 반출 데이터 범위(비공개 노트 제외) 먼저 점검.
- 이 단계는 외부 서비스 게시이므로 실행 직전에 다시 확인받는다.

### 단계 F — 이식
- `~/dotfiles`에 `config/nvim/lua/plugins/pkm.lua` + `docs/pkm.md` 가이드(Arch 설치: `uv`, marksman 등).

## 5. 검증 기준
- `~/pkm`에서 Neovim으로 노트 생성/링크 이동/백링크 검색이 동작한다.
- `viz.html`이 생성되고 브라우저에서 그래프가 열린다.
- 모든 노트가 frontmatter `type`을 가진다(검증 스크립트 통과).
- 비밀(API 키 등)이 저장소에 없다.

## 6. 위험/주의
- 개념 노트의 "자동 생성" 기대치와 실제 툴체인 범위가 다르다(위 1번).
- 외부 저장소 코드를 설치하므로 커밋 해시 고정 후 사용.
- GitBook은 외부 서비스에 내용을 보낸다. 개인/업무 데이터는 공개 범위를 먼저 확인.
