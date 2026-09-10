package multi.com.marketplace.payment.refund.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum RefundRequesterType {
    MEMBER, SELLER_MEMBER, ADMIN, SYSTEM
}
