# 백엔드 작업 지침

## 현재 기준 (2026-09-21)

- 새 작업 전에 [docs/BACKEND_DESIGN.md](docs/BACKEND_DESIGN.md)를 읽습니다. 요구사항·서비스 소유권·현재 구현·계약·다음 작업의 기준입니다.
- 구현할 정책은 [docs/requirements/README.md](docs/requirements/README.md)와 해당 도메인 상세 문서를 읽습니다. DEC/요구사항/AT ID를 작업·테스트에 연결합니다. v1로 결정한 사항을 다시 미정으로 취급하지 않습니다.
- 기능 구현 전에 [구현 상세 문서](docs/implementation/README.md)의 해당 workflow/lock 순서·이벤트 schema·migration wave·화면·운영 복구를 읽습니다. 추적표의 X-01~11과 정식 OpenAPI의 연결을 확인하고, DT/AT는 실제 실행 증거 없이 통과 처리하지 않습니다.
- PG1=기존 KAKAO simulator, PG2=기존 NAVER simulator입니다. 실 카카오/네이버·은행 연결이나 새 PG 도입은 범위가 아닙니다. 목표 계약의 미구현 상태를 완료로 보고하지 않습니다.
- 실행·검증은 [MSA.md](MSA.md), HTTP 계약은 [contracts/README.md](contracts/README.md)를 따릅니다.
- 테이블 탐색은 [docs/erd](docs/erd/README.md), 빈 격리 DB용 SQL은 [docs/ddl](docs/ddl/README.md), API 필드·예시는 [docs/api](docs/api/README.md)를 읽습니다. 생성본을 직접 편집하지 말고 [문서 도구](scripts/docs/README.md)의 원본을 수정·재생성·검증합니다. 현재와 목표 모델을 혼동하지 않습니다.
- 파일 수정 시각으로 우선순위를 결정하지 않습니다. 과거 대화 백업·분석은 역사적 맥락이며 현재 설계를 덮어쓰지 않습니다. 최신 사용자 지시가 우선합니다.
- 4개 업무 서비스 Commerce/Payment/Settlement/Discovery 경계를 유지합니다. 구매확정은 Commerce, 지급 대상 원장은 Settlement, PG 결제 대사는 Payment가 소유합니다.
- 기존 “패키지 뼈대만 수정” 범위는 당시 요청의 기록입니다. 현재 사용자 요청에 맞게 코드·문서 문제를 수정하고 검증합니다.

## 구현 규칙

- 기존 미커밋 변경을 보존하고 작업 범위를 넘어 되돌리지 않습니다.
- 타 서비스 DB 직접 접근, 서비스 간 JPA Entity 관계, shared domain/entity jar를 만들지 않습니다. PG simulator의 HTTP DTO 라이브러리는 현재 명시된 예외입니다.
- PaymentLifecycleService는 메모리 reference implementation입니다. 영속 구현과 복구 없이 Spring Bean/공개 API로 노출하지 않습니다.
- PG 요청 전 입력·권한·금액·멱등성을 검증하고 요청 정보를 commit합니다. timeout·UNKNOWN을 실패로 단정해 재결제/재환불하지 않습니다.
- domain 변경·금융 거래 이력·outbox는 같은 DB transaction으로 저장합니다. 외부 HTTP 호출 동안 DB lock을 유지하지 않습니다.
- 기존 Flyway V1은 수정하지 않고 새 버전 migration을 추가합니다. 생성기는 build/schema-preview에 비교 후보만 만듭니다.
- 단일 앱이나 과거 10개 서비스 설계로 되돌리지 않습니다. 서비스 추가 분리는 별도 요구와 데이터 경계 근거가 있을 때 설계 문서를 함께 변경합니다.

## 검증과 기록

- 코드/설정 변경은 JDK 17로 `.\gradlew.bat clean build --no-daemon`을 실행합니다.
- schema는 `.\scripts\verify-service-schema.ps1`, 문서는 `.\scripts\verify-doc-links.ps1`로 검사합니다.
- 문서 계약 변경은 `node scripts/docs/build-implementation-docs.mjs --check`, `python scripts/docs/verify-implementation.py`, `python scripts/docs/verify-contract-closure.py`도 실행합니다. ERD/API/DDL 원본을 변경했다면 [문서 도구](scripts/docs/README.md)의 전체 생성·검증 순서를 따릅니다. SQL 검증은 기존 DB가 아닌 도구가 생성하는 메모리 DB에서만 수행합니다.
- DB lock·migration 변경은 기존 데이터와 분리된 PostgreSQL에서도 확인합니다. H2 통과를 PostgreSQL 검증으로 보고하지 않습니다.
- 실행하지 못한 검증과 미구현 범위를 명시하고 구현·계약·설계 문서를 함께 갱신합니다.
- 운영/기존 Compose DB 삭제나 배포는 검토 작업의 자동 후속 단계가 아닙니다.

## 참고 대화

- 최초 참고: https://chatgpt.com/s/cx_6aa0ba4831648191b29569c4069edbef
- 전체 공유: https://chatgpt.com/share/6a94ed7b-1184-83e8-88fe-b0a3fd22cc8f
- 과거 백업: [docs/conversation-backup-2026-09-09.md](docs/conversation-backup-2026-09-09.md)

사용자에게 같은 링크를 다시 요청하지 않습니다. 현재 개발에는 설계 문서를 먼저 사용하고 원문은 결정 출처를 확인할 필요가 있을 때만 참조합니다.
