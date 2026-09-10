package multi.com.marketplace.payment.refund.domain;

import java.util.Objects;
import java.util.UUID;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;

/** Core refund snapshot; item and charge allocations are modeled in a later use case. */
public record Refund(
        UUID id, UUID paymentId, UUID claimId, String idempotencyKey,
        PaymentAmount requestedAmount, long actualRefundedAmount, RefundStatus status,
        String reasonCode, RefundRequesterType requestedByType, UUID requestedById) {
    public Refund {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(paymentId, "paymentId");
        Objects.requireNonNull(requestedAmount, "requestedAmount");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(requestedByType, "requestedByType");
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            throw new IllegalArgumentException("Idempotency key must not be blank");
        }
        if (reasonCode == null || reasonCode.isBlank()) {
            throw new IllegalArgumentException("Reason code must not be blank");
        }
        if (actualRefundedAmount < 0 || actualRefundedAmount > requestedAmount.amount()) {
            throw new IllegalArgumentException("Actual refunded amount must be between zero and requested amount");
        }
    }
}
