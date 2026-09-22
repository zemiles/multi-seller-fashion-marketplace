-- payment-service: empty isolated database schema snapshot.
-- NOT an upgrade migration. NEVER apply to an existing/production database.
-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.
-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.
BEGIN;
CREATE SCHEMA IF NOT EXISTS marketplace;

--  PAY-01; complete snapshot remains request_payload.
CREATE TABLE marketplace.payment_attempt (
    payment_attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL,
    order_id uuid NOT NULL,
    provider text NOT NULL,
    merchant_tx_id text NOT NULL,
    idempotency_key text NOT NULL,
    payment_method text NOT NULL,
    status text NOT NULL DEFAULT 'CREATED',
    currency varchar(3) NOT NULL,
    requested_amount bigint NOT NULL,
    request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    provider_response jsonb,
    error_code text,
    error_message text,
    requested_at timestamptz,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    payment_request_id uuid NOT NULL,
    request_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    pricing_policy_version text NOT NULL,
    CONSTRAINT payment_attempt_merchant_tx_uq UNIQUE (provider, merchant_tx_id),
    CONSTRAINT payment_attempt_idempotency_uq UNIQUE (provider, idempotency_key),
    CONSTRAINT payment_attempt_status_ck CHECK (status IN ('CREATED', 'REQUESTED', 'PENDING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED')),
    CONSTRAINT payment_attempt_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payment_attempt_amount_ck CHECK (requested_amount > 0),
    CONSTRAINT payment_attempt_request_payload_ck CHECK (jsonb_typeof(request_payload) = 'object'),
    CONSTRAINT payment_attempt_response_ck CHECK (provider_response IS NULL OR jsonb_typeof(provider_response) = 'object'),
    CONSTRAINT payment_attempt_times_ck CHECK (
        (requested_at IS NULL OR requested_at >= created_at)
        AND (resolved_at IS NULL OR resolved_at >= COALESCE(requested_at, created_at))
    ),
    CONSTRAINT payment_attempt_updated_at_ck CHECK (updated_at >= created_at),
    CONSTRAINT payment_attempt_request_hash_v1_ck CHECK (request_hash ~ '^[0-9a-f]{64}$')
);

