# payment-service — 현재 물리 데이터 사전

문서용 접두사는 서비스 DB 경계를 나타냅니다. 목표 파일은 실행 DDL이 아닙니다. 원본 출처는 [ERD 안내](../README.md)를 따릅니다.

## payment_attempt

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_attempt_id | uuid | 불가 | PK | payment_attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| checkout_id | uuid | 불가 |  | checkout_id uuid NOT NULL |
| order_id | uuid | 불가 |  | order_id uuid NOT NULL |
| provider | text | 불가 |  | provider text NOT NULL |
| merchant_tx_id | text | 불가 |  | merchant_tx_id text NOT NULL |
| idempotency_key | text | 불가 |  | idempotency_key text NOT NULL |
| payment_method | text | 불가 |  | payment_method text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'CREATED' |
| currency | varchar(3) | 불가 |  | currency varchar(3) NOT NULL |
| requested_amount | bigint | 불가 |  | requested_amount bigint NOT NULL |
| request_payload | jsonb | 불가 |  | request_payload jsonb NOT NULL DEFAULT '{}'::jsonb |
| provider_response | jsonb | 허용 |  | provider_response jsonb |
| error_code | text | 허용 |  | error_code text |
| error_message | text | 허용 |  | error_message text |
| requested_at | timestamptz | 허용 |  | requested_at timestamptz |
| resolved_at | timestamptz | 허용 |  | resolved_at timestamptz |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |
| updated_at | timestamptz | 불가 |  | updated_at timestamptz NOT NULL DEFAULT now() |

PK: (payment_attempt_id)

UNIQUE: (provider, merchant_tx_id); (provider, idempotency_key)


```sql
CONSTRAINT payment_attempt_merchant_tx_uq UNIQUE (provider, merchant_tx_id)
CONSTRAINT payment_attempt_idempotency_uq UNIQUE (provider, idempotency_key)
CONSTRAINT payment_attempt_status_ck CHECK (status IN ('CREATED', 'REQUESTED', 'PENDING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED'))
CONSTRAINT payment_attempt_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT payment_attempt_amount_ck CHECK (requested_amount > 0)
CONSTRAINT payment_attempt_request_payload_ck CHECK (jsonb_typeof(request_payload) = 'object')
CONSTRAINT payment_attempt_response_ck CHECK (provider_response IS NULL OR jsonb_typeof(provider_response) = 'object')
CONSTRAINT payment_attempt_times_ck CHECK (
        (requested_at IS NULL OR requested_at >= created_at)
        AND (resolved_at IS NULL OR resolved_at >= COALESCE(requested_at, created_at))
    )
CONSTRAINT payment_attempt_updated_at_ck CHECK (updated_at >= created_at)
CREATE INDEX payment_attempt_checkout_recent_idx
    ON marketplace.payment_attempt (checkout_id, created_at DESC);
CREATE INDEX payment_attempt_order_recent_idx
    ON marketplace.payment_attempt (order_id, created_at DESC);
CREATE UNIQUE INDEX payment_attempt_one_unresolved_per_order_provider_uidx
    ON marketplace.payment_attempt (order_id, provider)
    WHERE status IN ('CREATED', 'REQUESTED', 'PENDING', 'UNKNOWN');
CREATE INDEX payment_attempt_recovery_idx
    ON marketplace.payment_attempt (provider, updated_at, payment_attempt_id)
    WHERE status IN ('PENDING', 'UNKNOWN');
```

## payment

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_id | uuid | 불가 | PK | payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_attempt_id | uuid | 불가 | FK, UK | payment_attempt_id uuid NOT NULL |
| order_id | uuid | 불가 |  | order_id uuid NOT NULL |
| provider | text | 불가 |  | provider text NOT NULL |
| provider_payment_key | text | 불가 |  | provider_payment_key text NOT NULL |
| payment_method | text | 불가 |  | payment_method text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'APPROVED' |
| currency | varchar(3) | 불가 |  | currency varchar(3) NOT NULL |
| total_payment_amount | bigint | 불가 |  | total_payment_amount bigint NOT NULL |
| refunded_amount | bigint | 불가 |  | refunded_amount bigint NOT NULL DEFAULT 0 |
| approved_at | timestamptz | 불가 |  | approved_at timestamptz NOT NULL |
| version | integer | 불가 |  | version integer NOT NULL DEFAULT 0 |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |
| updated_at | timestamptz | 불가 |  | updated_at timestamptz NOT NULL DEFAULT now() |

