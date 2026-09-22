-- settlement-service: empty isolated database schema snapshot.
-- NOT an upgrade migration. NEVER apply to an existing/production database.
-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.
-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.
BEGIN;
CREATE SCHEMA IF NOT EXISTS marketplace;

--  MIG-REVERSAL: partial reversals use owner lock and cumulative absolute sum <= original; source_key remains unique. No direct updates/deletes.
CREATE TABLE marketplace.seller_ledger_entry (
    seller_ledger_entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    entry_type text NOT NULL,
    signed_amount bigint NOT NULL,
    currency text NOT NULL,
    source_type text NOT NULL,
    source_id uuid,
    source_key text NOT NULL,
    reversal_of_entry_id uuid,
    recognized_at timestamptz NOT NULL,
    due_date date NOT NULL,
    description text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_seller_ledger_source_key UNIQUE (source_key),
    CONSTRAINT ck_seller_ledger_entry_type CHECK (entry_type IN (
        'SALE_PROCEEDS', 'SHIPPING_REVENUE', 'COMMISSION_FEE', 'PAYMENT_FEE',
        'REFUND', 'CHARGEBACK', 'HOLD', 'HOLD_RELEASE', 'PENALTY',
        'TAX_WITHHOLDING', 'ADJUSTMENT', 'REVERSAL'
    )),
    CONSTRAINT ck_seller_ledger_nonzero_amount CHECK (signed_amount <> 0),
    CONSTRAINT ck_seller_ledger_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_seller_ledger_source_type CHECK (source_type IN (
        'PURCHASE_CONFIRMATION', 'REFUND_ITEM', 'CLAIM', 'SETTLEMENT_HOLD',
        'SELLER_PENALTY', 'CHARGEBACK', 'MANUAL_ADJUSTMENT', 'MIGRATION'
    )),
    CONSTRAINT ck_seller_ledger_reversal_shape CHECK (
        (reversal_of_entry_id IS NULL AND entry_type <> 'REVERSAL')
        OR (reversal_of_entry_id IS NOT NULL AND entry_type = 'REVERSAL')
    ),
    CONSTRAINT ck_seller_ledger_source_key_not_blank CHECK (btrim(source_key) <> ''),
    CONSTRAINT ck_seller_ledger_metadata_object CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT ck_ledger_not_self_reversal_v1 CHECK (reversal_of_entry_id IS NULL OR reversal_of_entry_id <> seller_ledger_entry_id)
);

--  MIG-NET/SET-02; API netAmount = gross_net_amount = credit - debit. Keep legacy net_amount = gross_net_amount - hold; payout bounded by post-hold net.
CREATE TABLE marketplace.settlement (
    settlement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    currency text NOT NULL,
    version_no integer NOT NULL DEFAULT 1,
    status text NOT NULL DEFAULT 'DRAFT',
    credit_amount bigint NOT NULL DEFAULT 0,
    debit_amount bigint NOT NULL DEFAULT 0,
    hold_amount bigint NOT NULL DEFAULT 0,
    net_amount bigint NOT NULL DEFAULT 0,
    payout_amount bigint NOT NULL DEFAULT 0,
    calculation_version text NOT NULL,
    calculated_at timestamptz,
    approved_at timestamptz,
    finalized_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    gross_net_amount bigint NOT NULL,
    CONSTRAINT uq_settlement_period_version UNIQUE (
        seller_id, period_start, period_end, currency, version_no
    ),
    CONSTRAINT ck_settlement_period CHECK (period_start <= period_end),
    CONSTRAINT ck_settlement_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_settlement_version_positive CHECK (version_no > 0),
    CONSTRAINT ck_settlement_status CHECK (status IN (
        'DRAFT', 'CALCULATED', 'APPROVAL_PENDING', 'APPROVED',
        'PAYOUT_PENDING', 'PAID', 'FAILED', 'VOID'
    )),
    CONSTRAINT ck_settlement_amounts_nonnegative CHECK (
        credit_amount >= 0 AND debit_amount >= 0 AND hold_amount >= 0 AND payout_amount >= 0
    ),
    CONSTRAINT ck_settlement_net_formula CHECK (
        net_amount = credit_amount - debit_amount - hold_amount
    ),
    CONSTRAINT ck_settlement_calculated_state CHECK (
        status = 'DRAFT' OR calculated_at IS NOT NULL
    ),
    CONSTRAINT ck_settlement_approval_state CHECK (
        status NOT IN ('APPROVED', 'PAYOUT_PENDING', 'PAID') OR approved_at IS NOT NULL
    ),
    CONSTRAINT ck_settlement_finalized_state CHECK (
        status NOT IN ('PAID', 'VOID') OR finalized_at IS NOT NULL
    ),
    CONSTRAINT ck_settlement_calc_version_not_blank CHECK (btrim(calculation_version) <> ''),
    CONSTRAINT ck_settlement_gross_net_v1 CHECK (gross_net_amount = credit_amount - debit_amount),
    CONSTRAINT ck_settlement_payout_limit CHECK (payout_amount <= GREATEST(gross_net_amount - hold_amount, 0)),
    CONSTRAINT ck_settlement_hold_limit_v1 CHECK (hold_amount <= GREATEST(gross_net_amount, 0))
);

