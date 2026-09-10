# 이전 단일 애플리케이션 메모

> This document describes the retired single-application bootstrap. The active architecture is the four-service Gradle MSA documented in [MSA.md](./MSA.md).

## 업무별 모듈 구조

현재는 하나의 Spring Boot 애플리케이션 안에서 업무 경계를 먼저 분리합니다. 각 업무를 곧바로 별도 배포 서비스로 만들지 않으며, 실제 독립 배포 필요성과 데이터 소유권이 확인된 업무만 이후 MSA로 추출합니다.

```text
multi.com.multisellerfashtionmarketplace
├─ member/          # 회원, 인증 식별자, 프로필, 배송지
├─ seller/          # 판매자 가입, 구성원, 검증
├─ catalog/         # 브랜드, 카테고리, 상품, 옵션, SKU
├─ cart/            # 장바구니, Checkout snapshot
├─ order/           # 주문, 주문 항목 snapshot, 구매 흐름
├─ payment/         # 결제, 취소, 환불, PG webhook
├─ inventory/       # 실재고, 원장, reservation
├─ fulfillment/     # 출고, 배송, 구매확정
├─ claim/           # 반품, 교환, 클레임
└─ settlement/      # 판매자 원장, 정산, 지급, 대사
```

구현이 시작되면 각 업무 패키지 내부를 필요에 따라 `api`, `application`, `domain`, `infrastructure`로 나눕니다. 빈 계층이나 공통 domain DTO를 미리 만들지 않습니다. 업무 간 호출은 공개된 application port를 통해서만 하고 다른 업무의 repository를 직접 사용하지 않는 것을 기본 규칙으로 합니다.

멀티셀러 패션 마켓플레이스의 Spring Boot 백엔드입니다. 이 문서는 개발자와 AI 작업자가 현재 스캐폴드 상태, 데이터베이스 기준, 아직 결정되지 않은 계약을 구분하고 안전하게 기능을 확장하기 위한 작업 기준입니다.

> 문서 기준일: 2026-08-31
> 현재 상태: Spring Boot 애플리케이션 진입점과 context smoke test만 있습니다. REST API, 도메인 모델, 인증, 마이그레이션은 아직 구현되지 않았습니다.

이 디렉터리는 전체 백엔드의 최종 구조가 아니라 현재 단일 스캐폴드입니다. 목표 MSA 서비스 경계와 구축 순서는 [상위 백엔드 README](../README.md)를 기준으로 합니다.

## 먼저 확인할 사항

- 실제 Gradle 프로젝트 루트는 `back-end/multi-seller-fashtion-marketplace`입니다.
- 현재 Git 저장소는 백엔드 프로젝트에만 있고 `front-end/`와 `database/`는 그 저장소 밖의 통합 워크스페이스에 있습니다. 이 문서의 `../../front-end`, `../../database` 링크는 현재 `D:\programing\new-pj` 배치 기준입니다.
- 디렉터리, Gradle 프로젝트명, Java package의 `fashtion`은 현재 실제 이름에 포함된 오타입니다. 전체 rename을 별도 작업으로 합의하기 전에는 일부 경로만 `fashion`으로 바꾸지 않습니다.
- `build.gradle`에 선언된 JPA, Redis, Kafka, Batch, Security는 대부분 의존성만 존재하며 구현 완료를 의미하지 않습니다.
- 별도 설계된 PostgreSQL 스키마는 `database/`에 있지만 현재 애플리케이션 migration 흐름과 연결되어 있지 않습니다.
- 프론트엔드 API 계약도 아직 없습니다. 존재하지 않는 endpoint, DTO, 인증 규칙을 추측하지 않습니다.

## 기술 스택

