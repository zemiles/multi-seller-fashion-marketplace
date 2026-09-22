# commerce / 상품·재고 — current

주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](commerce-service.md), 영역 밖 FK는 서비스 DBML을 확인합니다.

```mermaid
erDiagram
    direction LR
    commerceBrand["commerce.brand"] {
        uuid brand_id PK "required"
        text brand_name "required"
        text brand_name_normalized UK "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceBrandRegistrationRequest["commerce.brand_registration_request"] {
        uuid request_id PK "required"
        uuid seller_id FK "required"
        uuid approved_brand_id FK "nullable"
        uuid reviewed_by_admin_user_id FK "nullable"
        text requested_name "required"
        text requested_name_normalized "required"
        jsonb request_snapshot "required"
        text status "required"
        timestamptz requested_at "required"
        timestamptz reviewed_at "nullable"
    }
    commerceCategory["commerce.category"] {
        uuid category_id PK "required"
        uuid parent_category_id FK "nullable"
        text category_code UK "required"
        text category_name "required"
        text category_name_normalized "required"
        boolean is_leaf "required"
        text status "required"
        integer display_order "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceProduct["commerce.product"] {
        uuid product_id PK, FK "required"
        uuid seller_brand_relation_id FK "required"
        uuid category_id FK "required"
        integer current_revision_no FK "nullable"
        text seller_product_code "nullable"
        text sale_status "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
        timestamptz published_at "nullable"
        timestamptz archived_at "nullable"
    }
    commerceProductRevision["commerce.product_revision"] {
        uuid product_revision_id PK "required"
        uuid product_id FK "required"
        uuid primary_image_id FK "nullable"
        uuid created_by_seller_member_id FK "nullable"
        integer revision_no "required"
        text product_name "required"
        text description "nullable"
        jsonb attributes_snapshot "required"
        timestamptz created_at "required"
        timestamptz published_at "nullable"
    }
    commerceProductImage["commerce.product_image"] {
        uuid image_id PK "required"
        uuid product_id FK "required"
        text image_type "required"
        text image_url "required"
        text alt_text "nullable"
        text content_hash "nullable"
        integer display_order "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz deleted_at "nullable"
    }
    commerceProductFeature["commerce.product_feature"] {
        uuid feature_id PK "required"
        uuid product_revision_id FK "required"
        uuid confirmed_by_seller_member_id FK "nullable"
        integer feature_order "required"
        text feature_text "required"
        text source_type "required"
        jsonb source_snapshot "required"
        boolean confirmed_by_seller "required"
        timestamptz confirmed_at "nullable"
        timestamptz created_at "required"
    }
    commerceOptionGroup["commerce.option_group"] {
        uuid option_group_id PK "required"
        uuid product_id FK "required"
        text group_code "required"
        text display_name "required"
        integer display_order "required"
        boolean is_required "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceOptionValue["commerce.option_value"] {
        uuid option_value_id PK "required"
        uuid option_group_id FK "required"
        text value_code "required"
        text display_name "required"
        integer display_order "required"
        jsonb value_metadata "required"
        text status "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceSku["commerce.sku"] {
        uuid sku_id PK "required"
        uuid product_id FK "required"
        text seller_sku_code "required"
        text combination_key "required"
        bigint sale_price "required"
        char_3_ currency "required"
        text sku_status "required"
        timestamptz created_at "required"
        timestamptz updated_at "required"
        timestamptz archived_at "nullable"
    }
    commerceSkuOptionValue["commerce.sku_option_value"] {
        uuid sku_option_value_id PK "required"
        uuid product_id FK "required"
        uuid sku_id FK "required"
        uuid option_group_id FK "required"
        uuid option_value_id FK "required"
        timestamptz created_at "required"
    }
    commerceInventory["commerce.inventory"] {
        uuid sku_id PK, FK "required"
        integer on_hand_qty "required"
        integer reserved_qty "required"
        integer safety_stock_qty "required"
        integer available_qty "nullable"
        integer version "required"
        timestamptz updated_at "required"
    }
    commerceInventoryLedger["commerce.inventory_ledger"] {
        uuid inventory_ledger_id PK "required"
        uuid sku_id FK "required"
        text quantity_type "required"
        integer signed_delta "required"
        integer balance_after "required"
        text reason_type "required"
        text reference_type "required"
        text reference_key UK "required"
        jsonb source_snapshot "required"
        timestamptz occurred_at "required"
    }
    commerceProductComplianceFinding["commerce.product_compliance_finding"] {
        uuid finding_id PK "required"
        uuid product_revision_id FK "required"
        uuid rule_version_id FK "required"
        uuid decided_by_admin_user_id FK "nullable"
        text evaluation_run_key "required"
        text status "required"
        text severity "required"
        jsonb evidence "required"
        text model_version "nullable"
        text human_decision "nullable"
    }
    commerceBrand |o..o{ commerceBrandRegistrationRequest : "approved_brand_id"
    commerceCategory |o..o{ commerceCategory : "parent_category_id"
    commerceCategory ||..o{ commerceProduct : "category_id"
    commerceProduct ||..o{ commerceProductRevision : "product_id"
    commerceProduct ||..o{ commerceProductImage : "product_id"
    commerceProductImage |o..o{ commerceProductRevision : "product_id+primary_image_id"
    commerceProductRevision |o..o| commerceProduct : "product_id+current_revision_no"
    commerceProductRevision ||..o{ commerceProductFeature : "product_revision_id"
    commerceProduct ||..o{ commerceOptionGroup : "product_id"
    commerceOptionGroup ||..o{ commerceOptionValue : "option_group_id"
    commerceProduct ||..o{ commerceSku : "product_id"
    commerceSku ||..o{ commerceSkuOptionValue : "product_id+sku_id"
    commerceOptionGroup ||..o{ commerceSkuOptionValue : "product_id+option_group_id"
    commerceOptionValue ||..o{ commerceSkuOptionValue : "option_group_id+option_value_id"
    commerceSku ||--o| commerceInventory : "sku_id"
    commerceInventory ||..o{ commerceInventoryLedger : "sku_id"
    commerceProductRevision ||..o{ commerceProductComplianceFinding : "product_revision_id"
```
