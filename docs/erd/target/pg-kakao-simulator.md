# pg-kakao-simulator — v1 목표 / 미적용 데이터 사전

문서용 접두사는 서비스 DB 경계를 나타냅니다. 목표 파일은 실행 DDL이 아닙니다. 원본 출처는 [ERD 안내](../README.md)를 따릅니다.

## pg_payment

상태: CURRENT · 실제 schema: pgkakao · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_id | uuid | 불가 | PK | payment_id uuid PRIMARY KEY |
| merchant_tx_id | text | 불가 | UK | merchant_tx_id text NOT NULL UNIQUE |
| currency | varchar(3) | 불가 |  | currency varchar(3) NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'APPROVED' |
| refunded_amount | bigint | 불가 |  | refunded_amount bigint NOT NULL DEFAULT 0 |
| created_at | timestamp with time zone | 불가 |  | created_at timestamp with time zone NOT NULL DEFAULT now() |
| updated_at | timestamp with time zone | 불가 |  | updated_at timestamp with time zone NOT NULL DEFAULT now() |

PK: (payment_id)

UNIQUE: (merchant_tx_id)


```sql
CONSTRAINT pg_payment_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT pg_payment_amount_ck CHECK (amount > 0)
CONSTRAINT pg_payment_refund_ck CHECK (refunded_amount >= 0 AND refunded_amount <= amount)
CONSTRAINT pg_payment_status_ck CHECK (status IN ('APPROVED','PARTIALLY_REFUNDED','REFUNDED','CANCELLED'))
```

## pg_transaction

상태: MODIFIED · 실제 schema: pgkakao · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| transaction_id | uuid | 불가 | PK | transaction_id uuid PRIMARY KEY |
| payment_id | uuid | 불가 | FK | payment_id uuid NOT NULL REFERENCES pgkakao.pg_payment(payment_id) |
| transaction_type | text | 불가 |  | transaction_type text NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| status | text | 불가 |  | status text NOT NULL |
| idempotency_key | text | 허용 |  | idempotency_key text |
| created_at | timestamp with time zone | 불가 |  | created_at timestamp with time zone NOT NULL DEFAULT now() |

PK: (transaction_id)

UNIQUE: (payment_id, transaction_type, idempotency_key)

- FK pg_transaction_payment_id_fkey: (payment_id) → pg1.pg_payment(payment_id)

```sql
CONSTRAINT pg_transaction_type_ck CHECK (transaction_type IN ('APPROVE','CANCEL','REFUND'))
CONSTRAINT pg_transaction_amount_ck CHECK (amount > 0)
CONSTRAINT pg_transaction_status_ck CHECK (status IN ('SUCCEEDED','FAILED'))
CONSTRAINT pg_transaction_idempotency_uq UNIQUE (payment_id, transaction_type, idempotency_key)
CREATE INDEX pg_transaction_payment_idx ON pgkakao.pg_transaction(payment_id, created_at DESC);
CREATE INDEX ix_pg_transaction_cursor_v1 ON pgkakao.pg_transaction (created_at, transaction_id);
```

## pg_webhook_outbox

상태: PLANNED · 실제 schema: pgkakao · PG-03; transaction commit and webhook row atomic; timestamp/signature refreshed on retry.

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| event_id | uuid | 불가 | PK | PLANNED event_id uuid NOT NULL |
| transaction_id | uuid | 불가 | FK | PLANNED transaction_id uuid NOT NULL |
| body | jsonb | 불가 |  | PLANNED body jsonb NOT NULL |
| body_hash | text | 불가 |  | PLANNED body_hash text NOT NULL |
| status | text | 불가 |  | PLANNED status text NOT NULL |
| attempt_count | integer | 불가 |  | PLANNED attempt_count integer NOT NULL |
| next_retry_at | timestamptz | 불가 |  | PLANNED next_retry_at timestamptz NOT NULL |
| lease_expires_at | timestamptz | 허용 |  | PLANNED lease_expires_at timestamptz NULL |
| created_at | timestamptz | 불가 |  | PLANNED created_at timestamptz NOT NULL |

PK: (event_id)

UNIQUE: 없음

- FK pg_webhook_outbox_transaction_id_planned_fk: (transaction_id) → pg1.pg_transaction(transaction_id)

```sql
CONSTRAINT pg_webhook_outbox_body_hash_v1_ck CHECK (body_hash ~ '^[0-9a-f]{64}$')
CONSTRAINT pg_webhook_outbox_attempt_count_v1_ck CHECK (attempt_count >= 0)
CREATE INDEX ix_pg_webhook_due_v1 ON pgkakao.pg_webhook_outbox (status, next_retry_at, event_id);
```

## pg_fault_scenario

상태: PLANNED · 실제 schema: pgkakao · PG-02; local/stage only; fail closed in prod profile.

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| scenario_id | uuid | 불가 | PK | PLANNED scenario_id uuid NOT NULL |
| scenario_type | text | 불가 |  | PLANNED scenario_type text NOT NULL |
| remaining_uses | integer | 불가 |  | PLANNED remaining_uses integer NOT NULL |
| delay_ms | integer | 불가 |  | PLANNED delay_ms integer NOT NULL |
| expires_at | timestamptz | 불가 |  | PLANNED expires_at timestamptz NOT NULL |
| enabled | boolean | 불가 |  | PLANNED enabled boolean NOT NULL |

PK: (scenario_id)

UNIQUE: 없음

