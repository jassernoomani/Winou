package tn.winou.security;

import java.time.Instant;
import java.util.UUID;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Component;

import tn.winou.config.WinouProperties;

/** Access tokens: HS256 JWT with the user id as subject. */
@Component
public class Tokens {

    private final JwtEncoder encoder;
    private final WinouProperties properties;

    public Tokens(JwtEncoder encoder, WinouProperties properties) {
        this.encoder = encoder;
        this.properties = properties;
    }

    public String issue(UUID userId) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .subject(userId.toString())
                .issuedAt(now)
                .expiresAt(now.plus(properties.jwt().expiry()))
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }
}