| 구분 | 현재 구성 |
| --- | --- |
| 언어·런타임 | Java 17 toolchain |
| 애플리케이션 | Spring Boot 4.1.1 |
| 빌드 | Gradle Wrapper 9.7.1, Groovy DSL |
| 웹 | Spring MVC, Validation |
| 데이터 | Spring Data JPA, PostgreSQL JDBC |
| 인프라 | Redis, Kafka, Spring Batch |
| 보안·운영 | Spring Security, Actuator |
| 개발 지원 | Lombok, DevTools, Spring Boot Docker Compose |
| 테스트 | JUnit Platform과 Spring Boot test starters |

단일 Gradle 프로젝트이며 서브모듈은 없습니다. 별도의 시스템 Gradle 설치 없이 wrapper를 사용합니다.

## 빠른 시작

### 준비물

- JDK 17
- 현재 무설정 local 실행에는 실행 중인 Docker daemon(Docker Desktop 포함)과 Docker Compose
- 외부 PostgreSQL·Redis를 사용한다면 해당 연결 정보를 제공할 별도 profile 또는 환경변수

다음 명령은 백엔드 프로젝트 루트 `D:\programing\new-pj\back-end\multi-seller-fashtion-marketplace`에서 실행합니다. Windows PowerShell에서는 다음과 같이 확인하고 시작합니다.

```powershell
java -version
.\gradlew.bat --version
.\gradlew.bat bootRun
```

서버 포트를 별도로 설정하지 않았으므로 Spring Boot 기본값은 `http://localhost:8080`입니다. 이는 아직 공개 API 계약으로 고정된 값은 아닙니다.

Spring Boot Docker Compose 개발 의존성이 `compose.yaml`을 감지하도록 구성되어 있습니다. 자동 인프라 시작이 환경에서 동작하지 않으면 다음 중 설치된 명령을 사용합니다.

```powershell
docker compose up -d
docker compose ps
```

아래 예제는 `docker compose` plugin 문법을 사용합니다. 이 명령이 없는 standalone Compose 환경에서는 모든 예제의 `docker compose`를 `docker-compose`로 바꿉니다.

Docker Compose를 사용하지 않으면 서비스를 실행하는 것만으로는 충분하지 않습니다. 예를 들어 `SPRING_DOCKER_COMPOSE_ENABLED=false`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `SPRING_DATA_REDIS_HOST`, `SPRING_DATA_REDIS_PORT`를 환경에 맞게 제공해야 합니다. 실제 변수와 profile은 아직 프로젝트에 확정되어 있지 않습니다.

현재 `compose.yaml`의 포트 표기는 고정 host port가 아니라 런타임 할당 방식입니다. 직접 접속할 포트는 다음처럼 확인합니다.

```powershell
docker compose port postgres 5432
docker compose port redis 6379
```

작업 후에는 다음 명령으로 개발 인프라를 종료합니다.

```powershell
docker compose down
```

## 명령어

| Windows 명령 | 용도 |
| --- | --- |
| `.\gradlew.bat bootRun` | 개발용 애플리케이션 실행 |
| `.\gradlew.bat test` | JUnit Platform 테스트 실행 |
| `.\gradlew.bat clean build` | 전체 검증과 실행 jar 빌드 |
| `.\gradlew.bat bootJar` | Spring Boot 실행 jar 생성 |
| `.\gradlew.bat tasks` | 사용 가능한 Gradle task 확인 |

현재 Git index의 `gradlew`에는 실행 bit가 없습니다. 이를 저장소에서 고치기 전 macOS/Linux에서는 `.\gradlew.bat` 대신 `sh ./gradlew`를 사용합니다.

### 현재 baseline 검증 상태

문서 기준일에 `.\gradlew.bat test`를 실행하면 `contextLoads()`가 실패합니다. JPA가 datasource를 자동 구성하려 하지만 datasource URL도 embedded database도 없어 `Failed to determine a suitable driver class`가 발생합니다. 이는 README 변경으로 생긴 오류가 아니라 현재 스캐폴드의 미완성 설정입니다.

