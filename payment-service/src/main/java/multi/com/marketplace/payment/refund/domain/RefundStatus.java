package multi.com.marketplace.payment.refund.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum RefundStatus {
    REQUESTED, PROCESSING, SUCCEEDED, FAILED, UNKNOWN, CANCELLED
}
