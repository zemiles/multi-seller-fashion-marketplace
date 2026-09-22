# Payment Service

상세 구현 기준은 [BACKEND_DESIGN](../docs/BACKEND_DESIGN.md), 실행은 [MSA](../MSA.md)를 따릅니다.

## 현재 구현

`PaymentAmount`, `PaymentAttempt`, `Payment`, `Refund` 불변 snapshot과 상태 enum, 내부 port, 메모리 `PaymentLifecycleService`가 있습니다. 이 클래스는 Spring Bean이 아니며 REST Controller·JPA repository·provider HTTP adapter·거래/배분 영속화·webhook·outbox 발행은 미구현입니다.

`prepare`는 provider/key와 provider/merchantTxId를 검사하고 동일 주문의 미해결/성공 시도를 다른 provider까지 차단합니다. 같은 key의 요청 내용은 같아야 합니다. `approve`는 요청 전 REQUESTED, 성공 시 SUCCEEDED, 응답 유실·불일치·예외 시 UNKNOWN을 보존합니다. UNKNOWN/PENDING을 approve로 재호출하지 않습니다.

환불은 PG 호출 전에 필수값·통화·상태·미예약 잔액을 검증합니다. 같은 key에 금액·claim·사유·요청자가 다르면 거부합니다. SYSTEM 외 요청자 ID는 필수이나 인증·권한 검증 자체는 아직 없습니다. PG 요청에는 providerPaymentKey와 멱등 키를 전달합니다. UNKNOWN은 키와 금액 예약을 유지하며 동일 요청은 재호출 없이 기존 상태를 반환합니다.

Map/synchronized는 단일 인스턴스에서만 유효합니다. 재시작하면 상태가 사라지므로 운영 처리에 사용하지 않습니다. UNKNOWN 해제/복구도 미구현입니다. 기존 V1의 주문/provider 부분 인덱스는 provider 변경이나 성공 후 재결제를 막지 못하므로 영속 구현 시 주문 기준 DB 보호를 추가합니다.

## 데이터와 계약

Payment DB의 11개 테이블은 [설계 기준의 소유 목록](../docs/BACKEND_DESIGN.md#4-데이터-소유권과-변경-방법)에 있습니다. V1을 보존하고 V2에서 내부 FK 11개를 복원하여 총 14개로 맞췄습니다. 물리 테이블이 있다는 사실과 메모리 유스케이스가 DB에 저장된다는 것은 다릅니다.

[Checkout 계약](../contracts/commerce-payment-checkout-contract-v0.1.md)과 [OpenAPI](../contracts/payment-service.openapi.yaml)는 v1 목표 계약이며 HTTP 구현은 아직 없습니다. [Payment/PG 전체 요구사항](../docs/requirements/03-payment-pg.md)의 영속 guard·close-order·수량 배분·복구를 함께 구현합니다. 현재 내부 PreparePayment에는 전체 snapshot이 없으므로 확장해야 합니다. 고객의 임의 금액을 신뢰하지 않고 인증된 Commerce 요청만 받습니다.

## 다음 작업

1. snapshot·attempt·결제·거래·환불·배분 영속화와 주문 단위 중복 결제 가드.
2. provider별 HTTP adapter, 요청 전 commit, PG 결과 불명 복구.
3. 결과·거래·outbox 원자적 저장 및 소비 측 inbox.
4. webhook 원문 검증·중복·역순 처리.
5. PG 거래 대사. Settlement DB의 과거 reconciliation 테이블을 직접 사용하지 않고 Payment 소유 migration으로 설계합니다.

PG simulator 자체는 승인/취소/환불/조회 및 DB 잠금·멱등 처리를 구현했습니다. 실제 PG 연결, 인증, webhook, 대사 API는 없습니다.

## 검증

프로젝트 루트에서 `.\gradlew.bat :payment-service:test --no-daemon`을 실행합니다. 현재 총 18개 테스트로 금액·도메인 검증, 요청 변경 멱등 충돌, 외부 호출 전 검증, 주문/merchant 중복, UNKNOWN 차단·예약을 확인합니다. DB 영속·다중 프로세스·서비스 간 E2E 검증은 포함하지 않습니다.
