# M1 운영 방법

## 실행과 상태

```sh
herd status microclaw
microclaw --config ~/.local/share/microclaw-workflow/gateway.json config check
microclaw-evolve status
herd schedule mcron
```

Web UI: <http://127.0.0.1:10961>. 최초 암호는 로컬 파일
`~/.local/share/microclaw-workflow/web-initial-password.txt`에서 확인한다.
암호는 Git에 넣지 않는다. Web UI에서 변경한 경우 파일은 최초 암호 기록으로만 남는다.
MicroClaw 0.11.1의 과거 `web_auth_token` 설정은 무시되므로 사용하지 않는다.
설정/시드 파일은 mode 0600, 신규 상태 디렉터리는 0700으로 생성한다.

```sh
microclaw --config ~/.local/share/microclaw-workflow/gateway.json run \
  --session my-project --prompt '프로젝트 작업 내용'
```

ChatGPT 연결은 MicroClaw의 `openai-codex` provider가 기존 `codex login` 인증을
사용한다. 별도 API 키를 복사하지 않는다. 현재 모델은 로컬 Codex 설정과 같은
`gpt-6.1-sol`. 인증 오류 시 `codex login status`부터 확인하고 필요한 경우 직접
`codex login`을 수행한다. 자동 재로그인이나 계정 전환을 하지 않는다.

## 개선 사이클

AfterToolCall hook은 성공 여부와 최소 메타데이터를 기록하고, 실패 시에만 최대
3,000자의 오류 내용을 보관한다. 도구 인자는 기록하지 않는다. 흔한 비밀값 패턴은
마스킹하지만 완전한 DLP가 아니다. 오류 발췌는 후보 생성 시 ChatGPT로 전달된다.
전용 SQLite DB를 사용하므로 MicroClaw 내부 DB 스키마를 직접 파싱하지 않는다.
미참조 관찰은 최근 약 10,000건으로 제한하며 후보에 사용한 증거는 유지한다.

mcron은 매시 00/30분 `tick`을 실행한다. 새 실패가 없으면 모델을 호출하지 않는다.
자동 제안은 UTC 하루 1회(실패한 요청도 예산 소비), 보류 후보 최대 1개다.
모델 요청은 동기 순차 실행, 요청별 240초 timeout이다. 워커 파일 잠금은 중복
진화를 차단한다. 매 요청은 임시 런타임·새 대화로 실행하고 모든 도구 실행을 차단한다.
MicroClaw 자체 Reflector와 end-of-turn skill review는 꺼서 별도 개선 루프를 막는다.
Learning Foundry의 빈 트랙 스캔은 upstream 내장 동작으로 남지만 트랙을 만들지 않는다.
백그라운드가 새 후보를 평가하거나 자동 승격하지 않는다.

```sh
microclaw-evolve tick
microclaw-evolve status
# 출력된 실제 ID를 아래 CANDIDATE_ID 자리에 사용
microclaw-evolve evaluate CANDIDATE_ID
microclaw-evolve promote CANDIDATE_ID
# 또는 보류 후보를 탈락시키고 다음 오류로 이동
microclaw-evolve reject CANDIDATE_ID
microclaw-evolve rollback
```

수동 `propose`는 자동 일일 예산 밖의 명시적 추가 호출이다. 평가는 suite의 각 case마다
baseline/candidate 각 1회(기본 4회), 최대 20회 모델을 호출한다. 기본 suite는 M1
연결 검사용이며 실제 코딩 품질의 증명이 아니다. M2에서 프로젝트 holdout으로 교체한다.
모든 case에서 기존 성공을 보존하면서 적어도 하나 개선해야 승격할 수 있다.
평가 후 baseline/candidate/suite/설정이 바뀌면 승격을 거부한다. 후보의 절차 내용은
승격 전 직접 검토한다. 출력된 평가의 eligible=true도 인간 판단을 대체하지 않는다.

현재 데이터 경로는 `~/work/workflow-evolution` Git checkout으로 연결된다.
Guix 선언 경로·자동 연결·복원은 [STORAGE.md](STORAGE.md)를 따른다.

산출물: `~/.local/share/microclaw-workflow/evolution/archive/<id>/` 아래 후보,
기준 스킬, 당시 meta-skill, 실패 발췌, 평가 결과를 보관한다. SQLite와 아카이브는
로컬 상태이며 Git으로 자동 commit/push하지 않는다. 업무 입력이 늘면 주기적으로
아카이브 크기를 확인한다. DB/파일 원자적 교체는 분산 트랜잭션이 아니므로 정전 시
현재 파일과 마지막 promotion 이력을 확인한 뒤 복구한다.

승격/rollback 뒤 다음 요청에서 스킬을 재확인한다. 확실한 재적용은
`herd restart microclaw`로 한다. 서비스 중인 요청이 없을 때 실행한다.

## Guix 배포와 재현

```sh
cd ~/guix-system
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_microclaw_evolve.py
make reconfigure-home NON_GUIX_UPDATES=0
# 교체 대기 중인 서비스가 표시될 때만 재시작
herd restart mcron
```

`NON_GUIX_UPDATES=0`은 Nix/Cargo/npm/Flatpak 일괄 업그레이드만 생략한다.
Guix Home reconfigure, 추가 Guix profile, Stow는 실행한다. 일반 배포의 기존 기본값은 1이다.
MicroClaw release와 Guix ELF 래퍼가 설치되어 있어야 한다. 새 PC에서는 먼저 기존
`non-guix-packages.sh` 설치 경로를 수행한다. 현재 release 설치기는 latest를 받으므로
완전 재현 가능한 패키징/해시 고정은 M2의 인프라 후속 작업이다.

시드는 Guix activation에서 없을 때만 작성한다. 재배포는 기존 스킬·meta-skill·설정을
덮어쓰지 않는다. 시드 변경을 기존 환경에 적용하려면 해당 변경만 명시적으로 병합한다.
전체 Home 되돌리기는 `guix home roll-back`; 상태 데이터는 별도로 백업한다.
자동 제안 중지는 evolution/config.json의 auto_propose를 false로 변경한다.
서비스 중지는 `herd stop microclaw`다. 도구/의존성 격리는 프로젝트마다 Guix shell 및
worktree를 사용하되, 보안 sandbox는 별도 설계임을 유지한다.
