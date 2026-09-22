package multi.com.marketplace.pgkakaosimulator.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PgTransactionRepository extends JpaRepository<PgTransactionEntity, UUID> {
    Optional<PgTransactionEntity> findByPaymentIdAndTransactionTypeAndIdempotencyKey(
            UUID paymentId, String transactionType, String idempotencyKey);
}