CREATE TABLE marketplace.settlement_allocation (
    settlement_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_id uuid NOT NULL,
    seller_ledger_entry_id uuid NOT NULL,
    allocated_amount bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_settlement_ledger_allocation UNIQUE (
        settlement_id, seller_ledger_entry_id
    ),
    CONSTRAINT ck_settlement_allocation_nonzero CHECK (allocated_amount <> 0)
);

CREATE TABLE marketplace.settlement_hold (
    settlement_hold_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    claim_id uuid,
    source_type text NOT NULL,
    source_id uuid,
    source_key text NOT NULL,
    amount bigint NOT NULL,
    currency text NOT NULL,
    reason_code text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    held_at timestamptz NOT NULL DEFAULT now(),
    release_due_at timestamptz,
    released_at timestamptz,
    release_reason text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT uq_settlement_hold_source_key UNIQUE (source_key),
    CONSTRAINT ck_settlement_hold_source_type CHECK (source_type IN (
        'CLAIM', 'COMPLIANCE', 'RISK_POLICY', 'CHARGEBACK', 'ADMIN'
    )),
    CONSTRAINT ck_settlement_hold_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_settlement_hold_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_settlement_hold_status CHECK (status IN (
        'ACTIVE', 'RELEASED', 'CAPTURED', 'CANCELLED'
    )),
    CONSTRAINT ck_settlement_hold_release_state CHECK (
        (status = 'ACTIVE' AND released_at IS NULL)
        OR (status <> 'ACTIVE' AND released_at IS NOT NULL)
    ),
    CONSTRAINT ck_settlement_hold_claim_shape CHECK (
        (source_type = 'CLAIM' AND claim_id IS NOT NULL)
        OR (source_type <> 'CLAIM' AND claim_id IS NULL)
    ),
    CONSTRAINT ck_settlement_hold_source_key_not_blank CHECK (btrim(source_key) <> ''),
    CONSTRAINT ck_settlement_hold_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
);

--  SET-03; external Commerce approvals/fence, no cross-service FK.
CREATE TABLE marketplace.settlement_payout_attempt (
    payout_attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_id uuid NOT NULL,
    attempt_no integer NOT NULL,
    idempotency_key text NOT NULL,
    account_snapshot jsonb NOT NULL,
    amount bigint NOT NULL,
    currency text NOT NULL,
    status text NOT NULL DEFAULT 'REQUESTED',
    bank_tx_id text,
    requested_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    failure_code text,
    failure_message text,
    response_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    approval_id uuid NOT NULL,
    fence_id uuid NOT NULL,
    dispatch_permit_id uuid NULL,
    operation_hash text NOT NULL,
    result_version bigint NOT NULL,
    lease_expires_at timestamptz NULL,
    next_retry_at timestamptz NULL,
    CONSTRAINT uq_payout_settlement_attempt UNIQUE (settlement_id, attempt_no),
    CONSTRAINT uq_payout_idempotency_key UNIQUE (idempotency_key),
    CONSTRAINT uq_payout_bank_tx_id UNIQUE (bank_tx_id),
    CONSTRAINT ck_payout_attempt_positive CHECK (attempt_no > 0),
    CONSTRAINT ck_payout_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_payout_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_payout_status CHECK (status IN (
        'REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED'
    )),
    CONSTRAINT ck_payout_processed_state CHECK (
        status IN ('REQUESTED', 'PROCESSING') OR processed_at IS NOT NULL
    ),
    CONSTRAINT ck_payout_account_snapshot_object CHECK (jsonb_typeof(account_snapshot) = 'object'),
    CONSTRAINT ck_payout_response_payload_object CHECK (jsonb_typeof(response_payload) = 'object'),
    CONSTRAINT ck_payout_idempotency_not_blank CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT settlement_payout_attempt_operation_hash_v1_ck CHECK (operation_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT settlement_payout_attempt_result_version_v1_ck CHECK (result_version >= 0)
);

CREATE TABLE marketplace.reconciliation_file (
    reconciliation_file_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL,
    file_type text NOT NULL,
    business_date date NOT NULL,
    storage_uri text NOT NULL,
    content_hash text NOT NULL,
    row_count integer NOT NULL,
    control_total bigint,
    currency text,
    received_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT uq_reconciliation_file_content UNIQUE (content_hash),
    CONSTRAINT ck_reconciliation_file_type CHECK (file_type IN (
        'TRADE', 'PG_SETTLEMENT', 'BANK', 'CHARGEBACK'
    )),
    CONSTRAINT ck_reconciliation_file_row_count CHECK (row_count >= 0),
    CONSTRAINT ck_reconciliation_file_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    ),
    CONSTRAINT ck_reconciliation_file_provider_not_blank CHECK (btrim(provider) <> ''),
    CONSTRAINT ck_reconciliation_file_uri_not_blank CHECK (btrim(storage_uri) <> ''),
    CONSTRAINT ck_reconciliation_file_hash_not_blank CHECK (btrim(content_hash) <> ''),
    CONSTRAINT ck_reconciliation_file_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE marketplace.reconciliation_raw_row (
    raw_row_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_file_id uuid NOT NULL,
    row_no integer NOT NULL,
    provider_tx_id text,
    event_type text,
    occurred_at timestamptz,
    gross_amount bigint,
    fee_amount bigint,
    net_amount bigint,
    currency text,
    raw_hash text NOT NULL,
    raw_payload jsonb NOT NULL,
    ingested_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_reconciliation_raw_row_no UNIQUE (reconciliation_file_id, row_no),
    CONSTRAINT uq_reconciliation_raw_hash UNIQUE (reconciliation_file_id, raw_hash),
    CONSTRAINT ck_reconciliation_raw_row_no CHECK (row_no > 0),
    CONSTRAINT ck_reconciliation_raw_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    ),
    CONSTRAINT ck_reconciliation_raw_hash_not_blank CHECK (btrim(raw_hash) <> ''),
    CONSTRAINT ck_reconciliation_raw_payload_object CHECK (jsonb_typeof(raw_payload) = 'object')
);

