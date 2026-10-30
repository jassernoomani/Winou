package tn.winou.auth;

import java.time.Duration;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.security.Admins;
import tn.winou.security.AttemptLimiter;
import tn.winou.security.CurrentUser;
import tn.winou.security.CurrentUserResolver;
import tn.winou.security.GoogleTokens;
import tn.winou.security.Passwords;
import tn.winou.security.Sessions;
import tn.winou.web.ApiModels.GoogleIn;
import tn.winou.web.ApiModels.RefreshIn;
import tn.winou.web.ApiModels.RegisterIn;
import tn.winou.web.ApiModels.TokenOut;
import tn.winou.web.ApiModels.UserOut;
import tn.winou.web.ApiModels.UserUpdate;

@RestController
@Tag(name = "auth")
public class AuthController {

    private static final Duration HOUR = Duration.ofHours(1);

    private final UserRepository users;
    private final Passwords passwords;
    private final Sessions sessions;
    private final Admins admins;
    private final AttemptLimiter limiter;
    private final GoogleTokens googleTokens;
    private final EmailCodes codes;
    private final WinouProperties.Auth settings;

    public AuthController(UserRepository users, Passwords passwords, Sessions sessions, Admins admins,
            AttemptLimiter limiter, GoogleTokens googleTokens, EmailCodes codes, WinouProperties properties) {
        this.googleTokens = googleTokens;
        this.codes = codes;
        this.users = users;
        this.passwords = passwords;
        this.sessions = sessions;
        this.admins = admins;
        this.limiter = limiter;
        this.settings = properties.auth();
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create an account; signs in at once and emails a code to confirm the address",
            description = "At most REGISTRATIONS_PER_IP_PER_HOUR accounts per network address and hour.")
    public TokenOut register(@Valid @RequestBody RegisterIn body, HttpServletRequest request) {
        String ipKey = "register:" + request.getRemoteAddr();
        limiter.check(ipKey, settings.registrationsPerIpPerHour(), HOUR);
        String email = body.email().strip().toLowerCase();
        if (users.existsByEmail(email)) {
            throw emailTaken();
        }
        User user = new User(email, passwords.hash(body.password()), body.displayName().strip());
        user.setRole(admins.roleFor(email));
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw emailTaken(); // registered at the same moment by another request
        }
        limiter.record(ipKey, HOUR);
        try {
            codes.send(user, EmailCodes.Purpose.VERIFY, CodesController.language(request));
        } catch (ApiException e) {
            // The account works without it: they can ask again from the Account screen
        }
        return sessions.start(user);
    }

    @PostMapping(value = "/auth/login", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    @Operation(summary = "OAuth2 password form: `username` is the email",
            description = "After LOGIN_ATTEMPTS_PER_EMAIL wrong passwords for an email, or LOGIN_ATTEMPTS_PER_IP "
                    + "from one network address, within LOGIN_ATTEMPT_WINDOW_MINUTES: 429 \"too_many_attempts\".")
    public TokenOut login(@RequestParam String username, @RequestParam String password, HttpServletRequest request) {
        String email = username.strip().toLowerCase();
        String emailKey = "login:" + email;
        String ipKey = "login-ip:" + request.getRemoteAddr();
        Duration window = settings.loginAttemptWindow();
        limiter.check(emailKey, settings.loginAttemptsPerEmail(), window);
        limiter.check(ipKey, settings.loginAttemptsPerIp(), window);
        User user = users.findByEmail(email).orElse(null);
        if (!passwords.verify(user != null ? user.getPasswordHash() : null, password)) {
            limiter.record(emailKey, window);
            limiter.record(ipKey, window);
            throw ApiException.unauthorized("Wrong email or password");
        }
        CurrentUserResolver.requireNotBanned(user);
        limiter.clear(emailKey);
        return sessions.start(user);
    }

    @PostMapping("/auth/google")
    @Transactional
    @Operation(summary = "Continue with Google: the ID token from Google Sign-In",
            description = "Signs in the account tied to this Google account, or the one with its verified email "
                    + "(tying them), or creates one. 503 \"google_disabled\" without GOOGLE_CLIENT_IDS.")
    public TokenOut google(@Valid @RequestBody GoogleIn body, HttpServletRequest request) {
        GoogleTokens.Identity google = googleTokens.verify(body.idToken());
        User user = users.findByGoogleSub(google.sub()).orElse(null);
        if (user == null) {
            if (google.email() == null || !google.emailVerified()) {
                throw ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "google_no_email",
                        "This Google account has no verified email.");
            }
            String email = google.email().strip().toLowerCase();
            user = users.findByEmail(email).orElse(null);
            if (user == null) {
                String ipKey = "register:" + request.getRemoteAddr();
                limiter.check(ipKey, settings.registrationsPerIpPerHour(), HOUR);
                String name = google.name() != null && !google.name().isBlank() ? google.name().strip()
                        : email.substring(0, email.indexOf('@'));
                user = new User(email, null, name.length() > 80 ? name.substring(0, 80) : name);
                user.setRole(admins.roleFor(email));
                limiter.record(ipKey, HOUR);
            } else if (user.getEmailVerifiedAt() == null) {
                // Whoever registered this address with a password never proved it was theirs: Google
                // just did, so that password and its sessions stop working
                user.setPasswordHash(null);
                sessions.endAll(user);
            }
            user.setGoogleSub(google.sub());
        }
        if (user.getEmailVerifiedAt() == null) {
            user.setEmailVerifiedAt(java.time.OffsetDateTime.now());
        }
        users.saveAndFlush(user);
        CurrentUserResolver.requireNotBanned(user);
        return sessions.start(user);
    }

    @PostMapping("/auth/refresh")
    @Operation(summary = "A new access token and refresh token for a refresh token, which stops working",
            description = "401 \"session_expired\" when the session ended: sign in again.")
    public TokenOut refresh(@Valid @RequestBody RefreshIn body) {
        return sessions.refresh(body.refreshToken());
    }

    @PostMapping("/auth/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Ends the session of this refresh token")
    public void logout(@Valid @RequestBody RefreshIn body) {
        sessions.end(body.refreshToken());
    }

    @GetMapping("/me")
    public UserOut me(@CurrentUser User user) {
        return out(user);
    }

    @PatchMapping("/me")
    @Transactional
    public UserOut updateMe(@Valid @RequestBody UserUpdate body, @CurrentUser User user) {
        if (body.getDisplayName() != null) {
            if (body.getDisplayName().isBlank()) {
                throw ApiException.invalid("The name can't be empty");
            }
            user.setDisplayName(body.getDisplayName().strip());
        }
        if (body.isFcmTokenSent()) {
            if (body.getFcmToken() != null) {
                users.releaseFcmToken(body.getFcmToken(), user.getId());
            }
            user.setFcmToken(body.getFcmToken());
        }
        return out(users.save(user));
    }

    static UserOut out(User user) {
        return new UserOut(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole(),
                user.getAssociationName(), user.getCreatedAt(), user.getPasswordHash() != null,
                user.getEmailVerifiedAt() != null, user.getGoogleSub() != null);
    }

    private static ApiException emailTaken() {
        return ApiException.coded(HttpStatus.CONFLICT, "email_taken", "This email is already registered.");
    }
}