PK: (payment_id)

UNIQUE: (payment_attempt_id); (provider, provider_payment_key)

- FK payment_attempt_fk: (payment_attempt_id) → payment.payment_attempt(payment_attempt_id)

```sql
CONSTRAINT payment_attempt_uq UNIQUE (payment_attempt_id)
CONSTRAINT payment_provider_key_uq UNIQUE (provider, provider_payment_key)
CONSTRAINT payment_status_ck CHECK (status IN ('APPROVED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'VOIDED', 'CHARGEBACK'))
CONSTRAINT payment_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT payment_amounts_ck CHECK (
        total_payment_amount > 0
        AND refunded_amount >= 0
        AND refunded_amount <= total_payment_amount
    )
CONSTRAINT payment_version_ck CHECK (version >= 0)
CONSTRAINT payment_approved_at_ck CHECK (approved_at <= updated_at)
CONSTRAINT payment_updated_at_ck CHECK (updated_at >= created_at)
CREATE INDEX payment_order_status_idx
    ON marketplace.payment (order_id, status, approved_at DESC);
```

## payment_item

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_item_id | uuid | 불가 | PK | payment_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_id | uuid | 불가 | FK | payment_id uuid NOT NULL |
| order_item_id | uuid | 불가 |  | order_item_id uuid NOT NULL |
| quantity | integer | 불가 |  | quantity integer NOT NULL |
| product_amount | bigint | 불가 |  | product_amount bigint NOT NULL |
| discount_amount | bigint | 불가 |  | discount_amount bigint NOT NULL DEFAULT 0 |
| tax_amount | bigint | 불가 |  | tax_amount bigint NOT NULL DEFAULT 0 |
| paid_amount | bigint | 불가 |  | paid_amount bigint NOT NULL |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (payment_item_id)

UNIQUE: (payment_id, order_item_id)

- FK payment_item_payment_fk: (payment_id) → payment.payment(payment_id)

```sql
CONSTRAINT payment_item_order_item_uq UNIQUE (payment_id, order_item_id)
CONSTRAINT payment_item_quantity_ck CHECK (quantity > 0)
CONSTRAINT payment_item_amounts_ck CHECK (
        product_amount >= 0
        AND discount_amount >= 0
        AND discount_amount <= product_amount
        AND tax_amount >= 0
        AND paid_amount = product_amount - discount_amount + tax_amount
        AND paid_amount > 0
    )
CREATE INDEX payment_item_order_item_idx
    ON marketplace.payment_item (order_item_id, payment_id);
```

## payment_charge_allocation

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_charge_allocation_id | uuid | 불가 | PK | payment_charge_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_id | uuid | 불가 | FK | payment_id uuid NOT NULL |
| order_charge_id | uuid | 불가 |  | order_charge_id uuid NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (payment_charge_allocation_id)

UNIQUE: (payment_id, order_charge_id)

- FK payment_charge_allocation_payment_fk: (payment_id) → payment.payment(payment_id)

```sql
CONSTRAINT payment_charge_allocation_uq UNIQUE (payment_id, order_charge_id)
CONSTRAINT payment_charge_allocation_amount_ck CHECK (amount > 0)
CREATE INDEX payment_charge_allocation_order_charge_idx
    ON marketplace.payment_charge_allocation (order_charge_id, payment_id);
```

## payment_transaction

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payment_transaction_id | uuid | 불가 | PK | payment_transaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_id | uuid | 불가 | FK | payment_id uuid NOT NULL |
| original_transaction_id | uuid | 허용 | FK | original_transaction_id uuid |
| provider | text | 불가 |  | provider text NOT NULL |
| provider_tx_id | text | 불가 |  | provider_tx_id text NOT NULL |
| idempotency_key | text | 불가 |  | idempotency_key text NOT NULL |
| transaction_type | text | 불가 |  | transaction_type text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'PENDING' |
| currency | varchar(3) | 불가 |  | currency varchar(3) NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| provider_payload | jsonb | 불가 |  | provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb |
| occurred_at | timestamptz | 허용 |  | occurred_at timestamptz |
| completed_at | timestamptz | 허용 |  | completed_at timestamptz |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (payment_transaction_id)

