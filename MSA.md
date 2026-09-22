# 백엔드 실행·검증 가이드

기준일: 2026-09-21. 아키텍처·업무 규칙의 기준은 [BACKEND_DESIGN.md](docs/BACKEND_DESIGN.md)입니다. 이 문서는 실행과 검증만 다룹니다.

## 모듈과 포트

| 모듈 | 앱 포트 | DB / schema | PostgreSQL 호스트 포트 |
| --- | ---: | --- | ---: |
| commerce-service | 8081 | commerce / marketplace | 5432 |
| payment-service | 8082 | payment / marketplace | 5433 |
| settlement-service | 8083 | settlement / marketplace | 5434 |
| discovery-data-service | 8084 | discovery / marketplace | 5435 |
| pg-kakao-simulator | 8090 | pgkakao / pgkakao | 5436 |
| pg-naver-simulator | 8091 | pgnaver / pgnaver | 5437 |

`pg-simulator-common`은 HTTP DTO 라이브러리이며 별도 프로세스가 아닙니다. Redis는 6379, Kafka는 9092를 사용합니다. 기존 `pg-simulator` 모듈은 Kakao/Naver 모듈로 교체됐습니다.

실제 Java package는 `multi.com.marketplace.{commerce,payment,settlement,discovery,pgkakaosimulator,pgnaversimulator,pgsimulatorcommon}`입니다. 각 모듈은 독립 jar와 DB를 가집니다.

## 환경 프로필

| 프로필 | DB | Flyway | 사용 범위 |
| --- | --- | --- | --- |
| 기본 local — 업무 4개 | H2 메모리 | 꺼짐 | 기동·단위 개발; PostgreSQL 스키마 검증 아님 |
| 기본 local — PG 2개 | H2 메모리 | 켜짐 | 실제 PG V1으로 API 테스트 |
| test — 업무 4개 | H2 메모리 | 꺼짐 | context 테스트 |
| docker | PostgreSQL | 켜짐 | 개인 로컬 Compose |
| dev | 외부 주입 PostgreSQL | 켜짐 | 공유 개발 인프라는 별도 구성 필요 |
| stage/prod | 외부 주입 PostgreSQL | 명시적 환경변수 | 배포 인프라·인증·복구 정책은 아직 미구현 |

PG 테스트는 기본 local을 사용하며 PostgreSQL 검증 시 docker와 전용 datasource를 주입합니다. 프로필 파일의 존재는 실제 배포 완료를 의미하지 않습니다. 어떤 프로필이든 PG simulator는 실결제를 수행하지 않습니다.

`dev/stage/prod`에서 필요한 환경변수:

| 대상 | 변수 |
| --- | --- |
| 모든 실행 모듈 | MARKETPLACE_DATASOURCE_URL, MARKETPLACE_DATASOURCE_USERNAME, MARKETPLACE_DATASOURCE_PASSWORD |
| Commerce/Discovery | MARKETPLACE_REDIS_HOST, MARKETPLACE_REDIS_PORT, MARKETPLACE_KAFKA_BOOTSTRAP_SERVERS |
| Payment/Settlement | MARKETPLACE_KAFKA_BOOTSTRAP_SERVERS |
| stage/prod 전체 | MARKETPLACE_FLYWAY_ENABLED |

`SPRING_PROFILES_ACTIVE`로 활성화합니다. 현재 PG endpoint·credential 설정은 Payment HTTP adapter가 없어 소비되지 않습니다. 아직 없는 변수를 설정하는 것만으로 연동된다고 가정하지 않습니다.

## 로컬 빌드·단일 실행

