# settlement / settlement 2 — target

주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](settlement-service.md), 영역 밖 FK는 서비스 DBML을 확인합니다.

```mermaid
erDiagram
    direction LR
    settlementSellerRecognitionUnit["settlement.seller_recognition_unit"] {
        uuid recognition_id PK "required"
        uuid seller_id "required"
        uuid order_id "required"
        text source_unit_or_charge_id "required"
        uuid source_event_id "required"
        bigint recognized_amount "required"
        bigint commission_amount "required"
        bigint reversed_amount "required"
        bigint reversed_fee_amount "required"
    }
    settlementSellerCarryForward["settlement.seller_carry_forward"] {
        uuid carry_forward_id PK "required"
        uuid source_settlement_id FK, UK "required"
        uuid target_settlement_id FK "nullable"
        uuid seller_id "required"
        text currency "required"
        bigint signed_amount "required"
        jsonb source_ledger_ids "required"
        text status "required"
    }
    settlementSimulatedBankReceipt["settlement.simulated_bank_receipt"] {
        uuid bank_receipt_id PK "required"
        text idempotency_key UK "required"
        uuid dispatch_permit_id "required"
        text operation_hash "required"
        text account_snapshot_hash "required"
        text currency "required"
        bigint amount "required"
        text status "required"
        timestamptz occurred_at "required"
    }
    settlementBankReconciliationRun["settlement.bank_reconciliation_run"] {
        uuid run_id PK "required"
        date business_date "required"
        timestamptz source_as_of "required"
        text algorithm_version "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz completed_at "nullable"
    }
    settlementBankReconciliationReceipt["settlement.bank_reconciliation_receipt"] {
        uuid bank_receipt_id PK "required"
        uuid run_id FK "required"
        text idempotency_key UK "required"
        text account_snapshot_hash "required"
        text currency "required"
        bigint amount "required"
        text status "required"
        timestamptz occurred_at "required"
        jsonb receipt "required"
        text receipt_hash "required"
    }
    settlementBankReconciliationDiscrepancy["settlement.bank_reconciliation_discrepancy"] {
        uuid discrepancy_id PK "required"
        uuid run_id FK "required"
        uuid bank_receipt_id FK "nullable"
        uuid payout_attempt_id FK "nullable"
        text identity_key UK "required"
        text kind "required"
        text status "required"
        jsonb expected_payload "required"
        jsonb actual_payload "required"
        uuid approval_id "nullable"
    }
    settlementBankReconciliationRun ||..o{ settlementBankReconciliationReceipt : "run_id"
    settlementBankReconciliationRun ||..o{ settlementBankReconciliationDiscrepancy : "run_id"
    settlementBankReconciliationReceipt |o..o{ settlementBankReconciliationDiscrepancy : "bank_receipt_id"
```
