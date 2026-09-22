package multi.com.marketplace.pgkakaosimulator.infrastructure;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(schema = "pgkakao", name = "pg_transaction")
public class PgTransactionEntity {
    @Id
    @Column(name = "transaction_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "payment_id", nullable = false, updatable = false)
    private UUID paymentId;

    @Column(name = "transaction_type", nullable = false, updatable = false)
    private String transactionType;

    @Column(nullable = false, updatable = false)
    private long amount;

    @Column(nullable = false, updatable = false)
    private String status;

    @Column(name = "idempotency_key", updatable = false)
    private String idempotencyKey;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected PgTransactionEntity() {
    }

    private PgTransactionEntity(UUID paymentId, String transactionType, long amount, String idempotencyKey) {
        this.id = UUID.randomUUID();
        this.paymentId = paymentId;
        this.transactionType = transactionType;
        this.amount = amount;
        this.status = "SUCCEEDED";
        this.idempotencyKey = idempotencyKey;
        this.createdAt = Instant.now();
    }

    public static PgTransactionEntity succeeded(UUID paymentId, String transactionType, long amount,
                                                String idempotencyKey) {
        return new PgTransactionEntity(paymentId, transactionType, amount, idempotencyKey);
    }

    public long amount() {
        return amount;
    }
}