UNIQUE: (provider, provider_tx_id); (payment_id, idempotency_key)

- FK payment_transaction_payment_fk: (payment_id) → payment.payment(payment_id)
- FK payment_transaction_original_fk: (original_transaction_id) → payment.payment_transaction(payment_transaction_id)

```sql
CONSTRAINT payment_transaction_provider_tx_uq UNIQUE (provider, provider_tx_id)
CONSTRAINT payment_transaction_idempotency_uq UNIQUE (payment_id, idempotency_key)
CONSTRAINT payment_transaction_type_ck CHECK (transaction_type IN ('AUTHORIZE', 'CAPTURE', 'SALE', 'VOID', 'REFUND', 'CHARGEBACK', 'REVERSAL'))
CONSTRAINT payment_transaction_status_ck CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED'))
CONSTRAINT payment_transaction_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT payment_transaction_amount_ck CHECK (amount > 0)
CONSTRAINT payment_transaction_payload_ck CHECK (jsonb_typeof(provider_payload) = 'object')
CONSTRAINT payment_transaction_original_ck CHECK (original_transaction_id IS NULL OR original_transaction_id <> payment_transaction_id)
CONSTRAINT payment_transaction_times_ck CHECK (
        completed_at IS NULL
        OR occurred_at IS NULL
        OR completed_at >= occurred_at
    )
CREATE INDEX payment_transaction_timeline_idx
    ON marketplace.payment_transaction (payment_id, created_at DESC, payment_transaction_id);
CREATE INDEX payment_transaction_original_idx
    ON marketplace.payment_transaction (original_transaction_id)
    WHERE original_transaction_id IS NOT NULL;
CREATE INDEX payment_transaction_recovery_idx
    ON marketplace.payment_transaction (provider, created_at, payment_transaction_id)
    WHERE status IN ('PENDING', 'UNKNOWN');
```

## payment_transaction_allocation

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| transaction_allocation_id | uuid | 불가 | PK | transaction_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_transaction_id | uuid | 불가 | FK | payment_transaction_id uuid NOT NULL |
| payment_item_id | uuid | 허용 | FK | payment_item_id uuid |
| payment_charge_allocation_id | uuid | 허용 | FK | payment_charge_allocation_id uuid |
| claim_item_id | uuid | 허용 |  | claim_item_id uuid |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (transaction_allocation_id)

UNIQUE: (payment_transaction_id, payment_item_id); (payment_transaction_id, payment_charge_allocation_id)

- FK payment_transaction_allocation_transaction_fk: (payment_transaction_id) → payment.payment_transaction(payment_transaction_id)
- FK payment_transaction_allocation_item_fk: (payment_item_id) → payment.payment_item(payment_item_id)
- FK payment_transaction_allocation_charge_fk: (payment_charge_allocation_id) → payment.payment_charge_allocation(payment_charge_allocation_id)

```sql
CONSTRAINT payment_transaction_item_allocation_uq UNIQUE (payment_transaction_id, payment_item_id)
CONSTRAINT payment_transaction_charge_allocation_uq UNIQUE (payment_transaction_id, payment_charge_allocation_id)
CONSTRAINT payment_transaction_allocation_target_ck CHECK (num_nonnulls(payment_item_id, payment_charge_allocation_id) = 1)
CONSTRAINT payment_transaction_allocation_amount_ck CHECK (amount > 0)
CREATE INDEX payment_transaction_allocation_item_idx
    ON marketplace.payment_transaction_allocation (payment_item_id, payment_transaction_id)
    WHERE payment_item_id IS NOT NULL;
CREATE INDEX payment_transaction_allocation_charge_idx
    ON marketplace.payment_transaction_allocation (payment_charge_allocation_id, payment_transaction_id)
    WHERE payment_charge_allocation_id IS NOT NULL;
CREATE INDEX payment_transaction_allocation_claim_item_idx
    ON marketplace.payment_transaction_allocation (claim_item_id, payment_transaction_id)
    WHERE claim_item_id IS NOT NULL;
```

