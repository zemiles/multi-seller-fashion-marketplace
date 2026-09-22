-- Restore intra-service FKs omitted when an ALTER also contained external references.
-- V1 is immutable. Existing orphan rows cause this migration to fail; investigate them,
-- do not delete data or use Flyway repair to bypass the failure.

ALTER TABLE marketplace.payment ADD CONSTRAINT payment_attempt_fk
    FOREIGN KEY (payment_attempt_id) REFERENCES marketplace.payment_attempt (payment_attempt_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.payment_item ADD CONSTRAINT payment_item_payment_fk
    FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.payment_charge_allocation ADD CONSTRAINT payment_charge_allocation_payment_fk
    FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_transaction_fk
    FOREIGN KEY (payment_transaction_id) REFERENCES marketplace.payment_transaction (payment_transaction_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_item_fk
    FOREIGN KEY (payment_item_id) REFERENCES marketplace.payment_item (payment_item_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.payment_transaction_allocation ADD CONSTRAINT payment_transaction_allocation_charge_fk
    FOREIGN KEY (payment_charge_allocation_id) REFERENCES marketplace.payment_charge_allocation (payment_charge_allocation_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.refund ADD CONSTRAINT refund_payment_fk
    FOREIGN KEY (payment_id) REFERENCES marketplace.payment (payment_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.refund_item ADD CONSTRAINT refund_item_refund_fk
    FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.refund_item ADD CONSTRAINT refund_item_payment_item_fk
    FOREIGN KEY (payment_item_id) REFERENCES marketplace.payment_item (payment_item_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.refund_charge_adjustment ADD CONSTRAINT refund_charge_adjustment_refund_fk
    FOREIGN KEY (refund_id) REFERENCES marketplace.refund (refund_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.refund_charge_adjustment ADD CONSTRAINT refund_charge_adjustment_payment_charge_fk
    FOREIGN KEY (payment_charge_allocation_id) REFERENCES marketplace.payment_charge_allocation (payment_charge_allocation_id) ON DELETE RESTRICT;
