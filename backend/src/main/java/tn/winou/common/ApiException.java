package tn.winou.common;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;

import lombok.Getter;

/**
 * An error answered as {"detail": ...}: either a plain message, or {"code", "message"} when the
 * app needs to react to it (e.g. "rate_limited"). Same shape as the Python API, which the app parses.
 */
@Getter
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final Object detail;

    private ApiException(HttpStatus status, String message, Object detail) {
        super(message);
        this.status = status;
        this.detail = detail;
    }

    public static ApiException of(HttpStatus status, String message) {
        return new ApiException(status, message, message);
    }

    public static ApiException coded(HttpStatus status, String code, String message) {
        return new ApiException(status, message, Map.of("code", code, "message", message));
    }

    public static ApiException notFound(String what) {
        return of(HttpStatus.NOT_FOUND, what + " not found");
    }

    public static ApiException forbidden() {
        return of(HttpStatus.FORBIDDEN, "Not allowed");
    }

    public static ApiException unauthorized(String message) {
        return of(HttpStatus.UNAUTHORIZED, message);
    }

    /** The app shows until when, and why. */
    public static ApiException banned(OffsetDateTime until, String reason) {
        String message = "This account is suspended.";
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("code", "banned");
        detail.put("message", message);
        detail.put("until", until);
        detail.put("reason", reason);
        return new ApiException(HttpStatus.FORBIDDEN, message, detail);
    }

    public static ApiException invalid(String message) {
        return of(HttpStatus.UNPROCESSABLE_CONTENT, message);
    }
}
