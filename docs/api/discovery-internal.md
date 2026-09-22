# Discovery 내부 API

[OpenAPI](../../contracts/discovery-internal.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| GET | /internal/v1/search/products | querySearchProducts | commerce-service | DIS-01 |
| POST | /internal/v1/products/{productId}/analysis-runs | queueAnalysis | commerce-service | DIS-02 |
| GET | /internal/v1/analysis-runs/{runId} | queryAnalysis | commerce-service | DIS-02 |
| POST | /internal/v1/products/{productId}/concept-reviews | applyConceptReview | commerce-service | DIS-02 |
| POST | /internal/v1/concept-taxonomies | addTaxonomy | commerce-service | DIS-02 |
| GET | /internal/v1/concept-taxonomies | queryTaxonomies | commerce-service | DIS-02 |
| POST | /internal/v1/concept-taxonomies/{taxonomyId}/publish | activateTaxonomy | commerce-service | DIS-02 |
| POST | /internal/v1/behavior-events/batch | ingestBehavior | commerce-service | DIS-03 |
| POST | /internal/v1/search/rebuilds | rebuildProjection | commerce-service | DIS-01 |
| GET | /internal/v1/search/rebuilds/{generationId} | queryProjectionRebuild | commerce-service | DIS-01 |
| POST | /internal/v1/server-behavior-events | ingestServerBehavior | commerce-service | DIS-03, EXP-01, ORD-01 |
