-- commerce-service: empty isolated database schema snapshot.
-- NOT an upgrade migration. NEVER apply to an existing/production database.
-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.
-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.
BEGIN;
CREATE SCHEMA IF NOT EXISTS marketplace;

CREATE TABLE marketplace.member (
    member_id uuid DEFAULT gen_random_uuid() NOT NULL,
    email_normalized text NOT NULL,
    password_hash text,
    status text DEFAULT 'ACTIVE' NOT NULL,
    email_verified_at timestamptz,
    last_login_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    withdrawn_at timestamptz,
    CONSTRAINT pk_member PRIMARY KEY (member_id),
    CONSTRAINT uq_member_email_normalized UNIQUE (email_normalized),
    CONSTRAINT ck_member_email_normalized CHECK (
        email_normalized = lower(btrim(email_normalized))
        AND char_length(email_normalized) > 2
    ),
    CONSTRAINT ck_member_status CHECK (
        status IN ('ACTIVE', 'DORMANT', 'SUSPENDED', 'WITHDRAWN')
    ),
    CONSTRAINT ck_member_withdrawn_state CHECK (
        status <> 'WITHDRAWN' OR withdrawn_at IS NOT NULL
    )
);

CREATE TABLE marketplace.member_auth_identity (
    auth_identity_id uuid DEFAULT gen_random_uuid() NOT NULL,
    member_id uuid NOT NULL,
    provider text NOT NULL,
    provider_subject text NOT NULL,
    credential_hash text,
    created_at timestamptz DEFAULT now() NOT NULL,
    last_authenticated_at timestamptz,
    revoked_at timestamptz,
    CONSTRAINT pk_member_auth_identity PRIMARY KEY (auth_identity_id),
    CONSTRAINT uq_member_auth_provider_subject UNIQUE (provider, provider_subject),
    CONSTRAINT ck_member_auth_provider CHECK (
        provider IN ('PASSWORD', 'GOOGLE', 'APPLE', 'KAKAO', 'NAVER', 'OTHER')
    ),
    CONSTRAINT ck_member_auth_provider_subject CHECK (char_length(btrim(provider_subject)) > 0),
    CONSTRAINT ck_member_auth_password_credential CHECK (
        provider <> 'PASSWORD' OR credential_hash IS NOT NULL
    )
);

CREATE TABLE marketplace.member_profile (
    member_id uuid DEFAULT gen_random_uuid() NOT NULL,
    gender text DEFAULT 'UNDISCLOSED' NOT NULL,
    birth_date date,
    height_cm numeric(5,2),
    weight_kg numeric(6,2),
    recommendation_consent boolean DEFAULT false NOT NULL,
    recommendation_consent_version text,
    recommendation_consented_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_member_profile PRIMARY KEY (member_id),
    CONSTRAINT ck_member_profile_gender CHECK (
        gender IN ('FEMALE', 'MALE', 'NON_BINARY', 'UNDISCLOSED')
    ),
    CONSTRAINT ck_member_profile_birth_date CHECK (
        birth_date IS NULL OR birth_date >= DATE '1900-01-01'
    ),
    CONSTRAINT ck_member_profile_height CHECK (
        height_cm IS NULL OR height_cm BETWEEN 30 AND 300
    ),
    CONSTRAINT ck_member_profile_weight CHECK (
        weight_kg IS NULL OR weight_kg BETWEEN 1 AND 1000
    ),
    CONSTRAINT ck_member_profile_recommendation_consent CHECK (
        NOT recommendation_consent
        OR (
            recommendation_consent_version IS NOT NULL
            AND char_length(btrim(recommendation_consent_version)) > 0
            AND recommendation_consented_at IS NOT NULL
        )
    )
);

CREATE TABLE marketplace.shipping_address (
    address_id uuid DEFAULT gen_random_uuid() NOT NULL,
    member_id uuid NOT NULL,
    address_label text,
    recipient_name text NOT NULL,
    phone_cipher bytea NOT NULL,
    postal_code text,
    address_cipher bytea NOT NULL,
    delivery_note_cipher bytea,
    status text DEFAULT 'ACTIVE' NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    deleted_at timestamptz,
    CONSTRAINT pk_shipping_address PRIMARY KEY (address_id),
    CONSTRAINT ck_shipping_address_recipient CHECK (char_length(btrim(recipient_name)) > 0),
    CONSTRAINT ck_shipping_address_phone_cipher CHECK (octet_length(phone_cipher) > 0),
    CONSTRAINT ck_shipping_address_address_cipher CHECK (octet_length(address_cipher) > 0),
    CONSTRAINT ck_shipping_address_status CHECK (status IN ('ACTIVE', 'ARCHIVED')),
    CONSTRAINT ck_shipping_address_archived CHECK (
        status <> 'ARCHIVED' OR deleted_at IS NOT NULL
    ),
    CONSTRAINT ck_shipping_address_default_active CHECK (
        NOT is_default OR (status = 'ACTIVE' AND deleted_at IS NULL)
    )
);

CREATE TABLE marketplace.seller (
    seller_id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_number text NOT NULL,
    legal_name text NOT NULL,
    display_name text NOT NULL,
    business_type text NOT NULL,
    seller_status text DEFAULT 'ONBOARDING' NOT NULL,
    opened_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    closed_at timestamptz,
    CONSTRAINT pk_seller PRIMARY KEY (seller_id),
    CONSTRAINT uq_seller_business_number UNIQUE (business_number),
    CONSTRAINT ck_seller_business_number CHECK (char_length(btrim(business_number)) > 0),
    CONSTRAINT ck_seller_legal_name CHECK (char_length(btrim(legal_name)) > 0),
    CONSTRAINT ck_seller_display_name CHECK (char_length(btrim(display_name)) > 0),
    CONSTRAINT ck_seller_business_type CHECK (
        business_type IN ('INDIVIDUAL', 'SOLE_PROPRIETOR', 'CORPORATION')
    ),
    CONSTRAINT ck_seller_status CHECK (
        seller_status IN ('ONBOARDING', 'ACTIVE', 'SUSPENDED', 'REJECTED', 'CLOSED')
    ),
    CONSTRAINT ck_seller_closed_state CHECK (
        seller_status <> 'CLOSED' OR closed_at IS NOT NULL
    )
);

CREATE TABLE marketplace.seller_member (
    seller_member_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    member_id uuid NOT NULL,
    role text NOT NULL,
    status text DEFAULT 'INVITED' NOT NULL,
    invited_at timestamptz DEFAULT now() NOT NULL,
    joined_at timestamptz,
    left_at timestamptz,
    CONSTRAINT pk_seller_member PRIMARY KEY (seller_member_id),
    CONSTRAINT uq_seller_member_pair UNIQUE (seller_id, member_id),
    CONSTRAINT ck_seller_member_role CHECK (
        role IN ('OWNER', 'ADMIN', 'CATALOG_MANAGER', 'ORDER_MANAGER', 'FINANCE', 'VIEWER')
    ),
    CONSTRAINT ck_seller_member_status CHECK (
        status IN ('INVITED', 'ACTIVE', 'SUSPENDED', 'LEFT')
    ),
    CONSTRAINT ck_seller_member_joined_state CHECK (
        status NOT IN ('ACTIVE', 'SUSPENDED', 'LEFT') OR joined_at IS NOT NULL
    ),
    CONSTRAINT ck_seller_member_left_state CHECK (
        status <> 'LEFT' OR left_at IS NOT NULL
    )
);

CREATE TABLE marketplace.seller_document (
    document_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    document_type text NOT NULL,
    file_url text NOT NULL,
    content_hash text NOT NULL,
    retention_class text NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    issued_at date,
    expires_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    deleted_at timestamptz,
    CONSTRAINT pk_seller_document PRIMARY KEY (document_id),
    CONSTRAINT ck_seller_document_type CHECK (
        document_type IN (
            'BUSINESS_REGISTRATION', 'IDENTITY', 'BANK_ACCOUNT',
            'BRAND_AUTHORIZATION', 'TAX', 'OTHER'
        )
    ),
    CONSTRAINT ck_seller_document_file_url CHECK (char_length(btrim(file_url)) > 0),
    CONSTRAINT ck_seller_document_content_hash CHECK (char_length(btrim(content_hash)) > 0),
    CONSTRAINT ck_seller_document_retention CHECK (
        retention_class IN ('LEGAL', 'FINANCE', 'ONBOARDING', 'TEMPORARY')
    ),
    CONSTRAINT ck_seller_document_status CHECK (status IN ('ACTIVE', 'SUPERSEDED', 'DELETED')),
    CONSTRAINT ck_seller_document_deleted_state CHECK (
        status <> 'DELETED' OR deleted_at IS NOT NULL
    )
);

CREATE TABLE marketplace.seller_verification (
    verification_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    document_id uuid,
    verification_request_key text NOT NULL,
    verification_type text NOT NULL,
    provider text,
    status text DEFAULT 'REQUESTED' NOT NULL,
    result_hash text,
    result_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    requested_at timestamptz DEFAULT now() NOT NULL,
    verified_at timestamptz,
    expires_at timestamptz,
    CONSTRAINT pk_seller_verification PRIMARY KEY (verification_id),
    CONSTRAINT uq_seller_verification_request_key UNIQUE (verification_request_key),
    CONSTRAINT ck_seller_verification_request_key CHECK (
        char_length(btrim(verification_request_key)) > 0
    ),
    CONSTRAINT ck_seller_verification_type CHECK (
        verification_type IN ('BUSINESS', 'IDENTITY', 'BANK_ACCOUNT', 'BRAND', 'TAX')
    ),
    CONSTRAINT ck_seller_verification_status CHECK (
        status IN ('REQUESTED', 'PROCESSING', 'VERIFIED', 'FAILED', 'EXPIRED')
    ),
    CONSTRAINT ck_seller_verification_result_object CHECK (
        jsonb_typeof(result_snapshot) = 'object'
    ),
    CONSTRAINT ck_seller_verification_verified_state CHECK (
        status <> 'VERIFIED' OR (verified_at IS NOT NULL AND result_hash IS NOT NULL)
    ),
    CONSTRAINT ck_seller_verification_expiry CHECK (
        expires_at IS NULL OR verified_at IS NULL OR expires_at > verified_at
    )
);

CREATE TABLE marketplace.seller_settlement_account (
    account_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    bank_code text NOT NULL,
    account_cipher bytea NOT NULL,
    account_fingerprint text NOT NULL,
    holder_name_cipher bytea NOT NULL,
    verification_status text DEFAULT 'PENDING' NOT NULL,
    status text DEFAULT 'PENDING' NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    verified_at timestamptz,
    deactivated_at timestamptz,
    CONSTRAINT pk_seller_settlement_account PRIMARY KEY (account_id),
    CONSTRAINT uq_seller_settlement_account_fingerprint UNIQUE (seller_id, account_fingerprint),
    CONSTRAINT ck_seller_settlement_bank_code CHECK (char_length(btrim(bank_code)) > 0),
    CONSTRAINT ck_seller_settlement_account_cipher CHECK (octet_length(account_cipher) > 0),
    CONSTRAINT ck_seller_settlement_account_fingerprint CHECK (
        char_length(btrim(account_fingerprint)) > 0
    ),
    CONSTRAINT ck_seller_settlement_holder_cipher CHECK (octet_length(holder_name_cipher) > 0),
    CONSTRAINT ck_seller_settlement_verification_status CHECK (
        verification_status IN ('PENDING', 'VERIFIED', 'FAILED')
    ),
    CONSTRAINT ck_seller_settlement_status CHECK (
        status IN ('PENDING', 'ACTIVE', 'INACTIVE', 'BLOCKED')
    ),
    CONSTRAINT ck_seller_settlement_verified_state CHECK (
        verification_status <> 'VERIFIED' OR verified_at IS NOT NULL
    ),
    CONSTRAINT ck_seller_settlement_default_active CHECK (
        NOT is_default
        OR (
            status = 'ACTIVE'
            AND verification_status = 'VERIFIED'
            AND deactivated_at IS NULL
        )
    ),
    CONSTRAINT ck_seller_settlement_deactivated_state CHECK (
        status NOT IN ('INACTIVE', 'BLOCKED') OR deactivated_at IS NOT NULL
    )
);

CREATE TABLE marketplace.brand (
    brand_id uuid DEFAULT gen_random_uuid() NOT NULL,
    brand_name text NOT NULL,
    brand_name_normalized text NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_brand PRIMARY KEY (brand_id),
    CONSTRAINT uq_brand_name_normalized UNIQUE (brand_name_normalized),
    CONSTRAINT ck_brand_name CHECK (char_length(btrim(brand_name)) > 0),
    CONSTRAINT ck_brand_name_normalized CHECK (
        brand_name_normalized = lower(btrim(brand_name_normalized))
        AND char_length(brand_name_normalized) > 0
    ),
    CONSTRAINT ck_brand_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'MERGED'))
);

CREATE TABLE marketplace.seller_brand_relation (
    seller_brand_relation_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    brand_id uuid NOT NULL,
    relation_type text NOT NULL,
    verification_status text DEFAULT 'PENDING' NOT NULL,
    evidence_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    valid_from timestamptz,
    valid_to timestamptz,
    approved_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_seller_brand_relation PRIMARY KEY (seller_brand_relation_id),
    CONSTRAINT uq_seller_brand_relation_pair UNIQUE (seller_id, brand_id),
    CONSTRAINT ck_seller_brand_relation_type CHECK (
        relation_type IN ('OWNER', 'AUTHORIZED_RESELLER', 'DISTRIBUTOR', 'MARKETPLACE_AGENT')
    ),
    CONSTRAINT ck_seller_brand_verification_status CHECK (
        verification_status IN ('PENDING', 'APPROVED', 'REJECTED', 'REVOKED')
    ),
    CONSTRAINT ck_seller_brand_evidence_object CHECK (
        jsonb_typeof(evidence_snapshot) = 'object'
    ),
    CONSTRAINT ck_seller_brand_valid_period CHECK (
        valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from
    ),
    CONSTRAINT ck_seller_brand_approved_state CHECK (
        verification_status <> 'APPROVED' OR approved_at IS NOT NULL
    ),
    CONSTRAINT ck_seller_brand_revoked_state CHECK (
        verification_status <> 'REVOKED' OR revoked_at IS NOT NULL
    )
);

CREATE TABLE marketplace.brand_registration_request (
    request_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_id uuid NOT NULL,
    requested_name text NOT NULL,
    requested_name_normalized text NOT NULL,
    request_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'REQUESTED' NOT NULL,
    approved_brand_id uuid,
    reviewed_by_admin_user_id uuid,
    requested_at timestamptz DEFAULT now() NOT NULL,
    reviewed_at timestamptz,
    review_note text,
    CONSTRAINT pk_brand_registration_request PRIMARY KEY (request_id),
    CONSTRAINT ck_brand_registration_requested_name CHECK (
        char_length(btrim(requested_name)) > 0
    ),
    CONSTRAINT ck_brand_registration_normalized_name CHECK (
        requested_name_normalized = lower(btrim(requested_name_normalized))
        AND char_length(requested_name_normalized) > 0
    ),
    CONSTRAINT ck_brand_registration_snapshot_object CHECK (
        jsonb_typeof(request_snapshot) = 'object'
    ),
    CONSTRAINT ck_brand_registration_status CHECK (
        status IN ('REQUESTED', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'CANCELLED')
    ),
    CONSTRAINT ck_brand_registration_reviewed_state CHECK (
        status NOT IN ('APPROVED', 'REJECTED') OR reviewed_at IS NOT NULL
    ),
    CONSTRAINT ck_brand_registration_approved_state CHECK (
        status <> 'APPROVED' OR approved_brand_id IS NOT NULL
    )
);

