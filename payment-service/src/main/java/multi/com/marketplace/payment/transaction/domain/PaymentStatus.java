package multi.com.marketplace.payment.transaction.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum PaymentStatus {
    APPROVED, PARTIALLY_REFUNDED, REFUNDED, VOIDED, CHARGEBACK
}
