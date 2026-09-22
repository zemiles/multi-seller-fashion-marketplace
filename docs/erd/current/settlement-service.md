# settlement-service — 현재 물리 데이터 사전

문서용 접두사는 서비스 DB 경계를 나타냅니다. 목표 파일은 실행 DDL이 아닙니다. 원본 출처는 [ERD 안내](../README.md)를 따릅니다.

## seller_ledger_entry

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| seller_ledger_entry_id | uuid | 불가 | PK | seller_ledger_entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| seller_id | uuid | 불가 |  | seller_id uuid NOT NULL |
| entry_type | text | 불가 |  | entry_type text NOT NULL |
| signed_amount | bigint | 불가 |  | signed_amount bigint NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| source_type | text | 불가 |  | source_type text NOT NULL |
| source_id | uuid | 허용 |  | source_id uuid |
| source_key | text | 불가 | UK | source_key text NOT NULL |
| reversal_of_entry_id | uuid | 허용 | FK, UK | reversal_of_entry_id uuid |
| recognized_at | timestamptz | 불가 |  | recognized_at timestamptz NOT NULL |
| due_date | date | 불가 |  | due_date date NOT NULL |
| description | text | 허용 |  | description text |
| metadata | jsonb | 불가 |  | metadata jsonb NOT NULL DEFAULT '{}'::jsonb |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (seller_ledger_entry_id)

UNIQUE: (source_key); (reversal_of_entry_id)

- FK fk_seller_ledger_reversal: (reversal_of_entry_id) → settlement.seller_ledger_entry(seller_ledger_entry_id)

```sql
CONSTRAINT uq_seller_ledger_source_key UNIQUE (source_key)
CONSTRAINT uq_seller_ledger_reversal UNIQUE (reversal_of_entry_id)
CONSTRAINT ck_seller_ledger_entry_type CHECK (entry_type IN (
        'SALE_PROCEEDS', 'SHIPPING_REVENUE', 'COMMISSION_FEE', 'PAYMENT_FEE',
        'REFUND', 'CHARGEBACK', 'HOLD', 'HOLD_RELEASE', 'PENALTY',
        'TAX_WITHHOLDING', 'ADJUSTMENT', 'REVERSAL'
    ))
CONSTRAINT ck_seller_ledger_nonzero_amount CHECK (signed_amount <> 0)
CONSTRAINT ck_seller_ledger_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_seller_ledger_source_type CHECK (source_type IN (
        'PURCHASE_CONFIRMATION', 'REFUND_ITEM', 'CLAIM', 'SETTLEMENT_HOLD',
        'SELLER_PENALTY', 'CHARGEBACK', 'MANUAL_ADJUSTMENT', 'MIGRATION'
    ))
CONSTRAINT ck_seller_ledger_reversal_shape CHECK (
        (reversal_of_entry_id IS NULL AND entry_type <> 'REVERSAL')
        OR (reversal_of_entry_id IS NOT NULL AND entry_type = 'REVERSAL')
    )
CONSTRAINT ck_seller_ledger_source_key_not_blank CHECK (btrim(source_key) <> '')
CONSTRAINT ck_seller_ledger_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
CREATE INDEX ix_seller_ledger_due
    ON marketplace.seller_ledger_entry (seller_id, currency, due_date, recognized_at)
    INCLUDE (signed_amount, entry_type);
CREATE INDEX ix_seller_ledger_source
    ON marketplace.seller_ledger_entry (source_type, source_id)
    WHERE source_id IS NOT NULL;
```

## settlement

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| settlement_id | uuid | 불가 | PK | settlement_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| seller_id | uuid | 불가 |  | seller_id uuid NOT NULL |
| period_start | date | 불가 |  | period_start date NOT NULL |
| period_end | date | 불가 |  | period_end date NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| version_no | integer | 불가 |  | version_no integer NOT NULL DEFAULT 1 |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'DRAFT' |
| credit_amount | bigint | 불가 |  | credit_amount bigint NOT NULL DEFAULT 0 |
| debit_amount | bigint | 불가 |  | debit_amount bigint NOT NULL DEFAULT 0 |
| hold_amount | bigint | 불가 |  | hold_amount bigint NOT NULL DEFAULT 0 |
| net_amount | bigint | 불가 |  | net_amount bigint NOT NULL DEFAULT 0 |
| payout_amount | bigint | 불가 |  | payout_amount bigint NOT NULL DEFAULT 0 |
| calculation_version | text | 불가 |  | calculation_version text NOT NULL |
| calculated_at | timestamptz | 허용 |  | calculated_at timestamptz |
| approved_at | timestamptz | 허용 |  | approved_at timestamptz |
| finalized_at | timestamptz | 허용 |  | finalized_at timestamptz |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |
| updated_at | timestamptz | 불가 |  | updated_at timestamptz NOT NULL DEFAULT now() |