--  PAY-04; VOID does not increment refunded_amount.
CREATE TABLE marketplace.payment (
    payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_attempt_id uuid NOT NULL,
    order_id uuid NOT NULL,
    provider text NOT NULL,
    provider_payment_key text NOT NULL,
    payment_method text NOT NULL,
    status text NOT NULL DEFAULT 'APPROVED',
    currency varchar(3) NOT NULL,
    total_payment_amount bigint NOT NULL,
    refunded_amount bigint NOT NULL DEFAULT 0,
    approved_at timestamptz NOT NULL,
    version bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    voided_amount bigint NOT NULL,
    CONSTRAINT payment_attempt_uq UNIQUE (payment_attempt_id),
    CONSTRAINT payment_provider_key_uq UNIQUE (provider, provider_payment_key),
    CONSTRAINT payment_status_ck CHECK (status IN ('APPROVED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'VOIDED', 'CHARGEBACK')),
    CONSTRAINT payment_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payment_amounts_ck CHECK (
        total_payment_amount > 0
        AND refunded_amount >= 0
        AND refunded_amount <= total_payment_amount
    ),
    CONSTRAINT payment_version_ck CHECK (version >= 0),
    CONSTRAINT payment_approved_at_ck CHECK (approved_at <= updated_at),
    CONSTRAINT payment_updated_at_ck CHECK (updated_at >= created_at),
    CONSTRAINT payment_version_v1_ck CHECK (version >= 0),
    CONSTRAINT payment_voided_balance_v1_ck CHECK (currency = 'KRW' AND total_payment_amount <= 100000000 AND voided_amount >= 0 AND refunded_amount + voided_amount <= total_payment_amount AND ((status = 'VOIDED' AND voided_amount = total_payment_amount AND refunded_amount = 0) OR (status <> 'VOIDED' AND voided_amount = 0)))
);

CREATE TABLE marketplace.payment_item (
    payment_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    quantity integer NOT NULL,
    product_amount bigint NOT NULL,
    discount_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    paid_amount bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_item_order_item_uq UNIQUE (payment_id, order_item_id),
    CONSTRAINT payment_item_quantity_ck CHECK (quantity > 0),
    CONSTRAINT payment_item_amounts_ck CHECK (
        product_amount >= 0
        AND discount_amount >= 0
        AND discount_amount <= product_amount
        AND tax_amount >= 0
        AND paid_amount = product_amount - discount_amount + tax_amount
        AND paid_amount > 0
    )
);

CREATE TABLE marketplace.payment_charge_allocation (
    payment_charge_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid NOT NULL,
    order_charge_id uuid NOT NULL,
    amount bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_charge_allocation_uq UNIQUE (payment_id, order_charge_id),
    CONSTRAINT payment_charge_allocation_amount_ck CHECK (amount > 0)
);

CREATE TABLE marketplace.payment_transaction (
    payment_transaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid NOT NULL,
    original_transaction_id uuid,
    provider text NOT NULL,
    provider_tx_id text NOT NULL,
    idempotency_key text NOT NULL,
    transaction_type text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    currency varchar(3) NOT NULL,
    amount bigint NOT NULL,
    provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_transaction_provider_tx_uq UNIQUE (provider, provider_tx_id),
    CONSTRAINT payment_transaction_idempotency_uq UNIQUE (payment_id, idempotency_key),
    CONSTRAINT payment_transaction_type_ck CHECK (transaction_type IN ('AUTHORIZE', 'CAPTURE', 'SALE', 'VOID', 'REFUND', 'CHARGEBACK', 'REVERSAL')),
    CONSTRAINT payment_transaction_status_ck CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED')),
    CONSTRAINT payment_transaction_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payment_transaction_amount_ck CHECK (amount > 0),
    CONSTRAINT payment_transaction_payload_ck CHECK (jsonb_typeof(provider_payload) = 'object'),
    CONSTRAINT payment_transaction_original_ck CHECK (original_transaction_id IS NULL OR original_transaction_id <> payment_transaction_id),
    CONSTRAINT payment_transaction_times_ck CHECK (
        completed_at IS NULL
        OR occurred_at IS NULL
        OR completed_at >= occurred_at
    )
);

CREATE TABLE marketplace.payment_transaction_allocation (
    transaction_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id uuid NOT NULL,
    payment_item_id uuid,
    payment_charge_allocation_id uuid,
    claim_item_id uuid,
    amount bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_transaction_item_allocation_uq UNIQUE (payment_transaction_id, payment_item_id),
    CONSTRAINT payment_transaction_charge_allocation_uq UNIQUE (payment_transaction_id, payment_charge_allocation_id),
    CONSTRAINT payment_transaction_allocation_target_ck CHECK (num_nonnulls(payment_item_id, payment_charge_allocation_id) = 1),
    CONSTRAINT payment_transaction_allocation_amount_ck CHECK (amount > 0)
);

--  PAY-04; claimId or compensationId mandatory, approval for manual adjustment.
CREATE TABLE marketplace.refund (
    refund_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid NOT NULL,
    claim_id uuid,
    idempotency_key text NOT NULL,
    status text NOT NULL DEFAULT 'REQUESTED',
    currency varchar(3) NOT NULL,
    requested_amount bigint NOT NULL,
    actual_refunded_amount bigint NOT NULL DEFAULT 0,
    reason_code text NOT NULL,
    reason_detail text,
    requested_by_type text NOT NULL,
    requested_by_id uuid,
    requested_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    compensation_id uuid NULL,
    approval_id uuid NULL,
    request_hash text NOT NULL,
    CONSTRAINT refund_idempotency_uq UNIQUE (payment_id, idempotency_key),
    CONSTRAINT refund_status_ck CHECK (status IN ('REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'UNKNOWN', 'CANCELLED')),
    CONSTRAINT refund_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT refund_amounts_ck CHECK (
        requested_amount > 0
        AND actual_refunded_amount >= 0
        AND actual_refunded_amount <= requested_amount
    ),
    CONSTRAINT refund_requester_type_ck CHECK (requested_by_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM')),
    CONSTRAINT refund_completed_at_ck CHECK (completed_at IS NULL OR completed_at >= requested_at),
    CONSTRAINT refund_updated_at_ck CHECK (updated_at >= created_at),
    CONSTRAINT refund_request_hash_v1_ck CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT refund_source_v1_ck CHECK (claim_id IS NOT NULL OR compensation_id IS NOT NULL),
    CONSTRAINT refund_requester_v1_ck CHECK (requested_by_type = 'SYSTEM' OR requested_by_id IS NOT NULL),
    CONSTRAINT refund_limit_v1_ck CHECK (currency = 'KRW' AND requested_amount <= 100000000 AND (status <> 'SUCCEEDED' OR actual_refunded_amount = requested_amount))
);

CREATE TABLE marketplace.refund_item (
    refund_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    refund_id uuid NOT NULL,
    payment_item_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    claim_item_id uuid,
    quantity integer NOT NULL,
    product_refund_amount bigint NOT NULL,
    discount_reversal_amount bigint NOT NULL DEFAULT 0,
    tax_refund_amount bigint NOT NULL DEFAULT 0,
    refund_amount bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT refund_item_payment_item_uq UNIQUE (refund_id, payment_item_id),
    CONSTRAINT refund_item_quantity_ck CHECK (quantity > 0),
    CONSTRAINT refund_item_amounts_ck CHECK (
        product_refund_amount >= 0
        AND discount_reversal_amount >= 0
        AND discount_reversal_amount <= product_refund_amount
        AND tax_refund_amount >= 0
        AND refund_amount = product_refund_amount - discount_reversal_amount + tax_refund_amount
        AND refund_amount >= 0
    )
);

CREATE TABLE marketplace.refund_charge_adjustment (
    adjustment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    refund_id uuid NOT NULL,
    order_charge_id uuid NOT NULL,
    payment_charge_allocation_id uuid,
    adjustment_type text NOT NULL,
    amount bigint NOT NULL,
    reason_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT refund_charge_adjustment_uq UNIQUE (refund_id, order_charge_id, adjustment_type),
    CONSTRAINT refund_charge_adjustment_type_ck CHECK (adjustment_type IN ('REFUND', 'RECHARGE', 'WAIVER')),
    CONSTRAINT refund_charge_adjustment_amount_ck CHECK (amount > 0),
    CONSTRAINT refund_charge_adjustment_source_ck CHECK (
        adjustment_type <> 'REFUND' OR payment_charge_allocation_id IS NOT NULL
    )
);

CREATE TABLE marketplace.pg_webhook_inbox (
    inbox_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_attempt_id uuid,
    provider text NOT NULL,
    provider_event_id text NOT NULL,
    event_type text NOT NULL,
    merchant_tx_id text,
    payload_hash text NOT NULL,
    headers jsonb NOT NULL DEFAULT '{}'::jsonb,
    payload jsonb NOT NULL,
    raw_body text NOT NULL,
    status text NOT NULL DEFAULT 'RECEIVED',
    attempt_count integer NOT NULL DEFAULT 0,
    received_at timestamptz NOT NULL DEFAULT now(),
    processing_started_at timestamptz,
    processed_at timestamptz,
    next_attempt_at timestamptz,
    last_error text,
    CONSTRAINT pg_webhook_provider_event_uq UNIQUE (provider, provider_event_id),
    CONSTRAINT pg_webhook_status_ck CHECK (status IN ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'DEAD')),
    CONSTRAINT pg_webhook_payload_hash_ck CHECK (payload_hash ~ '^[0-9A-Fa-f]{64}$'),
    CONSTRAINT pg_webhook_headers_ck CHECK (jsonb_typeof(headers) = 'object'),
    CONSTRAINT pg_webhook_payload_ck CHECK (jsonb_typeof(payload) IN ('object', 'array')),
    CONSTRAINT pg_webhook_attempt_count_ck CHECK (attempt_count >= 0),
    CONSTRAINT pg_webhook_times_ck CHECK (
        (processing_started_at IS NULL OR processing_started_at >= received_at)
        AND (processed_at IS NULL OR processed_at >= COALESCE(processing_started_at, received_at))
        AND (next_attempt_at IS NULL OR next_attempt_at >= received_at)
    )
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

-- PAY-01/03; CLOSED tombstone even before prepare; order_id external Commerce ID.
CREATE TABLE marketplace.order_payment_guard (
    order_id uuid NOT NULL,
    gate text NOT NULL,
    active_attempt_id uuid NULL,
    successful_payment_id uuid NULL,
    version bigint NOT NULL,
    closed_reason text NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT order_payment_guard_version_v1_ck CHECK (version >= 0),
    CONSTRAINT order_payment_guard_gate_v1_ck CHECK (gate IN ('OPEN', 'CLOSED')),
    PRIMARY KEY (order_id)
);

-- PAY-04; partial unique active dispatch per payment; due(status,next_retry_at). Payload may contain operation-local safe evidence only.
CREATE TABLE marketplace.payment_operation (
    operation_id uuid NOT NULL,
    order_id uuid NOT NULL,
    payment_attempt_id uuid NULL,
    payment_id uuid NULL,
    refund_id uuid NULL,
    kind text NOT NULL,
    status text NOT NULL,
    idempotency_key text NOT NULL,
    request_hash text NOT NULL,
    request_payload jsonb NOT NULL,
    result_version bigint NOT NULL,
    result_payload jsonb NOT NULL,
    provider text NOT NULL,
    merchant_tx_id text NOT NULL,
    lease_token uuid NULL,
    lease_version bigint NOT NULL,
    lease_expires_at timestamptz NULL,
    next_retry_at timestamptz NOT NULL,
    first_unknown_at timestamptz NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT payment_operation_request_hash_v1_ck CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT payment_operation_result_version_v1_ck CHECK (result_version >= 0),
    CONSTRAINT payment_operation_lease_version_v1_ck CHECK (lease_version >= 0),
    CONSTRAINT payment_operation_kind_v1_ck CHECK (kind IN ('APPROVE', 'CANCEL', 'REFUND')),
    CONSTRAINT payment_operation_status_v1_ck CHECK (status IN ('REQUESTED', 'PROCESSING', 'PENDING', 'UNKNOWN', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    PRIMARY KEY (operation_id),
    UNIQUE (provider, kind, merchant_tx_id, idempotency_key)
);

-- PAY-02; immutable result, response and event reference identical version.
CREATE TABLE marketplace.payment_operation_result (
    operation_id uuid NOT NULL,
    result_version bigint NOT NULL,
    immutable_result jsonb NOT NULL,
    evidence_hash text NOT NULL,
    occurred_at timestamptz NOT NULL,
    CONSTRAINT payment_operation_result_result_version_v1_ck CHECK (result_version >= 0),
    CONSTRAINT payment_operation_result_evidence_hash_v1_ck CHECK (evidence_hash ~ '^[0-9a-f]{64}$'),
    PRIMARY KEY (operation_id, result_version)
);

-- PAY-04; order_item/unit external IDs validated against attempt snapshot; active/terminal successful unit reservation guard in owner transaction.
CREATE TABLE marketplace.refund_unit_allocation (
    refund_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    unit_ordinal integer NOT NULL,
    amount bigint NOT NULL,
    CONSTRAINT refund_unit_allocation_amount_v1_ck CHECK (unit_ordinal BETWEEN 1 AND 99 AND amount BETWEEN 1 AND 100000000),
    PRIMARY KEY (refund_id, order_item_id, unit_ordinal)
);

-- PAY-06; Payment owns PG reconciliation.
CREATE TABLE marketplace.pg_reconciliation_run (
    run_id uuid NOT NULL,
    provider text NOT NULL,
    business_date date NOT NULL,
    source_as_of timestamptz NOT NULL,
    algorithm_version text NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (run_id),
    UNIQUE (provider, business_date, source_as_of, algorithm_version)
);

-- PAY-06; immutable receipt; a later run can re-observe without inserting a second receipt.
CREATE TABLE marketplace.pg_reconciliation_receipt (
    provider text NOT NULL,
    provider_transaction_id uuid NOT NULL,
    run_id uuid NOT NULL,
    receipt jsonb NOT NULL,
    receipt_hash text NOT NULL,
    CONSTRAINT pg_reconciliation_receipt_receipt_hash_v1_ck CHECK (receipt_hash ~ '^[0-9a-f]{64}$'),
    PRIMARY KEY (provider, provider_transaction_id)
);

-- PAY-06; approval_id external Commerce identity.
CREATE TABLE marketplace.pg_reconciliation_discrepancy (
    discrepancy_id uuid NOT NULL,
    run_id uuid NOT NULL,
    identity_key text NOT NULL,
    kind text NOT NULL,
    status text NOT NULL,
    expected_payload jsonb NOT NULL,
    actual_payload jsonb NOT NULL,
    approval_id uuid NULL,
    resolved_at timestamptz NULL,
    PRIMARY KEY (discrepancy_id),
    UNIQUE (identity_key)
);

ALTER TABLE marketplace.payment_transaction ADD CONSTRAINT payment_transaction_payment_fk FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_transaction ADD CONSTRAINT payment_transaction_original_fk FOREIGN KEY (original_transaction_id) REFERENCES marketplace.payment_transaction (payment_transaction_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.pg_webhook_inbox ADD CONSTRAINT pg_webhook_inbox_payment_attempt_fk FOREIGN KEY (payment_attempt_id) REFERENCES marketplace.payment_attempt (payment_attempt_id) ON DELETE SET NULL;
ALTER TABLE marketplace.payment ADD CONSTRAINT payment_attempt_fk FOREIGN KEY (payment_attempt_id) REFERENCES marketplace.payment_attempt (payment_attempt_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_item ADD CONSTRAINT payment_item_payment_fk FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_charge_allocation ADD CONSTRAINT payment_charge_allocation_payment_fk FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_transaction_fk FOREIGN KEY (payment_transaction_id) REFERENCES marketplace.payment_transaction (payment_transaction_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_item_fk FOREIGN KEY (payment_item_id) REFERENCES marketplace.payment_item (payment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_charge_fk FOREIGN KEY (payment_charge_allocation_id) REFERENCES marketplace.payment_charge_allocation (payment_charge_allocation_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.refund ADD CONSTRAINT refund_payment_fk FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.refund_item ADD CONSTRAINT refund_item_refund_fk FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.refund_item ADD CONSTRAINT refund_item_payment_item_fk FOREIGN KEY (payment_item_id) REFERENCES marketplace.payment_item (payment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.refund_charge_adjustment ADD CONSTRAINT refund_charge_adjustment_refund_fk FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.refund_charge_adjustment ADD CONSTRAINT refund_charge_adjustment_payment_charge_fk FOREIGN KEY (payment_charge_allocation_id) REFERENCES marketplace.payment_charge_allocation (payment_charge_allocation_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_payment_guard ADD CONSTRAINT order_payment_guard_active_attempt_id_planned_fk FOREIGN KEY (active_attempt_id) REFERENCES marketplace.payment_attempt (payment_attempt_id);
ALTER TABLE marketplace.order_payment_guard ADD CONSTRAINT order_payment_guard_successful_payment_id_planned_fk FOREIGN KEY (successful_payment_id) REFERENCES marketplace.payment (payment_id);
ALTER TABLE marketplace.payment_operation ADD CONSTRAINT payment_operation_payment_attempt_id_planned_fk FOREIGN KEY (payment_attempt_id) REFERENCES marketplace.payment_attempt (payment_attempt_id);
ALTER TABLE marketplace.payment_operation ADD CONSTRAINT payment_operation_payment_id_planned_fk FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id);
ALTER TABLE marketplace.payment_operation ADD CONSTRAINT payment_operation_refund_id_planned_fk FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id);
ALTER TABLE marketplace.payment_operation_result ADD CONSTRAINT payment_operation_result_operation_id_planned_fk FOREIGN KEY (operation_id) REFERENCES marketplace.payment_operation (operation_id);
ALTER TABLE marketplace.refund_unit_allocation ADD CONSTRAINT refund_unit_allocation_refund_id_planned_fk FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id);
ALTER TABLE marketplace.pg_reconciliation_receipt ADD CONSTRAINT pg_reconciliation_receipt_run_id_planned_fk FOREIGN KEY (run_id) REFERENCES marketplace.pg_reconciliation_run (run_id);
ALTER TABLE marketplace.pg_reconciliation_discrepancy ADD CONSTRAINT pg_reconciliation_discrepancy_run_id_planned_fk FOREIGN KEY (run_id) REFERENCES marketplace.pg_reconciliation_run (run_id);
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
CREATE INDEX payment_order_status_idx
    ON marketplace.payment (order_id, status, approved_at DESC);
CREATE INDEX payment_item_order_item_idx
    ON marketplace.payment_item (order_item_id, payment_id);
CREATE INDEX payment_charge_allocation_order_charge_idx
    ON marketplace.payment_charge_allocation (order_charge_id, payment_id);
CREATE INDEX payment_transaction_timeline_idx
    ON marketplace.payment_transaction (payment_id, created_at DESC, payment_transaction_id);
CREATE INDEX payment_transaction_original_idx
    ON marketplace.payment_transaction (original_transaction_id)
    WHERE original_transaction_id IS NOT NULL;
CREATE INDEX payment_transaction_recovery_idx
    ON marketplace.payment_transaction (provider, created_at, payment_transaction_id)
    WHERE status IN ('PENDING', 'UNKNOWN');
CREATE INDEX payment_transaction_allocation_item_idx
    ON marketplace.payment_transaction_allocation (payment_item_id, payment_transaction_id)
    WHERE payment_item_id IS NOT NULL;
CREATE INDEX payment_transaction_allocation_charge_idx
    ON marketplace.payment_transaction_allocation (payment_charge_allocation_id, payment_transaction_id)
    WHERE payment_charge_allocation_id IS NOT NULL;
CREATE INDEX payment_transaction_allocation_claim_item_idx
    ON marketplace.payment_transaction_allocation (claim_item_id, payment_transaction_id)
    WHERE claim_item_id IS NOT NULL;
CREATE INDEX refund_claim_idx
    ON marketplace.refund (claim_id, requested_at DESC)
    WHERE claim_id IS NOT NULL;
CREATE INDEX refund_processing_queue_idx
    ON marketplace.refund (status, updated_at, refund_id)
    WHERE status IN ('REQUESTED', 'PROCESSING', 'UNKNOWN');
CREATE INDEX refund_item_payment_item_idx
    ON marketplace.refund_item (payment_item_id, refund_id);
CREATE INDEX refund_item_order_item_idx
    ON marketplace.refund_item (order_item_id, refund_id);
CREATE INDEX refund_item_claim_item_idx
    ON marketplace.refund_item (claim_item_id, refund_id)
    WHERE claim_item_id IS NOT NULL;
CREATE INDEX refund_charge_adjustment_order_charge_idx
    ON marketplace.refund_charge_adjustment (order_charge_id, refund_id);
CREATE INDEX refund_charge_adjustment_payment_charge_idx
    ON marketplace.refund_charge_adjustment (payment_charge_allocation_id, refund_id)
    WHERE payment_charge_allocation_id IS NOT NULL;
CREATE INDEX pg_webhook_inbox_attempt_idx
    ON marketplace.pg_webhook_inbox (payment_attempt_id, received_at DESC)
    WHERE payment_attempt_id IS NOT NULL;
CREATE INDEX pg_webhook_inbox_merchant_tx_idx
    ON marketplace.pg_webhook_inbox (provider, merchant_tx_id, received_at DESC)
    WHERE merchant_tx_id IS NOT NULL;
CREATE INDEX pg_webhook_inbox_worker_idx
    ON marketplace.pg_webhook_inbox (COALESCE(next_attempt_at, received_at), received_at, inbox_id)
    WHERE status IN ('RECEIVED', 'FAILED');
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
CREATE UNIQUE INDEX uq_payment_operation_dispatch_v1 ON marketplace.payment_operation (payment_id) WHERE payment_id IS NOT NULL AND status IN ('PROCESSING','PENDING','UNKNOWN');
CREATE INDEX ix_payment_operation_due_v1 ON marketplace.payment_operation (status, next_retry_at, operation_id);
CREATE INDEX ix_payment_operation_lease_v1 ON marketplace.payment_operation (lease_expires_at, operation_id) WHERE lease_expires_at IS NOT NULL;
COMMIT;