첫 백엔드 구현 작업에서 test profile용 격리 DB 또는 Testcontainers 같은 테스트 인프라를 정하고 이 실패를 먼저 해소해야 합니다. 그 전에는 백엔드 test/build가 통과한다고 보고하지 않습니다.

현재 실행 jar에는 `developmentOnly` Docker Compose 지원이 포함되지 않고, 운영용 datasource 설정도 없습니다. 따라서 `java -jar ...` 실행을 배포 가능 상태로 간주하지 않습니다. 실행 profile, 비밀값 주입, 사용할 PostgreSQL·Redis 등 인프라 연결과 migration을 먼저 구성해야 합니다. Kafka를 사용하지 않는다면 연결을 강제하지 말고 의존성을 유지할지 결정합니다.

## 현재 구조

```text
multi-seller-fashtion-marketplace/
├─ gradle/wrapper/                    # 고정 Gradle Wrapper
├─ src/
│  ├─ main/
│  │  ├─ java/multi/com/multisellerfashtionmarketplace/
│  │  │  └─ MultiSellerFashtionMarketplaceApplication.java
│  │  └─ resources/
│  │     └─ application.properties
│  └─ test/java/multi/com/multisellerfashtionmarketplace/
│     └─ MultiSellerFashtionMarketplaceApplicationTests.java
├─ build.gradle
├─ settings.gradle
├─ compose.yaml
├─ gradlew
└─ gradlew.bat
```

베이스 package `multi.com.multisellerfashtionmarketplace` 아래가 기본 component scan 범위입니다. 현재 controller, service, repository, entity, security configuration, Kafka listener, batch job은 없습니다.

## 현재 설정과 인프라

`application.properties`에는 애플리케이션 이름만 있습니다.

```properties
spring.application.name=multi-seller-fashtion-marketplace
```

현재 별도 profile, application 환경변수, datasource URL, JPA `ddl-auto`, Redis/Kafka 주소, CORS 설정은 없습니다.

`compose.yaml`은 개발 초안입니다.

| 서비스 | 현재 구성 | 주의점 |
| --- | --- | --- |
| PostgreSQL | `postgres:latest`, DB `mydatabase`, user `myuser` | 버전 미고정, 개발용 평문 비밀번호, 고정 host port 없음 |
| Redis | `redis:latest` | 버전 미고정, 고정 host port 없음 |
| Kafka | 서비스 없음 | 의존성만 선언되어 있음 |

운영 전에는 image 버전을 고정하고 실제 자격증명을 외부 주입해야 합니다. 로컬 Compose 데이터를 유지해야 한다면 volume과 healthcheck를 추가하고, 운영 환경에는 별도의 영속성·healthcheck·백업 정책을 정의합니다. 현재 `secret`은 명시적인 로컬 placeholder이며 다른 환경의 자격증명으로 재사용하지 않습니다.

Spring Security starter가 있으므로 명시적 설정을 추가하기 전에는 framework 기본 보안 동작이 적용될 수 있습니다. 생성된 개발 비밀번호나 기본 login을 프로젝트 인증 설계로 간주하지 않습니다.

## 목표 MSA에서의 위치

현재 프로젝트는 아직 특정 microservice로 확정되지 않은 bootstrap app입니다. 새 business 기능을 이 애플리케이션에 계속 모아 modular monolith를 만들지 않습니다.

- 먼저 [상위 MSA 소유권 표](../README.md)를 확인해 기능 owner service를 결정합니다.
- 현재 앱을 service template으로 사용할지, `commerce-service`로 전환할지는 별도 migration 작업에서 결정합니다.
- 다른 service가 소유할 entity·repository·migration을 이 프로젝트에 추가하지 않습니다.
- MSA 디렉터리 전환 전에는 기존 파일과 nested Git repository를 임의로 이동하거나 삭제하지 않습니다.

## 데이터베이스 기준

