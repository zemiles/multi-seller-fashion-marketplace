# Service contracts

Place OpenAPI, AsyncAPI, and versioned event JSON Schema documents here. This directory is intentionally not a Gradle dependency module: no domain code or persistence model is shared between services.

## Draft contracts

- `payment-service.openapi.yaml`: 결제 시도·승인·조회·환불·PG 웹훅 초안입니다.
- `0.1.0-draft`는 구현 기준 초안이며, 인증, PG별 서명 규칙, Commerce 주문 검증 계약과 이벤트 스키마를 확정한 뒤 버전을 올립니다.
- JSON 금액은 DB와 동일하게 최소 화폐 단위 정수(`int64`)를 사용합니다.
- `Idempotency-Key`는 결제 시도·승인·환불 요청에 필수입니다. 같은 키의 다른 요청은 `409 Conflict`로 처리합니다.
- 웹훅은 `X-Provider-Event-Id`와 `X-Signature`를 사용하지만, 실제 PG별 서명 알고리즘은 provider를 정한 뒤 확정합니다.

## 외부 API 비교 검토

Stripe PaymentIntents처럼 결제 객체와 시도 이력을 분리하고 `processing`·추가 인증·`succeeded`·`canceled` 같은 비동기 상태를 고려해야 합니다. Stripe는 POST 멱등 키의 최초 결과를 재사용하고 요청 파라미터가 달라지면 오류를 반환하므로, 이 초안도 결제 시도·승인·취소·환불 POST에 멱등 키를 요구합니다. [PaymentIntent lifecycle](https://docs.stripe.com/payments/paymentintents/lifecycle), [Idempotent requests](https://docs.stripe.com/api/idempotent_requests)

토스페이먼츠처럼 승인·전체 취소·부분 취소를 서로 다른 거래 이력으로 남기는 모델은 현재 `PaymentTransaction`과 일치합니다. 따라서 승인 API의 200 성공만으로 모든 PG를 표현하지 않고, 취소와 환불의 `202 PENDING/UNKNOWN` 응답 및 웹훅·복구 조회를 계약에 포함했습니다. [토스페이먼츠 거래](https://docs.tosspayments.com/resources/glossary/transaction)

이번 비교에서 확인한 미확정 정책은 PG를 정한 뒤 확정해야 합니다: 추가 인증(3-D Secure)용 `nextAction`, 취소 가능 상태와 시간 제한, 웹훅 서명 알고리즘·timestamp 허용 오차, provider별 환불 비동기 처리, 최종 gateway 인증 방식.
