# commerce / 운영·금융협력 2 — current

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
        uuid aggregate_id "required"
        bigint aggregate_version "nullable"
        text event_type "required"
        jsonb payload "required"
        text status "required"
        integer attempt_count "required"
        timestamptz occurred_at "required"
    }
```
