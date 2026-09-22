package multi.com.marketplace.pgsimulatorcommon.api;

public record PgCancelRequest(String idempotencyKey) {
}
