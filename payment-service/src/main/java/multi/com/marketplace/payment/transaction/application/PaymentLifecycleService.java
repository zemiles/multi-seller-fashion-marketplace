package multi.com.marketplace.payment.transaction.application;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import multi.com.marketplace.payment.refund.application.RefundUseCase;
import multi.com.marketplace.payment.refund.domain.Refund;
import multi.com.marketplace.payment.refund.domain.RefundRequesterType;
import multi.com.marketplace.payment.refund.domain.RefundStatus;
import multi.com.marketplace.payment.transaction.domain.Payment;
import multi.com.marketplace.payment.transaction.domain.PaymentAmount;
import multi.com.marketplace.payment.transaction.domain.PaymentAttempt;
import multi.com.marketplace.payment.transaction.domain.PaymentAttemptStatus;
import multi.com.marketplace.payment.transaction.domain.PaymentStatus;

/**
 * In-process payment application service. Persistence and transaction boundaries
 * are intentionally represented by ports until JPA adapters are introduced.
 */
public final class PaymentLifecycleService implements PaymentUseCase, RefundUseCase {
    private final PaymentProviderPort provider;
    private final Map<UUID, PaymentAttempt> attempts = new ConcurrentHashMap<>();
    private final Map<UUID, Payment> payments = new ConcurrentHashMap<>();
    private final Map<UUID, Refund> refunds = new ConcurrentHashMap<>();
    private final Map<String, UUID> attemptIdempotency = new ConcurrentHashMap<>();
    private final Map<String, UUID> refundIdempotency = new ConcurrentHashMap<>();

    public PaymentLifecycleService(PaymentProviderPort provider) {
        this.provider = provider;
    }

    @Override
    public synchronized PaymentAttempt prepare(PreparePayment command) {
        require(command != null, "command");
        requireText(command.provider(), "provider");
        requireText(command.idempotencyKey(), "idempotencyKey");
        String key = command.provider() + ":" + command.idempotencyKey();
        UUID existingId = attemptIdempotency.get(key);
        if (existingId != null) {
            PaymentAttempt existing = attempts.get(existingId);
            if (!sameRequest(existing, command)) {
                throw new IllegalArgumentException("Idempotency key was reused with different payment data");
            }
            return existing;
        }
        PaymentAttempt attempt = new PaymentAttempt(UUID.randomUUID(), command.checkoutId(), command.orderId(),
                command.provider(), command.merchantTxId(), command.idempotencyKey(), command.paymentMethod(),
                command.requestedAmount(), PaymentAttemptStatus.CREATED);
        attempts.put(attempt.id(), attempt);
        attemptIdempotency.put(key, attempt.id());
        return attempt;
    }

    public synchronized Payment approve(UUID attemptId) {
        PaymentAttempt attempt = requireAttempt(attemptId);
        if (attempt.status() == PaymentAttemptStatus.SUCCEEDED) {
            return payments.values().stream().filter(p -> p.paymentAttemptId().equals(attemptId)).findFirst().orElseThrow();
        }
        if (attempt.status() != PaymentAttemptStatus.CREATED && attempt.status() != PaymentAttemptStatus.PENDING) {
            throw new IllegalStateException("Attempt cannot be approved from " + attempt.status());
        }
        PaymentProviderPort.Approval approval = provider.approve(new PaymentProviderPort.ApprovalRequest(
                attempt.id(), attempt.merchantTxId(), attempt.requestedAmount()));
        require(approval != null, "provider approval");
        if (!approval.amount().equals(attempt.requestedAmount())) {
            throw new IllegalStateException("Provider amount does not match requested amount");
        }
        Payment payment = new Payment(UUID.randomUUID(), attempt.id(), attempt.orderId(), attempt.provider(),
                approval.providerPaymentKey(), attempt.paymentMethod(), attempt.requestedAmount(), 0,
                PaymentStatus.APPROVED, Instant.now(), 0);
        payments.put(payment.id(), payment);
        attempts.put(attempt.id(), new PaymentAttempt(attempt.id(), attempt.checkoutId(), attempt.orderId(),
                attempt.provider(), attempt.merchantTxId(), attempt.idempotencyKey(), attempt.paymentMethod(),
                attempt.requestedAmount(), PaymentAttemptStatus.SUCCEEDED));
        return payment;
    }

    @Override
    public Optional<PaymentAttempt> findAttempt(UUID paymentAttemptId) { return Optional.ofNullable(attempts.get(paymentAttemptId)); }
    @Override
    public Optional<Payment> findPayment(UUID paymentId) { return Optional.ofNullable(payments.get(paymentId)); }
    @Override
    public Optional<Refund> findRefund(UUID refundId) { return Optional.ofNullable(refunds.get(refundId)); }

    @Override
    public synchronized Refund request(RequestRefund command) {
        require(command != null, "command");
        requireText(command.idempotencyKey(), "idempotencyKey");
        String key = command.paymentId() + ":" + command.idempotencyKey();
        UUID existingId = refundIdempotency.get(key);
        if (existingId != null) return refunds.get(existingId);
        Payment payment = payments.get(command.paymentId());
        require(payment != null, "payment");
        if (!payment.totalAmount().currency().equals(command.requestedAmount().currency())) {
            throw new IllegalArgumentException("Refund currency does not match payment currency");
        }
        if (command.requestedAmount().amount() > payment.remainingAmount()) {
            throw new IllegalArgumentException("Refund amount exceeds remaining payment amount");
        }
        PaymentProviderPort.RefundResult result = provider.refund(new PaymentProviderPort.RefundRequest(
                payment.id(), command.requestedAmount()));
        require(result != null, "provider refund result");
        if (result.refundedAmount() != command.requestedAmount().amount()) {
            throw new IllegalStateException("Provider refund amount does not match requested amount");
        }
        long refunded = payment.refundedAmount() + result.refundedAmount();
        PaymentStatus status = refunded == payment.totalAmount().amount()
                ? PaymentStatus.REFUNDED : PaymentStatus.PARTIALLY_REFUNDED;
        payments.put(payment.id(), new Payment(payment.id(), payment.paymentAttemptId(), payment.orderId(),
                payment.provider(), payment.providerPaymentKey(), payment.paymentMethod(), payment.totalAmount(),
                refunded, status, payment.approvedAt(), payment.version() + 1));
        Refund refund = new Refund(UUID.randomUUID(), payment.id(), command.claimId(), command.idempotencyKey(),
                command.requestedAmount(), result.refundedAmount(), RefundStatus.SUCCEEDED,
                command.reasonCode(), command.requestedByType(), command.requestedById());
        refunds.put(refund.id(), refund);
        refundIdempotency.put(key, refund.id());
        return refund;
    }

    private PaymentAttempt requireAttempt(UUID id) { PaymentAttempt value = attempts.get(id); require(value != null, "payment attempt"); return value; }
    private static boolean sameRequest(PaymentAttempt existing, PreparePayment command) {
        return existing.checkoutId().equals(command.checkoutId()) && existing.orderId().equals(command.orderId())
                && existing.merchantTxId().equals(command.merchantTxId()) && existing.paymentMethod().equals(command.paymentMethod())
                && existing.requestedAmount().equals(command.requestedAmount());
    }
    private static void require(Object value, String name) { if (value == null) throw new IllegalArgumentException(name + " must not be null"); }
    private static void requireText(String value, String name) { if (value == null || value.isBlank()) throw new IllegalArgumentException(name + " must not be blank"); }
}
