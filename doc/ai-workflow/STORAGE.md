# 진화 저장소 연결과 복원

2026-10-31 적용. `users/orka/home.scm`의 home-microclaw-configuration에
`(repository "~/work/workflow-evolution")`를 선언한다.

Guix Home activation은 wire → init → secure-web → snapshot 순서로 실행한다.
기존 경로 `~/.local/share/microclaw-workflow`는 checkout을 가리키는 symlink다.
새 PC에서는 이 저장소를 먼저 clone한다. 없으면 activation은 빈 상태 생성 대신 실패한다.
clone/pull은 자동 실행하지 않아 설치 중 인증 대기나 로컬 변경 충돌을 피한다.

기존 디렉터리의 최초 이전은 gateway와 mcron을 멈춘 뒤 수행한다. 복사한 파일의
SHA256을 확인하고, 원본을 `.pre-wiring-*` 이름으로 남긴 후 symlink를 설치한다.
활성 gateway/진화 worker가 감지되거나 양쪽에 같은 이름의 데이터가 있으면 거부한다.
첫 이전 외의 재설정은 실행 중에도 연결을 확인하는 작업만 수행한다.

스킬·후보·meta-skill·평가와 SQL 스냅샷을 Git으로 관리한다. 실행 DB/WAL, 대화 DB,
gateway 설정, Web 암호, 호스트별 hook은 Git에서 제외한다. hook은 Guix 시드로 재생성한다.
스냅샷은 SQLite backup API를 통해 WAL의 committed 데이터까지 일관되게 내보낸다.
activation 및 tick/propose/evaluate/promote/reject/rollback 종료 시 갱신한다.
수동 즉시 갱신은 `microclaw-evolve snapshot`이다. 자동 commit/push는 하지 않는다.

새 clone의 실행 DB가 없을 때 wire는 `evolution/snapshots/evidence.sql`을 복원하고,
무결성과 필수 테이블을 검증한 뒤 설치한다. 기존 DB는 덮어쓰지 않는다. ChatGPT 로그인과
Web 암호는 호스트별로 준비한다. Git SQL 이력은 다중 PC의 DB를 자동 병합하지 않는다.

## 이번 이전 결과

- `make reconfigure-home NON_GUIX_UPDATES=0`: 종료 코드 0.
- 원본 68개 파일 모두 이전 전 SHA256과 백업 SHA256 일치.
- 원본 백업: `~/.local/share/microclaw-workflow.pre-wiring-83b8854f6e26`.
- 복원한 SQL: traces 8개, proposals 2개, integrity_check=ok.
- 현재 스킬 SHA256과 후보 상태 유지. wire 재실행 시 already connected.
- gateway/mcron 실행 복귀, HTTP health 정상.
- 이관·충돌 방지·재실행·스냅샷 복원 포함 19개 테스트 통과.

저장소 운영 방법은 `~/work/workflow-evolution/README.md`를 따른다.