검토된 데이터베이스 산출물은 현재 통합 워크스페이스 상위의 `database/`에 있습니다. 백엔드 저장소를 단독 clone하면 이 문서의 외부 링크와 DB 명령은 사용할 수 없으므로 별도 위치를 연결해야 합니다.

- [데이터베이스 작업 안내](../../database/README.md)
- [외부 ERD용 DBML](../../database/marketplace.dbml)
- [브라우저 ERD](../../database/marketplace-erd.html)
- [PostgreSQL DDL](../../database/postgresql/marketplace_schema.sql)
- [인덱스 검토](../../database/INDEX_REVIEW.md)

현재 기준은 PostgreSQL 16+, 106개 테이블, 196개 외래 키, 191개 명시적 인덱스입니다. 이 숫자는 이후 스키마 변경으로 달라질 수 있으므로 생성 산출물과 `validate-schema.mjs`의 최신 결과를 기준으로 확인합니다. 현재 validator의 의도된 경고는 [인덱스 검토 문서](../../database/INDEX_REVIEW.md)에 설명되어 있으므로 경고를 모두 자동 수정하지 않습니다.

중요한 현재 차이점은 다음과 같습니다.

- DDL은 `marketplace` schema를 생성하지만 백엔드 JPA와 연결되어 있지 않습니다.
- database 문서의 적용 예시는 DB 이름 `marketplace`, Compose의 DB 이름은 `mydatabase`입니다.
- Flyway/Liquibase와 migration resource가 없습니다.
- JPA entity와 repository도 아직 없습니다.
- 애플리케이션이 DDL을 자동 생성하거나 자동 적용한다고 가정하면 안 됩니다.

DB 변경 시 생성된 합본 파일을 직접 수정하지 않습니다. `database/_parts/`의 도메인 원본을 수정한 다음 통합 워크스페이스 루트 `D:\programing\new-pj`에서 재생성·검증합니다.

이 작업에는 Node.js, PowerShell, 실제 적용 시 PostgreSQL `psql` client가 추가로 필요합니다.

```powershell
powershell -ExecutionPolicy Bypass -File database/postgresql/build-artifacts.ps1
node database/postgresql/validate-schema.mjs
```

빈 PostgreSQL 16+ 데이터베이스에 적용할 때는 workspace 루트에서 실제 host, published port, 사용자와 DB 이름을 명시합니다.

```powershell
psql -h <host> -p <published-port> -U <user> -d <database-name> `
  -v ON_ERROR_STOP=1 `
  -f database/postgresql/marketplace_schema.sql
```

현재 Compose를 대상으로 한다면 user는 `myuser`, database는 `mydatabase`이며 published port는 `docker compose port postgres 5432` 결과를 사용합니다. `marketplace`는 DDL이 생성하는 schema 이름이므로 database 이름과 구분합니다. `pgcrypto` extension과 `marketplace` schema를 만들 권한이 필요합니다. 애플리케이션 migration 전략을 정하면 이 절차와 산출물을 Flyway 또는 Liquibase 흐름에 연결하고 README를 갱신합니다.

## 서비스 내부 코드 배치 기준

이 프로젝트가 목표 MSA의 특정 service로 전환된 경우에만 아래 내부 구조를 적용합니다. 하나의 app 안에 모든 marketplace domain을 병렬 package로 추가하는 기준이 아닙니다.

```text
<service base package>/
├─ api/                         # controller, Kafka adapter, transport DTO
├─ application/                 # use case, saga/process manager, transaction 경계
├─ domain/                      # 해당 service가 소유하는 aggregate와 rule
└─ infrastructure/              # JPA, Kafka, Redis, 외부 provider adapter
```

- controller는 HTTP 변환과 validation을 담당하고 핵심 규칙은 application/domain에 둡니다.
- request/response DTO와 persistence entity를 분리합니다.
- transaction 경계를 use case 단위로 명시합니다.
- 외부 결제·배송·알림 연동은 interface와 adapter로 격리합니다.
- 주문, 결제, 재고, 정산 같은 ledger/event성 데이터를 임의로 update/delete하지 않습니다.
- 다른 service의 entity·repository를 import하지 않고 external ID, API contract, event로만 연결합니다.
- 공유 library에는 logging, tracing, security/messaging primitive만 두고 domain DTO/entity를 공유하지 않습니다.

