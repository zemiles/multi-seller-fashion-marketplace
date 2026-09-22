# PG1 · PG2 목표 v1 확장 API

[OpenAPI](../../contracts/pg-target.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| POST | /pg/v1/payments/approve | pgApprove | LOCAL_NETWORK_ONLY | PG-01 |
| POST | /pg/v1/payments/{paymentId}/cancel | pgCancel | LOCAL_NETWORK_ONLY | PG-01 |
| POST | /pg/v1/payments/{paymentId}/refund | pgRefund | LOCAL_NETWORK_ONLY | PG-01 |
| GET | /pg/v1/payments/{paymentId} | pgGetPayment | LOCAL_NETWORK_ONLY | PG-01 |
| GET | /pg/v1/payments/by-merchant/{merchantTxId} | pgGetByMerchant | pg:read | PG-02 |
| GET | /pg/v1/payments/{paymentId}/transactions | pgGetPaymentTransactions | pg:read | PG-02 |
| GET | /pg/v1/transactions | pgListTransactions | pg:read | PG-02 |
| POST | /pg/internal/v1/fault-scenarios | local/stage 전용 실패 주입 | pg:test | PG-02 |