CREATE TABLE marketplace.category (
    category_id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_category_id uuid,
    category_code text NOT NULL,
    category_name text NOT NULL,
    category_name_normalized text NOT NULL,
    is_leaf boolean DEFAULT true NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_category PRIMARY KEY (category_id),
    CONSTRAINT uq_category_code UNIQUE (category_code),
    CONSTRAINT ck_category_not_own_parent CHECK (
        parent_category_id IS NULL OR parent_category_id <> category_id
    ),
    CONSTRAINT ck_category_code CHECK (char_length(btrim(category_code)) > 0),
    CONSTRAINT ck_category_name CHECK (char_length(btrim(category_name)) > 0),
    CONSTRAINT ck_category_name_normalized CHECK (
        category_name_normalized = lower(btrim(category_name_normalized))
        AND char_length(category_name_normalized) > 0
    ),
    CONSTRAINT ck_category_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    CONSTRAINT ck_category_display_order CHECK (display_order >= 0)
);

CREATE TABLE marketplace.product (
    product_id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_brand_relation_id uuid NOT NULL,
    category_id uuid NOT NULL,
    seller_product_code text,
    sale_status text DEFAULT 'DRAFT' NOT NULL,
    current_revision_no integer,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    published_at timestamptz,
    archived_at timestamptz,
    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT uq_product_seller_relation_code UNIQUE (
        seller_brand_relation_id, seller_product_code
    ),
    CONSTRAINT ck_product_seller_code CHECK (
        seller_product_code IS NULL OR char_length(btrim(seller_product_code)) > 0
    ),
    CONSTRAINT ck_product_sale_status CHECK (
        sale_status IN ('DRAFT', 'IN_REVIEW', 'READY', 'ON_SALE', 'PAUSED', 'SOLD_OUT', 'ARCHIVED')
    ),
    CONSTRAINT ck_product_current_revision CHECK (
        current_revision_no IS NULL OR current_revision_no > 0
    ),
    CONSTRAINT ck_product_published_state CHECK (
        sale_status <> 'ON_SALE' OR published_at IS NOT NULL
    ),
    CONSTRAINT ck_product_archived_state CHECK (
        sale_status <> 'ARCHIVED' OR archived_at IS NOT NULL
    )
);

CREATE TABLE marketplace.product_revision (
    product_revision_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    revision_no integer NOT NULL,
    product_name text NOT NULL,
    description text,
    primary_image_id uuid,
    attributes_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_seller_member_id uuid,
    created_at timestamptz DEFAULT now() NOT NULL,
    published_at timestamptz,
    CONSTRAINT pk_product_revision PRIMARY KEY (product_revision_id),
    CONSTRAINT uq_product_revision_number UNIQUE (product_id, revision_no),
    CONSTRAINT ck_product_revision_number CHECK (revision_no > 0),
    CONSTRAINT ck_product_revision_name CHECK (char_length(btrim(product_name)) > 0),
    CONSTRAINT ck_product_revision_attributes_object CHECK (
        jsonb_typeof(attributes_snapshot) = 'object'
    )
);

CREATE TABLE marketplace.product_image (
    image_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    image_type text NOT NULL,
    image_url text NOT NULL,
    alt_text text,
    content_hash text,
    display_order integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    deleted_at timestamptz,
    CONSTRAINT pk_product_image PRIMARY KEY (image_id),
    CONSTRAINT uq_product_image_product_id UNIQUE (product_id, image_id),
    CONSTRAINT ck_product_image_type CHECK (image_type IN ('MAIN', 'DETAIL', 'SWATCH')),
    CONSTRAINT ck_product_image_url CHECK (char_length(btrim(image_url)) > 0),
    CONSTRAINT ck_product_image_display_order CHECK (display_order >= 0),
    CONSTRAINT ck_product_image_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED')),
    CONSTRAINT ck_product_image_deleted_state CHECK (
        status <> 'DELETED' OR deleted_at IS NOT NULL
    )
);

CREATE TABLE marketplace.product_feature (
    feature_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_revision_id uuid NOT NULL,
    feature_order integer NOT NULL,
    feature_text text NOT NULL,
    source_type text NOT NULL,
    source_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    confirmed_by_seller boolean DEFAULT false NOT NULL,
    confirmed_by_seller_member_id uuid,
    confirmed_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_product_feature PRIMARY KEY (feature_id),
    CONSTRAINT uq_product_feature_order UNIQUE (product_revision_id, feature_order),
    CONSTRAINT ck_product_feature_order CHECK (feature_order >= 0),
    CONSTRAINT ck_product_feature_text CHECK (char_length(btrim(feature_text)) > 0),
    CONSTRAINT ck_product_feature_source_type CHECK (
        source_type IN ('SELLER', 'AI', 'IMPORT', 'ADMIN')
    ),
    CONSTRAINT ck_product_feature_source_object CHECK (
        jsonb_typeof(source_snapshot) = 'object'
    ),
    CONSTRAINT ck_product_feature_confirmation CHECK (
        NOT confirmed_by_seller
        OR (confirmed_by_seller_member_id IS NOT NULL AND confirmed_at IS NOT NULL)
    )
);