PK: (settlement_id)

UNIQUE: (seller_id, period_start, period_end, currency, version_no)


```sql
CONSTRAINT uq_settlement_period_version UNIQUE (
        seller_id, period_start, period_end, currency, version_no
    )
CONSTRAINT ck_settlement_period CHECK (period_start <= period_end)
CONSTRAINT ck_settlement_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_settlement_version_positive CHECK (version_no > 0)
CONSTRAINT ck_settlement_status CHECK (status IN (
        'DRAFT', 'CALCULATED', 'APPROVAL_PENDING', 'APPROVED',
        'PAYOUT_PENDING', 'PAID', 'FAILED', 'VOID'
    ))
CONSTRAINT ck_settlement_amounts_nonnegative CHECK (
        credit_amount >= 0 AND debit_amount >= 0 AND hold_amount >= 0 AND payout_amount >= 0
    )
CONSTRAINT ck_settlement_net_formula CHECK (
        net_amount = credit_amount - debit_amount - hold_amount
    )
CONSTRAINT ck_settlement_payout_limit CHECK (
        payout_amount <= GREATEST(net_amount, 0)
    )
CONSTRAINT ck_settlement_calculated_state CHECK (
        status = 'DRAFT' OR calculated_at IS NOT NULL
    )
CONSTRAINT ck_settlement_approval_state CHECK (
        status NOT IN ('APPROVED', 'PAYOUT_PENDING', 'PAID') OR approved_at IS NOT NULL
    )
CONSTRAINT ck_settlement_finalized_state CHECK (
        status NOT IN ('PAID', 'VOID') OR finalized_at IS NOT NULL
    )
CONSTRAINT ck_settlement_calc_version_not_blank CHECK (btrim(calculation_version) <> '')
CREATE INDEX ix_settlement_work_queue
    ON marketplace.settlement (status, period_end, seller_id)
    INCLUDE (currency, net_amount, payout_amount)
    WHERE status IN ('CALCULATED', 'APPROVAL_PENDING', 'APPROVED', 'PAYOUT_PENDING', 'FAILED');
CREATE UNIQUE INDEX uq_settlement_one_approved_version
    ON marketplace.settlement (seller_id, period_start, period_end, currency)
    WHERE status IN ('APPROVED', 'PAYOUT_PENDING');
```

## settlement_allocation

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| settlement_allocation_id | uuid | 불가 | PK | settlement_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| settlement_id | uuid | 불가 | FK | settlement_id uuid NOT NULL |
| seller_ledger_entry_id | uuid | 불가 | FK | seller_ledger_entry_id uuid NOT NULL |
| allocated_amount | bigint | 불가 |  | allocated_amount bigint NOT NULL |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (settlement_allocation_id)

UNIQUE: (settlement_id, seller_ledger_entry_id)

- FK fk_settlement_allocation_settlement: (settlement_id) → settlement.settlement(settlement_id)
- FK fk_settlement_allocation_ledger: (seller_ledger_entry_id) → settlement.seller_ledger_entry(seller_ledger_entry_id)

```sql
CONSTRAINT uq_settlement_ledger_allocation UNIQUE (
        settlement_id, seller_ledger_entry_id
    )
CONSTRAINT ck_settlement_allocation_nonzero CHECK (allocated_amount <> 0)
CREATE INDEX ix_settlement_allocation_ledger
    ON marketplace.settlement_allocation (seller_ledger_entry_id, settlement_id)
    INCLUDE (allocated_amount);
```