## refund

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| refund_id | uuid | 불가 | PK | refund_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_id | uuid | 불가 | FK | payment_id uuid NOT NULL |
| claim_id | uuid | 허용 |  | claim_id uuid |
| idempotency_key | text | 불가 |  | idempotency_key text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'REQUESTED' |
| currency | varchar(3) | 불가 |  | currency varchar(3) NOT NULL |
| requested_amount | bigint | 불가 |  | requested_amount bigint NOT NULL |
| actual_refunded_amount | bigint | 불가 |  | actual_refunded_amount bigint NOT NULL DEFAULT 0 |
| reason_code | text | 불가 |  | reason_code text NOT NULL |
| reason_detail | text | 허용 |  | reason_detail text |
| requested_by_type | text | 불가 |  | requested_by_type text NOT NULL |
| requested_by_id | uuid | 허용 |  | requested_by_id uuid |
| requested_at | timestamptz | 불가 |  | requested_at timestamptz NOT NULL DEFAULT now() |
| completed_at | timestamptz | 허용 |  | completed_at timestamptz |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |
| updated_at | timestamptz | 불가 |  | updated_at timestamptz NOT NULL DEFAULT now() |

PK: (refund_id)

UNIQUE: (payment_id, idempotency_key)

- FK refund_payment_fk: (payment_id) → payment.payment(payment_id)

```sql
CONSTRAINT refund_idempotency_uq UNIQUE (payment_id, idempotency_key)
CONSTRAINT refund_status_ck CHECK (status IN ('REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED'))
CONSTRAINT refund_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT refund_amounts_ck CHECK (
        requested_amount > 0
        AND actual_refunded_amount >= 0
        AND actual_refunded_amount <= requested_amount
    )
CONSTRAINT refund_requester_type_ck CHECK (requested_by_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM'))
CONSTRAINT refund_completed_at_ck CHECK (completed_at IS NULL OR completed_at >= requested_at)
CONSTRAINT refund_updated_at_ck CHECK (updated_at >= created_at)
CREATE INDEX refund_claim_idx
    ON marketplace.refund (claim_id, requested_at DESC)
    WHERE claim_id IS NOT NULL;
CREATE INDEX refund_processing_queue_idx
    ON marketplace.refund (status, updated_at, refund_id)
    WHERE status IN ('REQUESTED', 'PROCESSING', 'UNKNOWN');
```

## refund_item

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| refund_item_id | uuid | 불가 | PK | refund_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| refund_id | uuid | 불가 | FK | refund_id uuid NOT NULL |
| payment_item_id | uuid | 불가 | FK | payment_item_id uuid NOT NULL |
| order_item_id | uuid | 불가 |  | order_item_id uuid NOT NULL |
| claim_item_id | uuid | 허용 |  | claim_item_id uuid |
| quantity | integer | 불가 |  | quantity integer NOT NULL |
| product_refund_amount | bigint | 불가 |  | product_refund_amount bigint NOT NULL |
| discount_reversal_amount | bigint | 불가 |  | discount_reversal_amount bigint NOT NULL DEFAULT 0 |
| tax_refund_amount | bigint | 불가 |  | tax_refund_amount bigint NOT NULL DEFAULT 0 |
| refund_amount | bigint | 불가 |  | refund_amount bigint NOT NULL |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (refund_item_id)

UNIQUE: (refund_id, payment_item_id)

- FK refund_item_refund_fk: (refund_id) → payment.refund(refund_id)
- FK refund_item_payment_item_fk: (payment_item_id) → payment.payment_item(payment_item_id)

