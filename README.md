# Multi-seller Fashion Marketplace Backend

**작업 시작 문서: [백엔드 구현 설계 기준](docs/BACKEND_DESIGN.md)**

**앞으로 구현할 로직: [v1 전체 요구사항·결정 목록](docs/requirements/README.md)** — 회원부터 주문/PG1·PG2/환불/정산/프론트까지, 정책·예외·검증 기준을 모았습니다.

현재 구조는 4개 업무 서비스(Commerce, Payment, Settlement, Discovery)와 2개 독립 PG simulator입니다. Java 17 / Spring Boot 4.1.1 / Gradle 9.7.1을 사용합니다. 기존 단일 앱 및 10개 서비스 설계 대신 위 기준 문서로 작업합니다.

| 문서 | 역할 |
| --- | --- |
| [BACKEND_DESIGN](docs/BACKEND_DESIGN.md) | 요구사항, 현재 구현, 서비스/테이블 소유권, 상태 전이, 거래 흐름, 다음 작업 |
| [MSA](MSA.md) | 실행 환경, 포트, 프로필, migration, 검증 명령 |
| [v1 요구사항](docs/requirements/README.md) | 구현 전 정책, 도메인별 로직, API·이벤트, 수용 테스트 |
| [구현 상세 문서 6종](docs/implementation/README.md) | transaction·상태 전이, typed 이벤트, migration, 요구사항 추적, 40개 화면, 장애 대응 |
| [테이블 ERD](docs/erd/README.md) · [시각화](docs/erd/index.html) | 현재/목표 구분, 서비스별 DBML·Mermaid, 전체 컬럼·키·인덱스 |
| [현재/목표 DDL](docs/ddl/README.md) | 6개 서비스별 SQL 12개, 빈 격리 DB용·기존 데이터 upgrade용 아님 |
| [API 명세서](docs/api/README.md) · [탐색 뷰어](docs/api/index.html) | 고객·판매자·관리자·내부·PG OpenAPI, 인증·요청·응답·오류·예시 |
| [Contracts](contracts/README.md) | 구현된 PG 계약과 미구현 목표 Payment/Checkout v1 계약의 구분 |
| [Payment](payment-service/README.md) | 메모리 reference implementation의 동작·제약 |
| [검토 보고서](docs/logic-analysis-2026-09-21.md) | 발견 문제, 수정 결과, 검증 근거 |
| [과거 대화 백업](docs/conversation-backup-2026-09-09.md) | 역사적 배경; 현행 지침은 아님 |

## 실행과 검증

프로젝트 루트에서 JDK 17을 사용합니다.

```powershell
.\gradlew.bat clean build --no-daemon
.\gradlew.bat :pg-kakao-simulator:bootRun
```

전체 PostgreSQL·Redis·Kafka 로컬 환경은 `docker compose up --build -d`로 실행합니다. 자세한 환경변수와 데이터 유지 정책은 [MSA.md](MSA.md)를 따릅니다.

현재 고객 주문→결제→정산 흐름은 미구현입니다. 실제 REST/DB 업무 처리는 PG simulator만 제공합니다. Payment의 내부 Java 구현은 Spring Bean·영속화·HTTP adapter가 없는 프로토타입입니다.

스키마 변경 시 기존 V1을 덮어쓰지 않습니다. [서비스별 migration](docs/BACKEND_DESIGN.md#4-데이터-소유권과-변경-방법)이 물리 DB 기준이며, 상위 워크스페이스의 논리 DDL 합본을 서비스 DB에 적용하지 않습니다. 백엔드 단독 clone에서도 migration·빌드·테스트가 가능하고, 논리 원본과 FK 비교 검증에는 상위 `database` 폴더가 필요합니다.
