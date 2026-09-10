package multi.com.marketplace.payment.transaction.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/** Approved payment snapshot, separate from an attempt and its transaction history. */
public record Payment(
        UUID id, UUID paymentAttemptId, UUID orderId, String provider,
        String providerPaymentKey, String paymentMethod, PaymentAmount totalAmount,
        long refundedAmount, PaymentStatus status, Instant approvedAt, int version) {
    public Payment {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(paymentAttemptId, "paymentAttemptId");
        Objects.requireNonNull(orderId, "orderId");
        Objects.requireNonNull(totalAmount, "totalAmount");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(approvedAt, "approvedAt");
        requireText(provider, "provider");
        requireText(providerPaymentKey, "providerPaymentKey");
        requireText(paymentMethod, "paymentMethod");
        if (refundedAmount < 0 || refundedAmount > totalAmount.amount()) {
            throw new IllegalArgumentException("Refunded amount must be between zero and total amount");
        }
        if (version < 0) {
            throw new IllegalArgumentException("Version must not be negative");
        }
    }

    /** Accounting balance only; does not authorize or reserve a refund. */
    public long remainingAmount() {
        return totalAmount.amount() - refundedAmount;
    }

    private static void requireText(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank");
        }
    }
}
