# 4개 서비스 마켓플레이스 MSA

첫 서비스 경계는 합의한 비즈니스 역량을 기준으로 정했습니다. 도메인 코드는 서비스 내부에서 모듈로 나누고, 독립 배포·확장·장애 격리·정합성 요구가 충분해질 때만 서비스를 추가로 분리합니다.

```text
multi-seller-fashtion-marketplace/
├─ commerce-service/       # 마켓플레이스 거래 코어
├─ payment-service/        # 결제와 환불 처리
├─ settlement-service/     # 셀러 정산과 대사
├─ discovery-data-service/ # 검색, 전시, 행동 데이터
├─ pg-simulator/           # 개발·통합 테스트용 가상 PG
├─ compose.yaml            # 로컬 4개 서비스 실행 환경
└─ scripts/                # DB 기준 생성 스크립트
```

| 서비스 | 담당 기능 | 포트 | 데이터베이스 |
| --- | --- | --- | --- |
| `commerce-service` | 회원/셀러, 상품/재고, 장바구니, 주문, 배송, 클레임, 리뷰 | 8081 | `commerce` |
| `payment-service` | 결제 승인·취소, 환불, PG 웹훅 | 8082 | `payment` |
| `settlement-service` | 구매확정, 셀러 원장, 정산, 지급, 대사 | 8083 | `settlement` |
| `discovery-data-service` | 검색, 전시/추천 입력, 사용자 행동 분석 | 8084 | `discovery` |
| `pg-simulator` | 승인·취소·부분환불을 흉내 내는 개발용 PG | 8090 | 없음 |

각 서비스는 자신의 데이터베이스와 Flyway migration 이력을 소유합니다. 서비스 경계를 넘는 관계는 데이터베이스 외래 키가 아니라 외부 UUID로 표현합니다. 변경은 버전이 있는 HTTP 계약과 서비스별 outbox/inbox를 사용하는 Kafka 이벤트로 조정합니다.

## 서비스 내부 뼈대 (2026-09-09)

각 서비스의 기존 `multi.com.marketplace.<service>` 패키지 아래에 업무 패키지를 두고, 업무별로 다음 계층을 구성합니다. 디렉터리는 역할을 설명하는 `package-info.java`로 보존합니다. 결제 서비스에는 핵심 도메인 모델과 내부 유스케이스 인터페이스를 추가했습니다. 세부 범위는 [결제 서비스 문서](payment-service/README.md)를 참고합니다. 아직 Controller, JPA Entity, Repository, PG 호출이나 공개 API 계약은 구현하지 않았습니다.

```text
<업무>/
├─ api/             # HTTP·이벤트 수신, 전송 DTO
├─ application/     # 유스케이스, 트랜잭션 경계, 연동 포트
├─ domain/          # 업무 모델과 규칙
└─ infrastructure/  # 영속성, 메시징, 외부 연동 구현
```

| 서비스 | 내부 업무 패키지 |
| --- | --- |
| commerce | member, seller, catalog, inventory, cart, order, fulfillment, claim, review |
| payment | transaction, refund, webhook |
| settlement | ledger, calculation, payout, reconciliation |
| discovery | search, concept, analysis, behavior |

- 서비스 간 Java 모듈 의존성이나 공유 Entity는 추가하지 않습니다.
- 다른 업무의 repository를 직접 호출하지 않고 application 계층의 공개 기능으로 연동합니다.
- 패키지는 현재 주요 업무를 위한 시작점입니다. 추가 업무와 세부 클래스는 해당 기능을 구현할 때 만듭니다.
- 구매확정 관련 테이블은 현재 commerce migration에 있으므로 `commerce.fulfillment`에 자리를 마련했습니다. 위 서비스 담당 표의 settlement 구매확정 표기는 추후 소유권 논의가 필요하며 이번 작업에서 테이블을 이동하지 않았습니다.

## 명령어

Windows에서 로컬 빌드는 JDK 17을 사용합니다. 현재 PC의 설치 경로는 아래와 같습니다.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

```powershell
# 모든 서비스를 빌드하고 테스트합니다.
.\gradlew.bat clean build

# H2를 사용하는 local 프로필로 서비스 하나를 실행합니다.
.\gradlew.bat :commerce-service:bootRun
.\gradlew.bat :payment-service:bootRun
.\gradlew.bat :settlement-service:bootRun
.\gradlew.bat :discovery-data-service:bootRun
```

