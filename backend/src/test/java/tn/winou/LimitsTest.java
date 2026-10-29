package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

import tools.jackson.databind.JsonNode;

/** Rate limits and the map's result cap, with small limits so the tests stay quick. */
@TestPropertySource(properties = {"winou.rate-limits.sightings-per-hour=2", "winou.map.max-results=2"})
class LimitsTest extends ApiTestBase {

    @Test
    void sightingRateLimitIsPerUser() {
        String auth = register("user");
        sighting(auth, null);
        sighting(auth, null);
        Response third = postJson("/sightings", auth, Map.of("species", "cat", "location", offset(TUNIS, 1, 0),
                "seen_at", "2026-10-25T10:00:00Z"));
        assertThat(third.status()).isEqualTo(429);
        assertThat(third.json().path("detail").path("code").asString()).isEqualTo("rate_limited");
        assertThat(sighting(register("someone-else"), null).path("id").asString()).isNotEmpty();
    }

    @Test
    void mapTruncates() {
        String a = register("a");
        String b = register("b");
        sighting(a, null);
        sighting(a, null);
        sighting(b, null);
        JsonNode body = getJson("/map", null, Map.of("bbox", "10.05,36.75,10.30,36.90")).json();
        assertThat(body.path("items")).hasSize(2);
        assertThat(body.path("truncated").asBoolean()).isTrue();
    }
}
