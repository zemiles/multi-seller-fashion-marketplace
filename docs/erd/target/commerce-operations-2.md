# commerce / 운영·금융협력 2 — target

주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](commerce-service.md), 영역 밖 FK는 서비스 DBML을 확인합니다.

```mermaid
erDiagram
    direction LR
    commerceSellerComplianceTaskItem["commerce.seller_compliance_task_item"] {
        uuid task_item_id PK "required"
        uuid task_id FK "required"
        uuid finding_id FK "required"
        text status "required"
        text seller_response "nullable"
        jsonb resolution_evidence "required"
        timestamptz resolved_at "nullable"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceOutboxEvent["commerce.outbox_event"] {
        uuid outbox_event_id PK "required"
        text event_key UK "required"
        text aggregate_type "required"
        text aggregate_id "required"
        bigint aggregate_version "required"
        text event_type "required"
        jsonb payload "required"
        text status "required"
        integer attempt_count "required"
        timestamptz occurred_at "required"
    }
    commerceConsumerInbox["commerce.consumer_inbox"] {
        text consumer_name PK "required"
        uuid event_id PK "required"
        uuid entry_id UK "required"
        bigint version "required"
        text aggregate_type "required"
        text aggregate_id "required"
        bigint aggregate_version "required"
        jsonb payload "required"
        text payload_hash "required"
        text status "required"
    }
    commerceConsumerStreamCheckpoint["commerce.consumer_stream_checkpoint"] {
        text consumer_name PK "required"
        text aggregate_type PK "required"
        text aggregate_id PK "required"
        bigint last_sequence "required"
        text blocked_reason "nullable"
        timestamptz updated_at "required"
    }
    commerceEventStreamSequence["commerce.event_stream_sequence"] {
        text aggregate_type PK "required"
        text aggregate_id PK "required"
        bigint last_sequence "required"
        bigint version "required"
    }
    commerceEventRecoveryJob["commerce.event_recovery_job"] {
        uuid job_id PK "required"
        uuid entry_id "required"
        text queue_type "required"
        text consumer_name "nullable"
        uuid event_id "required"
        text expected_hash "required"
        bigint source_version "required"
        text status "required"
        text request_hash "required"
        text idempotency_key "required"
    }
    commerceAdminRecoveryCode["commerce.admin_recovery_code"] {
        uuid admin_user_id PK, FK "required"
        text code_hash PK "required"
        timestamptz used_at "nullable"
    }
    commerceCommandIdempotency["commerce.command_idempotency"] {
        text principal_id PK "required"
        text operation PK "required"
        text target_id PK "required"
        text idempotency_key PK "required"
        text request_hash "required"
        uuid resource_id "nullable"
        jsonb result_payload "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz expires_at "nullable"
    }
    commerceActiveUnitClaimGuard["commerce.active_unit_claim_guard"] {
        uuid order_item_id PK, FK "required"
        integer unit_ordinal PK, FK "required"
        uuid claim_item_id FK "required"
    }
    commerceSellerFinancialState["commerce.seller_financial_state"] {
        uuid seller_id PK, FK "required"
        bigint state_version "required"
        bigint account_version "required"
        bigint hold_version "required"
        timestamptz updated_at "required"
    }
    commercePayoutFence["commerce.payout_fence"] {
        uuid fence_id PK "required"
        uuid seller_id FK "required"
        uuid settlement_id "required"
        uuid payout_attempt_id "required"
        bigint expected_seller_state_version "required"
        jsonb stream_snapshot "required"
        text account_snapshot_hash "required"
        text operation_hash "nullable"
        bigint fence_version "required"
        text status "required"
    }
    commerceApprovalExecution["commerce.approval_execution"] {
        uuid approval_request_id PK, FK "required"
        uuid action_id UK "required"
        text payload_hash "required"
        text status "required"
        uuid operation_id "nullable"
        timestamptz consumed_at "nullable"
    }
```
