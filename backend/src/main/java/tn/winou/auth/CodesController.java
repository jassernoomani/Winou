package tn.winou.auth;

import java.time.Duration;
import java.time.OffsetDateTime;

import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import tn.winou.auth.EmailCodes.Purpose;
import tn.winou.common.ApiException;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.security.AttemptLimiter;
import tn.winou.security.CurrentUser;
import tn.winou.security.Passwords;
import tn.winou.security.Sessions;
import tn.winou.web.ApiModels.CodeIn;
import tn.winou.web.ApiModels.PasswordResetConfirmIn;
import tn.winou.web.ApiModels.PasswordResetIn;
import tn.winou.web.ApiModels.TokenOut;
import tn.winou.web.ApiModels.UserOut;

/** Codes by email: a forgotten password, and proving an email is yours. */
@RestController
@Tag(name = "auth")
public class CodesController {

    private static final Duration HOUR = Duration.ofHours(1);
    private static final int RESETS_PER_IP_PER_HOUR = 10;

    private final UserRepository users;
    private final EmailCodes codes;
    private final Passwords passwords;
    private final Sessions sessions;
    private final AttemptLimiter limiter;

    public CodesController(UserRepository users, EmailCodes codes, Passwords passwords, Sessions sessions,
            AttemptLimiter limiter) {
        this.users = users;
        this.codes = codes;
        this.passwords = passwords;
        this.sessions = sessions;
        this.limiter = limiter;
    }

    /** French emails for phones in French, English otherwise. */
    static boolean french(HttpServletRequest request) {
        return "fr".equals(request.getLocale().getLanguage());
    }

    @PostMapping("/auth/password-reset")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @Operation(summary = "Forgot password: emails a 6-digit code",
            description = "Always 202, whether the email has an account or not, so it can't be used to find "
                    + "out who has one.")
    public void requestReset(@Valid @RequestBody PasswordResetIn body, HttpServletRequest request) {
        String ipKey = "reset:" + request.getRemoteAddr();
        limiter.check(ipKey, RESETS_PER_IP_PER_HOUR, HOUR);
        limiter.record(ipKey, HOUR);
        users.findByEmail(body.email().strip().toLowerCase()).filter(u -> !u.isBanned()).ifPresent(user -> {
            try {
                codes.send(user, Purpose.RESET, french(request));
            } catch (ApiException e) {
                // Too many codes already: same answer as for an unknown email
            }
        });
    }

    @PostMapping("/auth/password-reset/confirm")
    @Transactional(noRollbackFor = ApiException.class)
    @Operation(summary = "The code and a new password: signs in, and signs every other phone out",
            description = "422 \"wrong_code\" or \"code_expired\" (5 tries per code).")
    public TokenOut confirmReset(@Valid @RequestBody PasswordResetConfirmIn body) {
        User user = users.findByEmail(body.email().strip().toLowerCase()).orElseThrow(EmailCodes::expired);
        codes.check(user, Purpose.RESET, body.code());
        user.setPasswordHash(passwords.hash(body.newPassword()));
        if (user.getEmailVerifiedAt() == null) {
            user.setEmailVerifiedAt(OffsetDateTime.now()); // they read the email
        }
        sessions.endAll(user);
        tn.winou.security.CurrentUserResolver.requireNotBanned(user);
        limiter.clear("login:" + user.getEmail()); // a forgotten password often comes after wrong guesses
        return sessions.start(user);
    }

    @PostMapping("/me/email/verification")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @Operation(summary = "Emails a code to confirm the address; 409 \"already_verified\"")
    public void requestVerification(@CurrentUser User user, HttpServletRequest request) {
        if (user.getEmailVerifiedAt() != null) {
            throw ApiException.coded(HttpStatus.CONFLICT, "already_verified", "This email is already confirmed.");
        }
        codes.send(user, Purpose.VERIFY, french(request));
    }

    @PostMapping("/me/email/verification/confirm")
    @Transactional(noRollbackFor = ApiException.class)
    @Operation(summary = "The code from the email: the address is confirmed")
    public UserOut confirmVerification(@Valid @RequestBody CodeIn body, @CurrentUser User user) {
        if (user.getEmailVerifiedAt() == null) {
            codes.check(user, Purpose.VERIFY, body.code());
            user.setEmailVerifiedAt(OffsetDateTime.now());
            users.save(user);
        }
        return AuthController.out(user);
    }
}
