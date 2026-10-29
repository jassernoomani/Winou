package tn.winou.auth;

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
import jakarta.validation.Valid;
import tn.winou.common.ApiException;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.security.CurrentUser;
import tn.winou.security.Passwords;
import tn.winou.security.Tokens;
import tn.winou.web.ApiModels.RegisterIn;
import tn.winou.web.ApiModels.TokenOut;
import tn.winou.web.ApiModels.UserOut;
import tn.winou.web.ApiModels.UserUpdate;

@RestController
@Tag(name = "auth")
public class AuthController {

    private final UserRepository users;
    private final Passwords passwords;
    private final Tokens tokens;

    public AuthController(UserRepository users, Passwords passwords, Tokens tokens) {
        this.users = users;
        this.passwords = passwords;
        this.tokens = tokens;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenOut register(@Valid @RequestBody RegisterIn body) {
        String email = body.email().toLowerCase();
        if (users.existsByEmail(email)) {
            throw emailTaken();
        }
        User user = new User(email, passwords.hash(body.password()), body.displayName().strip());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw emailTaken(); // registered at the same moment by another request
        }
        return TokenOut.bearer(tokens.issue(user.getId()));
    }

    @PostMapping(value = "/auth/login", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    @Operation(summary = "OAuth2 password form: `username` is the email")
    public TokenOut login(@RequestParam String username, @RequestParam String password) {
        User user = users.findByEmail(username.toLowerCase()).orElse(null);
        if (!passwords.verify(user != null ? user.getPasswordHash() : null, password)) {
            throw ApiException.unauthorized("Wrong email or password");
        }
        return TokenOut.bearer(tokens.issue(user.getId()));
    }

    @GetMapping("/me")
    public UserOut me(@CurrentUser User user) {
        return out(user);
    }

    @PatchMapping("/me")
    @Transactional
    public UserOut updateMe(@Valid @RequestBody UserUpdate body, @CurrentUser User user) {
        if (body.getDisplayName() != null) {
            user.setDisplayName(body.getDisplayName());
        }
        if (body.isFcmTokenSent()) {
            user.setFcmToken(body.getFcmToken());
        }
        return out(users.save(user));
    }

    private static UserOut out(User user) {
        return new UserOut(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole(), user.getCreatedAt());
    }

    private static ApiException emailTaken() {
        return ApiException.coded(HttpStatus.CONFLICT, "email_taken", "This email is already registered.");
    }
}
