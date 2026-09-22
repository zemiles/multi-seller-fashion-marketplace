# 구현 상세 문서 검증 기록

검증일: 2026-09-22. 대상은 [구현 문서 6종](README.md), X-01~11 OpenAPI, 현재/목표 ERD·DDL, 이벤트·추적표와 생성/검증 도구입니다. 기존 사용자 변경은 보존했습니다. 이번 보완에서 업무 Java 코드·적용된 Flyway migration·기존 실행 DB는 수정하지 않았습니다.

## 완료 범위

합의된 모의 마켓플레이스 v1의 **설계 문서·계약 기준선**을 정리했습니다. X 보완 계약 11개 묶음은 모두 SPECIFIED이며 미반영 보완 계약은 0개입니다. M4 추가 구조/제약도 목표 모델과 SQL에 포함했습니다. 이 상태는 서버/화면 구현·배포·운영 검증 완료와 다릅니다.

- [API](../api/README.md): 8개 OpenAPI / 205개 operation 정의. X-01~11은 추가 38개 operation이며 [manifest](contract-extensions.json)에 연결합니다. pg-current/pg-target은 동일 PG의 현재/목표 버전이므로 배포 endpoint 수로 합산하지 않습니다.
- [ERD](../erd/README.md): 현재 113표/173FK → 목표 163표/209FK. 서비스 간 물리 FK는 없으며 각 서비스 내부 키·관계를 검사했습니다.
- [DDL](../ddl/README.md): 6개 서비스×현재/목표 SQL 12개. **빈 격리 DB용**이며 기존 DB upgrade migration이 아닙니다. 실제 schema는 업무 marketplace, PG1 pgkakao, PG2 pgnaver입니다.
- 인덱스: 명시적 CREATE INDEX 현재 202개/목표 252개. queue due/lease, payment dispatch partial unique, payout fence, claim 사유변경, 부분 역전, PG receipt cursor, 검색 generation 인덱스를 보완했습니다. PK/UNIQUE 자동 인덱스는 별도이고 실부하 최적화는 미측정입니다.
- [추적표](04-traceability.md): 요구사항 55개, AT 32개, DT 55개, 화면 40개, 이벤트 19종, 목표 변경 85개를 연결합니다. AT/DT/FE-AT는 실행 완료로 올리지 않았습니다.

## 실제 실행 결과

| 검증 | 결과 | 범위 |
| --- | --- | --- |
| `build-docs.mjs --check` | 117개 산출물, stale 0 | ERD/API/DDL 원본과 생성본 일치 |
| `build-implementation-docs.mjs --check` | 26개 산출물, stale 0 | 이벤트·추적표·migration/X manifest 일치 |
| `verify-docs.py` | 계약 8개, operation 205개, 예시 1,995개, schema 259개, reference 2,142개 | 구조·참조·예시·요구사항·원본 hash |
| `verify-implementation.py` | 정상 이벤트 19개 통과, 오류 fixture 51개 거부 | schema와 payload 내부 합계·수량·stream 및 요구사항 연결 |
| `verify-contract-closure.py` | X 11묶음/38 operation, HTTP 오류 입력 104개 거부, M4 4항목·DDL hash·화면 참조 통과 | 필수/추가/조건부 필드·version, 인증/역할/scope **명세**. 실제 인증 로직 시험 아님 |
| `verify-formats.mjs` | OpenAPI 8개 / DBML 14개 / Mermaid 27개 통과 | 각 parser 검증. 브라우저 시각 QA/E2E 아님 |
| `verify-ddl.mjs` | 새 메모리 DB 12개에 SQL 생성 성공; 합계 276표/382FK/454 명시적 인덱스 대조; 오류 SQL 10개 거부 | PGlite 0.5.8 / PostgreSQL 18.3 WASM 엔진. native PostgreSQL 17 서버 검증 아님 |
| `verify-service-schema.ps1` | Commerce 76표/136FK, Payment 11표/14FK, Settlement 12표/14FK, Discovery 10표/7FK | 현재 소유 테이블·서비스 내부 FK 파일 비교 |
| Markdown | 백엔드 82개 문서 + 워크스페이스 진입 4개 문서 통과 | 로컬 링크·코드 블록 |
| JDK 17 `gradlew clean build --no-daemon` | BUILD SUCCESSFUL, 56 tasks, 1분 28초 | XML 결과 11 suites / 39 tests, 실패·오류·skip 0 |
| `git diff --check` | 통과 | 공백 오류 없음. 기존 일부 파일의 LF/CRLF 안내만 발생 |

