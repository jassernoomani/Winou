package tn.winou.common;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import jakarta.validation.ConstraintViolationException;

/**
 * Every error is answered as {"detail": ...}. Invalid input is 422 with a list of {loc, msg},
 * like FastAPI, so the app and API clients keep working unchanged.
 */
@RestControllerAdvice
public class ErrorHandler {

    private static final Logger log = LoggerFactory.getLogger(ErrorHandler.class);
    private static final HttpStatus INVALID = HttpStatus.UNPROCESSABLE_CONTENT;

    @ExceptionHandler(ApiException.class)
    ResponseEntity<Map<String, Object>> api(ApiException e) {
        var response = ResponseEntity.status(e.getStatus());
        if (e.getStatus() == HttpStatus.UNAUTHORIZED) {
            response.header(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        }
        return response.body(Map.of("detail", e.getDetail()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, Object>> body(MethodArgumentNotValidException e) {
        List<Map<String, Object>> errors = new ArrayList<>();
        for (FieldError error : e.getBindingResult().getFieldErrors()) {
            errors.add(error("body", error.getField(), error.getDefaultMessage()));
        }
        e.getBindingResult().getGlobalErrors().forEach(g -> errors.add(error("body", null, g.getDefaultMessage())));
        return ResponseEntity.status(INVALID).body(Map.of("detail", errors));
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    ResponseEntity<Map<String, Object>> parameters(HandlerMethodValidationException e) {
        List<Map<String, Object>> errors = new ArrayList<>();
        e.getParameterValidationResults().forEach(result -> result.getResolvableErrors().forEach(error ->
                errors.add(error("query", result.getMethodParameter().getParameterName(),
                        error.getDefaultMessage()))));
        return ResponseEntity.status(INVALID).body(Map.of("detail", errors));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<Map<String, Object>> constraints(ConstraintViolationException e) {
        List<Map<String, Object>> errors = new ArrayList<>();
        e.getConstraintViolations().forEach(v -> errors.add(error("query", null, v.getPropertyPath() + ": " + v.getMessage())));
        return ResponseEntity.status(INVALID).body(Map.of("detail", errors));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<Map<String, Object>> typeMismatch(MethodArgumentTypeMismatchException e) {
        return invalid(error("query", e.getName(), "invalid value: " + e.getValue()));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    ResponseEntity<Map<String, Object>> missingParameter(MissingServletRequestParameterException e) {
        return invalid(error("query", e.getParameterName(), "field required"));
    }

    @ExceptionHandler(MissingServletRequestPartException.class)
    ResponseEntity<Map<String, Object>> missingPart(MissingServletRequestPartException e) {
        return invalid(error("body", e.getRequestPartName(), "field required"));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<Map<String, Object>> unreadable(HttpMessageNotReadableException e) {
        // Malformed JSON, an unknown enum value, a date without a timezone...
        String cause = e.getMostSpecificCause().getMessage();
        return invalid(error("body", null, "invalid request body: " + firstLine(cause)));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<Map<String, Object>> tooLarge(MaxUploadSizeExceededException e) {
        return api(ApiException.coded(HttpStatus.CONTENT_TOO_LARGE, "file_too_large", "Image is too large."));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<Map<String, Object>> noRoute(NoResourceFoundException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("detail", "Not Found"));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<Map<String, Object>> wrongMethod(HttpRequestMethodNotSupportedException e) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(Map.of("detail", "Method Not Allowed"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<Map<String, Object>> unexpected(Exception e) {
        log.error("unhandled error", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("detail", "Internal Server Error"));
    }

    private static ResponseEntity<Map<String, Object>> invalid(Map<String, Object> error) {
        return ResponseEntity.status(INVALID).body(Map.of("detail", List.of(error)));
    }

    private static Map<String, Object> error(String where, String field, String message) {
        List<String> loc = field == null ? List.of(where) : List.of(where, toSnakeCase(field));
        return Map.of("loc", loc, "msg", message == null ? "invalid value" : message);
    }

    private static String toSnakeCase(String field) {
        return field.replaceAll("([a-z0-9])([A-Z])", "$1_$2").toLowerCase();
    }

    private static String firstLine(String text) {
        return text == null ? "" : text.lines().findFirst().orElse("");
    }
}
