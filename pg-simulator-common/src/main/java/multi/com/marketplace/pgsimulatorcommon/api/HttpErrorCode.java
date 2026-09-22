package multi.com.marketplace.pgsimulatorcommon.api;

public enum HttpErrorCode {
    INVALID_REQUEST(400, "HTTP_400_001", "HTTP 요청 형식이 올바르지 않습니다."),
    VALIDATION_FAILED(400, "HTTP_400_002", "요청 값 검증에 실패했습니다."),
    ENDPOINT_NOT_FOUND(404, "HTTP_404_001", "요청한 API 경로를 찾을 수 없습니다."),
    METHOD_NOT_ALLOWED(405, "HTTP_405_001", "허용되지 않은 HTTP 메서드입니다."),
    NOT_ACCEPTABLE(406, "HTTP_406_001", "요청한 응답 형식을 제공할 수 없습니다."),
    UNSUPPORTED_MEDIA_TYPE(415, "HTTP_415_001", "지원하지 않는 요청 본문 형식입니다."),
    INTERNAL_SERVER_ERROR(500, "HTTP_500_001", "서버 내부 오류가 발생했습니다.");

    private final int status;
    private final String code;
    private final String message;

    HttpErrorCode(int status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    public int status() {
        return status;
    }

    public String code() {
        return code;
    }

    public String message() {
        return message;
    }
}