## API와 인증 계약

현재 REST controller, API base path, OpenAPI, 공통 오류 형식, 인증·인가 구현이 모두 없습니다. 다음 항목을 확정하기 전에 AI가 API를 임의로 발명하면 안 됩니다.

- `/api/v1` 같은 버전·경로 규칙
- Bearer JWT와 cookie session 중 인증 방식
- 역할·권한 모델과 401/403 구분
- CORS, credentials, CSRF 정책
- 성공·오류 envelope와 validation 오류 형식
- 페이지네이션, 정렬, 필터 규약
- idempotency key 적용 범위
- OpenAPI 생성·검증·프론트 타입 생성 흐름

현재 선택된 API base와 proxy 전략은 없습니다. 배포 구조를 확인한 뒤 아래 후보 중 하나를 프론트엔드와 합의합니다.

- same-origin 후보: browser API base `/api/v1`, 개발 Vite proxy target `http://localhost:8080`
- cross-origin 후보: 프론트 공개 환경변수로 backend origin을 주입하고, CORS allowlist를 실제 개발 서버 origin(기본 `http://localhost:5173`)으로 제한

위 경로와 포트는 현재 기본값을 사용한 비교용 후보일 뿐 승인된 계약이 아닙니다. 계약 확정 전에는 구현하지 않습니다. OpenAPI 단일 계약, JSON `camelCase`, UUID·timestamp·date 표현, `bigint` 금액의 안전한 JSON 표현도 양쪽 구현 전에 결정해야 합니다. 결제·환불·claim 같은 재시도 가능한 쓰기 API에는 idempotency 정책을 함께 검토합니다.

프론트엔드는 기본적으로 별도 origin에서 실행되므로 proxy 또는 제한된 CORS allowlist 중 하나를 선택해야 합니다. 자세한 현재 상태는 [프론트엔드 README](../../front-end/README.md)를 확인합니다.

## AI 작업 절차

### 작업 전

1. `build.gradle`, 설정 파일, 관련 package와 테스트를 먼저 읽습니다.
2. `../../database/README.md`와 관련 테이블·제약·index를 확인합니다.
3. controller부터 DB까지 한 use case의 변경 범위와 transaction 경계를 정합니다.
4. 외부 계약이나 정책이 없으면 추측하지 말고 미결정 항목을 명시합니다.
5. `front-end/`와 `database/`는 현재 백엔드 Git 저장소 밖이므로 사용자 요청 범위에 명시적으로 포함된 경우에만 수정합니다.

### 구현 중

- 요청 범위 밖의 dependency·infrastructure를 함께 도입하지 않습니다.
- schema 변경은 `../../database/_parts/` 원본과 생성 DDL/DBML을 맞추고, 해당 테이블에 백엔드 mapping이 이미 있거나 이번 작업에서 도입되는 경우 mapping과 테스트도 함께 갱신합니다.
- 실제·공유·운영 자격증명과 운영 URL은 코드·Compose·README에 커밋하지 않습니다. 명시적인 로컬 placeholder도 다른 환경에서 재사용하지 않습니다.
- 입력 validation과 도메인 invariant를 구분하고 둘 다 검증합니다.
- 인증이 필요한 endpoint는 권한 성공뿐 아니라 미인증 401과 권한 부족 403도 테스트합니다.
- 시간은 UTC 기준을 유지하고 settlement 같은 명시적 영업일만 별도 `date` 규칙을 사용합니다.
- 동시성에 민감한 재고·결제·정산 변경은 transaction, lock, idempotency와 재시도 영향을 검토합니다.
- 사용자 요청 범위에 프론트엔드 변경이 포함된 경우에만 프론트 타입과 소비 코드를 함께 수정합니다. 범위에 없으면 프론트를 임의 수정하지 말고 필요한 계약 변경과 blocker를 보고합니다.

