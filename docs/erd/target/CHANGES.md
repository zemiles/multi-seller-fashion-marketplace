# v1 목표 모델 변경 목록

실행 SQL 아님. 다음 Flyway 버전에서 backfill/제약/lock 테스트와 함께 구현합니다. 모든 기존 테이블을 포함한 목표 DBML에서 추가와 변경을 구분합니다. 상태 CHECK, partial unique, 합계 불변식은 해당 요구사항과 이 목록의 note를 함께 구현해야 합니다.

| 대상 | 변경 | 필드/이유 |
| --- | --- | --- |
| commerce.consumer_inbox | ADD_TABLE |  EVT-03/X-07; entry_id identifies one consumer/event row; sequence collision with a different hash is quarantined before overwrite. |
| commerce.consumer_stream_checkpoint | ADD_TABLE |  EVT-03; row lock with inbox business transaction. |
| commerce.event_stream_sequence | ADD_TABLE |  EVT-01; allocate contiguous sequence with outbox insert. |
| commerce.outbox_event | ALTER_COLUMNS | aggregate_id text,aggregate_version bigint,version bigint,payload_hash text,serialized_body bytea,lease_expires_at timestamptz?,event_version integer,producer text,correlation_id uuid,causation_id uuid,trace_id text EVT-01/X-07; text aggregateId, immutable published bytes/hash, optimistic replay version. Existing lock_token/locked_at retained; legacy non-v1 rows archived before NOT NULL validation. |
| commerce.event_recovery_job | ADD_TABLE |  X-07/EVT-03; entry target is polymorphic inbox/outbox. Actor/approval IDs are verified by Commerce contract, no cross-service FK. Commit source retry and job state atomically; complete only after source effect/dedup confirmation. |
| payment.consumer_inbox | ADD_TABLE |  EVT-03/X-07; entry_id identifies one consumer/event row; sequence collision with a different hash is quarantined before overwrite. |
| payment.consumer_stream_checkpoint | ADD_TABLE |  EVT-03; row lock with inbox business transaction. |
| payment.event_stream_sequence | ADD_TABLE |  EVT-01; allocate contiguous sequence with outbox insert. |
| payment.outbox_event | ALTER_COLUMNS | aggregate_id text,aggregate_version bigint,version bigint,payload_hash text,serialized_body bytea,lease_expires_at timestamptz?,event_version integer,producer text,correlation_id uuid,causation_id uuid,trace_id text EVT-01/X-07; text aggregateId, immutable published bytes/hash, optimistic replay version. Existing lock_token/locked_at retained; legacy non-v1 rows archived before NOT NULL validation. |
| payment.event_recovery_job | ADD_TABLE |  X-07/EVT-03; entry target is polymorphic inbox/outbox. Actor/approval IDs are verified by Commerce contract, no cross-service FK. Commit source retry and job state atomically; complete only after source effect/dedup confirmation. |
| settlement.consumer_inbox | ADD_TABLE |  EVT-03/X-07; entry_id identifies one consumer/event row; sequence collision with a different hash is quarantined before overwrite. |
| settlement.consumer_stream_checkpoint | ADD_TABLE |  EVT-03; row lock with inbox business transaction. |
| settlement.event_stream_sequence | ADD_TABLE |  EVT-01; allocate contiguous sequence with outbox insert. |
| settlement.outbox_event | ALTER_COLUMNS | aggregate_id text,aggregate_version bigint,version bigint,payload_hash text,serialized_body bytea,lease_expires_at timestamptz?,event_version integer,producer text,correlation_id uuid,causation_id uuid,trace_id text EVT-01/X-07; text aggregateId, immutable published bytes/hash, optimistic replay version. Existing lock_token/locked_at retained; legacy non-v1 rows archived before NOT NULL validation. |
| settlement.event_recovery_job | ADD_TABLE |  X-07/EVT-03; entry target is polymorphic inbox/outbox. Actor/approval IDs are verified by Commerce contract, no cross-service FK. Commit source retry and job state atomically; complete only after source effect/dedup confirmation. |
| discovery.consumer_inbox | ADD_TABLE |  EVT-03/X-07; entry_id identifies one consumer/event row; sequence collision with a different hash is quarantined before overwrite. |
| discovery.consumer_stream_checkpoint | ADD_TABLE |  EVT-03; row lock with inbox business transaction. |
| discovery.event_stream_sequence | ADD_TABLE |  EVT-01; allocate contiguous sequence with outbox insert. |
| discovery.outbox_event | ALTER_COLUMNS | aggregate_id text,aggregate_version bigint,version bigint,payload_hash text,serialized_body bytea,lease_expires_at timestamptz?,event_version integer,producer text,correlation_id uuid,causation_id uuid,trace_id text EVT-01/X-07; text aggregateId, immutable published bytes/hash, optimistic replay version. Existing lock_token/locked_at retained; legacy non-v1 rows archived before NOT NULL validation. |
| discovery.event_recovery_job | ADD_TABLE |  X-07/EVT-03; entry target is polymorphic inbox/outbox. Actor/approval IDs are verified by Commerce contract, no cross-service FK. Commit source retry and job state atomically; complete only after source effect/dedup confirmation. |
| commerce.member | ALTER_COLUMNS | session_version integer,nickname text,version integer SEC-01/COM-01; PASSWORD credential authority is member_auth_identity. Legacy member.password_hash must be migrated/disabled, not dual-written. |
| commerce.admin_user | ALTER_COLUMNS | password_hash text,totp_secret_cipher bytea?,mfa_state text,session_version integer,version integer SEC-02/X-06; MFA recovery clears secret/codes and blocks privileged login until verified CLI enrollment. |
| commerce.admin_recovery_code | ADD_TABLE |  SEC-02; one-time use conditional update. |
| commerce.verification_token | ADD_TABLE |  SEC-01; VERIFY_EMAIL/RESET_PASSWORD, never raw token. |
| commerce.seller_invitation | ADD_TABLE |  COM-02; 24h one-time invitation. |
| commerce.command_idempotency | ADD_TABLE |  API-02; command and result atomically persisted, no secrets. |
| commerce.claim_quote | ADD_TABLE |  X-01; 5 minute immutable quote, no stock/money reservation. Command idempotency replays same quote. |
| commerce.claim_reason_change | ALTER_COLUMNS | version bigint,evidence_ids jsonb X-02; evidence IDs only, owner verified; one open reason change per claim. |
| commerce.payment_dispatch_intent | ADD_TABLE |  ORD-05; attempt_id is external Payment ID, no FK. |
| commerce.order_item_unit | ADD_TABLE |  MONEY-01; ordinal 1..quantity. Sums match immutable order item. |
| commerce.shipment_item_unit | ADD_TABLE |  FUL-01; same order unit lock enforces only one active outbound per generation. |
| commerce.claim_item_unit | ADD_TABLE |  CLM-01; immutable allocation/history. |
| commerce.active_unit_claim_guard | ADD_TABLE |  CLM-01; unique live claim per unit; terminal history remains in claim_item_unit. |
| commerce.purchase_confirmation_unit | ADD_TABLE |  FUL-02; local confirmation event writer; no second income after exchange. |
| commerce.seller_financial_state | ADD_TABLE |  SET-03; barrier and fence and new hold share seller lock. Stream watermarks use event_stream_sequence. |
| commerce.payout_fence | ADD_TABLE |  SET-03; external settlement/payout IDs are not FKs. Same consumed fence replays same permit. Under seller lock expire the old unconsumed fence before creating a new version for the SAME payout attempt; partial unique payout_attempt_id WHERE status IN (ACTIVE,CONSUMED) required. Never create a new bank idempotency key to bypass UNKNOWN. |
| commerce.approval_execution | ADD_TABLE |  OPS-01; 1-time execution matching approved immutable payload. |
| commerce.upload_asset | ADD_TABLE |  SEC-04; private evidence vs public image. Owner is polymorphic, checked in application. |
| commerce.inventory_reservation | ALTER_COLUMNS | recovery_hold boolean,recovery_reason text? ORD-05; expiry never overrides financial hold. |
| commerce.orders | ALTER_COLUMNS | pricing_policy_version text,recovery_status text,payment_snapshot_hash text? ORD-04; payment UNKNOWN is not order_status. |
| commerce.admin_approval_request | ALTER_COLUMNS | payload_hash text,version bigint OPS-01; EXPIRED already exists; map DB PENDING to HTTP APPROVAL_PENDING. Do not overwrite prior migration. |
| payment.order_payment_guard | ADD_TABLE |  PAY-01/03; CLOSED tombstone even before prepare; order_id external Commerce ID. |
| payment.payment_operation | ADD_TABLE |  PAY-04; partial unique active dispatch per payment; due(status,next_retry_at). Payload may contain operation-local safe evidence only. |
| payment.payment_operation_result | ADD_TABLE |  PAY-02; immutable result, response and event reference identical version. |
| payment.refund_unit_allocation | ADD_TABLE |  PAY-04; order_item/unit external IDs validated against attempt snapshot; active/terminal successful unit reservation guard in owner transaction. |
| payment.pg_reconciliation_run | ADD_TABLE |  PAY-06; Payment owns PG reconciliation. |
| payment.pg_reconciliation_receipt | ADD_TABLE |  PAY-06; immutable receipt; a later run can re-observe without inserting a second receipt. |
| payment.pg_reconciliation_discrepancy | ADD_TABLE |  PAY-06; approval_id external Commerce identity. |
| payment.payment_attempt | ALTER_COLUMNS | payment_request_id uuid,request_hash text,expires_at timestamptz,pricing_policy_version text PAY-01; complete snapshot remains request_payload. |
| payment.payment | ALTER_COLUMNS | voided_amount bigint,version bigint PAY-04; VOID does not increment refunded_amount. |
| payment.refund | ALTER_COLUMNS | compensation_id uuid?,approval_id uuid?,request_hash text PAY-04; claimId or compensationId mandatory, approval for manual adjustment. |
| settlement.seller_recognition_unit | ADD_TABLE |  SET-01; snapshot/projection, no FK to Commerce. |
| settlement.seller_carry_forward | ADD_TABLE |  SET-02; signed debt/credit, no duplicate allocation. |
| settlement.simulated_bank_receipt | ADD_TABLE |  SET-03; separate adapter transaction, no FK tying bank commit to caller commit. |
| settlement.settlement | ALTER_COLUMNS | gross_net_amount bigint MIG-NET/SET-02; API netAmount = gross_net_amount = credit - debit. Keep legacy net_amount = gross_net_amount - hold; payout bounded by post-hold net. |
| settlement.bank_reconciliation_run | ADD_TABLE |  MIG-BANK/SET-04; bank payout reconciliation only; fixed snapshot cursor and immutable run inputs. |
| settlement.bank_reconciliation_receipt | ADD_TABLE |  MIG-BANK/SET-04; immutable observed bank fact. run_id is FIRST observation; later runs compare without updating original receipt. No FK to internal attempt: external-only receipts must be representable. |
| settlement.bank_reconciliation_discrepancy | ADD_TABLE |  MIG-BANK/SET-04; deterministic identity excludes run ID, repeat observation reuses discrepancy; approval is external Commerce ID. Legacy reconciliation_* remain read-only. |
| settlement.settlement_payout_attempt | ALTER_COLUMNS | approval_id uuid,fence_id uuid,dispatch_permit_id uuid?,operation_hash text,result_version bigint,lease_expires_at timestamptz?,next_retry_at timestamptz? SET-03; external Commerce approvals/fence, no cross-service FK. |
| pg1.pg_webhook_outbox | ADD_TABLE |  PG-03; transaction commit and webhook row atomic; timestamp/signature refreshed on retry. |
| pg1.pg_fault_scenario | ADD_TABLE |  PG-02; local/stage only; fail closed in prod profile. |
| pg2.pg_webhook_outbox | ADD_TABLE |  PG-03; transaction commit and webhook row atomic; timestamp/signature refreshed on retry. |
| pg2.pg_fault_scenario | ADD_TABLE |  PG-02; local/stage only; fail closed in prod profile. |
| discovery.search_projection_generation | ADD_TABLE |  DIS-01; partial unique status ACTIVE; verified atomic generation switch. |
| discovery.search_product_projection | ADD_TABLE |  DIS-01; all product/seller/revision IDs external, not FKs; query indexes on category/price/time+product_id. |
| discovery.product_analysis_run | ALTER_COLUMNS | product_id uuid,simulated boolean,attempt_count integer,next_retry_at timestamptz? DIS-02; externally owned product/revision IDs; no Commerce DB read. |
| commerce.member | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.orders | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.claim_reason_change | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.admin_user | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.admin_approval_request | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.outbox_event | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| payment.payment_attempt | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| payment.payment | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| payment.refund | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| payment.outbox_event | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| settlement.settlement_payout_attempt | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| settlement.outbox_event | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| discovery.product_analysis_run | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| discovery.outbox_event | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| settlement.settlement | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| settlement.seller_ledger_entry | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| commerce.shipment_event | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| pg1.pg_transaction | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |
| pg2.pg_transaction | ALTER_CONSTRAINTS_INDEXES |  v1 CHECK/index definition is included in target data dictionary and generated empty-DB SQL. Existing-data upgrade follows migration wave/backfill gates. |

Settlement 기존 reconciliation_*는 아직 PG형 legacy 필드를 포함합니다. 새 목표 Payment pg_reconciliation_*와 혼용하거나 Settlement에서 PG를 대사하지 않습니다. v1은 별도 bank_reconciliation_*를 추가하고 기존 행은 legacy 조회용으로 보존합니다. 정산 금액 매핑·부분 역전·은행 대사의 추가 명세는 [MIG-02](../../implementation/03-migrations.md)를 함께 적용합니다. 이 보완은 target overlay와 [빈 DB용 목표 SQL](../../ddl/README.md)에 반영됐습니다. 기존 DB에는 MIG-02의 expand/backfill/검증 절차를 따르는 새 migration으로 적용합니다.