```sql
CONSTRAINT refund_item_payment_item_uq UNIQUE (refund_id, payment_item_id)
CONSTRAINT refund_item_quantity_ck CHECK (quantity > 0)
CONSTRAINT refund_item_amounts_ck CHECK (
        product_refund_amount >= 0
        AND discount_reversal_amount >= 0
        AND discount_reversal_amount <= product_refund_amount
        AND tax_refund_amount >= 0
        AND refund_amount = product_refund_amount - discount_reversal_amount + tax_refund_amount
        AND refund_amount >= 0
    )
CREATE INDEX refund_item_payment_item_idx
    ON marketplace.refund_item (payment_item_id, refund_id);
CREATE INDEX refund_item_order_item_idx
    ON marketplace.refund_item (order_item_id, refund_id);
CREATE INDEX refund_item_claim_item_idx
    ON marketplace.refund_item (claim_item_id, refund_id)
    WHERE claim_item_id IS NOT NULL;
```

## refund_charge_adjustment

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| adjustment_id | uuid | 불가 | PK | adjustment_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| refund_id | uuid | 불가 | FK | refund_id uuid NOT NULL |
| order_charge_id | uuid | 불가 |  | order_charge_id uuid NOT NULL |
| payment_charge_allocation_id | uuid | 허용 | FK | payment_charge_allocation_id uuid |
| adjustment_type | text | 불가 |  | adjustment_type text NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| reason_code | text | 허용 |  | reason_code text |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (adjustment_id)

UNIQUE: (refund_id, order_charge_id, adjustment_type)

- FK refund_charge_adjustment_refund_fk: (refund_id) → payment.refund(refund_id)
- FK refund_charge_adjustment_payment_charge_fk: (payment_charge_allocation_id) → payment.payment_charge_allocation(payment_charge_allocation_id)

```sql
CONSTRAINT refund_charge_adjustment_uq UNIQUE (refund_id, order_charge_id, adjustment_type)
CONSTRAINT refund_charge_adjustment_type_ck CHECK (adjustment_type IN ('REFUND', 'RECHARGE', 'WAIVER'))
CONSTRAINT refund_charge_adjustment_amount_ck CHECK (amount > 0)
CONSTRAINT refund_charge_adjustment_source_ck CHECK (
        adjustment_type <> 'REFUND' OR payment_charge_allocation_id IS NOT NULL
    )
CREATE INDEX refund_charge_adjustment_order_charge_idx
    ON marketplace.refund_charge_adjustment (order_charge_id, refund_id);
CREATE INDEX refund_charge_adjustment_payment_charge_idx
    ON marketplace.refund_charge_adjustment (payment_charge_allocation_id, refund_id)
    WHERE payment_charge_allocation_id IS NOT NULL;
```

## pg_webhook_inbox

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| inbox_id | uuid | 불가 | PK | inbox_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| payment_attempt_id | uuid | 허용 | FK | payment_attempt_id uuid |
| provider | text | 불가 |  | provider text NOT NULL |
| provider_event_id | text | 불가 |  | provider_event_id text NOT NULL |
| event_type | text | 불가 |  | event_type text NOT NULL |
| merchant_tx_id | text | 허용 |  | merchant_tx_id text |
| payload_hash | text | 불가 |  | payload_hash text NOT NULL |
| headers | jsonb | 불가 |  | headers jsonb NOT NULL DEFAULT '{}'::jsonb |
| payload | jsonb | 불가 |  | payload jsonb NOT NULL |
| raw_body | text | 불가 |  | raw_body text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'RECEIVED' |
| attempt_count | integer | 불가 |  | attempt_count integer NOT NULL DEFAULT 0 |
| received_at | timestamptz | 불가 |  | received_at timestamptz NOT NULL DEFAULT now() |
| processing_started_at | timestamptz | 허용 |  | processing_started_at timestamptz |
| processed_at | timestamptz | 허용 |  | processed_at timestamptz |
| next_attempt_at | timestamptz | 허용 |  | next_attempt_at timestamptz |
| last_error | text | 허용 |  | last_error text |

PK: (inbox_id)

UNIQUE: (provider, provider_event_id)

- FK pg_webhook_inbox_payment_attempt_fk: (payment_attempt_id) → payment.payment_attempt(payment_attempt_id)

