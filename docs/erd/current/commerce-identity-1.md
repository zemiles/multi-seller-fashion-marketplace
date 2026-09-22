# commerce / 회원·판매자 — current

주요 키/컬럼 최대10개 표시. 전체 컬럼/제약은 [서비스 데이터 사전](commerce-service.md), 영역 밖 FK는 서비스 DBML을 확인합니다.

```mermaid
erDiagram
    direction LR
    commerceMember["commerce.member"] {
        uuid member_id PK "required"
        text email_normalized UK "required"
        text password_hash "nullable"
        text status "required"
        timestamptz email_verified_at "nullable"
        timestamptz last_login_at "nullable"
        timestamptz created_at "required"
        timestamptz updated_at "required"
        timestamptz withdrawn_at "nullable"
    }
    commerceMemberAuthIdentity["commerce.member_auth_identity"] {
        uuid auth_identity_id PK "required"
        uuid member_id FK "required"
        text provider "required"
        text provider_subject "required"
        text credential_hash "nullable"
        timestamptz created_at "required"
        timestamptz last_authenticated_at "nullable"
        timestamptz revoked_at "nullable"
    }
    commerceMemberProfile["commerce.member_profile"] {
        uuid member_id PK, FK "required"
        text gender "required"
        date birth_date "nullable"
        numeric_5_2_ height_cm "nullable"
        numeric_6_2_ weight_kg "nullable"
        boolean recommendation_consent "required"
        text recommendation_consent_version "nullable"
        timestamptz recommendation_consented_at "nullable"
        timestamptz created_at "required"
        timestamptz updated_at "required"
    }
    commerceShippingAddress["commerce.shipping_address"] {
        uuid address_id PK "required"
        uuid member_id FK "required"
        text address_label "nullable"
        text recipient_name "required"
        bytea phone_cipher "required"
        text postal_code "nullable"
        bytea address_cipher "required"
        bytea delivery_note_cipher "nullable"
        text status "required"
        boolean is_default "required"
    }
    commerceSeller["commerce.seller"] {
        uuid seller_id PK "required"
        text business_number UK "required"
        text legal_name "required"
        text display_name "required"
        text business_type "required"
        text seller_status "required"
        timestamptz opened_at "nullable"
        timestamptz created_at "required"
        timestamptz updated_at "required"
        timestamptz closed_at "nullable"
    }
    commerceSellerMember["commerce.seller_member"] {
        uuid seller_member_id PK "required"
        uuid seller_id FK "required"
        uuid member_id FK "required"
        text role "required"
        text status "required"
        timestamptz invited_at "required"
        timestamptz joined_at "nullable"
        timestamptz left_at "nullable"
    }
    commerceSellerDocument["commerce.seller_document"] {
        uuid document_id PK "required"
        uuid seller_id FK "required"
        text document_type "required"
        text file_url "required"
        text content_hash "required"
        text retention_class "required"
        text status "required"
        date issued_at "nullable"
        timestamptz expires_at "nullable"
        timestamptz created_at "required"
    }
    commerceSellerVerification["commerce.seller_verification"] {
        uuid verification_id PK "required"
        uuid seller_id FK "required"
        uuid document_id FK "nullable"
        text verification_request_key UK "required"
        text verification_type "required"
        text provider "nullable"
        text status "required"
        text result_hash "nullable"
        jsonb result_snapshot "required"
        timestamptz requested_at "required"
    }
    commerceSellerSettlementAccount["commerce.seller_settlement_account"] {
        uuid account_id PK "required"
        uuid seller_id FK "required"
        text bank_code "required"
        bytea account_cipher "required"
        text account_fingerprint "required"
        bytea holder_name_cipher "required"
        text verification_status "required"
        text status "required"
        boolean is_default "required"
        timestamptz created_at "required"
    }
    commerceMember ||..o{ commerceMemberAuthIdentity : "member_id"
    commerceMember ||--o| commerceMemberProfile : "member_id"
    commerceMember ||..o{ commerceShippingAddress : "member_id"
    commerceSeller ||..o{ commerceSellerMember : "seller_id"
    commerceMember ||..o{ commerceSellerMember : "member_id"
    commerceSeller ||..o{ commerceSellerDocument : "seller_id"
    commerceSeller ||..o{ commerceSellerVerification : "seller_id"
    commerceSellerDocument |o..o{ commerceSellerVerification : "document_id"
    commerceSeller ||..o{ commerceSellerSettlementAccount : "seller_id"
```