## settlement_hold

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| settlement_hold_id | uuid | 불가 | PK | settlement_hold_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| seller_id | uuid | 불가 |  | seller_id uuid NOT NULL |
| claim_id | uuid | 허용 |  | claim_id uuid |
| source_type | text | 불가 |  | source_type text NOT NULL |
| source_id | uuid | 허용 |  | source_id uuid |
| source_key | text | 불가 | UK | source_key text NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| reason_code | text | 불가 |  | reason_code text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'ACTIVE' |
| held_at | timestamptz | 불가 |  | held_at timestamptz NOT NULL DEFAULT now() |
| release_due_at | timestamptz | 허용 |  | release_due_at timestamptz |
| released_at | timestamptz | 허용 |  | released_at timestamptz |
| release_reason | text | 허용 |  | release_reason text |
| metadata | jsonb | 불가 |  | metadata jsonb NOT NULL DEFAULT '{}'::jsonb |

PK: (settlement_hold_id)

UNIQUE: (source_key)


```sql
CONSTRAINT uq_settlement_hold_source_key UNIQUE (source_key)
CONSTRAINT ck_settlement_hold_source_type CHECK (source_type IN (
        'CLAIM', 'COMPLIANCE', 'RISK_POLICY', 'CHARGEBACK', 'ADMIN'
    ))
CONSTRAINT ck_settlement_hold_amount_positive CHECK (amount > 0)
CONSTRAINT ck_settlement_hold_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_settlement_hold_status CHECK (status IN (
        'ACTIVE', 'RELEASED', 'CAPTURED', 'CANCELLED'
    ))
CONSTRAINT ck_settlement_hold_release_state CHECK (
        (status = 'ACTIVE' AND released_at IS NULL)
        OR (status <> 'ACTIVE' AND released_at IS NOT NULL)
    )
CONSTRAINT ck_settlement_hold_claim_shape CHECK (
        (source_type = 'CLAIM' AND claim_id IS NOT NULL)
        OR (source_type <> 'CLAIM' AND claim_id IS NULL)
    )
CONSTRAINT ck_settlement_hold_source_key_not_blank CHECK (btrim(source_key) <> '')
CONSTRAINT ck_settlement_hold_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
CREATE INDEX ix_settlement_hold_active_due
    ON marketplace.settlement_hold (seller_id, release_due_at, held_at)
    INCLUDE (amount, currency, reason_code)
    WHERE status = 'ACTIVE';
CREATE INDEX ix_settlement_hold_claim
    ON marketplace.settlement_hold (claim_id, status)
    WHERE claim_id IS NOT NULL;
```

## settlement_payout_attempt

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| payout_attempt_id | uuid | 불가 | PK | payout_attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| settlement_id | uuid | 불가 | FK | settlement_id uuid NOT NULL |
| attempt_no | integer | 불가 |  | attempt_no integer NOT NULL |
| idempotency_key | text | 불가 | UK | idempotency_key text NOT NULL |
| account_snapshot | jsonb | 불가 |  | account_snapshot jsonb NOT NULL |
| amount | bigint | 불가 |  | amount bigint NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'REQUESTED' |
| bank_tx_id | text | 허용 | UK | bank_tx_id text |
| requested_at | timestamptz | 불가 |  | requested_at timestamptz NOT NULL DEFAULT now() |
| processed_at | timestamptz | 허용 |  | processed_at timestamptz |
| failure_code | text | 허용 |  | failure_code text |
| failure_message | text | 허용 |  | failure_message text |
| response_payload | jsonb | 불가 |  | response_payload jsonb NOT NULL DEFAULT '{}'::jsonb |

PK: (payout_attempt_id)

UNIQUE: (settlement_id, attempt_no); (idempotency_key); (bank_tx_id)

- FK fk_payout_attempt_settlement: (settlement_id) → settlement.settlement(settlement_id)

```sql
CONSTRAINT uq_payout_settlement_attempt UNIQUE (settlement_id, attempt_no)
CONSTRAINT uq_payout_idempotency_key UNIQUE (idempotency_key)
CONSTRAINT uq_payout_bank_tx_id UNIQUE (bank_tx_id)
CONSTRAINT ck_payout_attempt_positive CHECK (attempt_no > 0)
CONSTRAINT ck_payout_amount_positive CHECK (amount > 0)
CONSTRAINT ck_payout_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_payout_status CHECK (status IN (
        'REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED'
    ))
CONSTRAINT ck_payout_processed_state CHECK (
        status IN ('REQUESTED', 'PROCESSING') OR processed_at IS NOT NULL
    )
CONSTRAINT ck_payout_account_snapshot_object CHECK (jsonb_typeof(account_snapshot) = 'object')
CONSTRAINT ck_payout_response_payload_object CHECK (jsonb_typeof(response_payload) = 'object')
CONSTRAINT ck_payout_idempotency_not_blank CHECK (btrim(idempotency_key) <> '')
CREATE INDEX ix_payout_attempt_work_queue
    ON marketplace.settlement_payout_attempt (status, requested_at)
    INCLUDE (settlement_id, amount, currency, attempt_no)
    WHERE status IN ('REQUESTED', 'PROCESSING', 'UNKNOWN', 'FAILED');
```

