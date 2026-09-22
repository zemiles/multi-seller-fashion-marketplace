package multi.com.marketplace.payment.transaction.application;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import multi.com.marketplace.payment.refund.application.RefundUseCase;
import multi.com.marketplace.payment.refund.domain.*;
import multi.com.marketplace.payment.transaction.domain.*;

/**
 * In-process reference implementation, not a Spring Bean.
 * State is lost on restart. Production requires durable transactions and reconciliation.
 */
public final class PaymentLifecycleService implements PaymentUseCase, RefundUseCase {
    private final PaymentProviderPort provider;
    private final Map<UUID, PaymentAttempt> attempts = new ConcurrentHashMap<>();
    private final Map<UUID, Payment> payments = new ConcurrentHashMap<>();
    private final Map<UUID, Refund> refunds = new ConcurrentHashMap<>();
    private final Map<ProviderKey, UUID> attemptIdempotency = new ConcurrentHashMap<>();
    private final Map<ProviderKey, UUID> merchantTransactions = new ConcurrentHashMap<>();
    private final Map<RefundKey, UUID> refundIdempotency = new ConcurrentHashMap<>();

    public PaymentLifecycleService(PaymentProviderPort provider) {
        this.provider = Objects.requireNonNull(provider, "provider");
    }

    @Override
    public synchronized PaymentAttempt prepare(PreparePayment command) {
        require(command, "command");
        PaymentAttempt candidate = new PaymentAttempt(UUID.randomUUID(), command.checkoutId(), command.orderId(),
                command.provider(), command.merchantTxId(), command.idempotencyKey(), command.paymentMethod(),
                command.requestedAmount(), PaymentAttemptStatus.CREATED);
        ProviderKey key = new ProviderKey(command.provider(), command.idempotencyKey());
        UUID existingId = attemptIdempotency.get(key);
        if (existingId != null) {
            PaymentAttempt existing = attempts.get(existingId);
            if (!sameRequest(existing, command)) {
                throw new IllegalArgumentException("Idempotency key was reused with different payment data");
            }
            return existing;
        }
        ProviderKey merchantKey = new ProviderKey(command.provider(), command.merchantTxId());
        if (merchantTransactions.containsKey(merchantKey)) {
            throw new IllegalArgumentException("Merchant transaction was already used");
        }
        boolean blocked = attempts.values().stream().anyMatch(a -> a.orderId().equals(command.orderId())
                && a.status() != PaymentAttemptStatus.FAILED && a.status() != PaymentAttemptStatus.CANCELLED);
        if (blocked) throw new IllegalStateException("Order has an unresolved or successful payment attempt");
        attempts.put(candidate.id(), candidate);
        attemptIdempotency.put(key, candidate.id());
        merchantTransactions.put(merchantKey, candidate.id());
        return candidate;
    }

    public synchronized Payment approve(UUID attemptId) {
        PaymentAttempt attempt = requireAttempt(attemptId);
        if (attempt.status() == PaymentAttemptStatus.SUCCEEDED) {
            return payments.values().stream().filter(p -> p.paymentAttemptId().equals(attemptId)).findFirst().orElseThrow();
        }
        if (attempt.status() != PaymentAttemptStatus.CREATED) {
            throw new IllegalStateException("Attempt cannot be approved from " + attempt.status());
        }
        attempts.put(attempt.id(), withStatus(attempt, PaymentAttemptStatus.REQUESTED));
        try {
            PaymentProviderPort.Approval approval = provider.approve(new PaymentProviderPort.ApprovalRequest(
                    attempt.id(), attempt.provider(), attempt.merchantTxId(), attempt.idempotencyKey(),
                    attempt.requestedAmount()));
            require(approval, "provider approval");
            if (!attempt.requestedAmount().equals(approval.amount())) {
                throw new IllegalStateException("Provider amount does not match requested amount");
            }
            Payment payment = new Payment(UUID.randomUUID(), attempt.id(), attempt.orderId(), attempt.provider(),
                    approval.providerPaymentKey(), attempt.paymentMethod(), attempt.requestedAmount(), 0,
                    PaymentStatus.APPROVED, Instant.now(), 0);
            payments.put(payment.id(), payment);
            attempts.put(attempt.id(), withStatus(attempt, PaymentAttemptStatus.SUCCEEDED));
            return payment;
        } catch (RuntimeException exception) {
            attempts.put(attempt.id(), withStatus(attempt, PaymentAttemptStatus.UNKNOWN));
            throw exception;
        }
    }

    @Override
    public Optional<PaymentAttempt> findAttempt(UUID id) {
        require(id, "paymentAttemptId");
        return Optional.ofNullable(attempts.get(id));
    }

    @Override
    public Optional<Payment> findPayment(UUID id) {
        require(id, "paymentId");
        return Optional.ofNullable(payments.get(id));
    }

    @Override
    public Optional<Refund> findRefund(UUID id) {
        require(id, "refundId");
        return Optional.ofNullable(refunds.get(id));
    }

