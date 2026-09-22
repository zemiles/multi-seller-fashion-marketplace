package multi.com.marketplace.pgnaversimulator.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;

public interface PgPaymentRepository extends JpaRepository<PgPaymentEntity, UUID> {
    Optional<PgPaymentEntity> findByMerchantTxId(String merchantTxId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select payment from PgPaymentEntity payment where payment.id = :paymentId")
    Optional<PgPaymentEntity> findByIdForUpdate(UUID paymentId);
}

