package multi.com.marketplace.payment.transaction.application;

import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import multi.com.marketplace.payment.refund.application.RefundUseCase;
import multi.com.marketplace.payment.refund.domain.RefundRequesterType;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;
import multi.com.marketplace.payment.transaction.domain.PaymentAttemptStatus;
import multi.com.marketplace.payment.transaction.domain.PaymentStatus;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PaymentLifecycleServiceTests {
    private final UUID checkoutId = UUID.randomUUID();
    private final UUID orderId = UUID.randomUUID();

    @Test
    void prepareIsIdempotentAndRejectsChangedPayload() {
        PaymentLifecycleService service = new PaymentLifecycleService(new FakeProvider());
        PaymentUseCase.PreparePayment command = prepare("key", 10_000);
        var first = service.prepare(command);
        var second = service.prepare(command);
        assertEquals(first.id(), second.id());
        assertEquals(PaymentAttemptStatus.CREATED, first.status());
        assertThrows(IllegalArgumentException.class, () -> service.prepare(prepare("key", 20_000)));
    }

    @Test
    void approvalPersistsPaymentAndRejectsProviderAmountMismatch() {
        FakeProvider provider = new FakeProvider();
        PaymentLifecycleService service = new PaymentLifecycleService(provider);
        var attempt = service.prepare(prepare("approval-key", 10_000));
        var payment = service.approve(attempt.id());
        assertEquals(PaymentStatus.APPROVED, payment.status());
        assertEquals(10_000, payment.remainingAmount());
        assertEquals(PaymentAttemptStatus.SUCCEEDED, service.findAttempt(attempt.id()).orElseThrow().status());
        assertSame(payment, service.approve(attempt.id()));
        assertEquals(1, provider.approvals.get());

        FakeProvider mismatch = new FakeProvider();
        mismatch.approvalAmount = 9_999;
        PaymentLifecycleService mismatchedService = new PaymentLifecycleService(mismatch);
        var mismatchedAttempt = mismatchedService.prepare(prepare("mismatch-key", 10_000));
        assertThrows(IllegalStateException.class, () -> mismatchedService.approve(mismatchedAttempt.id()));
    }

    @Test
    void refundIsIdempotentAndCannotExceedRemainingAmount() {
        FakeProvider provider = new FakeProvider();
        PaymentLifecycleService service = new PaymentLifecycleService(provider);
        var payment = service.approve(service.prepare(prepare("refund-attempt", 10_000)).id());
        var command = new RefundUseCase.RequestRefund(payment.id(), null, "refund-key",
                new PaymentAmount("KRW", 4_000), "CUSTOMER_REQUEST", RefundRequesterType.MEMBER, UUID.randomUUID());
        var refund = service.request(command);
        assertEquals(4_000, refund.actualRefundedAmount());
        assertSame(refund, service.request(command));
        assertEquals(6_000, service.findPayment(payment.id()).orElseThrow().remainingAmount());
        assertThrows(IllegalArgumentException.class, () -> service.request(new RefundUseCase.RequestRefund(
                payment.id(), null, "too-much", new PaymentAmount("KRW", 7_000),
                "CUSTOMER_REQUEST", RefundRequesterType.MEMBER, UUID.randomUUID())));
        assertEquals(1, provider.refunds.get());
    }

    private PaymentUseCase.PreparePayment prepare(String key, long amount) {
        return new PaymentUseCase.PreparePayment(checkoutId, orderId, "TEST", "merchant-" + key,
                key, "CARD", new PaymentAmount("KRW", amount));
    }

    private static final class FakeProvider implements PaymentProviderPort {
        private final AtomicInteger approvals = new AtomicInteger();
        private final AtomicInteger refunds = new AtomicInteger();
        private long approvalAmount = 10_000;

        @Override public Approval approve(ApprovalRequest request) {
            approvals.incrementAndGet();
            return new Approval("provider-payment-key", new PaymentAmount("KRW", approvalAmount));
        }

        @Override public RefundResult refund(RefundRequest request) {
            refunds.incrementAndGet();
            return new RefundResult(request.amount().amount());
        }
    }
}
