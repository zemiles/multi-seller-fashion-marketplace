package multi.com.marketplace.pgsimulatorcommon.api;

import java.util.UUID;

public record PgPaymentResponse(UUID paymentId, String merchantTxId, String currency, long amount,
                                String status, long refundedAmount) {
}