기본 `local`, `test` 프로필은 H2를 사용하며 Flyway를 실행하지 않습니다. `docker` 프로필은 PostgreSQL을 사용하며 Flyway를 실행합니다.

## 데이터베이스 기준

상위 워크스페이스의 `database/` 폴더가 검토된 마켓플레이스 데이터 모델의 원본입니다. 원본이 변경되면 다음 명령으로 서비스별 Flyway 기준 migration을 다시 생성합니다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/generate-service-migrations.ps1
```

생성기는 각 서비스에 할당된 테이블과 양쪽 모두 해당 서비스가 소유한 외래 키만 복사합니다. 서비스 간 참조는 UUID로 남깁니다. 공유·운영 환경에 적용하기 전에는 생성된 migration을 반드시 검토해야 합니다.

## Docker Compose

```powershell
# 선택 사항: .env.example을 .env로 복사한 뒤 로컬 값만 변경합니다.

# 이미지 빌드, 4개 DB 생성, Flyway migration 적용, 전체 실행
docker compose up --build -d

# 상태와 시작 로그 확인
docker compose ps
docker compose logs -f commerce-service payment-service settlement-service discovery-data-service

# 컨테이너만 내리고 로컬 데이터는 유지
docker compose down

# 컨테이너와 모든 로컬 볼륨을 함께 삭제
docker compose down -v
```

Compose는 PostgreSQL을 `5432`~`5435`, Redis를 `6379`, Kafka를 `9092`, 애플리케이션을 `8081`~`8084` 포트로 노출합니다. `.env.example`의 값은 로컬 개발 전용입니다. 공유·운영 환경에서는 별도 자격 증명과 외부 인프라 주소를 주입해야 합니다.

## 현재 PC의 로컬 환경 (2026-09-09)

검증 완료: `clean build --no-daemon` 성공, 서비스별 context 테스트 총 4개 통과, 네 서비스의 `/actuator/health`가 모두 `UP`, PostgreSQL 4개·Redis·Kafka가 모두 healthy입니다. 네 DB의 Flyway V1 성공 이력을 직접 조회했습니다. 업무 테이블은 commerce 76개, payment 11개, settlement 12개, discovery 10개이며 각 DB에는 별도의 Flyway 이력 테이블이 1개씩 있습니다.

- `.env`를 생성했으며 `COMPOSE_PROJECT_NAME=marketplace-four-services-local`을 지정했습니다. 이전 `multi-seller-marketplace` 환경과 컨테이너·볼륨을 분리합니다. `.env`는 Git에서 제외됩니다.
- 전체 환경은 프로젝트 루트에서 `docker compose up --build -d`로 실행하고 `docker compose down`으로 종료합니다. 일반 종료 시 DB 볼륨은 유지됩니다.
- Docker 실행 시 각 서비스의 PostgreSQL 스키마는 `spring-boot-starter-flyway`를 통해 자동 적용됩니다. Spring Boot 4에서는 `flyway-core`만 추가하면 자동 설정이 포함되지 않습니다. [공식 설명](https://spring.io/blog/2025/10/28/modularizing-spring-boot/)
- `pg-simulator`는 전용 PostgreSQL `pgsim`(호스트 5436)과 Flyway V1을 사용합니다. 승인·취소·환불 호출과 거래 이력은 `pgsim.pg_payment`, `pgsim.pg_transaction`에 저장됩니다.
- 서비스 상태 확인 주소는 `http://localhost:8081/actuator/health`부터 `http://localhost:8084/actuator/health`까지입니다.
- 현재 실행 방식은 전체 Docker Compose 또는 개별 서비스의 H2 `local` 프로필입니다. Kafka의 광고 주소 `kafka:9092`는 Docker 내부용이므로 호스트에서 실행하는 앱과 Kafka를 연동하려면 별도 외부 listener 설정이 필요합니다.
- Docker Compose가 실행 중일 때 같은 서비스의 `bootRun`을 동시에 실행하면 8081~8084 포트가 이미 사용 중이라 실패합니다. 먼저 해당 컨테이너를 멈추거나 별도 포트를 사용합니다.
