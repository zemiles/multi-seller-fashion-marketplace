-- pg-kakao-simulator: empty isolated database schema snapshot.
-- NOT an upgrade migration. NEVER apply to an existing/production database.
-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.
-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.
BEGIN;
CREATE SCHEMA IF NOT EXISTS pgkakao;

CREATE TABLE pgkakao.pg_payment (
    payment_id uuid PRIMARY KEY,
    merchant_tx_id text NOT NULL UNIQUE,
    currency varchar(3) NOT NULL,
    amount bigint NOT NULL,
    status text NOT NULL DEFAULT 'APPROVED',
    refunded_amount bigint NOT NULL DEFAULT 0,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT pg_payment_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT pg_payment_amount_ck CHECK (amount > 0),
    CONSTRAINT pg_payment_refund_ck CHECK (refunded_amount >= 0 AND refunded_amount <= amount),
    CONSTRAINT pg_payment_status_ck CHECK (status IN ('APPROVED','PARTIALLY_REFUNDED','REFUNDED','CANCELLED'))
);

CREATE TABLE pgkakao.pg_transaction (
    transaction_id uuid PRIMARY KEY,
    payment_id uuid NOT NULL,
    transaction_type text NOT NULL,
    amount bigint NOT NULL,
    status text NOT NULL,
    idempotency_key text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT pg_transaction_type_ck CHECK (transaction_type IN ('APPROVE','CANCEL','REFUND')),
    CONSTRAINT pg_transaction_amount_ck CHECK (amount > 0),
    CONSTRAINT pg_transaction_status_ck CHECK (status IN ('SUCCEEDED','FAILED')),
    CONSTRAINT pg_transaction_idempotency_uq UNIQUE (payment_id, transaction_type, idempotency_key)
);

-- PG-03; transaction commit and webhook row atomic; timestamp/signature refreshed on retry.
CREATE TABLE pgkakao.pg_webhook_outbox (
    event_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    body jsonb NOT NULL,
    body_hash text NOT NULL,
    status text NOT NULL,
    attempt_count integer NOT NULL,
    next_retry_at timestamptz NOT NULL,
    lease_expires_at timestamptz NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT pg_webhook_outbox_body_hash_v1_ck CHECK (body_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT pg_webhook_outbox_attempt_count_v1_ck CHECK (attempt_count >= 0),
    PRIMARY KEY (event_id)
);

-- PG-02; local/stage only; fail closed in prod profile.
CREATE TABLE pgkakao.pg_fault_scenario (
    scenario_id uuid NOT NULL,
    scenario_type text NOT NULL,
    remaining_uses integer NOT NULL,
    delay_ms integer NOT NULL,
    expires_at timestamptz NOT NULL,
    enabled boolean NOT NULL,
    PRIMARY KEY (scenario_id)
);

ALTER TABLE pgkakao.pg_transaction ADD CONSTRAINT pg_transaction_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES pgkakao.pg_payment (payment_id);
ALTER TABLE pgkakao.pg_webhook_outbox ADD CONSTRAINT pg_webhook_outbox_transaction_id_planned_fk FOREIGN KEY (transaction_id) REFERENCES pgkakao.pg_transaction (transaction_id);
CREATE INDEX pg_transaction_payment_idx ON pgkakao.pg_transaction(payment_id, created_at DESC);
CREATE INDEX ix_pg_transaction_cursor_v1 ON pgkakao.pg_transaction (created_at, transaction_id);
CREATE INDEX ix_pg_webhook_due_v1 ON pgkakao.pg_webhook_outbox (status, next_retry_at, event_id);
COMMIT;
