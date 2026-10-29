package tn.winou.common;

import org.springframework.http.HttpStatus;

public final class RateLimits {

    private RateLimits() {}

    /**
     * Rejects with 429 if the user already created `limit` rows in the window. The count comes from
     * Postgres, so the limit holds across API replicas.
     */
    public static void check(long countInWindow, int limit, String what) {
        if (countInWindow >= limit) {
            throw ApiException.coded(HttpStatus.TOO_MANY_REQUESTS, "rate_limited",
                    "Too many " + what + ". Try again later.");
        }
    }
}
