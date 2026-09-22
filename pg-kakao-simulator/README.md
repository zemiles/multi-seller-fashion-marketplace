# Kakao PG Simulator

v1 사용자 표기는 **PG1**, provider ID는 **KAKAO**입니다. 기존 모듈을 그대로 연결합니다. [PG 연결·확장 요구사항](../docs/requirements/03-payment-pg.md)의 인증/조회/웹훅/대사는 목표이며 아래 현재 구현과 구분합니다.

실제 카카오 결제사 연동이 불가한 환경에서 사용하는 카카오 역할의 독립 대체 PG입니다. 전용 PostgreSQL(`pgkakao` DB, 호스트 5436)에 결제와 거래 이력을 저장하며 Flyway V1로 초기화합니다. 이 모듈은 `api`(MVC Controller) → `application`(트랜잭션·상태 전이·멱등성) → `infrastructure`(JPA Entity·Repository) 구조를 사용합니다. Controller는 HTTP 변환만 수행하고 SQL을 직접 실행하지 않습니다.

```text
POST /pg/v1/payments/approve
POST /pg/v1/payments/{paymentId}/cancel
POST /pg/v1/payments/{paymentId}/refund
GET  /pg/v1/payments/{paymentId}
```

승인 요청은 `merchantTxId`, `currency`, `amount`, `idempotencyKey`를 받고, 취소 요청은 `{ "idempotencyKey": "..." }`, 환불 요청은 `{ "amount": 1000, "idempotencyKey": "..." }` 본문을 받습니다. `idempotencyKey`는 빈 값일 수 없습니다.

`amount`는 양수 JSON 정수여야 합니다. 소수나 숫자 문자열 자동 변환은 비활성화하여 잘못된 화폐 단위 입력을 HTTP 400으로 거부합니다.

승인 요청의 `merchantTxId`는 중복 승인되지 않으며, 같은 거래 번호를 통화나 금액이 다른 요청에 재사용하면 `409 Conflict`를 반환합니다. 취소·환불은 결제별 거래 유형과 멱등 키로 중복을 판별합니다. 같은 환불 키에 다른 금액을 보내면 `409 Conflict`를 반환합니다. 환불은 남은 금액을 초과할 수 없고, 취소된 결제에는 환불할 수 없습니다. 상태 변경과 거래 이력 기록은 하나의 DB 트랜잭션으로 처리합니다.

오류 응답은 아래 형식으로 통일합니다. 메시지는 모두 한글이며, 클라이언트는 문구 대신 `code`를 기준으로 처리합니다.
오류와 결제 응답 DTO는 `pg-simulator-common`의 공통 API 계약을 사용하며, 서버 내부에서는 `ErrorCode → PgKakaoSimulatorException → RestControllerAdvice → 오류 응답` 순서로 변환합니다.

```json
{
  "code": "KAKAO_PG_003",
  "message": "결제 정보를 찾을 수 없습니다.",
  "timestamp": "2026-09-16T00:00:00Z",
  "path": "/pg/v1/payments/{paymentId}"
}
```

주요 코드: `KAKAO_PG_001` 요청값 오류, `KAKAO_PG_002` 멱등 키 누락, `KAKAO_PG_003` 결제 없음, `KAKAO_PG_004` 가맹점 거래 번호 충돌, `KAKAO_PG_005` 상태 충돌, `KAKAO_PG_006` 환불 금액 오류, `KAKAO_PG_007` 환불 멱등성 충돌, `KAKAO_PG_999` 내부 오류.

HTTP 계층 공통 코드: `HTTP_400_001` 잘못된 요청 형식, `HTTP_400_002` 검증 실패, `HTTP_404_001` API 경로 없음, `HTTP_405_001` 허용되지 않은 메서드, `HTTP_406_001` 허용되지 않은 응답 형식, `HTTP_415_001` 지원하지 않는 요청 본문 형식, `HTTP_500_001` 서버 내부 오류.

## 대사 (구현 예정)

현재 구현의 공통 규칙은 [백엔드 설계 기준](../docs/BACKEND_DESIGN.md#6-현재-pg-simulator-계약)을 따릅니다. 기본 local은 H2 메모리 DB와 Flyway를 사용해 종료 시 데이터가 사라지고, Docker PostgreSQL은 volume을 유지합니다. 인증·webhook·Actuator는 구현하지 않았습니다.

승인 멱등성의 기준은 merchantTxId이며 idempotencyKey는 승인 이력에 기록됩니다. 같은 키로 다른 merchantTxId를 보내는 것을 전역 차단하지 않습니다. 취소·환불은 paymentId/transactionType/key 범위입니다. 동일 요청의 재응답은 최초 응답 캐시가 아니라 최신 결제 snapshot입니다.

동시 승인 unique 충돌은 실패 transaction 종료 후 새 transaction에서 기존 결제를 확인합니다. 취소·환불은 결제 행 DB lock을 사용합니다. `PgConcurrencyTests`는 승인 중복, 환불 중복 및 서로 다른 환불의 누적 상한을 검증합니다. 같은 테스트를 격리 PostgreSQL에서도 실행했습니다.

다음 절의 대사는 미구현입니다.

대사는 결제 서비스의 내부 `PaymentTransaction` 원장과 이 모듈의 `pg_transaction` 확정 거래 원장을 비교하는 기능이다. 일자·통화·금액·거래 유형·상태·가맹점 거래 번호를 기준으로 대사하고, 금액 또는 상태 불일치와 한쪽에만 존재하는 거래를 별도 상태로 보존해야 한다. 이를 구현하려면 결제 서비스의 거래 원장 영속화, 공급자별 대사 원본 조회 계약, 멱등 대사 실행 이력 및 불일치 해결 감사 이력이 함께 필요하다. 현재 결제 서비스가 메모리 기반이므로 이 요건이 갖춰진 뒤 일 단위 대사 작업을 추가한다.

주요 테이블은 `pgkakao.pg_payment`과 `pgkakao.pg_transaction`입니다. JPA의 DDL 자동 생성은 비활성화하고 Flyway 스키마를 그대로 사용합니다. 컨테이너를 재시작해도 Docker volume이 유지되는 동안 데이터와 승인·취소·환불 이력이 보존됩니다. `local`·`dev`·`stage`·`prod` 프로필을 제공하지만, 어떤 환경에서도 실제 금전 이동을 만들지 않는 simulator입니다.

