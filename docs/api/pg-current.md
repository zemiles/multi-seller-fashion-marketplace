# PG1 · PG2 현재 구현 API

[OpenAPI](../../contracts/pg-current.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| POST | /pg/v1/payments/approve | pgApprove | LOCAL_NETWORK_ONLY | PG-01 |
| POST | /pg/v1/payments/{paymentId}/cancel | pgCancel | LOCAL_NETWORK_ONLY | PG-01 |
| POST | /pg/v1/payments/{paymentId}/refund | pgRefund | LOCAL_NETWORK_ONLY | PG-01 |
| GET | /pg/v1/payments/{paymentId} | pgGetPayment | LOCAL_NETWORK_ONLY | PG-01 |
