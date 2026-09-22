package multi.com.marketplace.pgsimulatorcommon.api;

public record PgRefundRequest(long amount, String idempotencyKey) {
}
