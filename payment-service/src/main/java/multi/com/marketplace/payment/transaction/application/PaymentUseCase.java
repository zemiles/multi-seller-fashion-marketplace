package multi.com.marketplace.payment.transaction.application;

import java.util.Optional;
import java.util.UUID;
import multi.com.marketplace.payment.transaction.domain.Payment;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;
import multi.com.marketplace.payment.transaction.domain.PaymentAttempt;

/** Internal contract; no HTTP endpoint or Spring Bean is registered. */
public interface PaymentUseCase {
    /**
     * Prepare a CREATED attempt after verifying the order and amount with Commerce.
     * Implementations must enforce provider-scoped idempotency and reject changed
     * request data for a reused key. This operation does not approve a payment.
     */
    PaymentAttempt prepare(PreparePayment command);

    Optional<PaymentAttempt> findAttempt(UUID paymentAttemptId);

    Optional<Payment> findPayment(UUID paymentId);

    record PreparePayment(UUID checkoutId, UUID orderId, String provider,
                          String merchantTxId, String idempotencyKey,
                          String paymentMethod, PaymentAmount requestedAmount) {}
}