JDK 17과 Gradle wrapper를 사용합니다. PowerShell에서 현재 PC의 JDK 경로가 필요하면 설정합니다.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
.\gradlew.bat clean build --no-daemon
.\gradlew.bat :payment-service:test --no-daemon
.\gradlew.bat :pg-kakao-simulator:bootRun
```

다른 모듈도 `:모듈명:bootRun`으로 실행합니다. H2는 종료 시 데이터가 사라집니다. Compose와 같은 포트로 동시에 실행하지 않습니다. 업무 서비스는 현재 기동 기반이며 고객 API가 없습니다. Commerce/Payment/Settlement에는 Spring Security 기본 설정이 적용되고, 정식 인증 계약은 미구현입니다.

## 전체 로컬 Compose

PostgreSQL 17.11, Redis 7.4.11, Kafka 4.1.2 이미지가 compose.yaml에 고정돼 있습니다. `.env.example`은 로컬 값의 예시입니다. 기존 `.env`를 덮어쓰지 말고 필요한 변수만 맞춥니다.

```powershell
docker compose config --quiet
docker compose up --build -d
docker compose ps
docker compose logs --tail 100 commerce-service payment-service settlement-service discovery-data-service pg-kakao-simulator pg-naver-simulator
docker compose down
```

`down`은 DB volume을 유지합니다. `down -v`는 모든 해당 로컬 DB 데이터를 삭제하므로 일반 종료 명령으로 사용하지 않습니다. 이번 검토에서 기존 Compose DB를 초기화하거나 운영 migration을 실행하지 않았습니다.

Compose의 host 공개 포트는 127.0.0.1에 바인딩합니다. 이 환경은 로컬용이며 simulator에 인증은 없습니다. 공유 배포 전 호출 인증과 네트워크 정책을 구현합니다. 개별 bootRun도 공개 네트워크에 노출하지 않습니다.

Kafka가 광고하는 `kafka:9092`는 Docker 내부용입니다. 호스트 JVM에서 Kafka를 실제 사용할 때는 별도 외부 listener를 구성합니다. 현재 Kafka producer/consumer는 미구현입니다.

업무 서비스 Actuator 확인:

```powershell
Invoke-RestMethod http://localhost:8081/actuator/health
Invoke-RestMethod http://localhost:8082/actuator/health
Invoke-RestMethod http://localhost:8083/actuator/health
Invoke-RestMethod http://localhost:8084/actuator/health
```

PG simulator에는 Actuator 의존성이 없습니다. 앱 기동 로그와 PG API 호출로 확인합니다. 없는 UUID에 대한 GET의 provider별 404는 API 처리 확인에 사용할 수 있지만 DB 전체 상태를 보장하는 health check는 아닙니다.

## DB 변경·검증

각 서비스의 `src/main/resources/db/migration`에 버전 migration을 추가합니다. V1은 이미 적용된 기준이므로 수정·재생성하지 않습니다. V2는 누락 내부 FK를 복원합니다. 기존 orphan이 있으면 실패하며 데이터 검토 후 해결해야 합니다.

통합 워크스페이스에 `../../database/_parts`가 있을 때 다음을 실행합니다.

```powershell
.\scripts\generate-service-migrations.ps1
.\scripts\verify-service-schema.ps1
```

생성기는 `build/schema-preview/<service>/V1__service_owned_schema.sql`에 비교 후보만 생성합니다. 기존 서비스 migration 파일을 덮어쓰지 않습니다. 새로운 원본 변경은 candidate diff를 검토하여 새 버전 migration으로 작성합니다. SQL 적용은 빈 격리 PostgreSQL에서 서비스별 DB에 V1, V2 순으로 검증하고, 기존 DB용 업그레이드 경로도 검증합니다.

## 검증 명령과 한계

```powershell
.\gradlew.bat clean build --no-daemon
.\scripts\verify-service-schema.ps1
.\scripts\verify-doc-links.ps1
git diff --check
```

문서 검사는 상대 링크와 코드 블록을 확인하며 외부 URL 가용성이나 업무 의미를 증명하지 않습니다.

PG PostgreSQL 테스트는 기존 데이터와 분리된 DB를 준비한 뒤, 새 PowerShell 세션에서 아래처럼 실행합니다. URL은 반드시 테스트 DB로 바꿉니다. 테스트가 결제 데이터를 작성합니다.

```powershell
$env:SPRING_PROFILES_ACTIVE = 'docker'
$env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://localhost:15439/postgres'
$env:SPRING_DATASOURCE_USERNAME = 'postgres'
$env:SPRING_DATASOURCE_PASSWORD = '<test-db-password>'
.\gradlew.bat :pg-kakao-simulator:test :pg-naver-simulator:test --rerun-tasks --no-daemon
```

위 환경변수는 현재 셸에 남으므로 테스트용 셸을 종료한 뒤 일반 개발 명령을 실행합니다. 두 simulator는 서로 다른 schema를 생성하므로 테스트에서는 한 격리 DB를 사용할 수 있습니다. 실제 Compose는 별도 DB입니다.

2026-09-21 검증 결과: clean build 및 후속 변경을 포함한 전체 build 성공, 최종 39개 테스트 통과. PG API/동시성 테스트는 별도 PostgreSQL 17.11에서도 검증했습니다. 4개 업무 서비스의 V1+V2 SQL 적용 및 내부 FK 136/14/14/7개 확인. 전체 Compose 앱 E2E, 실결제, 재시작 복구, 운영 배포는 검증 범위가 아닙니다.