CREATE TABLE marketplace.reconciliation_run (
    reconciliation_run_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    replay_of_run_id uuid,
    run_key text NOT NULL,
    run_type text NOT NULL,
    business_date_from date NOT NULL,
    business_date_to date NOT NULL,
    algorithm_version text NOT NULL,
    parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'RUNNING',
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    created_by_admin_user_id uuid,
    CONSTRAINT uq_reconciliation_run_key UNIQUE (run_key),
    CONSTRAINT ck_reconciliation_run_type CHECK (run_type IN (
        'TRADE_TO_PG', 'PG_TO_BANK', 'PAYOUT_TO_BANK', 'FULL'
    )),
    CONSTRAINT ck_reconciliation_run_dates CHECK (business_date_from <= business_date_to),
    CONSTRAINT ck_reconciliation_run_status CHECK (status IN (
        'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'
    )),
    CONSTRAINT ck_reconciliation_run_completed CHECK (
        status = 'RUNNING' OR completed_at IS NOT NULL
    ),
    CONSTRAINT ck_reconciliation_run_key_not_blank CHECK (btrim(run_key) <> ''),
    CONSTRAINT ck_reconciliation_algorithm_not_blank CHECK (btrim(algorithm_version) <> ''),
    CONSTRAINT ck_reconciliation_parameters_object CHECK (jsonb_typeof(parameters) = 'object')
);

CREATE TABLE marketplace.reconciliation_match (
    reconciliation_match_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_run_id uuid NOT NULL,
    raw_row_id uuid NOT NULL,
    payment_transaction_id uuid NOT NULL,
    matched_amount bigint NOT NULL,
    currency text NOT NULL,
    match_type text NOT NULL,
    confidence numeric(7,6),
    match_details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_reconciliation_match_edge UNIQUE (
        reconciliation_run_id, raw_row_id, payment_transaction_id
    ),
    CONSTRAINT ck_reconciliation_match_amount CHECK (matched_amount <> 0),
    CONSTRAINT ck_reconciliation_match_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_reconciliation_match_type CHECK (match_type IN (
        'EXACT', 'AGGREGATED', 'SPLIT', 'MANUAL'
    )),
    CONSTRAINT ck_reconciliation_match_confidence CHECK (
        confidence IS NULL OR (confidence >= 0 AND confidence <= 1)
    ),
    CONSTRAINT ck_reconciliation_match_details_object CHECK (jsonb_typeof(match_details) = 'object')
);

CREATE TABLE marketplace.reconciliation_discrepancy (
    discrepancy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_run_id uuid NOT NULL,
    raw_row_id uuid,
    payment_transaction_id uuid,
    supersedes_discrepancy_id uuid,
    discrepancy_group_key text NOT NULL,
    version_no integer NOT NULL DEFAULT 1,
    discrepancy_type text NOT NULL,
    expected_amount bigint,
    actual_amount bigint,
    difference_amount bigint,
    currency text,
    status text NOT NULL DEFAULT 'OPEN',
    resolution_event jsonb,
    resolved_by_admin_user_id uuid,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT uq_reconciliation_discrepancy_version UNIQUE (
        discrepancy_group_key, version_no
    ),
    CONSTRAINT uq_reconciliation_discrepancy_successor UNIQUE (supersedes_discrepancy_id),
    CONSTRAINT ck_reconciliation_discrepancy_version CHECK (version_no > 0),
    CONSTRAINT ck_reconciliation_discrepancy_type CHECK (discrepancy_type IN (
        'MISSING_INTERNAL', 'MISSING_PROVIDER', 'AMOUNT_MISMATCH', 'FEE_MISMATCH',
        'CURRENCY_MISMATCH', 'DUPLICATE', 'DATE_MISMATCH', 'OTHER'
    )),
    CONSTRAINT ck_reconciliation_discrepancy_amounts CHECK (
        difference_amount IS NULL
        OR (expected_amount IS NOT NULL AND actual_amount IS NOT NULL
            AND difference_amount = actual_amount - expected_amount)
    ),
    CONSTRAINT ck_reconciliation_discrepancy_currency CHECK (
        currency IS NULL OR currency ~ '^[A-Z]{3}$'
    ),
    CONSTRAINT ck_reconciliation_discrepancy_status CHECK (status IN (
        'OPEN', 'INVESTIGATING', 'RESOLVED', 'ACCEPTED', 'FALSE_POSITIVE'
    )),
    CONSTRAINT ck_reconciliation_discrepancy_resolution CHECK (
        (status IN ('OPEN', 'INVESTIGATING') AND resolved_at IS NULL)
        OR (status IN ('RESOLVED', 'ACCEPTED', 'FALSE_POSITIVE')
            AND resolved_at IS NOT NULL AND resolution_event IS NOT NULL)
    ),
    CONSTRAINT ck_reconciliation_discrepancy_event_object CHECK (
        resolution_event IS NULL OR jsonb_typeof(resolution_event) = 'object'
    ),
    CONSTRAINT ck_reconciliation_discrepancy_group_not_blank CHECK (
        btrim(discrepancy_group_key) <> ''
    )
);

