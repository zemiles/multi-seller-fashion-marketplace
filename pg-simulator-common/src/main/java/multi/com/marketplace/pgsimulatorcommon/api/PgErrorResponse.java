package multi.com.marketplace.pgsimulatorcommon.api;

import java.time.Instant;

public record PgErrorResponse(String code, String message, Instant timestamp, String path) {
}
