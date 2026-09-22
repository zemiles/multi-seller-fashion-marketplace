package multi.com.marketplace.pgnaversimulator.application;

public final class PgNaverSimulatorException extends RuntimeException {
    private final PgNaverSimulatorErrorCode errorCode;

    private PgNaverSimulatorException(PgNaverSimulatorErrorCode errorCode) {
        super(errorCode.message());
        this.errorCode = errorCode;
    }

    public PgNaverSimulatorErrorCode errorCode() {
        return errorCode;
    }

    public static PgNaverSimulatorException of(PgNaverSimulatorErrorCode errorCode) {
        return new PgNaverSimulatorException(errorCode);
    }
}

