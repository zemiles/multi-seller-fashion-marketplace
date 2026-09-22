-- discovery-data-service: empty isolated database schema snapshot.
-- NOT an upgrade migration. NEVER apply to an existing/production database.
-- Generated from the same model as ERD; cross-row money/authority rules remain owner transactions.
-- PostgreSQL 17+; gen_random_uuid() is a built-in function. No external extension required.
BEGIN;
CREATE SCHEMA IF NOT EXISTS marketplace;

CREATE TABLE marketplace.concept_taxonomy_version (
    taxonomy_version_id uuid DEFAULT gen_random_uuid() NOT NULL,
    version text NOT NULL,
    status text DEFAULT 'DRAFT' NOT NULL,
    definition_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    effective_from timestamptz,
    effective_to timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_concept_taxonomy_version PRIMARY KEY (taxonomy_version_id),
    CONSTRAINT uq_concept_taxonomy_version UNIQUE (version),
    CONSTRAINT ck_concept_taxonomy_version_text CHECK (char_length(btrim(version)) > 0),
    CONSTRAINT ck_concept_taxonomy_status CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED')),
    CONSTRAINT ck_concept_taxonomy_definition_object CHECK (
        jsonb_typeof(definition_snapshot) = 'object'
    ),
    CONSTRAINT ck_concept_taxonomy_effective_period CHECK (
        effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from
    ),
    CONSTRAINT ck_concept_taxonomy_active_state CHECK (
        status <> 'ACTIVE' OR effective_from IS NOT NULL
    )
);

