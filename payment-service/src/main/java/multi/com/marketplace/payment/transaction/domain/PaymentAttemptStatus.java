package multi.com.marketplace.payment.transaction.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum PaymentAttemptStatus {
    CREATED, REQUESTED, PENDING, SUCCEEDED, FAILED, UNKNOWN, CANCELLED
}
