package tn.winou.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.AfterCommit;
import tn.winou.common.ApiException;
import tn.winou.domain.User;
import tn.winou.infra.Mailer;

/**
 * 6-digit codes sent by email: to reset a forgotten password, or to prove an email is yours. A
 * code works once, for 15 minutes, with 5 tries; at most 3 are sent per hour and purpose.
 */
@Component
public class EmailCodes {

    public enum Purpose { RESET, VERIFY }

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Duration VALID = Duration.ofMinutes(15);
    private static final int TRIES = 5;
    private static final int PER_HOUR = 3;

    private final JdbcClient jdbc;
    private final Mailer mailer;

    public EmailCodes(JdbcClient jdbc, Mailer mailer) {
        this.jdbc = jdbc;
        this.mailer = mailer;
    }

    /** Sends a new code (the previous one stops working), in French or English. */
    @Transactional
    public void send(User user, Purpose purpose, boolean french) {
        long recent = jdbc.sql("""
                        SELECT count(*) FROM email_codes
                        WHERE user_id = :user AND purpose = :purpose AND created_at > now() - interval '1 hour'""")
                .param("user", user.getId())
                .param("purpose", purpose.name())
                .query(Long.class).single();
        if (recent >= PER_HOUR) {
            throw ApiException.coded(HttpStatus.TOO_MANY_REQUESTS, "too_many_codes",
                    "We already sent you several codes. Check your inbox and spam, or try again in an hour.");
        }
        jdbc.sql("UPDATE email_codes SET used_at = now() WHERE user_id = :user AND purpose = :purpose AND used_at IS NULL")
                .param("user", user.getId())
                .param("purpose", purpose.name())
                .update();
        String code = "%06d".formatted(RANDOM.nextInt(1_000_000));
        jdbc.sql("""
                        INSERT INTO email_codes (id, user_id, purpose, code_hash, created_at, expires_at)
                        VALUES (:id, :user, :purpose, :hash, now(), :expires)""")
                .param("id", UUID.randomUUID())
                .param("user", user.getId())
                .param("purpose", purpose.name())
                .param("hash", hash(user.getId(), code))
                .param("expires", OffsetDateTime.now().plus(VALID))
                .update();
        Email email = email(purpose, code, user.getDisplayName(), french);
        String to = user.getEmail();
        AfterCommit.run(() -> mailer.send(to, email.subject(), email.text(), email.html()));
    }

    /**
     * Uses up the code if it's right; 422 "wrong_code" or "code_expired" otherwise. A wrong code
     * counts as a try even though the request fails: callers don't roll back on ApiException.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public void check(User user, Purpose purpose, String code) {
        record Pending(UUID id, String hash, int attempts) {}
        Pending pending = jdbc.sql("""
                        SELECT id, code_hash, attempts FROM email_codes
                        WHERE user_id = :user AND purpose = :purpose AND used_at IS NULL AND expires_at > now()
                        ORDER BY created_at DESC LIMIT 1 FOR UPDATE""")
                .param("user", user.getId())
                .param("purpose", purpose.name())
                .query((rs, i) -> new Pending(rs.getObject("id", UUID.class), rs.getString("code_hash"),
                        rs.getInt("attempts")))
                .optional()
                .orElseThrow(EmailCodes::expired);
        if (pending.attempts() >= TRIES) {
            throw expired();
        }
        if (!MessageDigest.isEqual(pending.hash().getBytes(StandardCharsets.UTF_8),
                hash(user.getId(), code.strip()).getBytes(StandardCharsets.UTF_8))) {
            jdbc.sql("UPDATE email_codes SET attempts = attempts + 1 WHERE id = :id").param("id", pending.id()).update();
            throw ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "wrong_code", "This code isn't right.");
        }
        jdbc.sql("UPDATE email_codes SET used_at = now() WHERE id = :id").param("id", pending.id()).update();
    }

    static ApiException expired() {
        return ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "code_expired",
                "This code expired or was used too many times. Ask for a new one.");
    }

    private static String hash(UUID userId, String code) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest((userId + ":" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    record Email(String subject, String text, String html) {}

    static Email email(Purpose purpose, String code, String name, boolean french) {
        String subject;
        String intro;
        String outro;
        if (purpose == Purpose.RESET) {
            subject = french ? "Votre code Winou : " + code : "Your Winou code: " + code;
            intro = french ? "Voici le code pour choisir un nouveau mot de passe :"
                    : "Here is the code to choose a new password:";
            outro = french ? "Si vous n'avez rien demandé, ignorez cet e-mail : votre mot de passe ne change pas."
                    : "If you didn't ask for it, ignore this email: your password stays the same.";
        } else {
            subject = french ? "Confirmez votre e-mail Winou : " + code : "Confirm your Winou email: " + code;
            intro = french ? "Voici le code pour confirmer votre adresse e-mail :"
                    : "Here is the code to confirm your email address:";
            outro = french ? "Si vous n'avez pas créé de compte Winou, ignorez cet e-mail."
                    : "If you didn't create a Winou account, ignore this email.";
        }
        String hello = (french ? "Bonjour " : "Hi ") + name + ",";
        String valid = french ? "Il est valable 15 minutes." : "It works for 15 minutes.";
        String text = hello + "\n\n" + intro + "\n\n    " + code + "\n\n" + valid + "\n\n" + outro + "\n\nWinou";
        String html = """
                <div style="font-family:Arial,sans-serif;max-width:440px;margin:auto;color:#111D36">
                  <p style="font-size:20px;font-weight:bold;color:#3884FF">winou</p>
                  <p>%s</p>
                  <p>%s</p>
                  <p style="font-size:32px;font-weight:bold;letter-spacing:6px;background:#EAF0FF;
                     padding:14px;border-radius:12px;text-align:center">%s</p>
                  <p>%s</p>
                  <p style="color:#526079;font-size:13px">%s</p>
                </div>""".formatted(escape(hello), intro, code, valid, outro);
        return new Email(subject, text, html);
    }

    private static String escape(String text) {
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