CREATE TABLE marketplace.concept (
    concept_id uuid DEFAULT gen_random_uuid() NOT NULL,
    taxonomy_version_id uuid NOT NULL,
    concept_code text NOT NULL,
    display_name text NOT NULL,
    definition text,
    status text DEFAULT 'ACTIVE' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_concept PRIMARY KEY (concept_id),
    CONSTRAINT uq_concept_taxonomy_code UNIQUE (taxonomy_version_id, concept_code),
    CONSTRAINT uq_concept_taxonomy_concept UNIQUE (taxonomy_version_id, concept_id),
    CONSTRAINT ck_concept_code CHECK (char_length(btrim(concept_code)) > 0),
    CONSTRAINT ck_concept_display_name CHECK (char_length(btrim(display_name)) > 0),
    CONSTRAINT ck_concept_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE marketplace.concept_alias (
    alias_id uuid DEFAULT gen_random_uuid() NOT NULL,
    concept_id uuid NOT NULL,
    locale text DEFAULT 'ko-KR' NOT NULL,
    alias_text text NOT NULL,
    alias_text_normalized text NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_concept_alias PRIMARY KEY (alias_id),
    CONSTRAINT uq_concept_alias_text UNIQUE (concept_id, locale, alias_text_normalized),
    CONSTRAINT ck_concept_alias_locale CHECK (char_length(btrim(locale)) > 0),
    CONSTRAINT ck_concept_alias_text CHECK (char_length(btrim(alias_text)) > 0),
    CONSTRAINT ck_concept_alias_normalized CHECK (
        alias_text_normalized = lower(btrim(alias_text_normalized))
        AND char_length(alias_text_normalized) > 0
    )
);

CREATE TABLE marketplace.product_analysis_run (
    analysis_run_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_revision_id uuid NOT NULL,
    taxonomy_version_id uuid NOT NULL,
    idempotency_key text NOT NULL,
    model_provider text NOT NULL,
    model_version text NOT NULL,
    prompt_version text NOT NULL,
    input_hash text NOT NULL,
    parameters_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'QUEUED' NOT NULL,
    error_code text,
    created_at timestamptz DEFAULT now() NOT NULL,
    started_at timestamptz,
    completed_at timestamptz,
    CONSTRAINT pk_product_analysis_run PRIMARY KEY (analysis_run_id),
    CONSTRAINT uq_product_analysis_idempotency UNIQUE (idempotency_key),
    CONSTRAINT uq_product_analysis_taxonomy_run UNIQUE (taxonomy_version_id, analysis_run_id),
    CONSTRAINT ck_product_analysis_idempotency CHECK (char_length(btrim(idempotency_key)) > 0),
    CONSTRAINT ck_product_analysis_model_provider CHECK (char_length(btrim(model_provider)) > 0),
    CONSTRAINT ck_product_analysis_model_version CHECK (char_length(btrim(model_version)) > 0),
    CONSTRAINT ck_product_analysis_prompt_version CHECK (char_length(btrim(prompt_version)) > 0),
    CONSTRAINT ck_product_analysis_input_hash CHECK (char_length(btrim(input_hash)) > 0),
    CONSTRAINT ck_product_analysis_parameters_object CHECK (
        jsonb_typeof(parameters_snapshot) = 'object'
    ),
    CONSTRAINT ck_product_analysis_status CHECK (
        status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_product_analysis_started_state CHECK (
        status NOT IN ('RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED') OR started_at IS NOT NULL
    ),
    CONSTRAINT ck_product_analysis_completed_state CHECK (
        status NOT IN ('SUCCEEDED', 'FAILED', 'CANCELLED') OR completed_at IS NOT NULL
    ),
    CONSTRAINT ck_product_analysis_time_order CHECK (
        completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
    )
);

CREATE TABLE marketplace.product_concept (
    product_concept_id uuid DEFAULT gen_random_uuid() NOT NULL,
    analysis_run_id uuid NOT NULL,
    concept_id uuid NOT NULL,
    taxonomy_version_id uuid NOT NULL,
    relevance_score numeric(7,6) NOT NULL,
    confidence numeric(7,6) NOT NULL,
    assignment_source text DEFAULT 'MODEL' NOT NULL,
    review_status text DEFAULT 'UNREVIEWED' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    reviewed_at timestamptz,
    CONSTRAINT pk_product_concept PRIMARY KEY (product_concept_id),
    CONSTRAINT uq_product_concept_run_concept UNIQUE (analysis_run_id, concept_id),
    CONSTRAINT ck_product_concept_relevance CHECK (relevance_score BETWEEN 0 AND 1),
    CONSTRAINT ck_product_concept_confidence CHECK (confidence BETWEEN 0 AND 1),
    CONSTRAINT ck_product_concept_assignment_source CHECK (
        assignment_source IN ('MODEL', 'HUMAN', 'RULE')
    ),
    CONSTRAINT ck_product_concept_review_status CHECK (
        review_status IN ('UNREVIEWED', 'ACCEPTED', 'REJECTED', 'ADJUSTED')
    ),
    CONSTRAINT ck_product_concept_reviewed_state CHECK (
        review_status = 'UNREVIEWED' OR reviewed_at IS NOT NULL
    )
);

CREATE TABLE marketplace.product_concept_evidence (
    evidence_id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_concept_id uuid NOT NULL,
    source_product_image_id uuid,
    source_product_feature_id uuid,
    evidence_type text NOT NULL,
    evidence_ref text NOT NULL,
    excerpt_hash text,
    evidence_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    evidence_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT pk_product_concept_evidence PRIMARY KEY (evidence_id),
    CONSTRAINT ck_product_concept_evidence_type CHECK (
        evidence_type IN ('PRODUCT_TEXT', 'FEATURE', 'IMAGE', 'OCR', 'EXTERNAL', 'HUMAN_NOTE')
    ),
    CONSTRAINT ck_product_concept_evidence_ref CHECK (char_length(btrim(evidence_ref)) > 0),
    CONSTRAINT ck_product_concept_excerpt_hash CHECK (
        excerpt_hash IS NULL OR char_length(btrim(excerpt_hash)) > 0
    ),
    CONSTRAINT ck_product_concept_evidence_object CHECK (
        jsonb_typeof(evidence_snapshot) = 'object'
    ),
    CONSTRAINT ck_product_concept_evidence_order CHECK (evidence_order >= 0)
);

CREATE TABLE marketplace.search_request (
    search_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid,
    anonymous_id text,
    session_id text NOT NULL,
    normalized_query text NOT NULL DEFAULT '',
    filters jsonb NOT NULL DEFAULT '{}'::jsonb,
    sort_code text NOT NULL DEFAULT 'RELEVANCE',
    algorithm_version text NOT NULL,
    locale text,
    requested_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_search_request_actor CHECK (
        member_id IS NOT NULL OR (anonymous_id IS NOT NULL AND btrim(anonymous_id) <> '')
    ),
    CONSTRAINT ck_search_request_session_not_blank CHECK (btrim(session_id) <> ''),
    CONSTRAINT ck_search_request_algorithm_not_blank CHECK (btrim(algorithm_version) <> ''),
    CONSTRAINT ck_search_request_filters_object CHECK (jsonb_typeof(filters) = 'object'),
    CONSTRAINT ck_search_request_query_length CHECK (char_length(normalized_query) <= 1000)
);

CREATE TABLE marketplace.search_impression (
    search_impression_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    search_request_id uuid NOT NULL,
    product_revision_id uuid NOT NULL,
    image_id uuid,
    impression_token text NOT NULL,
    position integer NOT NULL,
    score numeric(20,10),
    placement_type text NOT NULL DEFAULT 'ORGANIC',
    rendered_product_name text NOT NULL,
    rendered_price_amount bigint NOT NULL,
    currency text NOT NULL,
    impressed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_search_impression_token UNIQUE (impression_token),
    CONSTRAINT uq_search_impression_position UNIQUE (search_request_id, position),
    CONSTRAINT uq_search_impression_product UNIQUE (search_request_id, product_revision_id),
    CONSTRAINT ck_search_impression_position CHECK (position > 0),
    CONSTRAINT ck_search_impression_placement CHECK (placement_type IN (
        'ORGANIC', 'SPONSORED', 'RECOMMENDED'
    )),
    CONSTRAINT ck_search_impression_price CHECK (rendered_price_amount >= 0),
    CONSTRAINT ck_search_impression_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_search_impression_token_not_blank CHECK (btrim(impression_token) <> ''),
    CONSTRAINT ck_search_impression_name_not_blank CHECK (btrim(rendered_product_name) <> '')
);

CREATE TABLE marketplace.user_behavior_event (
    event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type text NOT NULL,
    schema_version integer NOT NULL,
    member_id uuid,
    anonymous_id text,
    session_id text NOT NULL,
    product_id uuid,
    search_request_id uuid,
    order_item_id uuid,
    dedupe_key text NOT NULL,
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_behavior_dedupe_key UNIQUE (dedupe_key),
    CONSTRAINT ck_user_behavior_schema_version CHECK (schema_version > 0),
    CONSTRAINT ck_user_behavior_actor CHECK (
        member_id IS NOT NULL OR (anonymous_id IS NOT NULL AND btrim(anonymous_id) <> '')
    ),
    CONSTRAINT ck_user_behavior_session_not_blank CHECK (btrim(session_id) <> ''),
    CONSTRAINT ck_user_behavior_event_type_not_blank CHECK (btrim(event_type) <> ''),
    CONSTRAINT ck_user_behavior_dedupe_not_blank CHECK (btrim(dedupe_key) <> ''),
    CONSTRAINT ck_user_behavior_payload_object CHECK (jsonb_typeof(event_payload) = 'object')
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

ALTER TABLE marketplace.concept ADD CONSTRAINT fk_concept_taxonomy_version FOREIGN KEY (taxonomy_version_id) REFERENCES marketplace.concept_taxonomy_version (taxonomy_version_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.concept_alias ADD CONSTRAINT fk_concept_alias_concept FOREIGN KEY (concept_id) REFERENCES marketplace.concept (concept_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_analysis_run ADD CONSTRAINT fk_product_analysis_run_taxonomy FOREIGN KEY (taxonomy_version_id) REFERENCES marketplace.concept_taxonomy_version (taxonomy_version_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_concept ADD CONSTRAINT fk_product_concept_analysis_run FOREIGN KEY (taxonomy_version_id, analysis_run_id) REFERENCES marketplace.product_analysis_run (taxonomy_version_id, analysis_run_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_concept ADD CONSTRAINT fk_product_concept_concept FOREIGN KEY (taxonomy_version_id, concept_id) REFERENCES marketplace.concept (taxonomy_version_id, concept_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.product_concept_evidence ADD CONSTRAINT fk_product_concept_evidence_concept FOREIGN KEY (product_concept_id) REFERENCES marketplace.product_concept (product_concept_id) ON DELETE RESTRICT;
ALTER TABLE marketplace.search_impression ADD CONSTRAINT fk_search_impression_request FOREIGN KEY (search_request_id) REFERENCES marketplace.search_request (search_request_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX ux_concept_taxonomy_single_active
    ON marketplace.concept_taxonomy_version ((1))
    WHERE status = 'ACTIVE';
CREATE INDEX idx_product_analysis_revision_taxonomy_latest
    ON marketplace.product_analysis_run (
        product_revision_id, taxonomy_version_id, created_at DESC, analysis_run_id
    );
CREATE INDEX idx_product_concept_concept_relevance
    ON marketplace.product_concept (
        taxonomy_version_id, concept_id, relevance_score DESC, product_concept_id
    );
CREATE INDEX idx_product_concept_evidence_order
    ON marketplace.product_concept_evidence (
        product_concept_id, evidence_order, evidence_id
    );
CREATE INDEX idx_product_concept_evidence_image
    ON marketplace.product_concept_evidence (source_product_image_id)
    WHERE source_product_image_id IS NOT NULL;
CREATE INDEX idx_product_concept_evidence_feature
    ON marketplace.product_concept_evidence (source_product_feature_id)
    WHERE source_product_feature_id IS NOT NULL;
CREATE INDEX ix_search_request_member_time
    ON marketplace.search_request (member_id, requested_at DESC)
    WHERE member_id IS NOT NULL;
CREATE INDEX ix_search_request_anonymous_time
    ON marketplace.search_request (anonymous_id, requested_at DESC)
    WHERE anonymous_id IS NOT NULL;
CREATE INDEX ix_search_request_session_time
    ON marketplace.search_request (session_id, requested_at DESC);
CREATE INDEX ix_search_request_filters_gin
    ON marketplace.search_request USING gin (filters jsonb_path_ops);
CREATE INDEX ix_search_impression_revision_time
    ON marketplace.search_impression (product_revision_id, impressed_at DESC)
    INCLUDE (search_request_id, position, placement_type);
CREATE INDEX ix_search_impression_image_time
    ON marketplace.search_impression (image_id, impressed_at DESC)
    INCLUDE (product_revision_id, search_request_id, position)
    WHERE image_id IS NOT NULL;
CREATE INDEX ix_user_behavior_event_type_time
    ON marketplace.user_behavior_event (event_type, occurred_at DESC);
CREATE INDEX ix_user_behavior_member_time
    ON marketplace.user_behavior_event (member_id, occurred_at DESC)
    WHERE member_id IS NOT NULL;
CREATE INDEX ix_user_behavior_anonymous_time
    ON marketplace.user_behavior_event (anonymous_id, occurred_at DESC)
    WHERE anonymous_id IS NOT NULL;
CREATE INDEX ix_user_behavior_session_time
    ON marketplace.user_behavior_event (session_id, occurred_at DESC);
CREATE INDEX ix_user_behavior_product_time
    ON marketplace.user_behavior_event (product_id, occurred_at DESC)
    WHERE product_id IS NOT NULL;
CREATE INDEX ix_user_behavior_search_request
    ON marketplace.user_behavior_event (search_request_id, occurred_at DESC)
    WHERE search_request_id IS NOT NULL;
CREATE INDEX ix_user_behavior_occurred_brin
    ON marketplace.user_behavior_event USING brin (occurred_at)
    WITH (pages_per_range = 64);
CREATE INDEX outbox_event_publish_worker_idx
    ON marketplace.outbox_event (available_at, occurred_at, outbox_event_id)
    WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX outbox_event_stale_lock_idx
    ON marketplace.outbox_event (locked_at, outbox_event_id)
    WHERE status = 'PUBLISHING';
CREATE INDEX outbox_event_aggregate_timeline_idx
    ON marketplace.outbox_event (aggregate_type, aggregate_id, occurred_at, outbox_event_id);
COMMIT;