## reconciliation_file

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| reconciliation_file_id | uuid | 불가 | PK | reconciliation_file_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| provider | text | 불가 |  | provider text NOT NULL |
| file_type | text | 불가 |  | file_type text NOT NULL |
| business_date | date | 불가 |  | business_date date NOT NULL |
| storage_uri | text | 불가 |  | storage_uri text NOT NULL |
| content_hash | text | 불가 | UK | content_hash text NOT NULL |
| row_count | integer | 불가 |  | row_count integer NOT NULL |
| control_total | bigint | 허용 |  | control_total bigint |
| currency | text | 허용 |  | currency text |
| received_at | timestamptz | 불가 |  | received_at timestamptz NOT NULL DEFAULT now() |
| metadata | jsonb | 불가 |  | metadata jsonb NOT NULL DEFAULT '{}'::jsonb |

PK: (reconciliation_file_id)

UNIQUE: (content_hash)


```sql
CONSTRAINT uq_reconciliation_file_content UNIQUE (content_hash)
CONSTRAINT ck_reconciliation_file_type CHECK (file_type IN (
        'TRADE', 'PG_SETTLEMENT', 'BANK', 'CHARGEBACK'
    ))
CONSTRAINT ck_reconciliation_file_row_count CHECK (row_count >= 0)
CONSTRAINT ck_reconciliation_file_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    )
CONSTRAINT ck_reconciliation_file_provider_not_blank CHECK (btrim(provider) <> '')
CONSTRAINT ck_reconciliation_file_uri_not_blank CHECK (btrim(storage_uri) <> '')
CONSTRAINT ck_reconciliation_file_hash_not_blank CHECK (btrim(content_hash) <> '')
CONSTRAINT ck_reconciliation_file_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
CREATE INDEX ix_reconciliation_file_business_date
    ON marketplace.reconciliation_file (provider, file_type, business_date DESC);
```

## reconciliation_raw_row

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| raw_row_id | uuid | 불가 | PK | raw_row_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| reconciliation_file_id | uuid | 불가 | FK | reconciliation_file_id uuid NOT NULL |
| row_no | integer | 불가 |  | row_no integer NOT NULL |
| provider_tx_id | text | 허용 |  | provider_tx_id text |
| event_type | text | 허용 |  | event_type text |
| occurred_at | timestamptz | 허용 |  | occurred_at timestamptz |
| gross_amount | bigint | 허용 |  | gross_amount bigint |
| fee_amount | bigint | 허용 |  | fee_amount bigint |
| net_amount | bigint | 허용 |  | net_amount bigint |
| currency | text | 허용 |  | currency text |
| raw_hash | text | 불가 |  | raw_hash text NOT NULL |
| raw_payload | jsonb | 불가 |  | raw_payload jsonb NOT NULL |
| ingested_at | timestamptz | 불가 |  | ingested_at timestamptz NOT NULL DEFAULT now() |

PK: (raw_row_id)

UNIQUE: (reconciliation_file_id, row_no); (reconciliation_file_id, raw_hash)

- FK fk_reconciliation_raw_file: (reconciliation_file_id) → settlement.reconciliation_file(reconciliation_file_id)

```sql
CONSTRAINT uq_reconciliation_raw_row_no UNIQUE (reconciliation_file_id, row_no)
CONSTRAINT uq_reconciliation_raw_hash UNIQUE (reconciliation_file_id, raw_hash)
CONSTRAINT ck_reconciliation_raw_row_no CHECK (row_no > 0)
CONSTRAINT ck_reconciliation_raw_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    )
CONSTRAINT ck_reconciliation_raw_hash_not_blank CHECK (btrim(raw_hash) <> '')
CONSTRAINT ck_reconciliation_raw_payload_object CHECK (jsonb_typeof(raw_payload) = 'object')
CREATE INDEX ix_reconciliation_raw_provider_tx
    ON marketplace.reconciliation_raw_row (provider_tx_id, occurred_at)
    INCLUDE (gross_amount, fee_amount, net_amount, currency)
    WHERE provider_tx_id IS NOT NULL;
CREATE INDEX ix_reconciliation_raw_occurred_brin
    ON marketplace.reconciliation_raw_row USING brin (occurred_at)
    WITH (pages_per_range = 64);
```