SQL 오류 시험은 잘못된 gross/net·지급 한도, 중복 source 역전·자기 역전, 중복 은행 key·오류 통화/금액/참조, 승인 또는 resolution_event 없는 대사 종결을 거부했습니다. 동일 원행의 두 부분 역전은 허용하고 source unique를 유지했습니다. **누적 역전 상한은 owner lock/transaction 구현 시험이 필요**하며 이 DDL 시험으로 보장하지 않습니다.

형식·SQL 엔진 검증은 Gradle clean 전에 실행했습니다. clean은 검증용 build/docs-tools 의존성을 지우므로 재설치는 [도구 README](../../scripts/docs/README.md)를 따릅니다. [PGlite API](https://pglite.dev/docs/api)의 in-memory 생성/종료만 사용했으며 기존 DB URL·데이터 경로를 받지 않습니다.

## 바로잡은 차이

- quote/사유변경/반송·배송보정/검토목록/계좌·이의/업로드/IAM/운영 replay/교환전환/지원 예외/서버 행동/검색 rebuild의 typed HTTP와 화면 연결을 완료했습니다.
- 공유 운영 내부 계약은 각 업무 owner의 port입니다. 새 업무 서비스를 추가하거나 다른 서비스 DB 접근을 허용하지 않습니다.
- 승인 actionType 11종과 역할 매핑, 자기 승인 금지, MFA 재등록 잠금, 원 payload/hash/version과 승인 소비를 연결했습니다.
- OUTBOX job 성공은 발행 ACK+PUBLISHED commit, INBOX는 업무/no-op+checkpoint commit입니다. 발행 성공을 모든 소비자의 반영 완료로 오인하지 않게 했습니다.
- 정산 gross_net_amount와 legacy net_amount의 의미를 분리하고 hold/payout CHECK, 부분 역전 UNIQUE 제거·조회 인덱스, 은행 대사 3표를 목표 ERD/SQL에 반영했습니다.
- inbox 식별자·복구 job·5분 claim quote, 불변 outbox bytes/hash, 배송 시계 허용 범위 및 이미지 5MiB 제한을 계약과 맞췄습니다.
- 이전 “OpenAPI/목표 모델에 아직 미반영” 문구를 정리하고 프론트 README·작업 지침·요구사항·migration/운영 문서를 갱신했습니다.

## 구현 단계에 남는 검증

실제 업무 REST·producer/consumer·신규 화면·새 Flyway upgrade/backfill은 미구현입니다. Docker daemon/native PostgreSQL 검증 환경이 준비되지 않아 기존 데이터 upgrade, 여러 DB 연결의 lock 경합, 실제 PostgreSQL 17의 실행계획·부하 검증은 수행하지 않았습니다. 이를 임베디드 SQL 또는 기존 H2/Java 테스트로 대체 완료했다고 표시하지 않습니다.

Kafka 재시작·순서/중복, PG1/PG2 adapter·receipt/webhook, 지급 장애 주입, 백업 복원, 프론트 E2E도 해당 기능 구현 후 AT/DT/FE-AT 증거로 남겨야 합니다. 모의 거래 정책을 실 PG/실은행 정책으로 확장하지 않았습니다. 운영/기존 Compose DB 삭제, 외부 ERD 게시, 실제 결제·지급·배포는 수행하지 않았습니다.
