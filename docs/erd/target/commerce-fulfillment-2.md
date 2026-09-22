# commerce / 배송·클레임 2 — target

주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](commerce-service.md), 영역 밖 FK는 서비스 DBML을 확인합니다.

```mermaid
erDiagram
    direction LR
    commerceClaimItemUnit["commerce.claim_item_unit"] {
        uuid claim_item_id PK, FK "required"
        uuid order_item_id PK, FK "required"
        integer unit_ordinal PK, FK "required"
        bigint refund_amount "required"
        text status "required"
    }
    commercePurchaseConfirmationUnit["commerce.purchase_confirmation_unit"] {
        uuid order_item_id PK, FK "required"
        integer unit_ordinal PK, FK "required"
        uuid confirmation_event_id FK "required"
        timestamptz confirmed_at "required"
    }
```
