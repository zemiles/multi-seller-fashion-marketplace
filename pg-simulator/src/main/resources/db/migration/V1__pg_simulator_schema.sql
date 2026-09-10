CREATE SCHEMA IF NOT EXISTS pgsim;
CREATE TABLE pgsim.pg_payment (
 payment_id uuid PRIMARY KEY, merchant_tx_id text NOT NULL UNIQUE,
 currency varchar(3) NOT NULL, amount bigint NOT NULL, status text NOT NULL DEFAULT 'APPROVED',
 refunded_amount bigint NOT NULL DEFAULT 0, created_at timestamp with time zone NOT NULL DEFAULT now(), updated_at timestamp with time zone NOT NULL DEFAULT now(),
 CONSTRAINT pg_payment_currency_ck CHECK (currency ~ '^[A-Z]{3}$'), CONSTRAINT pg_payment_amount_ck CHECK (amount > 0),
 CONSTRAINT pg_payment_refund_ck CHECK (refunded_amount >= 0 AND refunded_amount <= amount),
 CONSTRAINT pg_payment_status_ck CHECK (status IN ('APPROVED','PARTIALLY_REFUNDED','REFUNDED','CANCELLED'))
);
CREATE TABLE pgsim.pg_transaction (
 transaction_id uuid PRIMARY KEY, payment_id uuid NOT NULL REFERENCES pgsim.pg_payment(payment_id),
 transaction_type text NOT NULL, amount bigint NOT NULL, status text NOT NULL, idempotency_key text,
 created_at timestamp with time zone NOT NULL DEFAULT now(), CONSTRAINT pg_transaction_type_ck CHECK (transaction_type IN ('APPROVE','CANCEL','REFUND')),
 CONSTRAINT pg_transaction_amount_ck CHECK (amount > 0), CONSTRAINT pg_transaction_status_ck CHECK (status IN ('SUCCEEDED','FAILED')),
 CONSTRAINT pg_transaction_idempotency_uq UNIQUE (payment_id, transaction_type, idempotency_key)
);
CREATE INDEX pg_transaction_payment_idx ON pgsim.pg_transaction(payment_id, created_at DESC);