    @Override
    public synchronized Refund request(RequestRefund command) {
        require(command, "command");
        Refund pending = new Refund(UUID.randomUUID(), command.paymentId(), command.claimId(), command.idempotencyKey(),
                command.requestedAmount(), 0, RefundStatus.REQUESTED, command.reasonCode(),
                command.requestedByType(), command.requestedById());
        if (command.requestedByType() != RefundRequesterType.SYSTEM) require(command.requestedById(), "requestedById");
        RefundKey key = new RefundKey(command.paymentId(), command.idempotencyKey());
        UUID existingId = refundIdempotency.get(key);
        if (existingId != null) {
            Refund existing = refunds.get(existingId);
            if (!sameRequest(existing, command)) {
                throw new IllegalArgumentException("Idempotency key was reused with different refund data");
            }
            return existing;
        }
        Payment payment = payments.get(command.paymentId());
        require(payment, "payment");
        if (payment.status() != PaymentStatus.APPROVED && payment.status() != PaymentStatus.PARTIALLY_REFUNDED) {
            throw new IllegalStateException("Payment cannot be refunded from " + payment.status());
        }
        if (!payment.totalAmount().currency().equals(command.requestedAmount().currency())) {
            throw new IllegalArgumentException("Refund currency does not match payment currency");
        }
        long reserved = refunds.values().stream()
                .filter(r -> r.paymentId().equals(payment.id()) && (r.status() == RefundStatus.REQUESTED
                        || r.status() == RefundStatus.PROCESSING || r.status() == RefundStatus.UNKNOWN))
                .mapToLong(r -> r.requestedAmount().amount()).sum();
        if (command.requestedAmount().amount() > payment.remainingAmount() - reserved) {
            throw new IllegalArgumentException("Refund amount exceeds unreserved payment amount");
        }
        refunds.put(pending.id(), pending);
        refundIdempotency.put(key, pending.id());
        try {
            PaymentProviderPort.RefundResult result = provider.refund(new PaymentProviderPort.RefundRequest(
                    payment.id(), payment.provider(), payment.providerPaymentKey(), pending.idempotencyKey(),
                    pending.requestedAmount()));
            require(result, "provider refund result");
            if (result.refundedAmount() != command.requestedAmount().amount()) {
                throw new IllegalStateException("Provider refund amount does not match requested amount");
            }
            long refunded = payment.refundedAmount() + result.refundedAmount();
            PaymentStatus status = refunded == payment.totalAmount().amount()
                    ? PaymentStatus.REFUNDED : PaymentStatus.PARTIALLY_REFUNDED;
            payments.put(payment.id(), new Payment(payment.id(), payment.paymentAttemptId(), payment.orderId(),
                    payment.provider(), payment.providerPaymentKey(), payment.paymentMethod(), payment.totalAmount(),
                    refunded, status, payment.approvedAt(), payment.version() + 1));
            Refund succeeded = withStatus(pending, RefundStatus.SUCCEEDED, result.refundedAmount());
            refunds.put(pending.id(), succeeded);
            return succeeded;
        } catch (RuntimeException exception) {
            // Hold the amount and key until reconciliation; do not call the PG again.
            refunds.put(pending.id(), withStatus(pending, RefundStatus.UNKNOWN, 0));
            throw exception;
        }
    }

    private PaymentAttempt requireAttempt(UUID id) {
        require(id, "paymentAttemptId");
        PaymentAttempt value = attempts.get(id);
        require(value, "payment attempt");
        return value;
    }

    private static PaymentAttempt withStatus(PaymentAttempt a, PaymentAttemptStatus status) {
        return new PaymentAttempt(a.id(), a.checkoutId(), a.orderId(), a.provider(), a.merchantTxId(),
                a.idempotencyKey(), a.paymentMethod(), a.requestedAmount(), status);
    }

    private static Refund withStatus(Refund r, RefundStatus status, long actual) {
        return new Refund(r.id(), r.paymentId(), r.claimId(), r.idempotencyKey(), r.requestedAmount(),
                actual, status, r.reasonCode(), r.requestedByType(), r.requestedById());
    }

    private static boolean sameRequest(PaymentAttempt existing, PreparePayment command) {
        return existing.provider().equals(command.provider()) && existing.checkoutId().equals(command.checkoutId())
                && existing.orderId().equals(command.orderId()) && existing.merchantTxId().equals(command.merchantTxId())
                && existing.paymentMethod().equals(command.paymentMethod())
                && existing.requestedAmount().equals(command.requestedAmount());
    }

    private static boolean sameRequest(Refund existing, RequestRefund command) {
        return Objects.equals(existing.claimId(), command.claimId())
                && existing.requestedAmount().equals(command.requestedAmount())
                && existing.reasonCode().equals(command.reasonCode())
                && existing.requestedByType() == command.requestedByType()
                && Objects.equals(existing.requestedById(), command.requestedById());
    }

    private static void require(Object value, String name) {
        if (value == null) throw new IllegalArgumentException(name + " must not be null");
    }

    private record ProviderKey(String provider, String value) {}
    private record RefundKey(UUID paymentId, String value) {}
}
