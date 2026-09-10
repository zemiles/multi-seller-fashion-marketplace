# PG Simulator

개발 및 통합 테스트 전용 가상 PG입니다. 전용 PostgreSQL(`pgsim` DB, 호스트 5436)에 결제와 거래 이력을 저장하며 Flyway V1로 초기화합니다.

```text
POST /pg/v1/payments/approve
POST /pg/v1/payments/{paymentId}/cancel
POST /pg/v1/payments/{paymentId}/refund
GET  /pg/v1/payments/{paymentId}
```

승인 요청의 `merchantTxId`는 중복 승인되지 않습니다. 환불은 남은 금액을 초과할 수 없고, 4xx 응답은 payment-service의 provider adapter가 도메인 오류로 변환해야 합니다.

주요 테이블은 `pgsim.pg_payment`과 `pgsim.pg_transaction`입니다. 컨테이너를 재시작해도 Docker volume이 유지되는 동안 데이터와 승인·취소·환불 이력이 보존됩니다. 이 서버는 실제 결제사나 운영 데이터 저장소가 아닙니다.
