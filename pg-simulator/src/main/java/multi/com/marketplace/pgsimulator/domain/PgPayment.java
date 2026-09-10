package multi.com.marketplace.pgsimulator.domain;

import java.time.Instant;
import java.util.UUID;

public record PgPayment(UUID paymentId, String merchantTxId, String currency,
                        long amount, PgPaymentStatus status, long refundedAmount,
                        Instant createdAt, Instant updatedAt) {
    public PgPayment refund(long refundAmount) {
        if (refundAmount <= 0 || refundAmount > amount - refundedAmount) {
            throw new IllegalArgumentException("Refund amount exceeds remaining amount");
        }
        long next = refundedAmount + refundAmount;
        return new PgPayment(paymentId, merchantTxId, currency, amount,
                next == amount ? PgPaymentStatus.REFUNDED : PgPaymentStatus.PARTIALLY_REFUNDED,
                next, createdAt, Instant.now());
    }
}
