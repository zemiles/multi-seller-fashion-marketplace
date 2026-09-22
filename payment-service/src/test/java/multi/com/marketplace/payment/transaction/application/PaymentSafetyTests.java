package multi.com.marketplace.payment.transaction.application;

import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import multi.com.marketplace.payment.refund.application.RefundUseCase.RequestRefund;
import multi.com.marketplace.payment.refund.domain.*;
import multi.com.marketplace.payment.transaction.domain.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PaymentSafetyTests {
    private final CountingProvider provider = new CountingProvider();
    private final PaymentLifecycleService service = new PaymentLifecycleService(provider);

    @Test
    void invalidRefundNeverReachesProviderOrChangesBalance() {
        var payment = approved();
        assertThrows(IllegalArgumentException.class, () -> service.request(refund(payment.id(), "key", 100, " ")));
        assertThrows(IllegalArgumentException.class, () -> service.request(null));
        assertThrows(IllegalArgumentException.class, () -> service.request(refund(UUID.randomUUID(), "key", 100, "RETURN")));
        assertThrows(IllegalArgumentException.class, () -> service.request(new RequestRefund(payment.id(), null,
                "key", new PaymentAmount("KRW", 100), "RETURN", RefundRequesterType.MEMBER, null)));
        assertEquals(0, provider.refunds.get());
        assertEquals(1000, service.findPayment(payment.id()).orElseThrow().remainingAmount());
    }

    @Test
    void sameRefundKeyMustHaveIdenticalPayload() {
        var payment = approved();
        var original = refund(payment.id(), "key", 100, "RETURN");
        var first = service.request(original);
        assertEquals(first, service.request(original));
        assertThrows(IllegalArgumentException.class, () -> service.request(refund(payment.id(), "key", 200, "RETURN")));
        assertThrows(IllegalArgumentException.class, () -> service.request(refund(payment.id(), "key", 100, "OTHER")));
        assertThrows(IllegalArgumentException.class, () -> service.request(new RequestRefund(payment.id(), UUID.randomUUID(),
                "key", original.requestedAmount(), "RETURN", RefundRequesterType.SYSTEM, null)));
        assertThrows(IllegalArgumentException.class, () -> service.request(new RequestRefund(payment.id(), null,
                "key", original.requestedAmount(), "RETURN", RefundRequesterType.ADMIN, UUID.randomUUID())));
        assertEquals(1, provider.refunds.get());
        assertEquals(payment.providerPaymentKey(), provider.lastRefund.providerPaymentKey());
        assertEquals("TEST", provider.lastRefund.provider());
        assertEquals("key", provider.lastRefund.idempotencyKey());
    }

    @Test
    void duplicateMerchantAndDuplicateOrderAcrossProvidersAreRejected() {
        UUID order = UUID.randomUUID();
        var command = prepare(order, "TEST", "merchant", "key");
        var first = service.prepare(command);
        assertEquals(first, service.prepare(command));
        assertThrows(IllegalArgumentException.class,
                () -> service.prepare(prepare(UUID.randomUUID(), "TEST", "merchant", "new-key")));
        assertThrows(IllegalStateException.class,
                () -> service.prepare(prepare(order, "OTHER", "other-merchant", "other-key")));
        service.approve(first.id());
        assertThrows(IllegalStateException.class,
                () -> service.prepare(prepare(order, "OTHER", "other-merchant", "other-key")));
        assertEquals("key", provider.lastApproval.idempotencyKey());
    }

    @Test
    void compoundKeysCannotCollideOnColonSeparators() {
        var a = service.prepare(prepare(UUID.randomUUID(), "A:B", "m1", "C"));
        var b = service.prepare(prepare(UUID.randomUUID(), "A", "m2", "B:C"));
        assertNotEquals(a.id(), b.id());
    }

    @Test
    void failedApprovalBecomesUnknownAndCannotBeRepeated() {
        provider.failApproval = true;
        var attempt = service.prepare(prepare(UUID.randomUUID(), "TEST", "merchant", "key"));
        assertThrows(IllegalStateException.class, () -> service.approve(attempt.id()));
        assertEquals(PaymentAttemptStatus.UNKNOWN, service.findAttempt(attempt.id()).orElseThrow().status());
        assertThrows(IllegalStateException.class, () -> service.approve(attempt.id()));
        assertEquals(1, provider.approvals.get());
    }

    @Test
    void unknownRefundRetainsItsKeyAndReservesAmount() {
        var payment = approved();
        provider.failRefund = true;
        var command = refund(payment.id(), "uncertain", 700, "RETURN");
        assertThrows(IllegalStateException.class, () -> service.request(command));
        var unknown = service.request(command);
        assertEquals(RefundStatus.UNKNOWN, unknown.status());
        assertEquals(0, unknown.actualRefundedAmount());
        assertThrows(IllegalArgumentException.class,
                () -> service.request(refund(payment.id(), "another", 400, "RETURN")));
        assertEquals(1, provider.refunds.get());
        provider.failRefund = false;
        service.request(refund(payment.id(), "remaining", 300, "RETURN"));
        assertEquals(700, service.findPayment(payment.id()).orElseThrow().remainingAmount());
        assertThrows(IllegalArgumentException.class,
                () -> service.request(refund(payment.id(), "overspend", 1, "RETURN")));
    }

    @Test
    void invalidProviderResultAlsoRetainsUncertainty() {
        var payment = approved();
        provider.mismatchRefund = true;
        var command = refund(payment.id(), "mismatch", 700, "RETURN");
        assertThrows(IllegalStateException.class, () -> service.request(command));
        assertEquals(RefundStatus.UNKNOWN, service.request(command).status());
        assertEquals(1000, service.findPayment(payment.id()).orElseThrow().remainingAmount());
        assertEquals(1, provider.refunds.get());
    }

    private Payment approved() {
        return service.approve(service.prepare(prepare(UUID.randomUUID(), "TEST", "merchant", "approve")).id());
    }

    private PaymentUseCase.PreparePayment prepare(UUID order, String pg, String merchant, String key) {
        return new PaymentUseCase.PreparePayment(UUID.randomUUID(), order, pg, merchant, key,
                "CARD", new PaymentAmount("KRW", 1000));
    }

    private RequestRefund refund(UUID id, String key, long amount, String reason) {
        return new RequestRefund(id, null, key, new PaymentAmount("KRW", amount), reason, RefundRequesterType.SYSTEM, null);
    }

    private static class CountingProvider implements PaymentProviderPort {
        AtomicInteger approvals = new AtomicInteger();
        AtomicInteger refunds = new AtomicInteger();
        boolean failApproval, failRefund, mismatchRefund;
        ApprovalRequest lastApproval;
        RefundRequest lastRefund;
        public Approval approve(ApprovalRequest request) {
            approvals.incrementAndGet();
            lastApproval = request;
            if (failApproval) throw new IllegalStateException("timeout after possible PG approval");
            return new Approval("pg-key", request.amount());
        }
        public RefundResult refund(RefundRequest request) {
            refunds.incrementAndGet();
            lastRefund = request;
            if (failRefund) throw new IllegalStateException("timeout after possible PG refund");
            return new RefundResult(mismatchRefund ? 1 : request.amount().amount());
        }
    }
}
