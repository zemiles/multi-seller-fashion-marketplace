# 결제 서비스

## 현재 구현 범위

2026-09-09 기준 PG와 무관한 도메인 모델 및 내부 유스케이스 인터페이스를 마련했습니다. 이 단계에는 실행 가능한 결제 API, DB 저장, PG 승인·취소 호출, 웹훅 처리, 이벤트 발행이 없습니다. 인터페이스를 Spring Bean으로 등록하거나 임시 성공 응답을 반환하지 않습니다.

| 패키지 | 구성 |
| --- | --- |
| transaction.domain | PaymentAmount, PaymentAttempt, Payment, 결제 시도·결제·거래 상태 및 거래 유형 |
| transaction.application | PaymentUseCase: 결제 시도 준비, 시도 조회, 승인 결제 조회 |
| refund.domain | Refund, 환불 상태, 요청자 유형 |
| refund.application | RefundUseCase: 환불 요청 등록, 조회 |
| webhook.domain | WebhookStatus |

금액은 외부 database 문서와 동일하게 통화의 최소 단위 정수(long)로 표현합니다. 통화 형식, 양수 요청 금액, 누적 환불 상한 등을 검증합니다. 상태 enum은 기존 V1 SQL의 CHECK 값에 맞췄으며, 상태 전이 규칙은 아직 구현하지 않았습니다.

모델은 핵심 필드만 포함한 불변 스냅샷이며 JPA Entity나 DB 전체 행의 대체물이 아닙니다. payment_item, 비용 배분, 거래 이력, 환불 항목·배송비 조정 및 webhook/outbox 영속 모델은 해당 유스케이스 구현 시 추가합니다. Payment.remainingAmount는 단순 회계 잔액이며 환불 가능 여부 판단이나 동시 환불 예약을 대신하지 않습니다.

## 다음 구현 기준

1. 사용할 PG와 승인·취소 방식, 인증·인가와 HTTP 계약을 확정합니다. 내부 command record는 공개 API 계약이 아닙니다.
2. Commerce에서 주문·체크아웃 소유권과 결제 금액을 확인한 뒤 결제 시도를 저장합니다. provider + idempotency_key 중복 요청은 내용까지 비교하며, 같은 주문에 미해결 시도가 있는지도 확인합니다.
3. PG 승인 결과를 확인한 경우에만 Payment와 거래 이력·outbox를 같은 DB 트랜잭션에 기록합니다. 타임아웃처럼 결과가 불명확하면 UNKNOWN으로 남기고 PG 조회로 확인합니다. 네트워크 실패를 결제 실패나 재결제 허용으로 단정하지 않습니다.
4. 환불은 결제별 멱등성, 통화, 요청자 권한, 상품·비용 배분과 진행 중 환불 금액을 검증하고 동시 요청을 원자적으로 제어해야 합니다. 현재 RefundUseCase에는 이 실행 구현이 없습니다.
5. PG 웹훅은 원문 기반 검증과 provider + provider_event_id 중복 처리를 구현한 뒤 상태에 반영합니다. 현재는 상태값만 있습니다.

기존 V1 migration과 타 서비스는 변경하지 않았습니다. 상태 전이, JPA 매핑, PG adapter, Controller를 구현할 때 테스트 범위를 넓힙니다.

## 검증

프로젝트 루트에서 `.\gradlew.bat :payment-service:test`를 실행합니다. 금액·환불 경계와 멱등 키 필수값에 대한 단위 테스트 및 기존 Spring context 테스트가 있습니다.

Docker Compose 컨테이너가 실행 중이면 로컬 bootRun의 8082 포트와 충돌합니다. 컨테이너를 먼저 중지하거나 별도 포트를 지정하세요.
