package multi.com.marketplace.pgkakaosimulator.application;

public final class PgKakaoSimulatorException extends RuntimeException {
    private final PgKakaoSimulatorErrorCode errorCode;

    private PgKakaoSimulatorException(PgKakaoSimulatorErrorCode errorCode) {
        super(errorCode.message());
        this.errorCode = errorCode;
    }

    public PgKakaoSimulatorErrorCode errorCode() {
        return errorCode;
    }

    public static PgKakaoSimulatorException of(PgKakaoSimulatorErrorCode errorCode) {
        return new PgKakaoSimulatorException(errorCode);
    }
}

