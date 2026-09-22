package multi.com.marketplace.pgkakaosimulator.application;

import org.springframework.http.HttpStatus;

public enum PgKakaoSimulatorErrorCode {
    INVALID_REQUEST("KAKAO_PG_001", HttpStatus.BAD_REQUEST, "요청 값이 올바르지 않습니다."),
    IDEMPOTENCY_KEY_REQUIRED("KAKAO_PG_002", HttpStatus.BAD_REQUEST, "멱등 키는 필수입니다."),
    PAYMENT_NOT_FOUND("KAKAO_PG_003", HttpStatus.NOT_FOUND, "결제 정보를 찾을 수 없습니다."),
    MERCHANT_TRANSACTION_CONFLICT("KAKAO_PG_004", HttpStatus.CONFLICT, "동일한 가맹점 거래 번호가 다른 결제 정보에 사용되었습니다."),
    PAYMENT_STATUS_INVALID("KAKAO_PG_005", HttpStatus.CONFLICT, "현재 결제 상태에서는 요청을 처리할 수 없습니다."),
    REFUND_AMOUNT_INVALID("KAKAO_PG_006", HttpStatus.CONFLICT, "환불 금액은 남은 결제 금액을 초과할 수 없습니다."),
    REFUND_IDEMPOTENCY_CONFLICT("KAKAO_PG_007", HttpStatus.CONFLICT, "동일한 멱등 키가 다른 환불 금액에 사용되었습니다."),
    INTERNAL_ERROR("KAKAO_PG_999", HttpStatus.INTERNAL_SERVER_ERROR, "처리 중 내부 오류가 발생했습니다.");

    private final String code;
    private final HttpStatus status;
    private final String message;

    PgKakaoSimulatorErrorCode(String code, HttpStatus status, String message) {
        this.code = code;
        this.status = status;
        this.message = message;
    }

    public String code() {
        return code;
    }

    public HttpStatus status() {
        return status;
    }

    public String message() {
        return message;
    }
}
