package multi.com.marketplace.payment.transaction.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum PaymentTransactionType {
    AUTHORIZE, CAPTURE, SALE, VOID, REFUND, CHARGEBACK, REVERSAL
}
