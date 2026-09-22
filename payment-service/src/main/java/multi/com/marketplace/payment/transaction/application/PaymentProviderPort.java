package multi.com.marketplace.payment.transaction.application;

import java.util.UUID;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;

/** Adapter boundary for a real PG. Network calls must stay outside the domain. */
public interface PaymentProviderPort {
    Approval approve(ApprovalRequest request);

    RefundResult refund(RefundRequest request);

    record Approval(String providerPaymentKey, PaymentAmount amount) {}
    record ApprovalRequest(UUID attemptId, String provider, String merchantTxId,
                           String idempotencyKey, PaymentAmount amount) {}
    record RefundResult(long refundedAmount) {}
    record RefundRequest(UUID paymentId, String provider, String providerPaymentKey,
                         String idempotencyKey, PaymentAmount amount) {}
}
