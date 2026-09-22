package multi.com.marketplace.pgnaversimulator.infrastructure;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import multi.com.marketplace.pgnaversimulator.domain.PgPayment;
import multi.com.marketplace.pgnaversimulator.domain.PgPaymentStatus;

@Entity
@Table(schema = "pgnaver", name = "pg_payment")
public class PgPaymentEntity {
    @Id
    @Column(name = "payment_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "merchant_tx_id", nullable = false, unique = true, updatable = false)
    private String merchantTxId;

    @Column(nullable = false, length = 3, updatable = false)
    private String currency;

    @Column(nullable = false, updatable = false)
    private long amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PgPaymentStatus status;

    @Column(name = "refunded_amount", nullable = false)
    private long refundedAmount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PgPaymentEntity() {
    }

    private PgPaymentEntity(UUID id, String merchantTxId, String currency, long amount) {
        this.id = id;
        this.merchantTxId = merchantTxId;
        this.currency = currency;
        this.amount = amount;
        this.status = PgPaymentStatus.APPROVED;
        this.refundedAmount = 0;
        this.createdAt = Instant.now();
        this.updatedAt = createdAt;
    }

    public static PgPaymentEntity approve(UUID id, String merchantTxId, String currency, long amount) {
        return new PgPaymentEntity(id, merchantTxId, currency, amount);
    }

    public PgPayment toDomain() {
        return new PgPayment(id, merchantTxId, currency, amount, status, refundedAmount, createdAt, updatedAt);
    }

    public void apply(PgPayment payment) {
        this.status = payment.status();
        this.refundedAmount = payment.refundedAmount();
        this.updatedAt = Instant.now();
    }

    public void cancel() {
        this.status = PgPaymentStatus.CANCELLED;
        this.updatedAt = Instant.now();
    }
}

