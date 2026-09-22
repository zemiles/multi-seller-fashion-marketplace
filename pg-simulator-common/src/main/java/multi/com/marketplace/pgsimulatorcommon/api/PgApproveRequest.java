package multi.com.marketplace.pgsimulatorcommon.api;

public record PgApproveRequest(String merchantTxId, String currency, long amount, String idempotencyKey) {
}