```sql
CONSTRAINT pg_webhook_provider_event_uq UNIQUE (provider, provider_event_id)
CONSTRAINT pg_webhook_status_ck CHECK (status IN ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'DEAD'))
CONSTRAINT pg_webhook_payload_hash_ck CHECK (payload_hash ~ '^[0-9A-Fa-f]{64}$')
CONSTRAINT pg_webhook_headers_ck CHECK (jsonb_typeof(headers) = 'object')
CONSTRAINT pg_webhook_payload_ck CHECK (jsonb_typeof(payload) IN ('object', 'array'))
CONSTRAINT pg_webhook_attempt_count_ck CHECK (attempt_count >= 0)
CONSTRAINT pg_webhook_times_ck CHECK (
        (processing_started_at IS NULL OR processing_started_at >= received_at)
        AND (processed_at IS NULL OR processed_at >= COALESCE(processing_started_at, received_at))
        AND (next_attempt_at IS NULL OR next_attempt_at >= received_at)
    )
CREATE INDEX pg_webhook_inbox_attempt_idx
    ON marketplace.pg_webhook_inbox (payment_attempt_id, received_at DESC)
    WHERE payment_attempt_id IS NOT NULL;
CREATE INDEX pg_webhook_inbox_merchant_tx_idx
    ON marketplace.pg_webhook_inbox (provider, merchant_tx_id, received_at DESC)
    WHERE merchant_tx_id IS NOT NULL;
CREATE INDEX pg_webhook_inbox_worker_idx
    ON marketplace.pg_webhook_inbox (COALESCE(next_attempt_at, received_at), received_at, inbox_id)
    WHERE status IN ('RECEIVED', 'FAILED');
```

## outbox_event

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| outbox_event_id | uuid | 불가 | PK | outbox_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| event_key | text | 불가 | UK | event_key text NOT NULL |
| aggregate_type | text | 불가 |  | aggregate_type text NOT NULL |
| aggregate_id | uuid | 불가 |  | aggregate_id uuid NOT NULL |
| aggregate_version | bigint | 허용 |  | aggregate_version bigint |
| event_type | text | 불가 |  | event_type text NOT NULL |
| payload | jsonb | 불가 |  | payload jsonb NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'PENDING' |
| attempt_count | integer | 불가 |  | attempt_count integer NOT NULL DEFAULT 0 |
| occurred_at | timestamptz | 불가 |  | occurred_at timestamptz NOT NULL DEFAULT now() |
| available_at | timestamptz | 불가 |  | available_at timestamptz NOT NULL DEFAULT now() |
| published_at | timestamptz | 허용 |  | published_at timestamptz |
| locked_at | timestamptz | 허용 |  | locked_at timestamptz |
| lock_token | uuid | 허용 |  | lock_token uuid |
| last_error | text | 허용 |  | last_error text |

PK: (outbox_event_id)

UNIQUE: (event_key); (aggregate_type, aggregate_id, aggregate_version)


```sql
CONSTRAINT outbox_event_key_uq UNIQUE (event_key)
CONSTRAINT outbox_event_aggregate_version_uq UNIQUE (aggregate_type, aggregate_id, aggregate_version)
CONSTRAINT outbox_event_status_ck CHECK (status IN ('PENDING', 'PUBLISHING', 'PUBLISHED', 'FAILED', 'DEAD'))
CONSTRAINT outbox_event_version_ck CHECK (aggregate_version IS NULL OR aggregate_version >= 0)
CONSTRAINT outbox_event_payload_ck CHECK (jsonb_typeof(payload) IN ('object', 'array'))
CONSTRAINT outbox_event_attempt_count_ck CHECK (attempt_count >= 0)
CONSTRAINT outbox_event_times_ck CHECK (
        available_at >= occurred_at
        AND (published_at IS NULL OR published_at >= occurred_at)
        AND (locked_at IS NULL OR locked_at >= occurred_at)
    )
CONSTRAINT outbox_event_lock_ck CHECK ((locked_at IS NULL) = (lock_token IS NULL))
CREATE INDEX outbox_event_publish_worker_idx
    ON marketplace.outbox_event (available_at, occurred_at, outbox_event_id)
    WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX outbox_event_stale_lock_idx
    ON marketplace.outbox_event (locked_at, outbox_event_id)
    WHERE status = 'PUBLISHING';
CREATE INDEX outbox_event_aggregate_timeline_idx
    ON marketplace.outbox_event (aggregate_type, aggregate_id, occurred_at, outbox_event_id);
```

