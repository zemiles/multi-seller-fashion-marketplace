package multi.com.marketplace.payment.webhook.domain;

/** Values match the payment service's existing database CHECK constraint. */
public enum WebhookStatus {
    RECEIVED, PROCESSING, PROCESSED, FAILED, DEAD
}
