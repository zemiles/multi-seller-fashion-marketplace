package multi.com.marketplace.payment.refund.application;

import java.util.Optional;
import java.util.UUID;
import multi.com.marketplace.payment.refund.domain.Refund;
import multi.com.marketplace.payment.refund.domain.RefundRequesterType;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;

/** Internal contract; authorization and a durable production implementation are not provided. */
public interface RefundUseCase {
    /**
     * Register a refund request, not a completed PG refund. Implementations must
     * verify the requester, currency, item/charge allocations and available amount,
     * reserve the amount atomically and enforce payment-scoped idempotency.
     */
    Refund request(RequestRefund command);

    Optional<Refund> findRefund(UUID refundId);

    record RequestRefund(UUID paymentId, UUID claimId, String idempotencyKey,
                         PaymentAmount requestedAmount, String reasonCode,
                         RefundRequesterType requestedByType, UUID requestedById) {}
}