CREATE TABLE marketplace.bank_deposit_match (
    bank_deposit_match_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_run_id uuid NOT NULL,
    payout_attempt_id uuid NOT NULL,
    raw_row_id uuid NOT NULL,
    matched_amount bigint NOT NULL,
    currency text NOT NULL,
    status text NOT NULL DEFAULT 'MATCHED',
    matched_at timestamptz NOT NULL DEFAULT now(),
    matched_by_admin_user_id uuid,
    note text,
    CONSTRAINT uq_bank_deposit_match_edge UNIQUE (
        reconciliation_run_id, payout_attempt_id, raw_row_id
    ),
    CONSTRAINT ck_bank_deposit_match_amount CHECK (matched_amount > 0),
    CONSTRAINT ck_bank_deposit_match_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_bank_deposit_match_status CHECK (status IN (
        'MATCHED', 'PARTIAL', 'REVERSED'
    ))
);

--  EVT-01/X-07; text aggregateId, immutable published bytes/hash, optimistic replay version. Existing lock_token/locked_at retained; legacy non-v1 rows archived before NOT NULL validation.
CREATE TABLE marketplace.outbox_event (
    outbox_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_key text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    aggregate_version bigint NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    attempt_count integer NOT NULL DEFAULT 0,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    available_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    locked_at timestamptz,
    lock_token uuid,
    last_error text,
    version bigint NOT NULL,
    payload_hash text NOT NULL,
    serialized_body bytea NOT NULL,
    lease_expires_at timestamptz NULL,
    event_version integer NOT NULL,
    producer text NOT NULL,
    correlation_id uuid NOT NULL,
    causation_id uuid NOT NULL,
    trace_id text NOT NULL,
    CONSTRAINT outbox_event_key_uq UNIQUE (event_key),
    CONSTRAINT outbox_event_aggregate_version_uq UNIQUE (aggregate_type, aggregate_id, aggregate_version),
    CONSTRAINT outbox_event_status_ck CHECK (status IN ('PENDING', 'PUBLISHING', 'PUBLISHED', 'FAILED', 'DEAD')),
    CONSTRAINT outbox_event_version_ck CHECK (aggregate_version IS NULL OR aggregate_version >= 0),
    CONSTRAINT outbox_event_payload_ck CHECK (jsonb_typeof(payload) IN ('object', 'array')),
    CONSTRAINT outbox_event_attempt_count_ck CHECK (attempt_count >= 0),
    CONSTRAINT outbox_event_times_ck CHECK (
        available_at >= occurred_at
        AND (published_at IS NULL OR published_at >= occurred_at)
        AND (locked_at IS NULL OR locked_at >= occurred_at)
    ),
    CONSTRAINT outbox_event_lock_ck CHECK ((locked_at IS NULL) = (lock_token IS NULL)),
    CONSTRAINT outbox_event_version_v1_ck CHECK (version >= 0),
    CONSTRAINT outbox_event_payload_hash_v1_ck CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT outbox_envelope_v1_ck CHECK (aggregate_version >= 1 AND event_version = 1 AND jsonb_typeof(payload) = 'object' AND trace_id ~ '^[0-9a-f]{32}$' AND octet_length(serialized_body) > 0)
);

-- EVT-03/X-07; entry_id identifies one consumer/event row; sequence collision with a different hash is quarantined before overwrite.
CREATE TABLE marketplace.consumer_inbox (
    consumer_name text NOT NULL,
    event_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    version bigint NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    aggregate_version bigint NOT NULL,
    payload jsonb NOT NULL,
    payload_hash text NOT NULL,
    status text NOT NULL,
    attempt_count integer NOT NULL,
    next_retry_at timestamptz NOT NULL,
    lease_token uuid NULL,
    lease_expires_at timestamptz NULL,
    received_at timestamptz NOT NULL,
    processed_at timestamptz NULL,
    CONSTRAINT consumer_inbox_version_v1_ck CHECK (version >= 0),
    CONSTRAINT consumer_inbox_payload_hash_v1_ck CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT consumer_inbox_attempt_count_v1_ck CHECK (attempt_count >= 0),
    CONSTRAINT consumer_inbox_status_v1_ck CHECK (status IN ('RECEIVED', 'WAITING_GAP', 'PROCESSING', 'PROCESSED', 'IGNORED', 'FAILED', 'QUARANTINED')),
    CONSTRAINT consumer_inbox_sequence_v1_ck CHECK (aggregate_version >= 1),
    CONSTRAINT consumer_inbox_payload_v1_ck CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT consumer_inbox_lease_v1_ck CHECK ((lease_token IS NULL) = (lease_expires_at IS NULL)),
    PRIMARY KEY (consumer_name, event_id),
    UNIQUE (entry_id),
    UNIQUE (consumer_name, aggregate_type, aggregate_id, aggregate_version)
);