### 완료 전

코드, 설정 또는 의존성을 변경했다면 현재 baseline datasource 문제를 먼저 해소하고 최종 검증을 실행합니다. `clean build`에는 test 실행이 포함됩니다.

```powershell
.\gradlew.bat clean build
```

빠른 테스트 반복에는 `.\gradlew.bat test`만 사용할 수 있습니다. 문서만 변경했다면 상대 링크와 문서화한 명령을 실제 파일과 대조합니다. 실행하지 못했거나 baseline 문제로 실패한 검증은 이유를 밝히고 통과했다고 쓰지 않습니다. DB가 바뀌었다면 schema 재생성·정적 검증과 빈 PostgreSQL 적용도 확인합니다. API가 바뀌었다면 사용자 요청 범위 안에서 OpenAPI 또는 명시된 계약, 프론트 타입과 연동 테스트를 함께 갱신합니다.

## 테스트 기준

현재 테스트는 `contextLoads()` 하나뿐이며, datasource 미설정으로 현재 실패합니다. test profile과 격리된 DB 구성을 먼저 만든 뒤 새 use case에는 위험에 맞는 다음 테스트를 추가합니다.

- 순수 domain rule unit test
- application service transaction·권한 test
- controller validation·serialization test
- repository query와 constraint integration test
- 인증 401/403 및 역할별 authorization test
- 외부 adapter의 timeout, retry, duplicate callback test

테스트에서 운영 서비스나 공유 DB에 접속하지 않습니다. test profile과 격리된 DB 전략이 아직 없으므로 이를 도입할 때 실행 방법을 이 문서에 함께 기록합니다.

## 작업 완료 기준

- 해당되는 경우 요청 use case의 정상, validation 실패, 권한 실패, 경계 조건이 처리됩니다.
- 변경 범위에 해당하는 검증이 통과합니다. 백엔드 코드, 설정 또는 의존성 변경의 최종 검증은 test를 포함하는 `.\gradlew.bat clean build`입니다.
- schema 변경 시 DDL·DBML·검증 문서가 일치하고, 영향받는 JPA mapping이 있다면 함께 일치합니다.
- API 변경 시 DTO, 오류 처리, 계약 문서가 일치하며 사용자 요청 범위에 프론트가 포함된 경우 소비 코드도 일치합니다.
- 실제·공유·운영 자격증명이 커밋되지 않았고, 해당 환경별 설정이 외부 주입됩니다.
- README의 구현 현황과 실제 코드가 서로 일치합니다.

## 우선 결정할 기술 부채

1. `fashtion` 이름을 전체 rename할지 유지할지 결정
2. PostgreSQL·Redis image version과 database 이름 고정
3. DDL을 Flyway/Liquibase migration으로 연결
4. Kafka를 local infrastructure에 추가할지 의존성을 보류할지 결정
5. 인증 방식, CORS, API version, OpenAPI 규약 결정
6. local/test/prod profile과 비밀값 주입 방식 정의
7. test database 격리와 CI 검증 흐름 구성

## 관련 문서

- [목표 백엔드 MSA 아키텍처](../README.md)
- [프론트엔드 README](../../front-end/README.md)
- [데이터베이스 README](../../database/README.md)
- [인덱스 검토](../../database/INDEX_REVIEW.md)

## AI 요청 템플릿

```text
목표: [구현할 use case와 사용자 결과]
수정 범위: [domain/API/table 또는 제외 범위]
계약: [endpoint, request/response, 권한, 오류 규칙]
데이터 규칙: [transaction, 동시성, idempotency, 보존 정책]
완료 조건: [unit/integration/contract test와 빌드]
제약: [추가하면 안 되는 dependency, 호환성, 운영 조건]
```
