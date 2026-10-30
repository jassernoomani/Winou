package tn.winou.security;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import tn.winou.common.ApiException;

/**
 * Slows down password guessing and sign-up floods: at most a few attempts per key (an email, a
 * network address) in a sliding window. Kept in memory: a restart forgets them, which is fine for
 * one server.
 */
@Component
public class AttemptLimiter {

    private final Map<String, Deque<Instant>> attempts = new ConcurrentHashMap<>();

    /** 429 "too_many_attempts" if [key] already used its [max] attempts within [window]. */
    public void check(String key, int max, Duration window) {
        Deque<Instant> recent = attempts.get(key);
        if (recent == null) {
            return;
        }
        synchronized (recent) {
            prune(recent, window);
            if (recent.size() >= max) {
                long wait = Math.max(1, Duration.between(Instant.now(), recent.peekFirst().plus(window)).toSeconds());
                throw ApiException.coded(HttpStatus.TOO_MANY_REQUESTS, "too_many_attempts",
                        "Too many attempts. Try again in " + Math.ceilDiv(wait, 60) + " min.");
            }
        }
    }

    public void record(String key, Duration window) {
        Deque<Instant> recent = attempts.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (recent) {
            prune(recent, window);
            recent.addLast(Instant.now());
        }
    }

    /** After a success: the earlier failures no longer count. */
    public void clear(String key) {
        attempts.remove(key);
    }

    private static void prune(Deque<Instant> recent, Duration window) {
        Instant since = Instant.now().minus(window);
        while (!recent.isEmpty() && recent.peekFirst().isBefore(since)) {
            recent.removeFirst();
        }
    }
}
