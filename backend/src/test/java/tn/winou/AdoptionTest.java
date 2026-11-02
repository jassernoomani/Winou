package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Associations offer strays for adoption; people find them nearby. */
class AdoptionTest extends ApiTestBase {

    private static final Map<String, Object> OFFER = Map.of("note", "Gentle, vaccinated, loves children",
            "contact", "+216 20 123 456");

    private String admin;
    private String association;
    private String neighbour;
    private String strayId;

    private static String recent() {
        return OffsetDateTime.now().minusDays(1).withNano(0).toString();
    }

    private String association(String name) {
        String token = register(name);
        Map<String, Object> body = new HashMap<>(Map.of("organisation", name, "city", "Tunis",
                "contact", "+216 20 000 000", "location", TUNIS));
        String id = postJson("/me/association-request", token, body).json().path("id").asString();
        assertThat(postJson("/admin/association-requests/" + id + "/approve", admin, Map.of()).status()).isEqualTo(200);
        return token;
    }

    @BeforeEach
    void strayAndAssociation() {
        admin = postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
        association = association("Refuge-de-Tunis");
        neighbour = register("neighbour");
        strayId = sighting(neighbour, Map.of("is_stray", true, "seen_at", recent()), null).path("id").asString();
    }

    private Response offer(String token) {
        return putJson("/sightings/" + strayId + "/adoption", token, OFFER);
    }

    @Test
    void anAssociationOffersAStrayAndPeopleFindItNearby() {
        JsonNode offered = offer(association).json();
        assertThat(offered.path("adoption").path("status").asString()).isEqualTo("AVAILABLE");
        assertThat(offered.path("adoption").path("association").asString()).isEqualTo("Refuge-de-Tunis");
        assertThat(offered.path("adoption").path("mine").asBoolean()).isTrue();

        JsonNode near = getJson("/adoption", neighbour, Map.of("lat", 36.8065, "lon", 10.1815)).json();
        assertThat(near).hasSize(1);
        assertThat(near.get(0).path("id").asString()).isEqualTo(strayId);
        assertThat(near.get(0).path("adoption").path("contact").asString()).isEqualTo("+216 20 123 456");
        assertThat(near.get(0).path("adoption").path("mine").asBoolean()).isFalse();

        assertThat(getJson("/adoption", neighbour, Map.of("lat", 37.27, "lon", 9.87, "radius_km", 10)).json())
                .isEmpty(); // Bizerte, 60 km away
        assertThat(getJson("/adoption", neighbour).json()).hasSize(1); // no place: newest first
    }

    @Test
    void onlyAssociationsAndAdminsOffer() {
        Response refused = offer(neighbour);
        assertThat(refused.status()).isEqualTo(403);
        assertThat(refused.json().path("detail").path("code").asString()).isEqualTo("associations_only");
        assertThat(offer(admin).status()).isEqualTo(200);
    }

    @Test
    void anotherAssociationCannotTakeOverTheOffer() {
        offer(association);
        String other = association("Other-Refuge");
        assertThat(offer(other).status()).isEqualTo(403);
        assertThat(postJson("/sightings/" + strayId + "/adoption/adopted", other, Map.of()).status()).isEqualTo(403);
        assertThat(delete("/sightings/" + strayId + "/adoption", neighbour).status()).isEqualTo(403);
    }

    @Test
    void adoptedIsAHappyEnding() {
        offer(association);
        JsonNode adopted = postJson("/sightings/" + strayId + "/adoption/adopted", association, Map.of()).json();
        assertThat(adopted.path("adoption").path("status").asString()).isEqualTo("ADOPTED");
        assertThat(adopted.path("stray_status").asString()).isEqualTo("HELPED");
        assertThat(adopted.path("helped_by").asString()).isEqualTo("Refuge-de-Tunis");
        assertThat(getJson("/adoption", neighbour).json()).isEmpty();
    }

    @Test
    void withdrawingClearsTheOffer() {
        offer(association);
        JsonNode withdrawn = delete("/sightings/" + strayId + "/adoption", association).json();
        assertThat(withdrawn.path("adoption").isNull()).isTrue();
        assertThat(getJson("/adoption", neighbour).json()).isEmpty();
        assertThat(delete("/sightings/" + strayId + "/adoption", association).status()).isEqualTo(404);
    }

    @Test
    void onlyStraysStillAround() {
        String pet = sighting(neighbour, Map.of("seen_at", recent()), null).path("id").asString();
        assertThat(putJson("/sightings/" + pet + "/adoption", association, OFFER).status()).isEqualTo(422);
        patchJson("/sightings/" + strayId + "/stray-status", neighbour, Map.of("status", "GONE"));
        assertThat(offer(association).status()).isEqualTo(422);
    }

    @Test
    void theContactMustBeAPhoneNumber() {
        assertThat(putJson("/sightings/" + strayId + "/adoption", association, Map.of("contact", "call me")).status())
                .isEqualTo(422);
    }
}
