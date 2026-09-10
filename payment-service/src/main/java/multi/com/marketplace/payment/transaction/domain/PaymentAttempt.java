package multi.com.marketplace.payment.transaction.domain;

import java.util.Objects;
import java.util.UUID;

/** Core attempt snapshot; provider payloads and persistence belong to adapters. */
public record PaymentAttempt(
        UUID id, UUID checkoutId, UUID orderId, String provider,
        String merchantTxId, String idempotencyKey, String paymentMethod,
        PaymentAmount requestedAmount, PaymentAttemptStatus status) {
    public PaymentAttempt {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(checkoutId, "checkoutId");
        Objects.requireNonNull(orderId, "orderId");
        Objects.requireNonNull(requestedAmount, "requestedAmount");
        Objects.requireNonNull(status, "status");
        requireText(provider, "provider");
        requireText(merchantTxId, "merchantTxId");
        requireText(idempotencyKey, "idempotencyKey");
        requireText(paymentMethod, "paymentMethod");
    }

    private static void requireText(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank");
        }
    }
}
