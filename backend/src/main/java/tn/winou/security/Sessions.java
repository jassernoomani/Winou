package tn.winou.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.web.ApiModels.TokenOut;

/**
 * Signed-in phones. Signing in gives a short access token and a refresh token; the app trades the
 * refresh token for a new pair when the access token expires, so people stay signed in while they
 * use the app. Each refresh token works once.
 */
@Component
public class Sessions {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final JdbcClient jdbc;
    private final UserRepository users;
    private final Tokens tokens;
    private final Duration lifetime;

    public Sessions(JdbcClient jdbc, UserRepository users, Tokens tokens, WinouProperties properties) {
        this.jdbc = jdbc;
        this.users = users;
        this.tokens = tokens;
        this.lifetime = Duration.ofDays(properties.auth().refreshTokenDays());
    }

    /** A new session for a user who just proved who they are. */
    @Transactional
    public TokenOut start(User user) {
        String refresh = newToken();
        jdbc.sql("""
                        INSERT INTO sessions (id, user_id, token_hash, created_at, last_used_at, expires_at)
                        VALUES (:id, :user, :hash, now(), now(), :expires)""")
                .param("id", UUID.randomUUID())
                .param("user", user.getId())
                .param("hash", hash(refresh))
                .param("expires", OffsetDateTime.now().plus(lifetime))
                .update();
        return TokenOut.of(tokens.issue(user), refresh);
    }

    /** Trades a refresh token for a new pair. The old refresh token stops working. */
    @Transactional
    public TokenOut refresh(String refreshToken) {
        record Session(UUID id, UUID userId) {}
        Session session = jdbc.sql("""
                        SELECT id, user_id FROM sessions
                        WHERE token_hash = :hash AND revoked_at IS NULL AND expires_at > now()
                        FOR UPDATE""")
                .param("hash", hash(refreshToken))
                .query((rs, i) -> new Session(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class)))
                .optional()
                .orElseThrow(Sessions::expired);
        User user = users.findById(session.userId()).orElseThrow(Sessions::expired);
        CurrentUserResolver.requireNotBanned(user);
        String refresh = newToken();
        jdbc.sql("""
                        UPDATE sessions SET token_hash = :hash, last_used_at = now(), expires_at = :expires
                        WHERE id = :id""")
                .param("hash", hash(refresh))
                .param("expires", OffsetDateTime.now().plus(lifetime))
                .param("id", session.id())
                .update();
        return TokenOut.of(tokens.issue(user), refresh);
    }

    /** Signs this phone out. Unknown or already revoked tokens are ignored. */
    public void end(String refreshToken) {
        jdbc.sql("UPDATE sessions SET revoked_at = now() WHERE token_hash = :hash AND revoked_at IS NULL")
                .param("hash", hash(refreshToken))
                .update();
    }

    /** Signs every phone out: sessions end, and access tokens already issued are refused. */
    @Transactional
    public void endAll(User user) {
        jdbc.sql("UPDATE sessions SET revoked_at = now() WHERE user_id = :user AND revoked_at IS NULL")
                .param("user", user.getId())
                .update();
        user.setTokenVersion(user.getTokenVersion() + 1);
        users.saveAndFlush(user);
    }

    private static String newToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** Only hashes are stored: a database leak doesn't sign anyone in. */
    private static String hash(String token) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException expired() {
        return ApiException.coded(HttpStatus.UNAUTHORIZED, "session_expired", "Please sign in again.");
    }
}
