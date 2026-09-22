package multi.com.marketplace.pgkakaosimulator.api;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import multi.com.marketplace.pgkakaosimulator.application.PgKakaoSimulatorErrorCode;
import multi.com.marketplace.pgkakaosimulator.application.PgKakaoSimulatorException;
import multi.com.marketplace.pgsimulatorcommon.api.HttpErrorCode;
import multi.com.marketplace.pgsimulatorcommon.api.PgErrorResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindException;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.MissingPathVariableException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class PgKakaoSimulatorExceptionHandler {
    @ExceptionHandler(PgKakaoSimulatorException.class)
    ResponseEntity<PgErrorResponse> handleBusiness(
            PgKakaoSimulatorException exception, HttpServletRequest request) {
        return error(exception.errorCode(), request);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class, MissingPathVariableException.class})
    ResponseEntity<PgErrorResponse> handleInvalidRequest(
            Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.INVALID_REQUEST, request);
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, BindException.class})
    ResponseEntity<PgErrorResponse> handleValidationFailure(Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.VALIDATION_FAILED, request);
    }

    @ExceptionHandler({NoHandlerFoundException.class, NoResourceFoundException.class})
    ResponseEntity<PgErrorResponse> handleEndpointNotFound(Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.ENDPOINT_NOT_FOUND, request);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<PgErrorResponse> handleMethodNotAllowed(Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.METHOD_NOT_ALLOWED, request);
    }

    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    ResponseEntity<PgErrorResponse> handleNotAcceptable(Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.NOT_ACCEPTABLE, request);
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    ResponseEntity<PgErrorResponse> handleUnsupportedMediaType(Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.UNSUPPORTED_MEDIA_TYPE, request);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<PgErrorResponse> handleUnexpected(
            Exception exception, HttpServletRequest request) {
        return error(HttpErrorCode.INTERNAL_SERVER_ERROR, request);
    }

    private static ResponseEntity<PgErrorResponse> error(
            PgKakaoSimulatorErrorCode errorCode, HttpServletRequest request) {
        return ResponseEntity.status(errorCode.status()).body(new PgErrorResponse(
                errorCode.code(), errorCode.message(), Instant.now(), request.getRequestURI()));
    }

    private static ResponseEntity<PgErrorResponse> error(HttpErrorCode errorCode, HttpServletRequest request) {
        return ResponseEntity.status(errorCode.status()).body(new PgErrorResponse(
                errorCode.code(), errorCode.message(), Instant.now(), request.getRequestURI()));
    }
}