## reconciliation_run

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| reconciliation_run_id | uuid | 불가 | PK | reconciliation_run_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| replay_of_run_id | uuid | 허용 | FK | replay_of_run_id uuid |
| run_key | text | 불가 | UK | run_key text NOT NULL |
| run_type | text | 불가 |  | run_type text NOT NULL |
| business_date_from | date | 불가 |  | business_date_from date NOT NULL |
| business_date_to | date | 불가 |  | business_date_to date NOT NULL |
| algorithm_version | text | 불가 |  | algorithm_version text NOT NULL |
| parameters | jsonb | 불가 |  | parameters jsonb NOT NULL DEFAULT '{}'::jsonb |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'RUNNING' |
| started_at | timestamptz | 불가 |  | started_at timestamptz NOT NULL DEFAULT now() |
| completed_at | timestamptz | 허용 |  | completed_at timestamptz |
| created_by_admin_user_id | uuid | 허용 |  | created_by_admin_user_id uuid |

PK: (reconciliation_run_id)

UNIQUE: (run_key)

- FK fk_reconciliation_run_replay: (replay_of_run_id) → settlement.reconciliation_run(reconciliation_run_id)

```sql
CONSTRAINT uq_reconciliation_run_key UNIQUE (run_key)
CONSTRAINT ck_reconciliation_run_type CHECK (run_type IN (
        'TRADE_TO_PG', 'PG_TO_BANK', 'PAYOUT_TO_BANK', 'FULL'
    ))
CONSTRAINT ck_reconciliation_run_dates CHECK (business_date_from <= business_date_to)
CONSTRAINT ck_reconciliation_run_status CHECK (status IN (
        'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'
    ))
CONSTRAINT ck_reconciliation_run_completed CHECK (
        status = 'RUNNING' OR completed_at IS NOT NULL
    )
CONSTRAINT ck_reconciliation_run_key_not_blank CHECK (btrim(run_key) <> '')
CONSTRAINT ck_reconciliation_algorithm_not_blank CHECK (btrim(algorithm_version) <> '')
CONSTRAINT ck_reconciliation_parameters_object CHECK (jsonb_typeof(parameters) = 'object')
CREATE INDEX ix_reconciliation_run_work_queue
    ON marketplace.reconciliation_run (status, started_at)
    INCLUDE (run_type, business_date_from, business_date_to, algorithm_version)
    WHERE status IN ('RUNNING', 'FAILED');
CREATE INDEX ix_reconciliation_run_replay
    ON marketplace.reconciliation_run (replay_of_run_id, started_at)
    WHERE replay_of_run_id IS NOT NULL;
```

## reconciliation_match

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| reconciliation_match_id | uuid | 불가 | PK | reconciliation_match_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| reconciliation_run_id | uuid | 불가 | FK | reconciliation_run_id uuid NOT NULL |
| raw_row_id | uuid | 불가 | FK | raw_row_id uuid NOT NULL |
| payment_transaction_id | uuid | 불가 |  | payment_transaction_id uuid NOT NULL |
| matched_amount | bigint | 불가 |  | matched_amount bigint NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| match_type | text | 불가 |  | match_type text NOT NULL |
| confidence | numeric(7,6) | 허용 |  | confidence numeric(7,6) |
| match_details | jsonb | 불가 |  | match_details jsonb NOT NULL DEFAULT '{}'::jsonb |
| created_at | timestamptz | 불가 |  | created_at timestamptz NOT NULL DEFAULT now() |

PK: (reconciliation_match_id)

UNIQUE: (reconciliation_run_id, raw_row_id, payment_transaction_id)

- FK fk_reconciliation_match_run: (reconciliation_run_id) → settlement.reconciliation_run(reconciliation_run_id)
- FK fk_reconciliation_match_raw_row: (raw_row_id) → settlement.reconciliation_raw_row(raw_row_id)

