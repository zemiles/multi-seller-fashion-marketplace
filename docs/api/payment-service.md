# Payment Service API

[OpenAPI](../../contracts/payment-service.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| POST | /internal/v1/payment-attempts | Prepare a payment attempt from a Commerce-verified checkout snapshot | commerce-service | PAY-01 |
| POST | /internal/v1/payment-attempts/{paymentAttemptId}/approve | Approve an attempt through the configured PG | commerce-service | PAY-02 |
| GET | /internal/v1/payment-attempts/{paymentAttemptId} | Query an attempt after a pending or unknown approval result | commerce-service | PAY-01 |
| GET | /internal/v1/refunds/{refundId} | Query a pending or unknown refund | commerce-service | PAY-04 |
| GET | /internal/v1/payments/{paymentId} | Get a payment | commerce-service | PAY-01 |
| POST | /internal/v1/payments/{paymentId}/cancel | Cancel or void an approved payment when the provider allows it | commerce-service | PAY-01 |
| POST | /internal/v1/payments/{paymentId}/refunds | Request a full or partial refund | commerce-service | PAY-04 |
| POST | /internal/v1/payment-webhooks/{provider} | Receive and deduplicate a PG webhook | PG1/PG2_SIGNED_WEBHOOK | PG-03 |
| POST | /internal/v1/order-payment-guards/{orderId}/close | Fence future prepare/approve before Commerce releases stock | commerce-service | PAY-03 |
| GET | /internal/v1/payment-operations/{operationId} | undefined | commerce-service | PAY-01 |
