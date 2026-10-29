package tn.winou.security;

import java.nio.charset.StandardCharsets;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;

import com.nimbusds.jose.jwk.source.ImmutableSecret;

import tn.winou.config.WinouProperties;

/** Stateless JWT (HS256) authentication. Tokens issued by the Python API stay valid. */
@Configuration
public class SecurityConfig {

    /** Reachable without logging in. A token sent to these is ignored, so an expired one does no harm. */
    private static final RequestMatcher PUBLIC = new OrRequestMatcher(
            post("/auth/register"),
            post("/auth/login"),
            get("/health"),
            get("/map"),
            get("/photos/{id}/image"),
            get("/photos/{id}/crop"),
            get("/docs"),
            get("/docs/**"),
            get("/swagger-ui/**"),
            get("/openapi.json"),
            get("/openapi.json/**"),
            PathPatternRequestMatcher.withDefaults().matcher("/error"));

    @Bean
    @ConditionalOnWebApplication
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        AuthenticationEntryPoint unauthorized = SecurityConfig::unauthorized;
        return http
                .csrf(csrf -> csrf.disable()) // no cookies: the token is sent explicitly
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth.requestMatchers(PUBLIC).permitAll().anyRequest().authenticated())
                .oauth2ResourceServer(oauth -> oauth
                        .jwt(Customizer.withDefaults())
                        .bearerTokenResolver(bearerTokenResolver())
                        .authenticationEntryPoint(unauthorized))
                .exceptionHandling(e -> e.authenticationEntryPoint(unauthorized))
                .build();
    }

    private static BearerTokenResolver bearerTokenResolver() {
        var header = new DefaultBearerTokenResolver();
        return request -> PUBLIC.matches(request) ? null : header.resolve(request);
    }

    private static void unauthorized(jakarta.servlet.http.HttpServletRequest request,
            jakarta.servlet.http.HttpServletResponse response, AuthenticationException e)
            throws java.io.IOException {
        String message = e instanceof OAuth2AuthenticationException ? "Invalid or expired token" : "Not authenticated";
        response.setStatus(401);
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"detail\":\"" + message + "\"}");
    }

    @Bean
    JwtDecoder jwtDecoder(WinouProperties properties) {
        return NimbusJwtDecoder.withSecretKey(key(properties)).macAlgorithm(MacAlgorithm.HS256).build();
    }

    @Bean
    JwtEncoder jwtEncoder(WinouProperties properties) {
        return new NimbusJwtEncoder(new ImmutableSecret<>(key(properties)));
    }

    private static SecretKey key(WinouProperties properties) {
        byte[] secret = properties.jwt().secret().getBytes(StandardCharsets.UTF_8);
        if (secret.length < 32) {
            throw new IllegalStateException("JWT_SECRET must be at least 32 bytes for HS256");
        }
        return new SecretKeySpec(secret, "HmacSHA256");
    }

    private static RequestMatcher get(String pattern) {
        return PathPatternRequestMatcher.withDefaults().matcher(HttpMethod.GET, pattern);
    }

    private static RequestMatcher post(String pattern) {
        return PathPatternRequestMatcher.withDefaults().matcher(HttpMethod.POST, pattern);
    }
}
