-- Restore intra-service FKs omitted when an ALTER also contained external references.
-- V1 is immutable. Existing orphan rows cause this migration to fail; investigate them,
-- do not delete data or use Flyway repair to bypass the failure.

ALTER TABLE marketplace.search_impression ADD CONSTRAINT fk_search_impression_request
        FOREIGN KEY (search_request_id)
        REFERENCES marketplace.search_request (search_request_id) ON DELETE RESTRICT;
