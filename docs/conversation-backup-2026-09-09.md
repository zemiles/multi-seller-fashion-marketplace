# 작업 대화 백업

백업일: 2026-09-09
프로젝트: `multi-seller-fashtion-marketplace`

## 사용자가 전달한 참고 대화

- 이전 공유 링크: https://chatgpt.com/s/cx_6aa0ba4831648191b29569c4069edbef
- 전체 재확인 링크: https://chatgpt.com/share/6a94ed7b-1184-83e8-88fe-b0a3fd22cc8f
- 사용자는 매번 링크를 다시 보내지 않고 저장소에 맥락을 남기길 요청했다.

## 합의된 전체 기준

- 4개 서비스 MSA: `commerce-service`, `payment-service`, `settlement-service`, `discovery-data-service`.
- 개발 착수용 논리 ERD/DDL 기준: 106개 테이블, 196개 외래 키, 191개 명시적 인덱스.
- 서비스별 DB와 Flyway migration을 소유하며, 서비스 간 관계는 외래 키가 아닌 외부 UUID·HTTP 계약·Kafka 이벤트로 연결한다.
- 결제는 `Payment`(전체 결제), `PaymentItem`(상품별 금액), `PaymentTransaction`(승인·전체취소·부분취소 이력)으로 분리한다.
- PG 호출 전에 `PENDING_PAYMENT` 주문을 만들고 웹훅 멱등성·복구 구조를 사용한다.
- 재고는 Redis만을 원장으로 사용하지 않고 DB `inventory_reservation`을 진실의 원천으로 둔다.
- 부분 취소·환불은 상품·수량·배송비별 배분으로 추적한다.
- 주문 시점 상품명·옵션·가격은 불변 snapshot으로 보존한다.
- 분할 배송·부분 반품·구매확정·Claim을 수량 기반으로 처리한다.
- 정산은 불변 판매자 원장·배분·지급·은행 대사 구조로 처리한다.
- 운영 전 상태 전이표, 동시성·멱등성 테스트, 할인·세금 정책, 여러 행 합계의 트랜잭션/지연 제약 검증이 필요하다.

## 환경 구성 완료 상태

- Java 17, Spring Boot 4.1.1, Gradle Wrapper 9.7.1.
- `.env` 생성: `COMPOSE_PROJECT_NAME=marketplace-four-services-local`.
- Docker Compose에 PostgreSQL 4개, Redis, Kafka와 서비스 4개가 구성되어 있다.
- 모든 서비스에 `spring-boot-starter-flyway`를 적용했다. Spring Boot 4에서는 `flyway-core`만으로 자동 설정하지 않는다.
- `docker compose up -d` 실행 후 8081~8084 `/actuator/health`가 모두 `UP`인 것을 확인했다.
- 각 서비스 PostgreSQL의 Flyway V1 적용을 확인했다.
- 전체 `clean build`와 기존 서비스 테스트가 통과했다.

## 결제 서비스 작업 상태

- 결제 도메인 상태 enum, `PaymentAmount`, `PaymentAttempt`, `Payment`, `Refund`를 추가했다.
- `PaymentUseCase`, `RefundUseCase`, `PaymentProviderPort`, `PaymentLifecycleService`를 추가했다.
- 메모리 기반 애플리케이션 서비스에서 결제 준비·승인·환불·멱등성·금액 검증을 구현했다.
- 단위 테스트에서 결제 금액 경계, 상태값, 멱등 요청, 승인 금액 불일치, 부분·전체 환불을 검증했다.
- 실제 PG는 연결하지 않는다. 대신 별도 `pg-simulator`를 사용한다.

## 결제 API 계약 초안

파일: `contracts/payment-service.openapi.yaml`
상태: `0.1.0-draft`

포함 API:

```text
POST /api/v1/payment-attempts
POST /api/v1/payment-attempts/{paymentAttemptId}/approve
GET  /api/v1/payments/{paymentId}
POST /api/v1/payments/{paymentId}/cancel
POST /api/v1/payments/{paymentId}/refunds
POST /api/v1/payment-webhooks/{provider}
```

계약에는 Bearer JWT 자리, `Idempotency-Key`, PENDING/UNKNOWN 응답, 오류 코드 자리, PG 웹훅 원문 서명 검증 자리를 포함했다. 실제 PG사·인증·웹훅 서명 알고리즘은 아직 확정하지 않았다.

## PG Simulator 작업 상태

- Gradle 서브모듈 `pg-simulator` 추가.
- 포트: 8090.
- API:

```text
POST /pg/v1/payments/approve
POST /pg/v1/payments/{paymentId}/cancel
POST /pg/v1/payments/{paymentId}/refund
GET  /pg/v1/payments/{paymentId}
```

- 전용 PostgreSQL DB `pgsim`, 호스트 포트 5436, schema `pgsim`을 추가했다.
- Flyway V1: `pg_payment`, `pg_transaction`.
- `pg_payment`는 현재 결제 상태·최초 금액·누적 환불 금액을 저장한다.
- `pg_transaction`은 APPROVE/CANCEL/REFUND 이력을 저장한다.
- `merchant_tx_id` 중복 승인을 막고, 환불은 남은 금액을 넘지 못하게 한다.
- Docker Compose에 `pg-simulator-postgres`와 `pg-simulator`를 추가했다.
- DB migration 오류(`Unsupported Database: PostgreSQL 17.11`)를 `flyway-database-postgresql` 의존성 추가로 해결했다.
- H2 테스트 호환을 위해 `timestamp with time zone`을 사용하고 UUID는 애플리케이션에서 생성한다.
- PG Simulator 테스트 3개가 통과했고, Docker 컨테이너 기동·Flyway 적용·승인 API 호출·DB 저장을 직접 확인했다.

## 현재 제한과 다음 작업

- PG Simulator는 개발·통합 테스트 전용이며 실제 PG가 아니다.
- 아직 `pg_webhook_event`, 환불 요청 이력의 별도 멱등 테이블, provider 응답 원문, 비동기 지연/실패 시뮬레이션은 추가하지 않았다.
- payment-service는 아직 JPA/REST Controller/실제 HTTP adapter/outbox와 연결되지 않았다.
- 다음 구현 순서는 PG Simulator 웹훅·실패 시나리오 → payment-service HTTP adapter와 DB Entity → outbox/inbox → Commerce 주문 검증 계약이다.

## 재부팅 후 확인 명령

```powershell
docker compose up -d
docker compose ps
Invoke-RestMethod http://localhost:8082/actuator/health
Invoke-RestMethod http://localhost:8090/actuator/health
```

프로젝트 지침과 전체 합의 요약은 루트 `AGENTS.md`에 있으며, 이 백업은 현재 대화의 상세 작업 기록이다.
