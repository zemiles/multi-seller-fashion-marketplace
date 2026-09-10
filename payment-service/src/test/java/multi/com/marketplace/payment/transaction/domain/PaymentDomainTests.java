package multi.com.marketplace.payment.transaction.domain;

import java.time.Instant;
import java.util.UUID;
import multi.com.marketplace.payment.refund.domain.Refund;
import multi.com.marketplace.payment.refund.domain.RefundRequesterType;
import multi.com.marketplace.payment.refund.domain.RefundStatus;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PaymentDomainTests {
    @Test
    void monetaryAmountsRequirePositiveMinorUnitsAndUppercaseCurrency() {
        assertThrows(IllegalArgumentException.class, () -> new PaymentAmount("KRW", 0));
        assertThrows(IllegalArgumentException.class, () -> new PaymentAmount("KRW", -1));
        assertThrows(IllegalArgumentException.class, () -> new PaymentAmount("krw", 100));
        assertThrows(IllegalArgumentException.class, () -> new PaymentAmount(null, 100));
        assertEquals(Long.MAX_VALUE, new PaymentAmount("KRW", Long.MAX_VALUE).amount());
    }

    @Test
    void calculatesRemainingAmountWithoutFloatingPointOrOverflow() {
        Payment payment = payment(Long.MAX_VALUE, Long.MAX_VALUE - 1);
        assertEquals(1, payment.remainingAmount());
        assertEquals(0, payment(100, 100).remainingAmount());
        assertEquals(100, payment(100, 0).remainingAmount());
    }

    @Test
    void rejectsNegativeRefundAndRefundAboveOriginalPayment() {
        assertThrows(IllegalArgumentException.class, () -> payment(100, -1));
        assertThrows(IllegalArgumentException.class, () -> payment(100, 101));
    }

    @Test
    void attemptsRequireAnIdempotencyKey() {
        assertThrows(IllegalArgumentException.class, () -> new PaymentAttempt(
                UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), "TEST",
                "merchant-tx", " ", "CARD", new PaymentAmount("KRW", 100),
                PaymentAttemptStatus.CREATED));
    }

    @Test
    void refundCannotReportMoreThanRequestedOrNegativeAmount() {
        assertThrows(IllegalArgumentException.class, () -> refund(-1));
        assertThrows(IllegalArgumentException.class, () -> refund(101));
        assertEquals(0, refund(0).actualRefundedAmount());
        assertEquals(100, refund(100).actualRefundedAmount());
    }

    @Test
    void statusEnumsMatchTheDatabaseLifecycleValues() {
        assertArrayEquals(new PaymentAttemptStatus[]{
                PaymentAttemptStatus.CREATED, PaymentAttemptStatus.REQUESTED,
                PaymentAttemptStatus.PENDING, PaymentAttemptStatus.SUCCEEDED,
                PaymentAttemptStatus.FAILED, PaymentAttemptStatus.UNKNOWN,
                PaymentAttemptStatus.CANCELLED
        }, PaymentAttemptStatus.values());
        assertArrayEquals(new PaymentStatus[]{
                PaymentStatus.APPROVED, PaymentStatus.PARTIALLY_REFUNDED,
                PaymentStatus.REFUNDED, PaymentStatus.VOIDED, PaymentStatus.CHARGEBACK
        }, PaymentStatus.values());
        assertArrayEquals(new PaymentTransactionType[]{
                PaymentTransactionType.AUTHORIZE, PaymentTransactionType.CAPTURE,
                PaymentTransactionType.SALE, PaymentTransactionType.VOID,
                PaymentTransactionType.REFUND, PaymentTransactionType.CHARGEBACK,
                PaymentTransactionType.REVERSAL
        }, PaymentTransactionType.values());
        assertArrayEquals(new PaymentTransactionStatus[]{
                PaymentTransactionStatus.PENDING, PaymentTransactionStatus.SUCCEEDED,
                PaymentTransactionStatus.FAILED, PaymentTransactionStatus.UNKNOWN,
                PaymentTransactionStatus.CANCELLED
        }, PaymentTransactionStatus.values());
        assertArrayEquals(new RefundStatus[]{
                RefundStatus.REQUESTED, RefundStatus.PROCESSING, RefundStatus.SUCCEEDED,
                RefundStatus.FAILED, RefundStatus.UNKNOWN, RefundStatus.CANCELLED
        }, RefundStatus.values());
    }

    @Test
    void recordsRejectMissingRequiredIdentityAndProviderFields() {
        assertThrows(NullPointerException.class, () -> new PaymentAttempt(
                null, UUID.randomUUID(), UUID.randomUUID(), "TEST", "merchant",
                "key", "CARD", new PaymentAmount("KRW", 100), PaymentAttemptStatus.CREATED));
        assertThrows(IllegalArgumentException.class, () -> payment(100, 0,
                " ", "provider-key", "CARD"));
        assertThrows(IllegalArgumentException.class, () -> payment(100, 0,
                "TEST", " ", "CARD"));
        assertThrows(IllegalArgumentException.class, () -> payment(100, 0,
                "TEST", "provider-key", " "));
    }

    private Payment payment(long total, long refunded) {
        return payment(total, refunded, "TEST", "provider-key", "CARD");
    }

    private Payment payment(long total, long refunded, String provider,
                            String providerPaymentKey, String paymentMethod) {
        PaymentStatus status = refunded == 0 ? PaymentStatus.APPROVED
                : refunded == total ? PaymentStatus.REFUNDED : PaymentStatus.PARTIALLY_REFUNDED;
        return new Payment(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                provider, providerPaymentKey, paymentMethod, new PaymentAmount("KRW", total),
                refunded, status, Instant.parse("2026-09-09T00:00:00Z"), 0);
    }

    private Refund refund(long actual) {
        return new Refund(UUID.randomUUID(), UUID.randomUUID(), null, "refund-key",
                new PaymentAmount("KRW", 100), actual,
                actual == 0 ? RefundStatus.REQUESTED : RefundStatus.SUCCEEDED,
                "TEST_REASON", RefundRequesterType.SYSTEM, null);
    }
}