CREATE TABLE marketplace.option_group (
    option_group_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    group_code text NOT NULL,
    display_name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_required boolean DEFAULT true NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_option_group PRIMARY KEY (option_group_id),
    CONSTRAINT uq_option_group_product_code UNIQUE (product_id, group_code),
    CONSTRAINT uq_option_group_product_id UNIQUE (product_id, option_group_id),
    CONSTRAINT ck_option_group_code CHECK (char_length(btrim(group_code)) > 0),
    CONSTRAINT ck_option_group_display_name CHECK (char_length(btrim(display_name)) > 0),
    CONSTRAINT ck_option_group_display_order CHECK (display_order >= 0),
    CONSTRAINT ck_option_group_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE marketplace.option_value (
    option_value_id uuid DEFAULT gen_random_uuid() NOT NULL,
    option_group_id uuid NOT NULL,
    value_code text NOT NULL,
    display_name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    value_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'ACTIVE' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_option_value PRIMARY KEY (option_value_id),
    CONSTRAINT uq_option_value_group_code UNIQUE (option_group_id, value_code),
    CONSTRAINT uq_option_value_group_id UNIQUE (option_group_id, option_value_id),
    CONSTRAINT ck_option_value_code CHECK (char_length(btrim(value_code)) > 0),
    CONSTRAINT ck_option_value_display_name CHECK (char_length(btrim(display_name)) > 0),
    CONSTRAINT ck_option_value_display_order CHECK (display_order >= 0),
    CONSTRAINT ck_option_value_metadata_object CHECK (jsonb_typeof(value_metadata) = 'object'),
    CONSTRAINT ck_option_value_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE marketplace.sku (
    sku_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    seller_sku_code text NOT NULL,
    combination_key text NOT NULL,
    sale_price bigint NOT NULL,
    currency char(3) DEFAULT 'KRW' NOT NULL,
    sku_status text DEFAULT 'DRAFT' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    archived_at timestamptz,
    CONSTRAINT pk_sku PRIMARY KEY (sku_id),
    CONSTRAINT uq_sku_product_seller_code UNIQUE (product_id, seller_sku_code),
    CONSTRAINT uq_sku_product_combination UNIQUE (product_id, combination_key),
    CONSTRAINT uq_sku_product_id UNIQUE (product_id, sku_id),
    CONSTRAINT ck_sku_seller_code CHECK (char_length(btrim(seller_sku_code)) > 0),
    CONSTRAINT ck_sku_combination_key CHECK (char_length(btrim(combination_key)) > 0),
    CONSTRAINT ck_sku_sale_price CHECK (sale_price >= 0),
    CONSTRAINT ck_sku_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_sku_status CHECK (
        sku_status IN ('DRAFT', 'ACTIVE', 'SOLD_OUT', 'INACTIVE', 'ARCHIVED')
    ),
    CONSTRAINT ck_sku_archived_state CHECK (
        sku_status <> 'ARCHIVED' OR archived_at IS NOT NULL
    )
);

CREATE TABLE marketplace.sku_option_value (
    sku_option_value_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    option_group_id uuid NOT NULL,
    option_value_id uuid NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_sku_option_value PRIMARY KEY (sku_option_value_id),
    CONSTRAINT uq_sku_option_group UNIQUE (sku_id, option_group_id)
);

CREATE TABLE marketplace.inventory (
    sku_id uuid DEFAULT gen_random_uuid() NOT NULL,
    on_hand_qty integer DEFAULT 0 NOT NULL,
    reserved_qty integer DEFAULT 0 NOT NULL,
    safety_stock_qty integer DEFAULT 0 NOT NULL,
    available_qty integer GENERATED ALWAYS AS (
        on_hand_qty - reserved_qty - safety_stock_qty
    ) STORED,
    version integer DEFAULT 0 NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_inventory PRIMARY KEY (sku_id),
    CONSTRAINT ck_inventory_on_hand_nonnegative CHECK (on_hand_qty >= 0),
    CONSTRAINT ck_inventory_reserved_nonnegative CHECK (reserved_qty >= 0),
    CONSTRAINT ck_inventory_safety_stock_nonnegative CHECK (safety_stock_qty >= 0),
    CONSTRAINT ck_inventory_available_nonnegative CHECK (
        on_hand_qty >= reserved_qty + safety_stock_qty
    ),
    CONSTRAINT ck_inventory_version_nonnegative CHECK (version >= 0)
);

CREATE TABLE marketplace.inventory_ledger (
    inventory_ledger_id uuid DEFAULT gen_random_uuid() NOT NULL,
    sku_id uuid NOT NULL,
    quantity_type text NOT NULL,
    signed_delta integer NOT NULL,
    balance_after integer NOT NULL,
    reason_type text NOT NULL,
    reference_type text NOT NULL,
    reference_key text NOT NULL,
    source_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamptz DEFAULT now() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_inventory_ledger PRIMARY KEY (inventory_ledger_id),
    CONSTRAINT uq_inventory_ledger_reference_key UNIQUE (reference_key),
    CONSTRAINT ck_inventory_ledger_quantity_type CHECK (
        quantity_type IN ('ON_HAND', 'RESERVED', 'SAFETY_STOCK')
    ),
    CONSTRAINT ck_inventory_ledger_nonzero_delta CHECK (signed_delta <> 0),
    CONSTRAINT ck_inventory_ledger_balance_nonnegative CHECK (balance_after >= 0),
    CONSTRAINT ck_inventory_ledger_reason_type CHECK (
        reason_type IN (
            'RECEIPT', 'RESERVE', 'RELEASE', 'SALE', 'CANCEL',
            'RETURN', 'ADJUSTMENT', 'SAFETY_STOCK_CHANGE'
        )
    ),
    CONSTRAINT ck_inventory_ledger_reference_type CHECK (
        char_length(btrim(reference_type)) > 0
    ),
    CONSTRAINT ck_inventory_ledger_reference_key CHECK (
        char_length(btrim(reference_key)) > 0
    ),
    CONSTRAINT ck_inventory_ledger_source_object CHECK (
        jsonb_typeof(source_snapshot) = 'object'
    )
);

CREATE TABLE marketplace.cart (
    cart_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    version integer NOT NULL DEFAULT 0,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT cart_status_ck CHECK (status IN ('ACTIVE', 'CHECKED_OUT', 'ABANDONED', 'MERGED')),
    CONSTRAINT cart_version_ck CHECK (version >= 0),
    CONSTRAINT cart_expires_at_ck CHECK (expires_at IS NULL OR expires_at > created_at),
    CONSTRAINT cart_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.cart_item (
    cart_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL,
    selected boolean NOT NULL DEFAULT true,
    price_display_cache bigint,
    currency varchar(3),
    added_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT cart_item_cart_sku_uq UNIQUE (cart_id, sku_id),
    CONSTRAINT cart_item_quantity_ck CHECK (quantity > 0),
    CONSTRAINT cart_item_price_cache_ck CHECK (price_display_cache IS NULL OR price_display_cache >= 0),
    CONSTRAINT cart_item_currency_ck CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    CONSTRAINT cart_item_updated_at_ck CHECK (updated_at >= added_at)
);

CREATE TABLE marketplace.checkout (
    checkout_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid NOT NULL,
    cart_id uuid,
    idempotency_key text NOT NULL,
    status text NOT NULL DEFAULT 'OPEN',
    currency varchar(3) NOT NULL,
    item_subtotal_amount bigint NOT NULL DEFAULT 0,
    discount_amount bigint NOT NULL DEFAULT 0,
    shipping_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    payable_amount bigint NOT NULL DEFAULT 0,
    pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    shipping_address_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 0,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT checkout_member_idempotency_uq UNIQUE (member_id, idempotency_key),
    CONSTRAINT checkout_status_ck CHECK (status IN ('OPEN', 'PRICED', 'RESERVED', 'ORDER_CREATED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT checkout_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT checkout_amounts_ck CHECK (
        item_subtotal_amount >= 0
        AND discount_amount >= 0
        AND shipping_amount >= 0
        AND tax_amount >= 0
        AND payable_amount >= 0
        AND discount_amount <= item_subtotal_amount
        AND payable_amount = item_subtotal_amount - discount_amount + shipping_amount + tax_amount
    ),
    CONSTRAINT checkout_pricing_snapshot_ck CHECK (jsonb_typeof(pricing_snapshot) = 'object'),
    CONSTRAINT checkout_address_snapshot_ck CHECK (jsonb_typeof(shipping_address_snapshot) = 'object'),
    CONSTRAINT checkout_version_ck CHECK (version >= 0),
    CONSTRAINT checkout_expires_at_ck CHECK (expires_at > created_at),
    CONSTRAINT checkout_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.checkout_shipping_group (
    checkout_shipping_group_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    group_key text NOT NULL,
    fulfillment_type text NOT NULL,
    shipping_method_code text,
    shipping_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    recipient_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    address_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    policy_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    promised_ship_at timestamptz,
    promised_delivery_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT checkout_shipping_group_key_uq UNIQUE (checkout_id, group_key),
    CONSTRAINT checkout_shipping_group_type_ck CHECK (fulfillment_type IN ('DELIVERY', 'PICKUP', 'DIGITAL')),
    CONSTRAINT checkout_shipping_group_amounts_ck CHECK (shipping_amount >= 0 AND tax_amount >= 0),
    CONSTRAINT checkout_shipping_group_recipient_ck CHECK (jsonb_typeof(recipient_snapshot) = 'object'),
    CONSTRAINT checkout_shipping_group_address_ck CHECK (jsonb_typeof(address_snapshot) = 'object'),
    CONSTRAINT checkout_shipping_group_policy_ck CHECK (jsonb_typeof(policy_snapshot) = 'object'),
    CONSTRAINT checkout_shipping_group_promise_ck CHECK (
        promised_ship_at IS NULL
        OR promised_delivery_at IS NULL
        OR promised_delivery_at >= promised_ship_at
    )
);

CREATE TABLE marketplace.checkout_item (
    checkout_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL,
    checkout_shipping_group_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    product_revision_id uuid,
    line_number integer NOT NULL,
    quantity integer NOT NULL,
    unit_price_amount bigint NOT NULL,
    product_amount bigint NOT NULL,
    discount_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    paid_amount bigint NOT NULL,
    product_snapshot jsonb NOT NULL,
    option_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT checkout_item_line_uq UNIQUE (checkout_id, line_number),
    CONSTRAINT checkout_item_line_number_ck CHECK (line_number > 0),
    CONSTRAINT checkout_item_quantity_ck CHECK (quantity > 0),
    CONSTRAINT checkout_item_amounts_ck CHECK (
        unit_price_amount >= 0
        AND product_amount = unit_price_amount * quantity
        AND discount_amount >= 0
        AND discount_amount <= product_amount
        AND tax_amount >= 0
        AND paid_amount = product_amount - discount_amount + tax_amount
    ),
    CONSTRAINT checkout_item_product_snapshot_ck CHECK (jsonb_typeof(product_snapshot) = 'object'),
    CONSTRAINT checkout_item_option_snapshot_ck CHECK (jsonb_typeof(option_snapshot) = 'object'),
    CONSTRAINT checkout_item_pricing_snapshot_ck CHECK (jsonb_typeof(pricing_snapshot) = 'object')
);

CREATE TABLE marketplace.inventory_reservation (
    reservation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL,
    idempotency_key text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    version integer NOT NULL DEFAULT 0,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    released_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT inventory_reservation_checkout_uq UNIQUE (checkout_id),
    CONSTRAINT inventory_reservation_idempotency_uq UNIQUE (idempotency_key),
    CONSTRAINT inventory_reservation_status_ck CHECK (status IN ('ACTIVE', 'CONSUMED', 'RELEASED', 'EXPIRED')),
    CONSTRAINT inventory_reservation_version_ck CHECK (version >= 0),
    CONSTRAINT inventory_reservation_expires_at_ck CHECK (expires_at > created_at),
    CONSTRAINT inventory_reservation_terminal_time_ck CHECK (
        (status = 'CONSUMED' AND consumed_at IS NOT NULL AND released_at IS NULL)
        OR (status IN ('RELEASED', 'EXPIRED') AND released_at IS NOT NULL AND consumed_at IS NULL)
        OR (status = 'ACTIVE' AND consumed_at IS NULL AND released_at IS NULL)
    ),
    CONSTRAINT inventory_reservation_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.inventory_reservation_item (
    reservation_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL,
    consumed_quantity integer NOT NULL DEFAULT 0,
    released_quantity integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'RESERVED',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT inventory_reservation_item_sku_uq UNIQUE (reservation_id, sku_id),
    CONSTRAINT inventory_reservation_item_quantities_ck CHECK (
        quantity > 0
        AND consumed_quantity >= 0
        AND released_quantity >= 0
        AND consumed_quantity + released_quantity <= quantity
    ),
    CONSTRAINT inventory_reservation_item_status_ck CHECK (status IN ('RESERVED', 'PARTIALLY_CONSUMED', 'CONSUMED', 'RELEASED', 'EXPIRED')),
    CONSTRAINT inventory_reservation_item_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.orders (
    order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL,
    member_id uuid NOT NULL,
    order_number text NOT NULL,
    order_status text NOT NULL DEFAULT 'PENDING_PAYMENT',
    currency varchar(3) NOT NULL,
    item_subtotal_amount bigint NOT NULL,
    discount_amount bigint NOT NULL DEFAULT 0,
    shipping_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    payable_amount bigint NOT NULL,
    purchaser_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    payment_due_at timestamptz,
    ordered_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    completed_at timestamptz,
    version integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT orders_checkout_uq UNIQUE (checkout_id),
    CONSTRAINT orders_order_number_uq UNIQUE (order_number),
    CONSTRAINT orders_status_ck CHECK (order_status IN (
        'PENDING_PAYMENT', 'PAID', 'PROCESSING', 'PARTIALLY_SHIPPED', 'SHIPPED',
        'PARTIALLY_COMPLETED', 'COMPLETED', 'PAYMENT_FAILED', 'CANCELLED'
    )),
    CONSTRAINT orders_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT orders_amounts_ck CHECK (
        item_subtotal_amount >= 0
        AND discount_amount >= 0
        AND discount_amount <= item_subtotal_amount
        AND shipping_amount >= 0
        AND tax_amount >= 0
        AND payable_amount = item_subtotal_amount - discount_amount + shipping_amount + tax_amount
    ),
    CONSTRAINT orders_purchaser_snapshot_ck CHECK (jsonb_typeof(purchaser_snapshot) = 'object'),
    CONSTRAINT orders_version_ck CHECK (version >= 0),
    CONSTRAINT orders_payment_due_ck CHECK (payment_due_at IS NULL OR payment_due_at >= ordered_at),
    CONSTRAINT orders_cancelled_at_ck CHECK (cancelled_at IS NULL OR cancelled_at >= ordered_at),
    CONSTRAINT orders_completed_at_ck CHECK (completed_at IS NULL OR completed_at >= ordered_at),
    CONSTRAINT orders_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.order_shipping_group (
    order_shipping_group_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    checkout_shipping_group_id uuid,
    seller_id uuid NOT NULL,
    group_number integer NOT NULL,
    fulfillment_type text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    shipping_method_code text,
    recipient_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    address_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    policy_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    shipping_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    promised_ship_at timestamptz,
    promised_delivery_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT order_shipping_group_number_uq UNIQUE (order_id, group_number),
    CONSTRAINT order_shipping_group_checkout_uq UNIQUE (checkout_shipping_group_id),
    CONSTRAINT order_shipping_group_number_ck CHECK (group_number > 0),
    CONSTRAINT order_shipping_group_type_ck CHECK (fulfillment_type IN ('DELIVERY', 'PICKUP', 'DIGITAL')),
    CONSTRAINT order_shipping_group_status_ck CHECK (status IN ('PENDING', 'READY', 'PARTIALLY_SHIPPED', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    CONSTRAINT order_shipping_group_amounts_ck CHECK (shipping_amount >= 0 AND tax_amount >= 0),
    CONSTRAINT order_shipping_group_recipient_ck CHECK (jsonb_typeof(recipient_snapshot) = 'object'),
    CONSTRAINT order_shipping_group_address_ck CHECK (jsonb_typeof(address_snapshot) = 'object'),
    CONSTRAINT order_shipping_group_policy_ck CHECK (jsonb_typeof(policy_snapshot) = 'object'),
    CONSTRAINT order_shipping_group_promise_ck CHECK (
        promised_ship_at IS NULL
        OR promised_delivery_at IS NULL
        OR promised_delivery_at >= promised_ship_at
    ),
    CONSTRAINT order_shipping_group_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.order_item (
    order_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    checkout_item_id uuid NOT NULL,
    order_shipping_group_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    product_id uuid NOT NULL,
    product_revision_id uuid,
    sku_id uuid NOT NULL,
    line_number integer NOT NULL,
    ordered_quantity integer NOT NULL,
    unit_price_amount bigint NOT NULL,
    product_amount bigint NOT NULL,
    discount_amount bigint NOT NULL DEFAULT 0,
    tax_amount bigint NOT NULL DEFAULT 0,
    paid_amount bigint NOT NULL,
    seller_snapshot jsonb NOT NULL,
    product_snapshot jsonb NOT NULL,
    option_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT order_item_line_uq UNIQUE (order_id, line_number),
    CONSTRAINT order_item_checkout_item_uq UNIQUE (checkout_item_id),
    CONSTRAINT order_item_line_number_ck CHECK (line_number > 0),
    CONSTRAINT order_item_quantity_ck CHECK (ordered_quantity > 0),
    CONSTRAINT order_item_amounts_ck CHECK (
        unit_price_amount >= 0
        AND product_amount = unit_price_amount * ordered_quantity
        AND discount_amount >= 0
        AND discount_amount <= product_amount
        AND tax_amount >= 0
        AND paid_amount = product_amount - discount_amount + tax_amount
    ),
    CONSTRAINT order_item_seller_snapshot_ck CHECK (jsonb_typeof(seller_snapshot) = 'object'),
    CONSTRAINT order_item_product_snapshot_ck CHECK (jsonb_typeof(product_snapshot) = 'object'),
    CONSTRAINT order_item_option_snapshot_ck CHECK (jsonb_typeof(option_snapshot) = 'object'),
    CONSTRAINT order_item_pricing_snapshot_ck CHECK (jsonb_typeof(pricing_snapshot) = 'object')
);

CREATE TABLE marketplace.order_charge (
    order_charge_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    order_shipping_group_id uuid,
    charge_key text NOT NULL,
    charge_type text NOT NULL,
    description text,
    original_amount bigint NOT NULL,
    tax_amount bigint NOT NULL DEFAULT 0,
    refunded_amount bigint NOT NULL DEFAULT 0,
    version integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT order_charge_key_uq UNIQUE (order_id, charge_key),
    CONSTRAINT order_charge_type_ck CHECK (charge_type IN ('SHIPPING', 'REMOTE_AREA', 'GIFT_WRAP', 'SERVICE', 'OTHER')),
    CONSTRAINT order_charge_amounts_ck CHECK (
        original_amount >= 0
        AND tax_amount >= 0
        AND refunded_amount >= 0
        AND refunded_amount <= original_amount + tax_amount
    ),
    CONSTRAINT order_charge_version_ck CHECK (version >= 0),
    CONSTRAINT order_charge_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.order_state_event (
    order_state_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    event_type text NOT NULL,
    from_status text,
    to_status text NOT NULL,
    actor_type text NOT NULL DEFAULT 'SYSTEM',
    actor_id uuid,
    reason_code text,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key text NOT NULL,
    occurred_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT order_state_event_idempotency_uq UNIQUE (order_id, idempotency_key),
    CONSTRAINT order_state_event_actor_type_ck CHECK (actor_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM', 'PG')),
    CONSTRAINT order_state_event_transition_ck CHECK (from_status IS NULL OR from_status <> to_status),
    CONSTRAINT order_state_event_payload_ck CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT order_state_event_recorded_at_ck CHECK (recorded_at >= occurred_at)
);

CREATE TABLE marketplace.shipment (
    shipment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    order_shipping_group_id uuid,
    seller_id uuid NOT NULL,
    claim_id uuid,
    direction text NOT NULL,
    purpose text NOT NULL,
    status text NOT NULL DEFAULT 'READY',
    carrier_code text,
    tracking_number text,
    service_level text,
    origin_address_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    destination_address_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    policy_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    shipped_at timestamptz,
    delivered_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT shipment_tracking_uq UNIQUE (carrier_code, tracking_number),
    CONSTRAINT shipment_direction_ck CHECK (direction IN ('OUTBOUND', 'INBOUND')),
    CONSTRAINT shipment_purpose_ck CHECK (purpose IN ('ORDER_FULFILLMENT', 'RETURN_PICKUP', 'EXCHANGE_DELIVERY')),
    CONSTRAINT shipment_direction_purpose_ck CHECK (
        (purpose IN ('ORDER_FULFILLMENT', 'EXCHANGE_DELIVERY') AND direction = 'OUTBOUND')
        OR (purpose = 'RETURN_PICKUP' AND direction = 'INBOUND')
    ),
    CONSTRAINT shipment_status_ck CHECK (status IN ('READY', 'HANDED_OVER', 'IN_TRANSIT', 'DELIVERED', 'LOST', 'FAILED', 'CANCELLED')),
    CONSTRAINT shipment_tracking_pair_ck CHECK ((carrier_code IS NULL) = (tracking_number IS NULL)),
    CONSTRAINT shipment_origin_snapshot_ck CHECK (jsonb_typeof(origin_address_snapshot) = 'object'),
    CONSTRAINT shipment_destination_snapshot_ck CHECK (jsonb_typeof(destination_address_snapshot) = 'object'),
    CONSTRAINT shipment_policy_snapshot_ck CHECK (jsonb_typeof(policy_snapshot) = 'object'),
    CONSTRAINT shipment_times_ck CHECK (
        delivered_at IS NULL
        OR shipped_at IS NULL
        OR delivered_at >= shipped_at
    ),
    CONSTRAINT shipment_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.shipment_item (
    shipment_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    exchange_line_id uuid,
    quantity integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT shipment_item_line_uq UNIQUE (shipment_id, order_item_id, sku_id),
    CONSTRAINT shipment_item_quantity_ck CHECK (quantity > 0)
);

CREATE TABLE marketplace.shipment_event (
    shipment_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL,
    provider text,
    provider_event_id text,
    event_type text NOT NULL,
    location_text text,
    description text,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT shipment_event_provider_event_uq UNIQUE (provider, provider_event_id),
    CONSTRAINT shipment_event_provider_pair_ck CHECK ((provider IS NULL) = (provider_event_id IS NULL)),
    CONSTRAINT shipment_event_payload_ck CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT shipment_event_received_at_ck CHECK (received_at >= occurred_at)
);

CREATE TABLE marketplace.purchase_confirmation_state (
    shipment_item_id uuid PRIMARY KEY,
    delivered_quantity integer NOT NULL DEFAULT 0,
    confirmed_quantity integer NOT NULL DEFAULT 0,
    held_quantity integer NOT NULL DEFAULT 0,
    auto_confirm_at timestamptz,
    last_delivered_at timestamptz,
    last_confirmed_at timestamptz,
    version integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT purchase_confirmation_quantities_ck CHECK (
        delivered_quantity >= 0
        AND confirmed_quantity >= 0
        AND held_quantity >= 0
        AND confirmed_quantity + held_quantity <= delivered_quantity
    ),
    CONSTRAINT purchase_confirmation_version_ck CHECK (version >= 0),
    CONSTRAINT purchase_confirmation_times_ck CHECK (
        (last_delivered_at IS NULL OR last_delivered_at >= created_at)
        AND (last_confirmed_at IS NULL OR last_confirmed_at >= created_at)
        AND (auto_confirm_at IS NULL OR auto_confirm_at >= COALESCE(last_delivered_at, created_at))
    ),
    CONSTRAINT purchase_confirmation_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.purchase_confirmation_event (
    confirmation_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_item_id uuid NOT NULL,
    event_type text NOT NULL,
    quantity integer NOT NULL,
    actor_type text NOT NULL DEFAULT 'SYSTEM',
    actor_id uuid,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT purchase_confirmation_event_idempotency_uq UNIQUE (shipment_item_id, idempotency_key),
    CONSTRAINT purchase_confirmation_event_type_ck CHECK (event_type IN ('DELIVERY_RECORDED', 'MANUAL_CONFIRMED', 'AUTO_CONFIRMED', 'HOLD_PLACED', 'HOLD_RELEASED', 'ADJUSTED')),
    CONSTRAINT purchase_confirmation_event_quantity_ck CHECK (quantity > 0),
    CONSTRAINT purchase_confirmation_event_actor_ck CHECK (actor_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM', 'CARRIER')),
    CONSTRAINT purchase_confirmation_event_payload_ck CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT purchase_confirmation_event_recorded_at_ck CHECK (recorded_at >= occurred_at)
);

CREATE TABLE marketplace.purchase_confirmation_hold (
    hold_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_item_id uuid NOT NULL,
    claim_item_id uuid NOT NULL,
    held_quantity integer NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    reason_code text,
    held_at timestamptz NOT NULL DEFAULT now(),
    released_at timestamptz,
    CONSTRAINT purchase_confirmation_hold_source_uq UNIQUE (shipment_item_id, claim_item_id),
    CONSTRAINT purchase_confirmation_hold_quantity_ck CHECK (held_quantity > 0),
    CONSTRAINT purchase_confirmation_hold_status_ck CHECK (status IN ('ACTIVE', 'RELEASED', 'CANCELLED')),
    CONSTRAINT purchase_confirmation_hold_release_ck CHECK (
        (status = 'ACTIVE' AND released_at IS NULL)
        OR (status IN ('RELEASED', 'CANCELLED') AND released_at IS NOT NULL AND released_at >= held_at)
    )
);

CREATE TABLE marketplace.claim (
    claim_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid NOT NULL,
    order_id uuid NOT NULL,
    claim_number text NOT NULL,
    idempotency_key text NOT NULL,
    claim_type text NOT NULL,
    status text NOT NULL DEFAULT 'REQUESTED',
    reason_code text NOT NULL,
    reason_detail text,
    responsibility text NOT NULL DEFAULT 'UNKNOWN',
    currency varchar(3) NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    approved_at timestamptz,
    refund_due_at timestamptz,
    completed_at timestamptz,
    version integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_number_uq UNIQUE (claim_number),
    CONSTRAINT claim_member_idempotency_uq UNIQUE (member_id, idempotency_key),
    CONSTRAINT claim_type_ck CHECK (claim_type IN ('CANCEL', 'RETURN', 'EXCHANGE')),
    CONSTRAINT claim_status_ck CHECK (status IN (
        'REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'PICKUP_PENDING',
        'IN_TRANSIT', 'RECEIVED', 'INSPECTING', 'REFUND_PENDING', 'COMPLETED', 'CANCELLED'
    )),
    CONSTRAINT claim_responsibility_ck CHECK (responsibility IN ('UNKNOWN', 'BUYER', 'SELLER', 'CARRIER', 'PLATFORM')),
    CONSTRAINT claim_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT claim_version_ck CHECK (version >= 0),
    CONSTRAINT claim_times_ck CHECK (
        (approved_at IS NULL OR approved_at >= requested_at)
        AND (refund_due_at IS NULL OR refund_due_at >= requested_at)
        AND (completed_at IS NULL OR completed_at >= requested_at)
        AND updated_at >= created_at
    )
);

CREATE TABLE marketplace.claim_item (
    claim_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'REQUESTED',
    quantity integer NOT NULL,
    approved_quantity integer NOT NULL DEFAULT 0,
    received_quantity integer NOT NULL DEFAULT 0,
    accepted_quantity integer NOT NULL DEFAULT 0,
    rejected_quantity integer NOT NULL DEFAULT 0,
    responsibility text NOT NULL DEFAULT 'UNKNOWN',
    expected_refund_amount bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_item_order_item_uq UNIQUE (claim_id, order_item_id),
    CONSTRAINT claim_item_status_ck CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED', 'IN_TRANSIT', 'RECEIVED', 'INSPECTING', 'ACCEPTED', 'PARTIALLY_ACCEPTED', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT claim_item_quantities_ck CHECK (
        quantity > 0
        AND approved_quantity BETWEEN 0 AND quantity
        AND received_quantity BETWEEN 0 AND quantity
        AND accepted_quantity BETWEEN 0 AND received_quantity
        AND rejected_quantity BETWEEN 0 AND received_quantity
        AND accepted_quantity + rejected_quantity <= received_quantity
    ),
    CONSTRAINT claim_item_responsibility_ck CHECK (responsibility IN ('UNKNOWN', 'BUYER', 'SELLER', 'CARRIER', 'PLATFORM')),
    CONSTRAINT claim_item_refund_ck CHECK (expected_refund_amount >= 0),
    CONSTRAINT claim_item_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.claim_item_source_allocation (
    source_allocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_item_id uuid NOT NULL,
    outbound_shipment_item_id uuid NOT NULL,
    quantity integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_item_source_allocation_uq UNIQUE (claim_item_id, outbound_shipment_item_id),
    CONSTRAINT claim_item_source_allocation_quantity_ck CHECK (quantity > 0)
);

CREATE TABLE marketplace.claim_evidence (
    evidence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL,
    claim_item_id uuid,
    evidence_type text NOT NULL,
    file_url text,
    description text,
    content_hash text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    submitted_by_type text NOT NULL,
    submitted_by_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_evidence_type_ck CHECK (evidence_type IN ('PHOTO', 'VIDEO', 'DOCUMENT', 'TEXT', 'TRACKING', 'INSPECTION_REPORT')),
    CONSTRAINT claim_evidence_content_ck CHECK (file_url IS NOT NULL OR description IS NOT NULL),
    CONSTRAINT claim_evidence_hash_ck CHECK (content_hash IS NULL OR content_hash ~ '^[0-9A-Fa-f]{64}$'),
    CONSTRAINT claim_evidence_file_hash_ck CHECK (file_url IS NULL OR content_hash IS NOT NULL),
    CONSTRAINT claim_evidence_metadata_ck CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT claim_evidence_submitter_ck CHECK (submitted_by_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM', 'CARRIER'))
);

CREATE TABLE marketplace.claim_reason_change (
    reason_change_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL,
    from_reason text NOT NULL,
    to_reason text NOT NULL,
    request_note text,
    requested_by_type text NOT NULL,
    requested_by_id uuid,
    status text NOT NULL DEFAULT 'REQUESTED',
    reviewed_by_id uuid,
    review_note text,
    requested_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT claim_reason_change_reason_ck CHECK (from_reason <> to_reason),
    CONSTRAINT claim_reason_change_requester_ck CHECK (requested_by_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM')),
    CONSTRAINT claim_reason_change_status_ck CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED')),
    CONSTRAINT claim_reason_change_resolution_ck CHECK (
        (status = 'REQUESTED' AND resolved_at IS NULL)
        OR (status IN ('APPROVED', 'REJECTED', 'CANCELLED') AND resolved_at IS NOT NULL AND resolved_at >= requested_at)
    )
);

CREATE TABLE marketplace.claim_review (
    claim_review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL,
    claim_item_id uuid,
    reviewer_type text NOT NULL,
    reviewer_id uuid,
    decision text NOT NULL,
    rationale text,
    evidence_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
    confidence numeric(5,4),
    model_version text,
    policy_version text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_review_reviewer_type_ck CHECK (reviewer_type IN ('AI', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM')),
    CONSTRAINT claim_review_decision_ck CHECK (decision IN ('APPROVE', 'REJECT', 'PARTIAL_APPROVE', 'ESCALATE', 'NO_DECISION')),
    CONSTRAINT claim_review_confidence_ck CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    CONSTRAINT claim_review_ai_version_ck CHECK (reviewer_type <> 'AI' OR model_version IS NOT NULL),
    CONSTRAINT claim_review_human_id_ck CHECK (reviewer_type NOT IN ('SELLER_MEMBER', 'ADMIN') OR reviewer_id IS NOT NULL),
    CONSTRAINT claim_review_evidence_ck CHECK (jsonb_typeof(evidence_summary) = 'object')
);

CREATE TABLE marketplace.claim_event (
    claim_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL,
    claim_item_id uuid,
    event_type text NOT NULL,
    from_status text,
    to_status text,
    quantity integer,
    actor_type text NOT NULL DEFAULT 'SYSTEM',
    actor_id uuid,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_event_idempotency_uq UNIQUE (claim_id, idempotency_key),
    CONSTRAINT claim_event_transition_ck CHECK (from_status IS NULL OR to_status IS NULL OR from_status <> to_status),
    CONSTRAINT claim_event_quantity_ck CHECK (quantity IS NULL OR quantity > 0),
    CONSTRAINT claim_event_actor_type_ck CHECK (actor_type IN ('MEMBER', 'SELLER_MEMBER', 'ADMIN', 'SYSTEM', 'CARRIER', 'PG')),
    CONSTRAINT claim_event_payload_ck CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT claim_event_recorded_at_ck CHECK (recorded_at >= occurred_at)
);

CREATE TABLE marketplace.exchange_line (
    exchange_line_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_item_id uuid NOT NULL,
    replacement_sku_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_difference bigint NOT NULL DEFAULT 0,
    currency varchar(3) NOT NULL,
    status text NOT NULL DEFAULT 'REQUESTED',
    replacement_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT exchange_line_sku_uq UNIQUE (claim_item_id, replacement_sku_id),
    CONSTRAINT exchange_line_quantity_ck CHECK (quantity > 0),
    CONSTRAINT exchange_line_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT exchange_line_status_ck CHECK (status IN ('REQUESTED', 'RESERVED', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    CONSTRAINT exchange_line_snapshot_ck CHECK (jsonb_typeof(replacement_snapshot) = 'object'),
    CONSTRAINT exchange_line_updated_at_ck CHECK (updated_at >= created_at)
);

CREATE TABLE marketplace.review_eligibility (
    order_item_id uuid PRIMARY KEY,
    eligible_quantity integer NOT NULL,
    reviewed_quantity integer NOT NULL DEFAULT 0,
    eligible_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revocation_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_review_eligibility_quantities CHECK (
        eligible_quantity > 0
        AND reviewed_quantity >= 0
        AND reviewed_quantity <= eligible_quantity
    ),
    CONSTRAINT ck_review_eligibility_revocation CHECK (
        revoked_at IS NULL OR revocation_reason IS NOT NULL
    )
);

CREATE TABLE marketplace.review (
    review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id uuid NOT NULL,
    member_id uuid NOT NULL,
    rating integer NOT NULL,
    content text,
    status text NOT NULL DEFAULT 'PUBLISHED',
    moderation_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT uq_review_order_item UNIQUE (order_item_id),
    CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_review_content_length CHECK (
        content IS NULL OR char_length(content) <= 10000
    ),
    CONSTRAINT ck_review_status CHECK (status IN (
        'PENDING_MODERATION', 'PUBLISHED', 'HIDDEN', 'DELETED'
    )),
    CONSTRAINT ck_review_deleted_state CHECK (
        (status = 'DELETED' AND deleted_at IS NOT NULL)
        OR (status <> 'DELETED' AND deleted_at IS NULL)
    )
);

CREATE TABLE marketplace.review_revision (
    review_revision_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id uuid NOT NULL,
    revision_no integer NOT NULL,
    revision_action text NOT NULL,
    rating integer NOT NULL,
    content text,
    review_status text NOT NULL,
    change_reason text,
    changed_by_type text NOT NULL,
    changed_by_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_review_revision_no UNIQUE (review_id, revision_no),
    CONSTRAINT ck_review_revision_no CHECK (revision_no > 0),
    CONSTRAINT ck_review_revision_action CHECK (revision_action IN (
        'CREATED', 'EDITED', 'HIDDEN', 'RESTORED', 'DELETED'
    )),
    CONSTRAINT ck_review_revision_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_review_revision_content_length CHECK (
        content IS NULL OR char_length(content) <= 10000
    ),
    CONSTRAINT ck_review_revision_status CHECK (review_status IN (
        'PENDING_MODERATION', 'PUBLISHED', 'HIDDEN', 'DELETED'
    )),
    CONSTRAINT ck_review_revision_actor CHECK (changed_by_type IN (
        'MEMBER', 'ADMIN', 'SYSTEM'
    )),
    CONSTRAINT ck_review_revision_actor_id CHECK (
        (changed_by_type = 'SYSTEM' AND changed_by_id IS NULL)
        OR (changed_by_type <> 'SYSTEM' AND changed_by_id IS NOT NULL)
    )
);

CREATE TABLE marketplace.review_image (
    review_image_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id uuid NOT NULL,
    review_revision_id uuid,
    storage_uri text NOT NULL,
    content_hash text,
    alt_text text,
    display_order integer NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT uq_review_image_storage UNIQUE (review_id, storage_uri),
    CONSTRAINT ck_review_image_order CHECK (display_order >= 0),
    CONSTRAINT ck_review_image_status CHECK (status IN ('ACTIVE', 'DELETED', 'REJECTED')),
    CONSTRAINT ck_review_image_deleted_state CHECK (
        (status = 'ACTIVE' AND deleted_at IS NULL)
        OR (status <> 'ACTIVE' AND deleted_at IS NOT NULL)
    ),
    CONSTRAINT ck_review_image_uri_not_blank CHECK (btrim(storage_uri) <> '')
);

CREATE TABLE marketplace.seller_review_reply (
    reply_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id uuid NOT NULL,
    seller_member_id uuid NOT NULL,
    content text NOT NULL,
    status text NOT NULL DEFAULT 'PUBLISHED',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT uq_seller_review_reply_review UNIQUE (review_id),
    CONSTRAINT ck_seller_review_reply_content CHECK (
        btrim(content) <> '' AND char_length(content) <= 5000
    ),
    CONSTRAINT ck_seller_review_reply_status CHECK (status IN ('PUBLISHED', 'HIDDEN', 'DELETED')),
    CONSTRAINT ck_seller_review_reply_deleted_state CHECK (
        (status = 'DELETED' AND deleted_at IS NOT NULL)
        OR (status <> 'DELETED' AND deleted_at IS NULL)
    )
);

CREATE TABLE marketplace.wishlist_item (
    member_id uuid NOT NULL,
    product_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_wishlist_item PRIMARY KEY (member_id, product_id)
);

CREATE TABLE marketplace.notification (
    notification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid,
    seller_id uuid,
    event_type text NOT NULL,
    importance text NOT NULL DEFAULT 'NORMAL',
    mandatory boolean NOT NULL DEFAULT false,
    dedupe_key text NOT NULL,
    payload jsonb NOT NULL,
    scheduled_at timestamptz,
    expires_at timestamptz,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_dedupe_key UNIQUE (dedupe_key),
    CONSTRAINT ck_notification_one_recipient CHECK (num_nonnulls(member_id, seller_id) = 1),
    CONSTRAINT ck_notification_importance CHECK (importance IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    CONSTRAINT ck_notification_event_type CHECK (btrim(event_type) <> ''),
    CONSTRAINT ck_notification_dedupe_key CHECK (btrim(dedupe_key) <> ''),
    CONSTRAINT ck_notification_payload_object CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT ck_notification_expiry CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE TABLE marketplace.notification_preference (
    preference_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid,
    seller_id uuid,
    event_type text NOT NULL,
    channel text NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    timezone text NOT NULL DEFAULT 'Asia/Seoul',
    quiet_hours_start time,
    quiet_hours_end time,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_preference_recipient UNIQUE NULLS NOT DISTINCT (
        member_id, seller_id, event_type, channel
    ),
    CONSTRAINT ck_notification_preference_one_recipient CHECK (
        num_nonnulls(member_id, seller_id) = 1
    ),
    CONSTRAINT ck_notification_preference_channel CHECK (channel IN (
        'IN_APP', 'EMAIL', 'SMS', 'PUSH', 'WEBHOOK'
    )),
    CONSTRAINT ck_notification_preference_event CHECK (btrim(event_type) <> ''),
    CONSTRAINT ck_notification_preference_timezone CHECK (btrim(timezone) <> ''),
    CONSTRAINT ck_notification_preference_quiet_hours CHECK (
        (quiet_hours_start IS NULL AND quiet_hours_end IS NULL)
        OR (quiet_hours_start IS NOT NULL AND quiet_hours_end IS NOT NULL)
    ),
    UNIQUE (member_id, seller_id, event_type, channel)
);

CREATE TABLE marketplace.notification_delivery (
    delivery_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    channel text NOT NULL,
    attempt_no integer NOT NULL,
    status text NOT NULL DEFAULT 'QUEUED',
    provider text,
    provider_message_id text,
    requested_at timestamptz NOT NULL DEFAULT now(),
    sent_at timestamptz,
    delivered_at timestamptz,
    failed_at timestamptz,
    error_code text,
    error_message text,
    provider_response jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT uq_notification_delivery_attempt UNIQUE (
        notification_id, channel, attempt_no
    ),
    CONSTRAINT uq_notification_provider_message UNIQUE (provider, provider_message_id),
    CONSTRAINT ck_notification_delivery_attempt CHECK (attempt_no > 0),
    CONSTRAINT ck_notification_delivery_channel CHECK (channel IN (
        'IN_APP', 'EMAIL', 'SMS', 'PUSH', 'WEBHOOK'
    )),
    CONSTRAINT ck_notification_delivery_status CHECK (status IN (
        'QUEUED', 'SENDING', 'SENT', 'DELIVERED', 'FAILED', 'SUPPRESSED'
    )),
    CONSTRAINT ck_notification_delivery_sent CHECK (
        status NOT IN ('SENT', 'DELIVERED') OR sent_at IS NOT NULL
    ),
    CONSTRAINT ck_notification_delivery_delivered CHECK (
        status <> 'DELIVERED' OR delivered_at IS NOT NULL
    ),
    CONSTRAINT ck_notification_delivery_failed CHECK (
        status <> 'FAILED' OR failed_at IS NOT NULL
    ),
    CONSTRAINT ck_notification_provider_response_object CHECK (
        jsonb_typeof(provider_response) = 'object'
    )
);

CREATE TABLE marketplace.admin_user (
    admin_user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_subject text NOT NULL,
    email text,
    display_name text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    last_login_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    disabled_at timestamptz,
    CONSTRAINT uq_admin_user_identity_subject UNIQUE (identity_subject),
    CONSTRAINT uq_admin_user_email UNIQUE (email),
    CONSTRAINT ck_admin_user_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DISABLED')),
    CONSTRAINT ck_admin_user_disabled_state CHECK (
        (status = 'DISABLED' AND disabled_at IS NOT NULL)
        OR (status <> 'DISABLED' AND disabled_at IS NULL)
    ),
    CONSTRAINT ck_admin_user_identity_not_blank CHECK (btrim(identity_subject) <> ''),
    CONSTRAINT ck_admin_user_name_not_blank CHECK (btrim(display_name) <> '')
);

CREATE TABLE marketplace.admin_role (
    admin_role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code text NOT NULL,
    name text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_admin_role_code UNIQUE (role_code),
    CONSTRAINT ck_admin_role_status CHECK (status IN ('ACTIVE', 'DISABLED')),
    CONSTRAINT ck_admin_role_code_not_blank CHECK (btrim(role_code) <> ''),
    CONSTRAINT ck_admin_role_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE marketplace.admin_user_role (
    admin_user_role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id uuid NOT NULL,
    admin_role_id uuid NOT NULL,
    granted_by_admin_user_id uuid,
    granted_at timestamptz NOT NULL DEFAULT now(),
    revoked_by_admin_user_id uuid,
    revoked_at timestamptz,
    revocation_reason text,
    CONSTRAINT uq_admin_user_role_grant UNIQUE (
        admin_user_id, admin_role_id, granted_at
    ),
    CONSTRAINT ck_admin_user_role_revocation CHECK (
        (revoked_at IS NULL AND revoked_by_admin_user_id IS NULL AND revocation_reason IS NULL)
        OR (revoked_at IS NOT NULL AND revoked_by_admin_user_id IS NOT NULL AND revocation_reason IS NOT NULL)
    ),
    CONSTRAINT ck_admin_user_role_grantor CHECK (
        granted_by_admin_user_id IS NULL OR admin_user_id <> granted_by_admin_user_id
    )
);

CREATE TABLE marketplace.admin_permission (
    permission_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code text NOT NULL,
    name text NOT NULL,
    description text,
    risk_level text NOT NULL DEFAULT 'LOW',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_admin_permission_code UNIQUE (permission_code),
    CONSTRAINT ck_admin_permission_risk CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_admin_permission_code_not_blank CHECK (btrim(permission_code) <> ''),
    CONSTRAINT ck_admin_permission_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE marketplace.admin_role_permission (
    admin_role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    granted_by_admin_user_id uuid,
    granted_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_admin_role_permission PRIMARY KEY (admin_role_id, permission_id)
);

CREATE TABLE marketplace.admin_approval_request (
    approval_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_by_admin_user_id uuid NOT NULL,
    action_type text NOT NULL,
    target_type text NOT NULL,
    target_id uuid,
    risk_level text NOT NULL,
    request_payload jsonb NOT NULL,
    justification text NOT NULL,
    required_approvals integer NOT NULL DEFAULT 1,
    idempotency_key text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    decided_at timestamptz,
    CONSTRAINT uq_admin_approval_request_idempotency UNIQUE (idempotency_key),
    CONSTRAINT uq_admin_approval_request_maker UNIQUE (
        approval_request_id, requested_by_admin_user_id
    ),
    CONSTRAINT ck_admin_approval_risk CHECK (risk_level IN ('HIGH', 'CRITICAL')),
    CONSTRAINT ck_admin_approval_count CHECK (required_approvals > 0),
    CONSTRAINT ck_admin_approval_status CHECK (status IN (
        'PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'EXECUTED', 'FAILED'
    )),
    CONSTRAINT ck_admin_approval_decided_state CHECK (
        (status = 'PENDING' AND decided_at IS NULL)
        OR (status <> 'PENDING' AND decided_at IS NOT NULL)
    ),
    CONSTRAINT ck_admin_approval_expiry CHECK (expires_at > created_at),
    CONSTRAINT ck_admin_approval_action_not_blank CHECK (btrim(action_type) <> ''),
    CONSTRAINT ck_admin_approval_target_not_blank CHECK (btrim(target_type) <> ''),
    CONSTRAINT ck_admin_approval_justification_not_blank CHECK (btrim(justification) <> ''),
    CONSTRAINT ck_admin_approval_idempotency_not_blank CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_admin_approval_payload_object CHECK (jsonb_typeof(request_payload) = 'object')
);

CREATE TABLE marketplace.admin_approval_step (
    approval_step_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL,
    requester_admin_user_id uuid NOT NULL,
    approver_admin_user_id uuid NOT NULL,
    step_no integer NOT NULL,
    decision text NOT NULL DEFAULT 'PENDING',
    decision_reason text,
    assigned_at timestamptz NOT NULL DEFAULT now(),
    decided_at timestamptz,
    CONSTRAINT uq_admin_approval_step_no UNIQUE (approval_request_id, step_no),
    CONSTRAINT uq_admin_approval_step_approver UNIQUE (
        approval_request_id, approver_admin_user_id
    ),
    CONSTRAINT ck_admin_approval_step_no CHECK (step_no > 0),
    CONSTRAINT ck_admin_approval_step_maker_checker CHECK (
        requester_admin_user_id <> approver_admin_user_id
    ),
    CONSTRAINT ck_admin_approval_step_decision CHECK (decision IN (
        'PENDING', 'APPROVED', 'REJECTED', 'ABSTAINED'
    )),
    CONSTRAINT ck_admin_approval_step_decided_state CHECK (
        (decision = 'PENDING' AND decided_at IS NULL)
        OR (decision <> 'PENDING' AND decided_at IS NOT NULL)
    )
);

CREATE TABLE marketplace.admin_audit_log (
    audit_log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id uuid,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id uuid,
    approval_request_id uuid,
    request_id text NOT NULL,
    correlation_id text,
    source_ip inet,
    user_agent text,
    before_hash text,
    after_hash text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_admin_audit_action_not_blank CHECK (btrim(action) <> ''),
    CONSTRAINT ck_admin_audit_target_not_blank CHECK (btrim(target_type) <> ''),
    CONSTRAINT ck_admin_audit_request_not_blank CHECK (btrim(request_id) <> ''),
    CONSTRAINT ck_admin_audit_details_object CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT ck_admin_audit_hash_change CHECK (
        before_hash IS NULL OR after_hash IS NULL OR before_hash <> after_hash
    )
);

CREATE TABLE marketplace.seller_incident (
    incident_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    finding_id uuid,
    incident_type text NOT NULL,
    source_type text NOT NULL,
    source_id uuid,
    source_key text NOT NULL,
    severity text NOT NULL,
    responsibility text NOT NULL,
    status text NOT NULL DEFAULT 'OPEN',
    occurred_at timestamptz NOT NULL,
    detected_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT uq_seller_incident_source_key UNIQUE (source_key),
    CONSTRAINT ck_seller_incident_severity CHECK (severity IN (
        'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    )),
    CONSTRAINT ck_seller_incident_responsibility CHECK (responsibility IN (
        'SELLER', 'BUYER', 'CARRIER', 'PLATFORM', 'UNKNOWN'
    )),
    CONSTRAINT ck_seller_incident_status CHECK (status IN (
        'OPEN', 'INVESTIGATING', 'CONFIRMED', 'DISMISSED', 'CLOSED'
    )),
    CONSTRAINT ck_seller_incident_closed CHECK (
        (status IN ('DISMISSED', 'CLOSED') AND closed_at IS NOT NULL)
        OR (status NOT IN ('DISMISSED', 'CLOSED') AND closed_at IS NULL)
    ),
    CONSTRAINT ck_seller_incident_source_key CHECK (btrim(source_key) <> ''),
    CONSTRAINT ck_seller_incident_type CHECK (btrim(incident_type) <> ''),
    CONSTRAINT ck_seller_incident_source_type CHECK (btrim(source_type) <> ''),
    CONSTRAINT ck_seller_incident_details_object CHECK (jsonb_typeof(details) = 'object')
);

CREATE TABLE marketplace.seller_penalty (
    penalty_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id uuid NOT NULL,
    rule_version_id uuid,
    penalty_type text NOT NULL,
    status text NOT NULL DEFAULT 'SCHEDULED',
    amount bigint,
    currency text,
    restrictions jsonb NOT NULL DEFAULT '{}'::jsonb,
    effective_from timestamptz NOT NULL,
    effective_to timestamptz,
    approved_by_admin_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz,
    revocation_reason text,
    CONSTRAINT ck_seller_penalty_type CHECK (penalty_type IN (
        'WARNING', 'FEE', 'LISTING_RESTRICTION', 'PAYOUT_HOLD', 'SUSPENSION', 'TERMINATION'
    )),
    CONSTRAINT ck_seller_penalty_status CHECK (status IN (
        'SCHEDULED', 'ACTIVE', 'COMPLETED', 'REVOKED', 'CANCELLED'
    )),
    CONSTRAINT ck_seller_penalty_money CHECK (
        (amount IS NULL AND currency IS NULL)
        OR (amount IS NOT NULL AND amount > 0 AND currency ~ '^[A-Z]{3}$')
    ),
    CONSTRAINT ck_seller_penalty_effective_range CHECK (
        effective_to IS NULL OR effective_from < effective_to
    ),
    CONSTRAINT ck_seller_penalty_revocation CHECK (
        (status = 'REVOKED' AND revoked_at IS NOT NULL AND revocation_reason IS NOT NULL)
        OR (status <> 'REVOKED' AND revoked_at IS NULL)
    ),
    CONSTRAINT ck_seller_penalty_restrictions_object CHECK (jsonb_typeof(restrictions) = 'object')
);

CREATE TABLE marketplace.seller_health_metric (
    metric_snapshot_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    metric_code text NOT NULL,
    dimension_key text NOT NULL DEFAULT '',
    window_start timestamptz NOT NULL,
    window_end timestamptz NOT NULL,
    numerator bigint NOT NULL,
    denominator bigint NOT NULL,
    calculated_value numeric(24,8) NOT NULL,
    calc_version text NOT NULL,
    dimensions jsonb NOT NULL DEFAULT '{}'::jsonb,
    calculated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_seller_health_metric_snapshot UNIQUE (
        seller_id, metric_code, dimension_key, window_start, window_end, calc_version
    ),
    CONSTRAINT ck_seller_health_metric_window CHECK (window_start < window_end),
    CONSTRAINT ck_seller_health_metric_counts CHECK (numerator >= 0 AND denominator > 0),
    CONSTRAINT ck_seller_health_metric_code CHECK (btrim(metric_code) <> ''),
    CONSTRAINT ck_seller_health_metric_calc_version CHECK (btrim(calc_version) <> ''),
    CONSTRAINT ck_seller_health_metric_dimensions_object CHECK (jsonb_typeof(dimensions) = 'object')
);

CREATE TABLE marketplace.seller_appeal (
    appeal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    incident_id uuid NOT NULL,
    penalty_id uuid,
    submitted_by_seller_member_id uuid NOT NULL,
    appeal_no integer NOT NULL DEFAULT 1,
    status text NOT NULL DEFAULT 'SUBMITTED',
    statement text NOT NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    decision text,
    decision_reason text,
    decided_by_admin_user_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    decided_at timestamptz,
    CONSTRAINT uq_seller_appeal_no UNIQUE (incident_id, appeal_no),
    CONSTRAINT ck_seller_appeal_no CHECK (appeal_no > 0),
    CONSTRAINT ck_seller_appeal_status CHECK (status IN (
        'SUBMITTED', 'UNDER_REVIEW', 'MORE_INFO_REQUIRED', 'ACCEPTED', 'REJECTED', 'WITHDRAWN'
    )),
    CONSTRAINT ck_seller_appeal_decision CHECK (
        decision IS NULL OR decision IN ('UPHELD', 'MODIFIED', 'OVERTURNED')
    ),
    CONSTRAINT ck_seller_appeal_decided_state CHECK (
        (status IN ('ACCEPTED', 'REJECTED')
            AND decision IS NOT NULL AND decision_reason IS NOT NULL
            AND decided_by_admin_user_id IS NOT NULL AND decided_at IS NOT NULL)
        OR (status NOT IN ('ACCEPTED', 'REJECTED')
            AND decision IS NULL AND decided_by_admin_user_id IS NULL AND decided_at IS NULL)
    ),
    CONSTRAINT ck_seller_appeal_statement CHECK (btrim(statement) <> ''),
    CONSTRAINT ck_seller_appeal_evidence_object CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE marketplace.compliance_rule (
    compliance_rule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL,
    rule_name text NOT NULL,
    scope text NOT NULL,
    jurisdiction text NOT NULL DEFAULT 'KR',
    status text NOT NULL DEFAULT 'ACTIVE',
    owner_team text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    retired_at timestamptz,
    CONSTRAINT uq_compliance_rule_code UNIQUE (rule_code),
    CONSTRAINT ck_compliance_rule_scope CHECK (scope IN (
        'PRODUCT', 'CATEGORY', 'SELLER', 'ORDER', 'ADVERTISING'
    )),
    CONSTRAINT ck_compliance_rule_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'RETIRED')),
    CONSTRAINT ck_compliance_rule_retired_state CHECK (
        (status = 'RETIRED' AND retired_at IS NOT NULL)
        OR (status <> 'RETIRED' AND retired_at IS NULL)
    ),
    CONSTRAINT ck_compliance_rule_code_not_blank CHECK (btrim(rule_code) <> ''),
    CONSTRAINT ck_compliance_rule_name_not_blank CHECK (btrim(rule_name) <> ''),
    CONSTRAINT ck_compliance_rule_owner_not_blank CHECK (btrim(owner_team) <> '')
);

CREATE TABLE marketplace.compliance_rule_version (
    rule_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compliance_rule_id uuid NOT NULL,
    version_no integer NOT NULL,
    effective_from timestamptz NOT NULL,
    effective_to timestamptz,
    rule_definition jsonb NOT NULL,
    definition_hash text NOT NULL,
    published_at timestamptz NOT NULL DEFAULT now(),
    published_by_admin_user_id uuid,
    CONSTRAINT uq_compliance_rule_version UNIQUE (compliance_rule_id, version_no),
    CONSTRAINT uq_compliance_rule_definition_hash UNIQUE (compliance_rule_id, definition_hash),
    CONSTRAINT ck_compliance_rule_version_no CHECK (version_no > 0),
    CONSTRAINT ck_compliance_rule_effective_range CHECK (
        effective_to IS NULL OR effective_from < effective_to
    ),
    CONSTRAINT ck_compliance_rule_definition_object CHECK (jsonb_typeof(rule_definition) = 'object'),
    CONSTRAINT ck_compliance_rule_definition_hash CHECK (btrim(definition_hash) <> '')
);

CREATE TABLE marketplace.product_compliance_finding (
    finding_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_revision_id uuid NOT NULL,
    rule_version_id uuid NOT NULL,
    evaluation_run_key text NOT NULL,
    status text NOT NULL,
    severity text NOT NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    model_version text,
    human_decision text,
    decided_by_admin_user_id uuid,
    decided_at timestamptz,
    detected_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_product_compliance_evaluation UNIQUE (
        product_revision_id, rule_version_id, evaluation_run_key
    ),
    CONSTRAINT ck_product_compliance_status CHECK (status IN (
        'PASS', 'FAIL', 'NEEDS_REVIEW', 'WAIVED', 'REMEDIATED'
    )),
    CONSTRAINT ck_product_compliance_severity CHECK (severity IN (
        'INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    )),
    CONSTRAINT ck_product_compliance_human_decision CHECK (
        human_decision IS NULL OR human_decision IN (
            'CONFIRMED', 'OVERRIDDEN_PASS', 'OVERRIDDEN_FAIL', 'WAIVED'
        )
    ),
    CONSTRAINT ck_product_compliance_decision_shape CHECK (
        (human_decision IS NULL AND decided_at IS NULL AND decided_by_admin_user_id IS NULL)
        OR (human_decision IS NOT NULL AND decided_at IS NOT NULL AND decided_by_admin_user_id IS NOT NULL)
    ),
    CONSTRAINT ck_product_compliance_run_key CHECK (btrim(evaluation_run_key) <> ''),
    CONSTRAINT ck_product_compliance_evidence_object CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE marketplace.seller_compliance_task (
    task_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    task_type text NOT NULL,
    policy_version text NOT NULL,
    priority text NOT NULL DEFAULT 'NORMAL',
    status text NOT NULL DEFAULT 'OPEN',
    due_at timestamptz NOT NULL,
    assigned_admin_user_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz,
    CONSTRAINT ck_seller_compliance_task_type CHECK (task_type IN (
        'PRODUCT_REMEDIATION', 'DOCUMENT_REQUEST', 'SELLER_ATTESTATION', 'INVESTIGATION'
    )),
    CONSTRAINT ck_seller_compliance_task_priority CHECK (priority IN (
        'LOW', 'NORMAL', 'HIGH', 'URGENT'
    )),
    CONSTRAINT ck_seller_compliance_task_status CHECK (status IN (
        'OPEN', 'IN_PROGRESS', 'SUBMITTED', 'COMPLETED', 'CANCELLED', 'OVERDUE'
    )),
    CONSTRAINT ck_seller_compliance_task_closed CHECK (
        (status IN ('COMPLETED', 'CANCELLED') AND closed_at IS NOT NULL)
        OR (status NOT IN ('COMPLETED', 'CANCELLED') AND closed_at IS NULL)
    ),
    CONSTRAINT ck_seller_compliance_policy_version CHECK (btrim(policy_version) <> '')
);

CREATE TABLE marketplace.seller_compliance_task_item (
    task_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL,
    finding_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'OPEN',
    seller_response text,
    resolution_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_seller_compliance_task_finding UNIQUE (task_id, finding_id),
    CONSTRAINT ck_seller_compliance_task_item_status CHECK (status IN (
        'OPEN', 'IN_PROGRESS', 'SUBMITTED', 'ACCEPTED', 'REJECTED', 'CANCELLED'
    )),
    CONSTRAINT ck_seller_compliance_task_item_resolved CHECK (
        (status IN ('ACCEPTED', 'REJECTED', 'CANCELLED') AND resolved_at IS NOT NULL)
        OR (status NOT IN ('ACCEPTED', 'REJECTED', 'CANCELLED') AND resolved_at IS NULL)
    ),
    CONSTRAINT ck_seller_compliance_resolution_object CHECK (
        jsonb_typeof(resolution_evidence) = 'object'
    )
);

CREATE TABLE marketplace.outbox_event (
    outbox_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_key text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    aggregate_version bigint,
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
    CONSTRAINT outbox_event_lock_ck CHECK ((locked_at IS NULL) = (lock_token IS NULL))
);

ALTER TABLE marketplace.member_auth_identity ADD CONSTRAINT fk_member_auth_identity_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE CASCADE;
ALTER TABLE marketplace.member_profile ADD CONSTRAINT fk_member_profile_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE CASCADE;
ALTER TABLE marketplace.shipping_address ADD CONSTRAINT fk_shipping_address_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE CASCADE;
ALTER TABLE marketplace.seller_member ADD CONSTRAINT fk_seller_member_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_member ADD CONSTRAINT fk_seller_member_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_document ADD CONSTRAINT fk_seller_document_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_verification ADD CONSTRAINT fk_seller_verification_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_verification ADD CONSTRAINT fk_seller_verification_document FOREIGN KEY (document_id) REFERENCES marketplace.seller_document (document_id) ON DELETE SET NULL;
ALTER TABLE marketplace.seller_settlement_account ADD CONSTRAINT fk_seller_settlement_account_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_brand_relation ADD CONSTRAINT fk_seller_brand_relation_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_brand_relation ADD CONSTRAINT fk_seller_brand_relation_brand FOREIGN KEY (brand_id) REFERENCES marketplace.brand (brand_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.brand_registration_request ADD CONSTRAINT fk_brand_registration_request_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.brand_registration_request ADD CONSTRAINT fk_brand_registration_request_approved_brand FOREIGN KEY (approved_brand_id) REFERENCES marketplace.brand (brand_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.brand_registration_request ADD CONSTRAINT fk_brand_registration_request_reviewer FOREIGN KEY (reviewed_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE SET NULL;
ALTER TABLE marketplace.category ADD CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id) REFERENCES marketplace.category (category_id) ON DELETE RESTRICT
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE marketplace.product ADD CONSTRAINT fk_product_seller_brand_relation FOREIGN KEY (seller_brand_relation_id) REFERENCES marketplace.seller_brand_relation (seller_brand_relation_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product ADD CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES marketplace.category (category_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_revision ADD CONSTRAINT fk_product_revision_product FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_image ADD CONSTRAINT fk_product_image_product FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_revision ADD CONSTRAINT fk_product_revision_primary_image FOREIGN KEY (product_id, primary_image_id) REFERENCES marketplace.product_image (product_id, image_id) ON DELETE RESTRICT
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE marketplace.product ADD CONSTRAINT fk_product_current_revision FOREIGN KEY (product_id, current_revision_no) REFERENCES marketplace.product_revision (product_id, revision_no) ON DELETE RESTRICT
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE marketplace.product_revision ADD CONSTRAINT fk_product_revision_creator FOREIGN KEY (created_by_seller_member_id) REFERENCES marketplace.seller_member (seller_member_id) ON DELETE SET NULL;
ALTER TABLE marketplace.product_feature ADD CONSTRAINT fk_product_feature_revision FOREIGN KEY (product_revision_id) REFERENCES marketplace.product_revision (product_revision_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_feature ADD CONSTRAINT fk_product_feature_confirmer FOREIGN KEY (confirmed_by_seller_member_id) REFERENCES marketplace.seller_member (seller_member_id) ON DELETE SET NULL;
ALTER TABLE marketplace.option_group ADD CONSTRAINT fk_option_group_product FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.option_value ADD CONSTRAINT fk_option_value_group FOREIGN KEY (option_group_id) REFERENCES marketplace.option_group (option_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.sku ADD CONSTRAINT fk_sku_product FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.sku_option_value ADD CONSTRAINT fk_sku_option_value_sku FOREIGN KEY (product_id, sku_id) REFERENCES marketplace.sku (product_id, sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.sku_option_value ADD CONSTRAINT fk_sku_option_value_group FOREIGN KEY (product_id, option_group_id) REFERENCES marketplace.option_group (product_id, option_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.sku_option_value ADD CONSTRAINT fk_sku_option_value_value FOREIGN KEY (option_group_id, option_value_id) REFERENCES marketplace.option_value (option_group_id, option_value_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.inventory ADD CONSTRAINT fk_inventory_sku FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.inventory_ledger ADD CONSTRAINT fk_inventory_ledger_inventory FOREIGN KEY (sku_id) REFERENCES marketplace.inventory (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.cart ADD CONSTRAINT cart_member_fk FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.cart_item ADD CONSTRAINT cart_item_cart_fk FOREIGN KEY (cart_id) REFERENCES marketplace.cart (cart_id) ON DELETE CASCADE;
ALTER TABLE marketplace.cart_item ADD CONSTRAINT cart_item_sku_fk FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.checkout ADD CONSTRAINT checkout_member_fk FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.checkout ADD CONSTRAINT checkout_cart_fk FOREIGN KEY (cart_id) REFERENCES marketplace.cart (cart_id) ON DELETE SET NULL;
ALTER TABLE marketplace.checkout_shipping_group ADD CONSTRAINT checkout_shipping_group_checkout_fk FOREIGN KEY (checkout_id) REFERENCES marketplace.checkout (checkout_id) ON DELETE CASCADE;
ALTER TABLE marketplace.checkout_shipping_group ADD CONSTRAINT checkout_shipping_group_seller_fk FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.checkout_item ADD CONSTRAINT checkout_item_checkout_fk FOREIGN KEY (checkout_id) REFERENCES marketplace.checkout (checkout_id) ON DELETE CASCADE;
ALTER TABLE marketplace.checkout_item ADD CONSTRAINT checkout_item_shipping_group_fk FOREIGN KEY (checkout_shipping_group_id) REFERENCES marketplace.checkout_shipping_group (checkout_shipping_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.checkout_item ADD CONSTRAINT checkout_item_sku_fk FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.checkout_item ADD CONSTRAINT checkout_item_product_revision_fk FOREIGN KEY (product_revision_id) REFERENCES marketplace.product_revision (product_revision_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.inventory_reservation ADD CONSTRAINT inventory_reservation_checkout_fk FOREIGN KEY (checkout_id) REFERENCES marketplace.checkout (checkout_id) ON DELETE CASCADE;
ALTER TABLE marketplace.inventory_reservation_item ADD CONSTRAINT inventory_reservation_item_reservation_fk FOREIGN KEY (reservation_id) REFERENCES marketplace.inventory_reservation (reservation_id) ON DELETE CASCADE;
ALTER TABLE marketplace.inventory_reservation_item ADD CONSTRAINT inventory_reservation_item_sku_fk FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.orders ADD CONSTRAINT orders_checkout_fk FOREIGN KEY (checkout_id) REFERENCES marketplace.checkout (checkout_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.orders ADD CONSTRAINT orders_member_fk FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_shipping_group ADD CONSTRAINT order_shipping_group_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_shipping_group ADD CONSTRAINT order_shipping_group_checkout_group_fk FOREIGN KEY (checkout_shipping_group_id) REFERENCES marketplace.checkout_shipping_group (checkout_shipping_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_shipping_group ADD CONSTRAINT order_shipping_group_seller_fk FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_checkout_item_fk FOREIGN KEY (checkout_item_id) REFERENCES marketplace.checkout_item (checkout_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_shipping_group_fk FOREIGN KEY (order_shipping_group_id) REFERENCES marketplace.order_shipping_group (order_shipping_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_seller_fk FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_product_fk FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_product_revision_fk FOREIGN KEY (product_revision_id) REFERENCES marketplace.product_revision (product_revision_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_item ADD CONSTRAINT order_item_sku_fk FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_charge ADD CONSTRAINT order_charge_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_charge ADD CONSTRAINT order_charge_shipping_group_fk FOREIGN KEY (order_shipping_group_id) REFERENCES marketplace.order_shipping_group (order_shipping_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.order_state_event ADD CONSTRAINT order_state_event_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment ADD CONSTRAINT shipment_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment ADD CONSTRAINT shipment_order_shipping_group_fk FOREIGN KEY (order_shipping_group_id) REFERENCES marketplace.order_shipping_group (order_shipping_group_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment ADD CONSTRAINT shipment_seller_fk FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment ADD CONSTRAINT shipment_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment_item ADD CONSTRAINT shipment_item_shipment_fk FOREIGN KEY (shipment_id) REFERENCES marketplace.shipment (shipment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment_item ADD CONSTRAINT shipment_item_order_item_fk FOREIGN KEY (order_item_id) REFERENCES marketplace.order_item (order_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment_item ADD CONSTRAINT shipment_item_sku_fk FOREIGN KEY (sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment_item ADD CONSTRAINT shipment_item_exchange_line_fk FOREIGN KEY (exchange_line_id) REFERENCES marketplace.exchange_line (exchange_line_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.shipment_event ADD CONSTRAINT shipment_event_shipment_fk FOREIGN KEY (shipment_id) REFERENCES marketplace.shipment (shipment_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.purchase_confirmation_state ADD CONSTRAINT purchase_confirmation_state_shipment_item_fk FOREIGN KEY (shipment_item_id) REFERENCES marketplace.shipment_item (shipment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.purchase_confirmation_event ADD CONSTRAINT purchase_confirmation_event_shipment_item_fk FOREIGN KEY (shipment_item_id) REFERENCES marketplace.shipment_item (shipment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.purchase_confirmation_hold ADD CONSTRAINT purchase_confirmation_hold_shipment_item_fk FOREIGN KEY (shipment_item_id) REFERENCES marketplace.shipment_item (shipment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.purchase_confirmation_hold ADD CONSTRAINT purchase_confirmation_hold_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim ADD CONSTRAINT claim_member_fk FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim ADD CONSTRAINT claim_order_fk FOREIGN KEY (order_id) REFERENCES marketplace.orders (order_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_item ADD CONSTRAINT claim_item_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_item ADD CONSTRAINT claim_item_order_item_fk FOREIGN KEY (order_item_id) REFERENCES marketplace.order_item (order_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_item_source_allocation ADD CONSTRAINT claim_item_source_allocation_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_item_source_allocation ADD CONSTRAINT claim_item_source_allocation_shipment_item_fk FOREIGN KEY (outbound_shipment_item_id) REFERENCES marketplace.shipment_item (shipment_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_evidence ADD CONSTRAINT claim_evidence_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_evidence ADD CONSTRAINT claim_evidence_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_reason_change ADD CONSTRAINT claim_reason_change_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_review ADD CONSTRAINT claim_review_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_review ADD CONSTRAINT claim_review_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_event ADD CONSTRAINT claim_event_claim_fk FOREIGN KEY (claim_id) REFERENCES marketplace.claim (claim_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.claim_event ADD CONSTRAINT claim_event_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.exchange_line ADD CONSTRAINT exchange_line_claim_item_fk FOREIGN KEY (claim_item_id) REFERENCES marketplace.claim_item (claim_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.exchange_line ADD CONSTRAINT exchange_line_replacement_sku_fk FOREIGN KEY (replacement_sku_id) REFERENCES marketplace.sku (sku_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review_eligibility ADD CONSTRAINT fk_review_eligibility_order_item FOREIGN KEY (order_item_id) REFERENCES marketplace.order_item (order_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review ADD CONSTRAINT fk_review_eligibility FOREIGN KEY (order_item_id) REFERENCES marketplace.review_eligibility (order_item_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review ADD CONSTRAINT fk_review_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review_revision ADD CONSTRAINT fk_review_revision_review FOREIGN KEY (review_id) REFERENCES marketplace.review (review_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review_image ADD CONSTRAINT fk_review_image_review FOREIGN KEY (review_id) REFERENCES marketplace.review (review_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.review_image ADD CONSTRAINT fk_review_image_revision FOREIGN KEY (review_revision_id) REFERENCES marketplace.review_revision (review_revision_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_review_reply ADD CONSTRAINT fk_seller_review_reply_review FOREIGN KEY (review_id) REFERENCES marketplace.review (review_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_review_reply ADD CONSTRAINT fk_seller_review_reply_member FOREIGN KEY (seller_member_id) REFERENCES marketplace.seller_member (seller_member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.wishlist_item ADD CONSTRAINT fk_wishlist_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE CASCADE;
ALTER TABLE marketplace.wishlist_item ADD CONSTRAINT fk_wishlist_product FOREIGN KEY (product_id) REFERENCES marketplace.product (product_id) ON DELETE CASCADE;
ALTER TABLE marketplace.compliance_rule_version ADD CONSTRAINT fk_compliance_rule_version_rule FOREIGN KEY (compliance_rule_id) REFERENCES marketplace.compliance_rule (compliance_rule_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.compliance_rule_version ADD CONSTRAINT fk_compliance_rule_version_publisher FOREIGN KEY (published_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_compliance_finding ADD CONSTRAINT fk_product_compliance_revision FOREIGN KEY (product_revision_id) REFERENCES marketplace.product_revision (product_revision_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_compliance_finding ADD CONSTRAINT fk_product_compliance_rule_version FOREIGN KEY (rule_version_id) REFERENCES marketplace.compliance_rule_version (rule_version_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_compliance_finding ADD CONSTRAINT fk_product_compliance_decider FOREIGN KEY (decided_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_compliance_task ADD CONSTRAINT fk_seller_compliance_task_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_compliance_task ADD CONSTRAINT fk_seller_compliance_task_assignee FOREIGN KEY (assigned_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_compliance_task_item ADD CONSTRAINT fk_seller_compliance_task_item_task FOREIGN KEY (task_id) REFERENCES marketplace.seller_compliance_task (task_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_compliance_task_item ADD CONSTRAINT fk_seller_compliance_task_item_finding FOREIGN KEY (finding_id) REFERENCES marketplace.product_compliance_finding (finding_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.notification ADD CONSTRAINT fk_notification_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.notification ADD CONSTRAINT fk_notification_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.notification_preference ADD CONSTRAINT fk_notification_preference_member FOREIGN KEY (member_id) REFERENCES marketplace.member (member_id) ON DELETE CASCADE;
ALTER TABLE marketplace.notification_preference ADD CONSTRAINT fk_notification_preference_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE CASCADE;
ALTER TABLE marketplace.notification_delivery ADD CONSTRAINT fk_notification_delivery_notification FOREIGN KEY (notification_id) REFERENCES marketplace.notification (notification_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_user_role ADD CONSTRAINT fk_admin_user_role_user FOREIGN KEY (admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_user_role ADD CONSTRAINT fk_admin_user_role_role FOREIGN KEY (admin_role_id) REFERENCES marketplace.admin_role (admin_role_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_user_role ADD CONSTRAINT fk_admin_user_role_grantor FOREIGN KEY (granted_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_user_role ADD CONSTRAINT fk_admin_user_role_revoker FOREIGN KEY (revoked_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_role_permission ADD CONSTRAINT fk_admin_role_permission_role FOREIGN KEY (admin_role_id) REFERENCES marketplace.admin_role (admin_role_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_role_permission ADD CONSTRAINT fk_admin_role_permission_permission FOREIGN KEY (permission_id) REFERENCES marketplace.admin_permission (permission_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_role_permission ADD CONSTRAINT fk_admin_role_permission_grantor FOREIGN KEY (granted_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_approval_request ADD CONSTRAINT fk_admin_approval_request_maker FOREIGN KEY (requested_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_approval_step ADD CONSTRAINT fk_admin_approval_step_request_maker FOREIGN KEY (approval_request_id, requester_admin_user_id) REFERENCES marketplace.admin_approval_request (approval_request_id, requested_by_admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_approval_step ADD CONSTRAINT fk_admin_approval_step_approver FOREIGN KEY (approver_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_audit_log ADD CONSTRAINT fk_admin_audit_log_user FOREIGN KEY (admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.admin_audit_log ADD CONSTRAINT fk_admin_audit_log_approval FOREIGN KEY (approval_request_id) REFERENCES marketplace.admin_approval_request (approval_request_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_incident ADD CONSTRAINT fk_seller_incident_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_incident ADD CONSTRAINT fk_seller_incident_finding FOREIGN KEY (finding_id) REFERENCES marketplace.product_compliance_finding (finding_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_penalty ADD CONSTRAINT fk_seller_penalty_incident FOREIGN KEY (incident_id) REFERENCES marketplace.seller_incident (incident_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_penalty ADD CONSTRAINT fk_seller_penalty_rule_version FOREIGN KEY (rule_version_id) REFERENCES marketplace.compliance_rule_version (rule_version_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_penalty ADD CONSTRAINT fk_seller_penalty_approver FOREIGN KEY (approved_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_health_metric ADD CONSTRAINT fk_seller_health_metric_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_appeal ADD CONSTRAINT fk_seller_appeal_seller FOREIGN KEY (seller_id) REFERENCES marketplace.seller (seller_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_appeal ADD CONSTRAINT fk_seller_appeal_incident FOREIGN KEY (incident_id) REFERENCES marketplace.seller_incident (incident_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_appeal ADD CONSTRAINT fk_seller_appeal_penalty FOREIGN KEY (penalty_id) REFERENCES marketplace.seller_penalty (penalty_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_appeal ADD CONSTRAINT fk_seller_appeal_submitter FOREIGN KEY (submitted_by_seller_member_id) REFERENCES marketplace.seller_member (seller_member_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.seller_appeal ADD CONSTRAINT fk_seller_appeal_decider FOREIGN KEY (decided_by_admin_user_id) REFERENCES marketplace.admin_user (admin_user_id) ON DELETE RESTRICT;
CREATE INDEX idx_member_auth_identity_member_active
    ON marketplace.member_auth_identity (member_id, provider)
    WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX ux_shipping_address_member_default_active
    ON marketplace.shipping_address (member_id)
    WHERE is_default AND status = 'ACTIVE' AND deleted_at IS NULL;
CREATE INDEX idx_shipping_address_member_active_updated
    ON marketplace.shipping_address (member_id, updated_at DESC)
    WHERE status = 'ACTIVE' AND deleted_at IS NULL;
CREATE INDEX idx_seller_member_member_status
    ON marketplace.seller_member (member_id, status, seller_id);
CREATE INDEX idx_seller_document_seller_type_created
    ON marketplace.seller_document (seller_id, document_type, created_at DESC)
    WHERE status <> 'DELETED';
CREATE INDEX idx_seller_verification_seller_type_requested
    ON marketplace.seller_verification (seller_id, verification_type, requested_at DESC);
CREATE INDEX idx_seller_verification_document
    ON marketplace.seller_verification (document_id)
    WHERE document_id IS NOT NULL;
CREATE UNIQUE INDEX ux_seller_settlement_account_default_active
    ON marketplace.seller_settlement_account (seller_id)
    WHERE is_default
      AND status = 'ACTIVE'
      AND verification_status = 'VERIFIED'
      AND deactivated_at IS NULL;
CREATE INDEX idx_seller_brand_relation_brand_approved
    ON marketplace.seller_brand_relation (brand_id, seller_id)
    WHERE verification_status = 'APPROVED';
CREATE UNIQUE INDEX ux_brand_registration_open_name
    ON marketplace.brand_registration_request (seller_id, requested_name_normalized)
    WHERE status IN ('REQUESTED', 'IN_REVIEW');
CREATE INDEX idx_brand_registration_review_queue
    ON marketplace.brand_registration_request (status, requested_at)
    WHERE status IN ('REQUESTED', 'IN_REVIEW');
CREATE INDEX idx_brand_registration_reviewer
    ON marketplace.brand_registration_request (reviewed_by_admin_user_id)
    WHERE reviewed_by_admin_user_id IS NOT NULL;
CREATE INDEX idx_brand_registration_approved_brand
    ON marketplace.brand_registration_request (approved_brand_id)
    WHERE approved_brand_id IS NOT NULL;
CREATE UNIQUE INDEX ux_category_root_name
    ON marketplace.category (category_name_normalized)
    WHERE parent_category_id IS NULL;
CREATE UNIQUE INDEX ux_category_sibling_name
    ON marketplace.category (parent_category_id, category_name_normalized)
    WHERE parent_category_id IS NOT NULL;
CREATE INDEX idx_category_active_children
    ON marketplace.category (parent_category_id, display_order, category_id)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_product_category_status_updated
    ON marketplace.product (category_id, sale_status, updated_at DESC);
CREATE INDEX idx_product_relation_status_updated
    ON marketplace.product (seller_brand_relation_id, sale_status, updated_at DESC);
CREATE INDEX idx_product_revision_creator
    ON marketplace.product_revision (created_by_seller_member_id)
    WHERE created_by_seller_member_id IS NOT NULL;
CREATE INDEX idx_product_revision_primary_image
    ON marketplace.product_revision (product_id, primary_image_id)
    WHERE primary_image_id IS NOT NULL;
CREATE UNIQUE INDEX ux_product_image_one_active_main
    ON marketplace.product_image (product_id)
    WHERE image_type = 'MAIN' AND status = 'ACTIVE' AND deleted_at IS NULL;
CREATE INDEX idx_product_image_active_display
    ON marketplace.product_image (product_id, display_order, image_id)
    WHERE status = 'ACTIVE' AND deleted_at IS NULL;
CREATE INDEX idx_product_feature_confirmer
    ON marketplace.product_feature (confirmed_by_seller_member_id)
    WHERE confirmed_by_seller_member_id IS NOT NULL;
CREATE INDEX idx_option_group_product_active_display
    ON marketplace.option_group (product_id, display_order, option_group_id)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_option_value_group_active_display
    ON marketplace.option_value (option_group_id, display_order, option_value_id)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_sku_product_sellable_price
    ON marketplace.sku (product_id, sale_price, sku_id)
    WHERE sku_status IN ('ACTIVE', 'SOLD_OUT');
CREATE INDEX idx_sku_option_value_group_value
    ON marketplace.sku_option_value (option_group_id, option_value_id, sku_id);
CREATE INDEX idx_inventory_out_of_stock
    ON marketplace.inventory (updated_at, sku_id)
    WHERE available_qty = 0;
CREATE INDEX idx_inventory_ledger_sku_occurred
    ON marketplace.inventory_ledger (sku_id, occurred_at DESC, inventory_ledger_id);
CREATE UNIQUE INDEX cart_one_active_per_member_uidx
    ON marketplace.cart (member_id)
    WHERE status = 'ACTIVE';
CREATE INDEX cart_member_history_idx
    ON marketplace.cart (member_id, updated_at DESC);
CREATE INDEX cart_item_sku_idx
    ON marketplace.cart_item (sku_id);
CREATE INDEX checkout_cart_idx
    ON marketplace.checkout (cart_id)
    WHERE cart_id IS NOT NULL;
CREATE INDEX checkout_member_recent_idx
    ON marketplace.checkout (member_id, created_at DESC);
CREATE INDEX checkout_expiry_worker_idx
    ON marketplace.checkout (expires_at, checkout_id)
    WHERE status IN ('OPEN', 'PRICED', 'RESERVED');
CREATE INDEX checkout_shipping_group_seller_idx
    ON marketplace.checkout_shipping_group (seller_id, checkout_id);
CREATE INDEX checkout_item_shipping_group_idx
    ON marketplace.checkout_item (checkout_shipping_group_id, line_number);
CREATE INDEX checkout_item_sku_idx
    ON marketplace.checkout_item (sku_id);
CREATE INDEX checkout_item_product_revision_idx
    ON marketplace.checkout_item (product_revision_id)
    WHERE product_revision_id IS NOT NULL;
CREATE INDEX inventory_reservation_expiry_worker_idx
    ON marketplace.inventory_reservation (expires_at, reservation_id)
    WHERE status = 'ACTIVE';
CREATE INDEX inventory_reservation_item_active_sku_idx
    ON marketplace.inventory_reservation_item (sku_id, reservation_id)
    INCLUDE (quantity, consumed_quantity, released_quantity)
    WHERE status IN ('RESERVED', 'PARTIALLY_CONSUMED');
CREATE INDEX orders_member_recent_idx
    ON marketplace.orders (member_id, ordered_at DESC);
CREATE INDEX orders_pending_payment_idx
    ON marketplace.orders (payment_due_at, order_id)
    WHERE order_status = 'PENDING_PAYMENT';
CREATE INDEX orders_operations_queue_idx
    ON marketplace.orders (order_status, updated_at, order_id)
    WHERE order_status IN ('PAID', 'PROCESSING', 'PARTIALLY_SHIPPED', 'SHIPPED');
CREATE INDEX order_shipping_group_seller_queue_idx
    ON marketplace.order_shipping_group (seller_id, status, created_at, order_shipping_group_id)
    WHERE status IN ('PENDING', 'READY', 'PARTIALLY_SHIPPED', 'SHIPPED');
CREATE INDEX order_shipping_group_order_status_idx
    ON marketplace.order_shipping_group (order_id, status);
CREATE INDEX order_item_shipping_group_idx
    ON marketplace.order_item (order_shipping_group_id, line_number);
CREATE INDEX order_item_seller_order_idx
    ON marketplace.order_item (seller_id, order_id)
    INCLUDE (sku_id, ordered_quantity, paid_amount);
CREATE INDEX order_item_product_idx
    ON marketplace.order_item (product_id, created_at DESC);
CREATE INDEX order_item_product_revision_idx
    ON marketplace.order_item (product_revision_id)
    WHERE product_revision_id IS NOT NULL;
CREATE INDEX order_item_sku_idx
    ON marketplace.order_item (sku_id, created_at DESC);
CREATE INDEX order_charge_shipping_group_idx
    ON marketplace.order_charge (order_shipping_group_id)
    WHERE order_shipping_group_id IS NOT NULL;
CREATE INDEX order_state_event_timeline_idx
    ON marketplace.order_state_event (order_id, occurred_at DESC, order_state_event_id);
CREATE INDEX shipment_order_timeline_idx
    ON marketplace.shipment (order_id, created_at DESC);
CREATE INDEX shipment_shipping_group_status_idx
    ON marketplace.shipment (order_shipping_group_id, status, created_at DESC)
    WHERE order_shipping_group_id IS NOT NULL;
CREATE INDEX shipment_seller_queue_idx
    ON marketplace.shipment (seller_id, status, created_at, shipment_id)
    WHERE status IN ('READY', 'HANDED_OVER', 'IN_TRANSIT');
CREATE INDEX shipment_claim_idx
    ON marketplace.shipment (claim_id, created_at DESC)
    WHERE claim_id IS NOT NULL;
CREATE INDEX shipment_item_order_item_idx
    ON marketplace.shipment_item (order_item_id, shipment_id)
    INCLUDE (quantity, sku_id);
CREATE INDEX shipment_item_sku_idx
    ON marketplace.shipment_item (sku_id, shipment_id);
CREATE INDEX shipment_item_exchange_line_idx
    ON marketplace.shipment_item (exchange_line_id, shipment_id)
    WHERE exchange_line_id IS NOT NULL;
CREATE INDEX shipment_event_timeline_idx
    ON marketplace.shipment_event (shipment_id, occurred_at, shipment_event_id);
CREATE INDEX purchase_confirmation_auto_worker_idx
    ON marketplace.purchase_confirmation_state (auto_confirm_at, shipment_item_id)
    WHERE auto_confirm_at IS NOT NULL
      AND confirmed_quantity + held_quantity < delivered_quantity;
CREATE INDEX purchase_confirmation_event_timeline_idx
    ON marketplace.purchase_confirmation_event (shipment_item_id, occurred_at, confirmation_event_id);
CREATE INDEX purchase_confirmation_hold_claim_item_idx
    ON marketplace.purchase_confirmation_hold (claim_item_id, shipment_item_id);
CREATE INDEX purchase_confirmation_hold_active_idx
    ON marketplace.purchase_confirmation_hold (shipment_item_id, held_at, hold_id)
    WHERE status = 'ACTIVE';
CREATE INDEX claim_order_timeline_idx
    ON marketplace.claim (order_id, requested_at DESC, claim_id);
CREATE INDEX claim_member_timeline_idx
    ON marketplace.claim (member_id, requested_at DESC, claim_id);
CREATE INDEX claim_operations_queue_idx
    ON marketplace.claim (status, requested_at, claim_id)
    WHERE status IN ('REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'PICKUP_PENDING', 'IN_TRANSIT', 'RECEIVED', 'INSPECTING', 'REFUND_PENDING');
CREATE INDEX claim_refund_due_idx
    ON marketplace.claim (refund_due_at, claim_id)
    WHERE refund_due_at IS NOT NULL
      AND status IN ('APPROVED', 'REFUND_PENDING');
CREATE INDEX claim_item_order_item_status_idx
    ON marketplace.claim_item (order_item_id, status, claim_id);
CREATE INDEX claim_item_source_shipment_item_idx
    ON marketplace.claim_item_source_allocation (outbound_shipment_item_id, claim_item_id);
CREATE INDEX claim_evidence_claim_timeline_idx
    ON marketplace.claim_evidence (claim_id, created_at, evidence_id);
CREATE INDEX claim_evidence_claim_item_idx
    ON marketplace.claim_evidence (claim_item_id, created_at)
    WHERE claim_item_id IS NOT NULL;
CREATE INDEX claim_reason_change_timeline_idx
    ON marketplace.claim_reason_change (claim_id, requested_at DESC, reason_change_id);
CREATE INDEX claim_reason_change_pending_idx
    ON marketplace.claim_reason_change (requested_at, reason_change_id)
    WHERE status = 'REQUESTED';
CREATE INDEX claim_review_timeline_idx
    ON marketplace.claim_review (claim_id, created_at, claim_review_id);
CREATE INDEX claim_review_claim_item_idx
    ON marketplace.claim_review (claim_item_id, created_at)
    WHERE claim_item_id IS NOT NULL;
CREATE INDEX claim_event_timeline_idx
    ON marketplace.claim_event (claim_id, occurred_at, claim_event_id);
CREATE INDEX claim_event_claim_item_idx
    ON marketplace.claim_event (claim_item_id, occurred_at)
    WHERE claim_item_id IS NOT NULL;
CREATE INDEX exchange_line_replacement_sku_idx
    ON marketplace.exchange_line (replacement_sku_id, status);
CREATE INDEX exchange_line_fulfillment_queue_idx
    ON marketplace.exchange_line (status, created_at, exchange_line_id)
    WHERE status IN ('REQUESTED', 'RESERVED', 'SHIPPED');
CREATE INDEX ix_review_eligibility_available
    ON marketplace.review_eligibility (eligible_at, order_item_id)
    INCLUDE (eligible_quantity, reviewed_quantity)
    WHERE revoked_at IS NULL AND reviewed_quantity < eligible_quantity;
CREATE INDEX ix_review_member_feed
    ON marketplace.review (member_id, created_at DESC)
    INCLUDE (rating, status, order_item_id);
CREATE INDEX ix_review_published_feed
    ON marketplace.review (created_at DESC, review_id)
    INCLUDE (rating, member_id)
    WHERE status = 'PUBLISHED';
CREATE INDEX ix_review_revision_actor
    ON marketplace.review_revision (changed_by_type, changed_by_id, created_at DESC)
    WHERE changed_by_id IS NOT NULL;
CREATE INDEX ix_review_image_active_order
    ON marketplace.review_image (review_id, display_order)
    WHERE status = 'ACTIVE';
CREATE INDEX ix_review_image_revision
    ON marketplace.review_image (review_revision_id)
    WHERE review_revision_id IS NOT NULL;
CREATE INDEX ix_seller_review_reply_member
    ON marketplace.seller_review_reply (seller_member_id, created_at DESC)
    WHERE status <> 'DELETED';
CREATE INDEX ix_wishlist_product_popularity
    ON marketplace.wishlist_item (product_id, created_at DESC);
CREATE INDEX ix_notification_member_unread
    ON marketplace.notification (member_id, created_at DESC)
    INCLUDE (event_type, importance)
    WHERE member_id IS NOT NULL AND read_at IS NULL;
CREATE INDEX ix_notification_seller_unread
    ON marketplace.notification (seller_id, created_at DESC)
    INCLUDE (event_type, importance)
    WHERE seller_id IS NOT NULL AND read_at IS NULL;
CREATE INDEX ix_notification_scheduled
    ON marketplace.notification (scheduled_at, created_at)
    WHERE scheduled_at IS NOT NULL;
CREATE INDEX ix_notification_preference_seller
    ON marketplace.notification_preference (seller_id, event_type, channel)
    INCLUDE (enabled)
    WHERE seller_id IS NOT NULL;
CREATE INDEX ix_notification_delivery_retry
    ON marketplace.notification_delivery (status, requested_at)
    INCLUDE (notification_id, channel, attempt_no)
    WHERE status IN ('QUEUED', 'SENDING', 'FAILED');
CREATE UNIQUE INDEX uq_admin_user_role_active
    ON marketplace.admin_user_role (admin_user_id, admin_role_id)
    WHERE revoked_at IS NULL;
CREATE INDEX ix_admin_user_role_role_active
    ON marketplace.admin_user_role (admin_role_id, admin_user_id)
    WHERE revoked_at IS NULL;
CREATE INDEX ix_admin_role_permission_permission
    ON marketplace.admin_role_permission (permission_id, admin_role_id);
CREATE INDEX ix_admin_approval_request_maker_time
    ON marketplace.admin_approval_request (
        requested_by_admin_user_id, status, created_at DESC
    );
CREATE INDEX ix_admin_approval_request_pending
    ON marketplace.admin_approval_request (expires_at, risk_level, created_at)
    INCLUDE (action_type, requested_by_admin_user_id)
    WHERE status = 'PENDING';
CREATE INDEX ix_admin_approval_step_approver_pending
    ON marketplace.admin_approval_step (approver_admin_user_id, assigned_at)
    INCLUDE (approval_request_id, step_no)
    WHERE decision = 'PENDING';
CREATE INDEX ix_admin_audit_user_time
    ON marketplace.admin_audit_log (admin_user_id, created_at DESC)
    WHERE admin_user_id IS NOT NULL;
CREATE INDEX ix_admin_audit_target_time
    ON marketplace.admin_audit_log (target_type, target_id, created_at DESC);
CREATE INDEX ix_admin_audit_approval
    ON marketplace.admin_audit_log (approval_request_id, created_at)
    WHERE approval_request_id IS NOT NULL;
CREATE INDEX ix_admin_audit_request_id
    ON marketplace.admin_audit_log (request_id, created_at);
CREATE INDEX ix_admin_audit_created_brin
    ON marketplace.admin_audit_log USING brin (created_at)
    WITH (pages_per_range = 64);
CREATE INDEX ix_admin_audit_details_gin
    ON marketplace.admin_audit_log USING gin (details jsonb_path_ops);
CREATE INDEX ix_seller_incident_open
    ON marketplace.seller_incident (seller_id, severity, occurred_at DESC)
    INCLUDE (incident_type, responsibility)
    WHERE status IN ('OPEN', 'INVESTIGATING', 'CONFIRMED');
CREATE INDEX ix_seller_incident_finding
    ON marketplace.seller_incident (finding_id, occurred_at DESC)
    WHERE finding_id IS NOT NULL;
CREATE INDEX ix_seller_incident_source
    ON marketplace.seller_incident (source_type, source_id)
    WHERE source_id IS NOT NULL;
CREATE INDEX ix_seller_penalty_active
    ON marketplace.seller_penalty (effective_from, effective_to, incident_id)
    INCLUDE (penalty_type, amount, currency)
    WHERE status IN ('SCHEDULED', 'ACTIVE');
CREATE INDEX ix_seller_penalty_incident
    ON marketplace.seller_penalty (incident_id, status, effective_from DESC)
    INCLUDE (penalty_type, amount, currency);
CREATE INDEX ix_seller_penalty_rule_version
    ON marketplace.seller_penalty (rule_version_id, effective_from DESC)
    WHERE rule_version_id IS NOT NULL;
CREATE INDEX ix_seller_health_metric_series
    ON marketplace.seller_health_metric (metric_code, window_end DESC, seller_id)
    INCLUDE (calculated_value, numerator, denominator);
CREATE INDEX ix_seller_appeal_seller_queue
    ON marketplace.seller_appeal (seller_id, status, created_at DESC);
CREATE INDEX ix_seller_appeal_penalty
    ON marketplace.seller_appeal (penalty_id, created_at DESC)
    WHERE penalty_id IS NOT NULL;
CREATE INDEX ix_seller_appeal_review_queue
    ON marketplace.seller_appeal (created_at, appeal_id)
    INCLUDE (seller_id, incident_id)
    WHERE status IN ('SUBMITTED', 'UNDER_REVIEW', 'MORE_INFO_REQUIRED');
CREATE INDEX ix_compliance_rule_scope_status
    ON marketplace.compliance_rule (scope, jurisdiction, status);
CREATE INDEX ix_compliance_rule_version_effective
    ON marketplace.compliance_rule_version (
        compliance_rule_id, effective_from DESC, effective_to
    );
CREATE INDEX ix_product_compliance_rule_status
    ON marketplace.product_compliance_finding (rule_version_id, status, detected_at DESC)
    INCLUDE (product_revision_id, severity);
CREATE INDEX ix_product_compliance_review_queue
    ON marketplace.product_compliance_finding (severity, detected_at, finding_id)
    INCLUDE (product_revision_id, rule_version_id)
    WHERE status IN ('FAIL', 'NEEDS_REVIEW');
CREATE INDEX ix_product_compliance_evidence_gin
    ON marketplace.product_compliance_finding USING gin (evidence jsonb_path_ops);
CREATE INDEX ix_seller_compliance_task_due
    ON marketplace.seller_compliance_task (due_at, seller_id)
    INCLUDE (task_type, priority)
    WHERE status IN ('OPEN', 'IN_PROGRESS', 'SUBMITTED', 'OVERDUE');
CREATE INDEX ix_seller_compliance_task_seller
    ON marketplace.seller_compliance_task (seller_id, status, due_at DESC)
    INCLUDE (task_type, priority);
CREATE INDEX ix_seller_compliance_task_assignee
    ON marketplace.seller_compliance_task (assigned_admin_user_id, status, due_at)
    WHERE assigned_admin_user_id IS NOT NULL
      AND status IN ('OPEN', 'IN_PROGRESS', 'SUBMITTED', 'OVERDUE');
CREATE INDEX ix_seller_compliance_task_item_finding
    ON marketplace.seller_compliance_task_item (finding_id, status);
CREATE INDEX outbox_event_publish_worker_idx
    ON marketplace.outbox_event (available_at, occurred_at, outbox_event_id)
    WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX outbox_event_stale_lock_idx
    ON marketplace.outbox_event (locked_at, outbox_event_id)
    WHERE status = 'PUBLISHING';
CREATE INDEX outbox_event_aggregate_timeline_idx
    ON marketplace.outbox_event (aggregate_type, aggregate_id, occurred_at, outbox_event_id);
COMMIT;
