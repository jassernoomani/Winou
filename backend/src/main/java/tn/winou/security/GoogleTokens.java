package tn.winou.security;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;

/**
 * Checks the ID token the app got from "Continue with Google": signed by Google, not expired, and
 * issued for this app's web client ID (GOOGLE_CLIENT_IDS).
 */
@Component
public class GoogleTokens {

    /** Who Google says signed in. sub is stable; the email may change. */
    public record Identity(String sub, String email, boolean emailVerified, String name) {}

    private static final String KEYS = "https://www.googleapis.com/oauth2/v3/certs";
    private static final List<String> ISSUERS = List.of("https://accounts.google.com", "accounts.google.com");

    private final List<String> clientIds;
    private JwtDecoder decoder; // created on first use: no network call at startup

    public GoogleTokens(WinouProperties properties) {
        this.clientIds = properties.google().clientIds();
    }

    public boolean enabled() {
        return !clientIds.isEmpty();
    }

    public Identity verify(String idToken) {
        if (!enabled()) {
            throw ApiException.coded(HttpStatus.SERVICE_UNAVAILABLE, "google_disabled",
                    "Google sign-in isn't set up on this server.");
        }
        try {
            Jwt jwt = decoder().decode(idToken);
            return new Identity(jwt.getSubject(), jwt.getClaimAsString("email"),
                    Boolean.TRUE.equals(jwt.getClaimAsBoolean("email_verified")), jwt.getClaimAsString("name"));
        } catch (JwtException e) {
            throw ApiException.coded(HttpStatus.UNAUTHORIZED, "google_invalid", "Google sign-in failed. Try again.");
        }
    }

    private synchronized JwtDecoder decoder() {
        if (decoder == null) {
            NimbusJwtDecoder nimbus = NimbusJwtDecoder.withJwkSetUri(KEYS).build();
            OAuth2TokenValidator<Jwt> issuer = jwt -> ISSUERS.contains(jwt.getClaimAsString("iss"))
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "wrong issuer", null));
            OAuth2TokenValidator<Jwt> audience = jwt -> jwt.getAudience().stream().anyMatch(clientIds::contains)
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "not for this app", null));
            nimbus.setJwtValidator(new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefault(), issuer, audience));
            decoder = nimbus;
        }
        return decoder;
    }
}
