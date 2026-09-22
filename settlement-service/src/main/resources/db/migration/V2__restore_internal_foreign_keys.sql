-- Restore intra-service FKs omitted when an ALTER also contained external references.
-- V1 is immutable. Existing orphan rows cause this migration to fail; investigate them,
-- do not delete data or use Flyway repair to bypass the failure.

ALTER TABLE marketplace.seller_ledger_entry ADD CONSTRAINT fk_seller_ledger_reversal
        FOREIGN KEY (reversal_of_entry_id)
        REFERENCES marketplace.seller_ledger_entry (seller_ledger_entry_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_run ADD CONSTRAINT fk_reconciliation_run_replay
        FOREIGN KEY (replay_of_run_id)
        REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_match ADD CONSTRAINT fk_reconciliation_match_run
        FOREIGN KEY (reconciliation_run_id)
        REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_match ADD CONSTRAINT fk_reconciliation_match_raw_row
        FOREIGN KEY (raw_row_id)
        REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_run
        FOREIGN KEY (reconciliation_run_id)
        REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_raw_row
        FOREIGN KEY (raw_row_id)
        REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.reconciliation_discrepancy ADD CONSTRAINT fk_reconciliation_discrepancy_predecessor
        FOREIGN KEY (supersedes_discrepancy_id)
        REFERENCES marketplace.reconciliation_discrepancy (discrepancy_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_run
        FOREIGN KEY (reconciliation_run_id)
        REFERENCES marketplace.reconciliation_run (reconciliation_run_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_payout
        FOREIGN KEY (payout_attempt_id)
        REFERENCES marketplace.settlement_payout_attempt (payout_attempt_id) ON DELETE RESTRICT;

ALTER TABLE marketplace.bank_deposit_match ADD CONSTRAINT fk_bank_deposit_match_raw_row
        FOREIGN KEY (raw_row_id)
        REFERENCES marketplace.reconciliation_raw_row (raw_row_id) ON DELETE RESTRICT;