```sql
CONSTRAINT uq_reconciliation_match_edge UNIQUE (
        reconciliation_run_id, raw_row_id, payment_transaction_id
    )
CONSTRAINT ck_reconciliation_match_amount CHECK (matched_amount <> 0)
CONSTRAINT ck_reconciliation_match_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_reconciliation_match_type CHECK (match_type IN (
        'EXACT', 'AGGREGATED', 'SPLIT', 'MANUAL'
    ))
CONSTRAINT ck_reconciliation_match_confidence CHECK (
        confidence IS NULL OR (confidence >= 0 AND confidence <= 1)
    )
CONSTRAINT ck_reconciliation_match_details_object CHECK (jsonb_typeof(match_details) = 'object')
CREATE INDEX ix_reconciliation_match_raw_row
    ON marketplace.reconciliation_match (raw_row_id, reconciliation_run_id)
    INCLUDE (payment_transaction_id, matched_amount);
CREATE INDEX ix_reconciliation_match_payment_tx
    ON marketplace.reconciliation_match (payment_transaction_id, reconciliation_run_id)
    INCLUDE (raw_row_id, matched_amount);
```

## reconciliation_discrepancy

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| discrepancy_id | uuid | 불가 | PK | discrepancy_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| reconciliation_run_id | uuid | 불가 | FK | reconciliation_run_id uuid NOT NULL |
| raw_row_id | uuid | 허용 | FK | raw_row_id uuid |
| payment_transaction_id | uuid | 허용 |  | payment_transaction_id uuid |
| supersedes_discrepancy_id | uuid | 허용 | FK, UK | supersedes_discrepancy_id uuid |
| discrepancy_group_key | text | 불가 |  | discrepancy_group_key text NOT NULL |
| version_no | integer | 불가 |  | version_no integer NOT NULL DEFAULT 1 |
| discrepancy_type | text | 불가 |  | discrepancy_type text NOT NULL |
| expected_amount | bigint | 허용 |  | expected_amount bigint |
| actual_amount | bigint | 허용 |  | actual_amount bigint |
| difference_amount | bigint | 허용 |  | difference_amount bigint |
| currency | text | 허용 |  | currency text |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'OPEN' |
| resolution_event | jsonb | 허용 |  | resolution_event jsonb |
| resolved_by_admin_user_id | uuid | 허용 |  | resolved_by_admin_user_id uuid |
| recorded_at | timestamptz | 불가 |  | recorded_at timestamptz NOT NULL DEFAULT now() |
| resolved_at | timestamptz | 허용 |  | resolved_at timestamptz |

PK: (discrepancy_id)

UNIQUE: (discrepancy_group_key, version_no); (supersedes_discrepancy_id)

- FK fk_reconciliation_discrepancy_run: (reconciliation_run_id) → settlement.reconciliation_run(reconciliation_run_id)
- FK fk_reconciliation_discrepancy_raw_row: (raw_row_id) → settlement.reconciliation_raw_row(raw_row_id)
- FK fk_reconciliation_discrepancy_predecessor: (supersedes_discrepancy_id) → settlement.reconciliation_discrepancy(discrepancy_id)

