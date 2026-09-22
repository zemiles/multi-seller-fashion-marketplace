package multi.com.marketplace.pgkakaosimulator.application;

import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import multi.com.marketplace.pgkakaosimulator.domain.PgPayment;
import multi.com.marketplace.pgkakaosimulator.domain.PgPaymentStatus;
import multi.com.marketplace.pgkakaosimulator.infrastructure.PgPaymentEntity;
import multi.com.marketplace.pgkakaosimulator.infrastructure.PgPaymentRepository;
import multi.com.marketplace.pgkakaosimulator.infrastructure.PgTransactionEntity;
import multi.com.marketplace.pgkakaosimulator.infrastructure.PgTransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PgKakaoSimulatorService {
    private final PgPaymentRepository payments;
    private final PgTransactionRepository transactions;
    private final TransactionTemplate approvalTransaction;

    public PgKakaoSimulatorService(PgPaymentRepository payments, PgTransactionRepository transactions,
                                    PlatformTransactionManager transactionManager) {
        this.payments = payments;
        this.transactions = transactions;
        this.approvalTransaction = new TransactionTemplate(transactionManager);
        this.approvalTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    public PgPayment approve(ApproveCommand command) {
        validateApproval(command);
        try {
            // Commit inside this boundary so a uniqueness race can be recovered outside
            // the failed transaction, including across different service instances.
            return approvalTransaction.execute(status -> approveInTransaction(command));
        } catch (DataIntegrityViolationException conflict) {
            return approvalTransaction.execute(status -> payments.findByMerchantTxId(command.merchantTxId())
                    .map(existing -> matchingApproval(existing, command))
                    .orElseThrow(() -> conflict));
        }
    }

    private PgPayment matchingApproval(PgPaymentEntity existing, ApproveCommand command) {
        PgPayment payment = existing.toDomain();
        if (!payment.currency().equals(command.currency()) || payment.amount() != command.amount()) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.MERCHANT_TRANSACTION_CONFLICT);
        }
        return payment;
    }

    private PgPayment approveInTransaction(ApproveCommand command) {
        PgPaymentEntity existing = payments.findByMerchantTxId(command.merchantTxId()).orElse(null);
        if (existing != null) {
            return matchingApproval(existing, command);
        }

        PgPaymentEntity payment = payments.save(PgPaymentEntity.approve(
                UUID.randomUUID(), command.merchantTxId(), command.currency(), command.amount()));
        transactions.save(PgTransactionEntity.succeeded(payment.toDomain().paymentId(), "APPROVE",
                command.amount(), command.idempotencyKey()));
        return payment.toDomain();
    }

    @Transactional
    public PgPayment cancel(UUID paymentId, CancelCommand command) {
        requireIdempotencyKey(command == null ? null : command.idempotencyKey());
        PgPaymentEntity payment = requireForUpdate(paymentId);
        if (transactions.findByPaymentIdAndTransactionTypeAndIdempotencyKey(
                paymentId, "CANCEL", command.idempotencyKey()).isPresent()) {
            return payment.toDomain();
        }
        if (payment.toDomain().status() != PgPaymentStatus.APPROVED) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.PAYMENT_STATUS_INVALID);
        }

        payment.cancel();
        transactions.save(PgTransactionEntity.succeeded(paymentId, "CANCEL", payment.toDomain().amount(),
                command.idempotencyKey()));
        return payment.toDomain();
    }

    @Transactional
    public PgPayment refund(UUID paymentId, RefundCommand command) {
        validateRefund(command);
        PgPaymentEntity payment = requireForUpdate(paymentId);
        PgTransactionEntity existing = transactions.findByPaymentIdAndTransactionTypeAndIdempotencyKey(
                paymentId, "REFUND", command.idempotencyKey()).orElse(null);
        if (existing != null) {
            if (existing.amount() != command.amount()) {
                throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.REFUND_IDEMPOTENCY_CONFLICT);
            }
            return payment.toDomain();
        }

        PgPayment refunded;
        try {
            refunded = payment.toDomain().refund(command.amount());
        } catch (IllegalStateException exception) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.PAYMENT_STATUS_INVALID);
        } catch (IllegalArgumentException exception) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.REFUND_AMOUNT_INVALID);
        }
        payment.apply(refunded);
        transactions.save(PgTransactionEntity.succeeded(paymentId, "REFUND", command.amount(),
                command.idempotencyKey()));
        return payment.toDomain();
    }

    @Transactional(readOnly = true)
    public PgPayment findPayment(UUID paymentId) {
        return payments.findById(paymentId)
                .map(PgPaymentEntity::toDomain)
                .orElseThrow(() -> PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.PAYMENT_NOT_FOUND));
    }

    private PgPaymentEntity requireForUpdate(UUID paymentId) {
        return payments.findByIdForUpdate(paymentId)
                .orElseThrow(() -> PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.PAYMENT_NOT_FOUND));
    }

    private static void validateApproval(ApproveCommand command) {
        if (command == null || command.amount() <= 0 || command.currency() == null
                || !command.currency().matches("[A-Z]{3}") || blank(command.merchantTxId())) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.INVALID_REQUEST);
        }
        requireIdempotencyKey(command.idempotencyKey());
    }

    private static void validateRefund(RefundCommand command) {
        if (command == null || command.amount() <= 0) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.INVALID_REQUEST);
        }
        requireIdempotencyKey(command.idempotencyKey());
    }

    private static void requireIdempotencyKey(String value) {
        if (blank(value)) {
            throw PgKakaoSimulatorException.of(PgKakaoSimulatorErrorCode.IDEMPOTENCY_KEY_REQUIRED);
        }
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }

    public record ApproveCommand(String merchantTxId, String currency, long amount, String idempotencyKey) {
    }

    public record CancelCommand(String idempotencyKey) {
    }

    public record RefundCommand(long amount, String idempotencyKey) {
    }
}

