package multi.com.marketplace.pgnaversimulator.domain;

import java.time.Instant;
import java.util.UUID;

public record PgPayment(UUID paymentId, String merchantTxId, String currency,
                        long amount, PgPaymentStatus status, long refundedAmount,
                        Instant createdAt, Instant updatedAt) {
    public PgPayment refund(long refundAmount) {
        if (status != PgPaymentStatus.APPROVED && status != PgPaymentStatus.PARTIALLY_REFUNDED) {
            throw new IllegalStateException("현재 결제 상태에서는 환불할 수 없습니다.");
        }
        if (refundAmount <= 0 || refundAmount > amount - refundedAmount) {
            throw new IllegalArgumentException("환불 금액이 남은 결제 금액을 초과했습니다.");
        }
        long next = refundedAmount + refundAmount;
        return new PgPayment(paymentId, merchantTxId, currency, amount,
                next == amount ? PgPaymentStatus.REFUNDED : PgPaymentStatus.PARTIALLY_REFUNDED,
                next, createdAt, Instant.now());
    }
}