```sql
CONSTRAINT uq_reconciliation_discrepancy_version UNIQUE (
        discrepancy_group_key, version_no
    )
CONSTRAINT uq_reconciliation_discrepancy_successor UNIQUE (supersedes_discrepancy_id)
CONSTRAINT ck_reconciliation_discrepancy_version CHECK (version_no > 0)
CONSTRAINT ck_reconciliation_discrepancy_type CHECK (discrepancy_type IN (
        'MISSING_INTERNAL', 'MISSING_PROVIDER', 'AMOUNT_MISMATCH', 'FEE_MISMATCH',
        'CURRENCY_MISMATCH', 'DUPLICATE', 'DATE_MISMATCH', 'OTHER'
    ))
CONSTRAINT ck_reconciliation_discrepancy_amounts CHECK (
        difference_amount IS NULL
        OR (expected_amount IS NOT NULL AND actual_amount IS NOT NULL
            AND difference_amount = actual_amount - expected_amount)
    )
CONSTRAINT ck_reconciliation_discrepancy_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    )
CONSTRAINT ck_reconciliation_discrepancy_status CHECK (status IN (
        'OPEN', 'INVESTIGATING', 'RESOLVED', 'ACCEPTED', 'FALSE_POSITIVE'
    ))
CONSTRAINT ck_reconciliation_discrepancy_resolution CHECK (
        (status IN ('OPEN', 'INVESTIGATING') AND resolved_at IS NULL)
        OR (status IN ('RESOLVED', 'ACCEPTED', 'FALSE_POSITIVE')
            AND resolved_at IS NOT NULL AND resolution_event IS NOT NULL)
    )
CONSTRAINT ck_reconciliation_discrepancy_event_object CHECK (
        resolution_event IS NULL OR jsonb_typeof(resolution_event) = 'object'
    )
CONSTRAINT ck_reconciliation_discrepancy_group_not_blank CHECK (
        btrim(discrepancy_group_key) <> ''
    )
CREATE INDEX ix_reconciliation_discrepancy_run_status
    ON marketplace.reconciliation_discrepancy (
        reconciliation_run_id, status, discrepancy_type, recorded_at
    );
CREATE INDEX ix_reconciliation_discrepancy_open
    ON marketplace.reconciliation_discrepancy (recorded_at, discrepancy_type)
    INCLUDE (reconciliation_run_id, difference_amount, currency)
    WHERE status IN ('OPEN', 'INVESTIGATING');
CREATE INDEX ix_reconciliation_discrepancy_raw
    ON marketplace.reconciliation_discrepancy (raw_row_id, reconciliation_run_id)
    WHERE raw_row_id IS NOT NULL;
CREATE INDEX ix_reconciliation_discrepancy_payment
    ON marketplace.reconciliation_discrepancy (payment_transaction_id, reconciliation_run_id)
    WHERE payment_transaction_id IS NOT NULL;
```

## bank_deposit_match

상태: CURRENT · 실제 schema: marketplace · 현재 누적 마이그레이션 정의

| 컬럼 | 타입 | NULL | 키 | SQL 정의 / 계획 |
| --- | --- | --- | --- | --- |
| bank_deposit_match_id | uuid | 불가 | PK | bank_deposit_match_id uuid PRIMARY KEY DEFAULT gen_random_uuid() |
| reconciliation_run_id | uuid | 불가 | FK | reconciliation_run_id uuid NOT NULL |
| payout_attempt_id | uuid | 불가 | FK | payout_attempt_id uuid NOT NULL |
| raw_row_id | uuid | 불가 | FK | raw_row_id uuid NOT NULL |
| matched_amount | bigint | 불가 |  | matched_amount bigint NOT NULL |
| currency | text | 불가 |  | currency text NOT NULL |
| status | text | 불가 |  | status text NOT NULL DEFAULT 'MATCHED' |
| matched_at | timestamptz | 불가 |  | matched_at timestamptz NOT NULL DEFAULT now() |
| matched_by_admin_user_id | uuid | 허용 |  | matched_by_admin_user_id uuid |
| note | text | 허용 |  | note text |

PK: (bank_deposit_match_id)

UNIQUE: (reconciliation_run_id, payout_attempt_id, raw_row_id)

- FK fk_bank_deposit_match_run: (reconciliation_run_id) → settlement.reconciliation_run(reconciliation_run_id)
- FK fk_bank_deposit_match_payout: (payout_attempt_id) → settlement.settlement_payout_attempt(payout_attempt_id)
- FK fk_bank_deposit_match_raw_row: (raw_row_id) → settlement.reconciliation_raw_row(raw_row_id)

```sql
CONSTRAINT uq_bank_deposit_match_edge UNIQUE (
        reconciliation_run_id, payout_attempt_id, raw_row_id
    )
CONSTRAINT ck_bank_deposit_match_amount CHECK (matched_amount > 0)
CONSTRAINT ck_bank_deposit_match_currency CHECK (currency ~ '^[A-Z]{3}$')
CONSTRAINT ck_bank_deposit_match_status CHECK (status IN (
        'MATCHED', 'PARTIAL', 'REVERSED'
    ))
CREATE INDEX ix_bank_deposit_match_payout
    ON marketplace.bank_deposit_match (payout_attempt_id, reconciliation_run_id)
    INCLUDE (matched_amount, currency, status);
CREATE INDEX ix_bank_deposit_match_raw
    ON marketplace.bank_deposit_match (raw_row_id, reconciliation_run_id)
    INCLUDE (payout_attempt_id, matched_amount, status);
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

