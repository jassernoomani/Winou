package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import tools.jackson.databind.JsonNode;

/** A stray's care card, kept by the neighbourhood, and the people who feed it. */
class StrayCareTest extends ApiTestBase {

    private String stray(String token) {
        return sighting(token, Map.of("is_stray", true, "seen_at", OffsetDateTime.now().minusDays(1).toString()), null)
                .path("id").asString();
    }

    private Response put(String path, String token, Object payload) {
        var request = MockMvcRequestBuilders.put(path);
        if (payload != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(body(payload));
        }
        return call(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    private Map<String, Object> card(String nickname, Boolean sterilised, Boolean vaccinated, String notes) {
        Map<String, Object> card = new HashMap<>();
        card.put("nickname", nickname);
        card.put("sterilised", sterilised);
        card.put("vaccinated", vaccinated);
        card.put("notes", notes);
        return card;
    }

    @Test
    void anyoneSignedInKeepsTheCardUpToDate() {
        String id = stray(register("reporter"));
        String neighbour = register("neighbour");

        JsonNode care = put("/sightings/" + id + "/care", neighbour,
                card("  Simba ", true, null, "Ear-tipped. Eats at the bakery at 6pm.")).json().path("care");

        assertThat(care.path("nickname").asString()).isEqualTo("Simba");
        assertThat(care.path("sterilised").asBoolean()).isTrue();
        assertThat(care.path("vaccinated").isNull()).isTrue(); // nobody knows
        assertThat(care.path("notes").asString()).startsWith("Ear-tipped");
        assertThat(care.path("updated_at").isNull()).isFalse();

        // Everyone sees it, and the (public) map shows the name
        assertThat(getJson("/sightings/" + id, register("passer-by")).json().path("care").path("nickname").asString()).isEqualTo("Simba");
        JsonNode item = getJson("/map", null, Map.of("bbox", "10.05,36.75,10.30,36.90")).json().path("items").get(0);
        assertThat(item.path("name").asString()).isEqualTo("Simba");

        // Blank clears
        care = put("/sightings/" + id + "/care", neighbour, card(" ", true, false, "")).json().path("care");
        assertThat(care.path("nickname").isNull()).isTrue();
        assertThat(care.path("notes").isNull()).isTrue();
        assertThat(care.path("vaccinated").asBoolean()).isFalse();
    }

    @Test
    void onlyStraysHaveACardAndOnlySignedInUsersEditIt() {
        String owner = register("reporter");
        String loose = sighting(owner, Map.of("is_stray", false), null).path("id").asString();
        assertThat(put("/sightings/" + loose + "/care", owner, card("Rex", null, null, null)).status()).isEqualTo(422);
        assertThat(getJson("/sightings/" + loose, owner).json().path("care").isNull()).isTrue();

        String id = stray(owner);
        assertThat(call(MockMvcRequestBuilders.put("/sightings/" + id + "/care").contentType(MediaType.APPLICATION_JSON)
                .content(body(card("Simba", null, null, null)))).status()).isEqualTo(401);
        assertThat(put("/sightings/" + id + "/care", owner, card("x".repeat(41), null, null, null)).status())
                .isEqualTo(422);
    }

    @Test
    void feedersAreCountedOnceAndKeepTheStrayOnTheMap() {
        String id = stray(register("reporter"));
        String a = register("a");
        String b = register("b");
        jdbc.sql("UPDATE sightings SET seen_at = now() - interval '200 days' WHERE id = :id::uuid").param("id", id).update();

        JsonNode care = put("/sightings/" + id + "/feeding", a, null).json().path("care");
        assertThat(care.path("feeders").asInt()).isEqualTo(1);
        assertThat(care.path("i_feed").asBoolean()).isTrue();
        put("/sightings/" + id + "/feeding", a, null); // twice: still one
        care = put("/sightings/" + id + "/feeding", b, null).json().path("care");
        assertThat(care.path("feeders").asInt()).isEqualTo(2);

        // Feeding it says it is still around: an old stray stays on the map
        JsonNode items = getJson("/map", null, Map.of("bbox", "10.05,36.75,10.30,36.90")).json().path("items");
        assertThat(items.toString()).contains(id);

        care = delete("/sightings/" + id + "/feeding", a).json().path("care");
        assertThat(care.path("feeders").asInt()).isEqualTo(1);
        assertThat(care.path("i_feed").asBoolean()).isFalse();
        assertThat(getJson("/sightings/" + id, b).json().path("care").path("i_feed").asBoolean()).isTrue();
    }
}