-- EVT-03; row lock with inbox business transaction.
CREATE TABLE marketplace.consumer_stream_checkpoint (
    consumer_name text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    last_sequence bigint NOT NULL,
    blocked_reason text NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT consumer_stream_checkpoint_last_sequence_v1_ck CHECK (last_sequence >= 0),
    PRIMARY KEY (consumer_name, aggregate_type, aggregate_id)
);

-- EVT-01; allocate contiguous sequence with outbox insert.
CREATE TABLE marketplace.event_stream_sequence (
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    last_sequence bigint NOT NULL,
    version bigint NOT NULL,
    CONSTRAINT event_stream_sequence_last_sequence_v1_ck CHECK (last_sequence >= 0),
    CONSTRAINT event_stream_sequence_version_v1_ck CHECK (version >= 0),
    PRIMARY KEY (aggregate_type, aggregate_id)
);

-- X-07/EVT-03; entry target is polymorphic inbox/outbox. Actor/approval IDs are verified by Commerce contract, no cross-service FK. Commit source retry and job state atomically; complete only after source effect/dedup confirmation.
CREATE TABLE marketplace.event_recovery_job (
    job_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    queue_type text NOT NULL,
    consumer_name text NULL,
    event_id uuid NOT NULL,
    expected_hash text NOT NULL,
    source_version bigint NOT NULL,
    status text NOT NULL,
    request_hash text NOT NULL,
    idempotency_key text NOT NULL,
    requested_by_admin_id uuid NOT NULL,
    approval_id uuid NULL,
    lease_token uuid NULL,
    lease_expires_at timestamptz NULL,
    attempt_count integer NOT NULL,
    next_retry_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    completed_at timestamptz NULL,
    version bigint NOT NULL,
    last_error_code text NULL,
    CONSTRAINT event_recovery_job_expected_hash_v1_ck CHECK (expected_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT event_recovery_job_source_version_v1_ck CHECK (source_version >= 0),
    CONSTRAINT event_recovery_job_request_hash_v1_ck CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT event_recovery_job_attempt_count_v1_ck CHECK (attempt_count >= 0),
    CONSTRAINT event_recovery_job_version_v1_ck CHECK (version >= 0),
    CONSTRAINT event_recovery_job_status_v1_ck CHECK (status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED')),
    CONSTRAINT event_recovery_job_queue_type_v1_ck CHECK (queue_type IN ('OUTBOX', 'INBOX')),
    CONSTRAINT event_recovery_job_target_v1_ck CHECK ((queue_type = 'INBOX' AND consumer_name IS NOT NULL) OR (queue_type = 'OUTBOX' AND consumer_name IS NULL)),
    CONSTRAINT event_recovery_job_terminal_v1_ck CHECK ((status IN ('QUEUED','RUNNING') AND completed_at IS NULL) OR (status IN ('SUCCEEDED','FAILED') AND completed_at IS NOT NULL)),
    PRIMARY KEY (job_id),
    UNIQUE (requested_by_admin_id, entry_id, idempotency_key)
);

-- SET-01; snapshot/projection, no FK to Commerce.
CREATE TABLE marketplace.seller_recognition_unit (
    recognition_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    order_id uuid NOT NULL,
    source_unit_or_charge_id text NOT NULL,
    source_event_id uuid NOT NULL,
    recognized_amount bigint NOT NULL,
    commission_amount bigint NOT NULL,
    reversed_amount bigint NOT NULL,
    reversed_fee_amount bigint NOT NULL,
    CONSTRAINT seller_recognition_amounts_v1_ck CHECK (recognized_amount > 0 AND commission_amount BETWEEN 0 AND recognized_amount AND reversed_amount BETWEEN 0 AND recognized_amount AND reversed_fee_amount BETWEEN 0 AND commission_amount),
    PRIMARY KEY (recognition_id),
    UNIQUE (seller_id, order_id, source_unit_or_charge_id)
);

-- SET-02; signed debt/credit, no duplicate allocation.
CREATE TABLE marketplace.seller_carry_forward (
    carry_forward_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    currency text NOT NULL,
    source_settlement_id uuid NOT NULL,
    signed_amount bigint NOT NULL,
    target_settlement_id uuid NULL,
    source_ledger_ids jsonb NOT NULL,
    status text NOT NULL,
    CONSTRAINT seller_carry_forward_currency_v1_ck CHECK (currency = 'KRW'),
    CONSTRAINT seller_carry_forward_amount_v1_ck CHECK (signed_amount <> 0 AND (target_settlement_id IS NULL OR target_settlement_id <> source_settlement_id)),
    PRIMARY KEY (carry_forward_id),
    UNIQUE (source_settlement_id)
);

-- SET-03; separate adapter transaction, no FK tying bank commit to caller commit.
CREATE TABLE marketplace.simulated_bank_receipt (
    bank_receipt_id uuid NOT NULL,
    idempotency_key text NOT NULL,
    dispatch_permit_id uuid NOT NULL,
    operation_hash text NOT NULL,
    account_snapshot_hash text NOT NULL,
    currency text NOT NULL,
    amount bigint NOT NULL,
    status text NOT NULL,
    occurred_at timestamptz NOT NULL,
    CONSTRAINT simulated_bank_receipt_operation_hash_v1_ck CHECK (operation_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT simulated_bank_receipt_account_snapshot_hash_v1_ck CHECK (account_snapshot_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT simulated_bank_receipt_currency_v1_ck CHECK (currency = 'KRW'),
    CONSTRAINT simulated_bank_receipt_status_v1_ck CHECK (status IN ('SUCCEEDED', 'FAILED')),
    CONSTRAINT simulated_bank_receipt_amount_v1_ck CHECK (amount BETWEEN 1 AND 9007199254740991),
    PRIMARY KEY (bank_receipt_id),
    UNIQUE (idempotency_key)
);

-- MIG-BANK/SET-04; bank payout reconciliation only; fixed snapshot cursor and immutable run inputs.
CREATE TABLE marketplace.bank_reconciliation_run (
    run_id uuid NOT NULL,
    business_date date NOT NULL,
    source_as_of timestamptz NOT NULL,
    algorithm_version text NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    completed_at timestamptz NULL,
    CONSTRAINT bank_reconciliation_run_status_v1_ck CHECK (status IN ('RUNNING', 'SUCCEEDED', 'FAILED')),
    CONSTRAINT bank_reconciliation_run_completed_v1_ck CHECK ((status = 'RUNNING' AND completed_at IS NULL) OR (status IN ('SUCCEEDED','FAILED') AND completed_at IS NOT NULL)),
    PRIMARY KEY (run_id),
    UNIQUE (business_date, source_as_of, algorithm_version)
);

-- MIG-BANK/SET-04; immutable observed bank fact. run_id is FIRST observation; later runs compare without updating original receipt. No FK to internal attempt: external-only receipts must be representable.
CREATE TABLE marketplace.bank_reconciliation_receipt (
    bank_receipt_id uuid NOT NULL,
    run_id uuid NOT NULL,
    idempotency_key text NOT NULL,
    account_snapshot_hash text NOT NULL,
    currency text NOT NULL,
    amount bigint NOT NULL,
    status text NOT NULL,
    occurred_at timestamptz NOT NULL,
    receipt jsonb NOT NULL,
    receipt_hash text NOT NULL,
    CONSTRAINT bank_reconciliation_receipt_account_snapshot_hash_v1_ck CHECK (account_snapshot_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT bank_reconciliation_receipt_receipt_hash_v1_ck CHECK (receipt_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT bank_reconciliation_receipt_currency_v1_ck CHECK (currency = 'KRW'),
    CONSTRAINT bank_reconciliation_receipt_status_v1_ck CHECK (status IN ('SUCCEEDED', 'FAILED')),
    CONSTRAINT bank_reconciliation_receipt_amount_v1_ck CHECK (amount BETWEEN 1 AND 9007199254740991),
    CONSTRAINT bank_reconciliation_receipt_receipt_v1_ck CHECK (receipt IS NULL OR jsonb_typeof(receipt) = 'object'),
    PRIMARY KEY (bank_receipt_id),
    UNIQUE (idempotency_key)
);

-- MIG-BANK/SET-04; deterministic identity excludes run ID, repeat observation reuses discrepancy; approval is external Commerce ID. Legacy reconciliation_* remain read-only.
CREATE TABLE marketplace.bank_reconciliation_discrepancy (
    discrepancy_id uuid NOT NULL,
    run_id uuid NOT NULL,
    identity_key text NOT NULL,
    bank_receipt_id uuid NULL,
    payout_attempt_id uuid NULL,
    kind text NOT NULL,
    status text NOT NULL,
    expected_payload jsonb NOT NULL,
    actual_payload jsonb NOT NULL,
    approval_id uuid NULL,
    resolution_event jsonb NULL,
    recorded_at timestamptz NOT NULL,
    resolved_at timestamptz NULL,
    version bigint NOT NULL,
    CONSTRAINT bank_reconciliation_discrepancy_version_v1_ck CHECK (version >= 0),
    CONSTRAINT bank_reconciliation_discrepancy_kind_v1_ck CHECK (kind IN ('PROVIDER_ONLY', 'INTERNAL_ONLY', 'AMOUNT_MISMATCH', 'STATUS_MISMATCH', 'DUPLICATE')),
    CONSTRAINT bank_reconciliation_discrepancy_status_v1_ck CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'ACCEPTED', 'FALSE_POSITIVE')),
    CONSTRAINT bank_discrepancy_resolution_v1_ck CHECK ((status IN ('OPEN','INVESTIGATING') AND resolved_at IS NULL AND resolution_event IS NULL) OR (status IN ('RESOLVED','ACCEPTED','FALSE_POSITIVE') AND resolved_at IS NOT NULL AND approval_id IS NOT NULL AND resolution_event IS NOT NULL AND jsonb_typeof(resolution_event) = 'object')),
    CONSTRAINT bank_reconciliation_discrepancy_expected_payload_v1_ck CHECK (expected_payload IS NULL OR jsonb_typeof(expected_payload) = 'object'),
    CONSTRAINT bank_reconciliation_discrepancy_actual_payload_v1_ck CHECK (actual_payload IS NULL OR jsonb_typeof(actual_payload) = 'object'),
    CONSTRAINT bank_reconciliation_discrepancy_resolution_event_v1_ck CHECK (resolution_event IS NULL OR jsonb_typeof(resolution_event) = 'object'),
    PRIMARY KEY (discrepancy_id),
    UNIQUE (identity_key)
);

ALTER TABLE marketplace.settlement_allocation ADD CONSTRAINT fk_settlement_allocation_settlement FOREIGN KEY (settlement_id) REFERENCES marketplace.settlement (settlement_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.settlement_allocation ADD CONSTRAINT fk_settlement_allocation_ledger FOREIGN KEY (seller_ledger_entry_id) REFERENCES marketplace.seller_ledger_entry (seller_ledger_entry_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.settlement_payout_attempt ADD CONSTRAINT fk_payout_attempt_settlement FOREIGN KEY (settlement_id) REFERENCES marketplace.settlement (settlement_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_raw_row ADD CONSTRAINT fk_reconciliation_raw_file FOREIGN KEY (reconciliation_file_id) REFERENCES marketplace.reconciliation_file (reconciliation_file_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_ledger_entry ADD CONSTRAINT fk_seller_ledger_reversal FOREIGN KEY (reversal_of_entry_id) REFERENCES marketplace.seller_ledger_entry (seller_ledger_entry_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_run ADD CONSTRAINT fk_reconciliation_run_replay FOREIGN KEY (replay_of_run_id) REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_match ADD CONSTRAINT fk_reconciliation_match_run FOREIGN KEY (reconciliation_run_id) REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_match ADD CONSTRAINT fk_reconciliation_match_raw_row FOREIGN KEY (raw_row_id) REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_run FOREIGN KEY (reconciliation_run_id) REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_raw_row FOREIGN KEY (raw_row_id) REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_predecessor FOREIGN KEY (supersedes_discrepancy_id) REFERENCES marketplace.reconciliation_discrepancy (discrepancy_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_run FOREIGN KEY (reconciliation_run_id) REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_payout FOREIGN KEY (payout_attempt_id) REFERENCES marketplace.settlement_payout_attempt (payout_attempt_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_raw_row FOREIGN KEY (raw_row_id) REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_carry_forward ADD CONSTRAINT seller_carry_forward_source_settlement_id_planned_fk FOREIGN KEY (source_settlement_id) REFERENCES marketplace.settlement (settlement_id);
ALTER TABLE marketplace.seller_carry_forward ADD CONSTRAINT seller_carry_forward_target_settlement_id_planned_fk FOREIGN KEY (target_settlement_id) REFERENCES marketplace.settlement (settlement_id);
ALTER TABLE marketplace.bank_reconciliation_receipt ADD CONSTRAINT bank_reconciliation_receipt_run_id_planned_fk FOREIGN KEY (run_id) REFERENCES marketplace.bank_reconciliation_run (run_id);
ALTER TABLE marketplace.bank_reconciliation_discrepancy ADD CONSTRAINT bank_reconciliation_discrepancy_run_id_planned_fk FOREIGN KEY (run_id) REFERENCES marketplace.bank_reconciliation_run (run_id);
ALTER TABLE marketplace.bank_reconciliation_discrepancy ADD CONSTRAINT bank_reconciliation_discrepancy_bank_receipt_id_planned_fk FOREIGN KEY (bank_receipt_id) REFERENCES marketplace.bank_reconciliation_receipt (bank_receipt_id);
ALTER TABLE marketplace.bank_reconciliation_discrepancy ADD CONSTRAINT bank_reconciliation_discrepancy_payout_attempt_id_planned_fk FOREIGN KEY (payout_attempt_id) REFERENCES marketplace.settlement_payout_attempt (payout_attempt_id);
CREATE INDEX ix_seller_ledger_due
    ON marketplace.seller_ledger_entry (seller_id, currency, due_date, recognized_at)
    INCLUDE (signed_amount, entry_type);
CREATE INDEX ix_seller_ledger_source
    ON marketplace.seller_ledger_entry (source_type, source_id)
    WHERE source_id IS NOT NULL;
CREATE INDEX ix_seller_ledger_reversal_v1 ON marketplace.seller_ledger_entry (reversal_of_entry_id, seller_ledger_entry_id) WHERE reversal_of_entry_id IS NOT NULL;
CREATE INDEX ix_settlement_work_queue
    ON marketplace.settlement (status, period_end, seller_id)
    INCLUDE (currency, net_amount, payout_amount)
    WHERE status IN ('CALCULATED', 'APPROVAL_PENDING', 'APPROVED', 'PAYOUT_PENDING', 'FAILED');
CREATE UNIQUE INDEX uq_settlement_one_approved_version
    ON marketplace.settlement (seller_id, period_start, period_end, currency)
    WHERE status IN ('APPROVED', 'PAYOUT_PENDING');
CREATE INDEX ix_settlement_allocation_ledger
    ON marketplace.settlement_allocation (seller_ledger_entry_id, settlement_id)
    INCLUDE (allocated_amount);
CREATE INDEX ix_settlement_hold_active_due
    ON marketplace.settlement_hold (seller_id, release_due_at, held_at)
    INCLUDE (amount, currency, reason_code)
    WHERE status = 'ACTIVE';
CREATE INDEX ix_settlement_hold_claim
    ON marketplace.settlement_hold (claim_id, status)
    WHERE claim_id IS NOT NULL;
CREATE INDEX ix_payout_attempt_work_queue
    ON marketplace.settlement_payout_attempt (status, requested_at)
    INCLUDE (settlement_id, amount, currency, attempt_no)
    WHERE status IN ('REQUESTED', 'PROCESSING', 'UNKNOWN', 'FAILED');
CREATE INDEX ix_reconciliation_file_business_date
    ON marketplace.reconciliation_file (provider, file_type, business_date DESC);
CREATE INDEX ix_reconciliation_raw_provider_tx
    ON marketplace.reconciliation_raw_row (provider_tx_id, occurred_at)
    INCLUDE (gross_amount, fee_amount, net_amount, currency)
    WHERE provider_tx_id IS NOT NULL;
CREATE INDEX ix_reconciliation_raw_occurred_brin
    ON marketplace.reconciliation_raw_row USING brin (occurred_at)
    WITH (pages_per_range = 64);
CREATE INDEX ix_reconciliation_run_work_queue
    ON marketplace.reconciliation_run (status, started_at)
    INCLUDE (run_type, business_date_from, business_date_to, algorithm_version)
    WHERE status IN ('RUNNING', 'FAILED');
CREATE INDEX ix_reconciliation_run_replay
    ON marketplace.reconciliation_run (replay_of_run_id, started_at)
    WHERE replay_of_run_id IS NOT NULL;
CREATE INDEX ix_reconciliation_match_raw_row
    ON marketplace.reconciliation_match (raw_row_id, reconciliation_run_id)
    INCLUDE (payment_transaction_id, matched_amount);
CREATE INDEX ix_reconciliation_match_payment_tx
    ON marketplace.reconciliation_match (payment_transaction_id, reconciliation_run_id)
    INCLUDE (raw_row_id, matched_amount);
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
CREATE INDEX ix_bank_deposit_match_payout
    ON marketplace.bank_deposit_match (payout_attempt_id, reconciliation_run_id)
    INCLUDE (matched_amount, currency, status);
CREATE INDEX ix_bank_deposit_match_raw
    ON marketplace.bank_deposit_match (raw_row_id, reconciliation_run_id)
    INCLUDE (payout_attempt_id, matched_amount, status);
CREATE INDEX outbox_event_publish_worker_idx
    ON marketplace.outbox_event (available_at, occurred_at, outbox_event_id)
    WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX outbox_event_stale_lock_idx
    ON marketplace.outbox_event (locked_at, outbox_event_id)
    WHERE status = 'PUBLISHING';
CREATE INDEX outbox_event_aggregate_timeline_idx
    ON marketplace.outbox_event (aggregate_type, aggregate_id, occurred_at, outbox_event_id);
CREATE UNIQUE INDEX uq_outbox_stream_sequence_v1 ON marketplace.outbox_event (aggregate_type, aggregate_id, aggregate_version);
CREATE INDEX ix_outbox_due_v1 ON marketplace.outbox_event (available_at, outbox_event_id) WHERE status IN ('PENDING','FAILED');
CREATE INDEX ix_outbox_lease_v1 ON marketplace.outbox_event (lease_expires_at, outbox_event_id) WHERE status = 'PUBLISHING';
CREATE INDEX ix_consumer_inbox_due_v1 ON marketplace.consumer_inbox (status, next_retry_at, entry_id);
CREATE INDEX ix_consumer_inbox_lease_v1 ON marketplace.consumer_inbox (lease_expires_at, entry_id) WHERE lease_expires_at IS NOT NULL;
CREATE INDEX ix_event_recovery_job_due_v1 ON marketplace.event_recovery_job (status, next_retry_at, job_id) WHERE status IN ('QUEUED','RUNNING');
CREATE INDEX ix_event_recovery_job_source_v1 ON marketplace.event_recovery_job (entry_id, created_at, job_id);
CREATE INDEX ix_simulated_bank_receipt_cursor_v1 ON marketplace.simulated_bank_receipt (occurred_at, bank_receipt_id);
CREATE INDEX ix_bank_reconciliation_run_due_v1 ON marketplace.bank_reconciliation_run (status, business_date, run_id);
CREATE INDEX ix_bank_reconciliation_receipt_cursor_v1 ON marketplace.bank_reconciliation_receipt (occurred_at, bank_receipt_id);
CREATE INDEX ix_bank_discrepancy_open_v1 ON marketplace.bank_reconciliation_discrepancy (recorded_at, discrepancy_id) WHERE status IN ('OPEN','INVESTIGATING');
CREATE INDEX ix_bank_discrepancy_run_v1 ON marketplace.bank_reconciliation_discrepancy (run_id, status, discrepancy_id);
CREATE INDEX ix_bank_discrepancy_payout_v1 ON marketplace.bank_reconciliation_discrepancy (payout_attempt_id) WHERE payout_attempt_id IS NOT NULL;
COMMIT;
