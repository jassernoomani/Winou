package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Anyone can watch an area: pets lost there, and animals that need help there. */
class AlertAreasTest extends ApiTestBase {

    private Response watch(String token, Map<String, Object> location, double radiusKm, boolean lost, boolean help) {
        return call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/me/alert-area")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .content(body(Map.of("location", location, "radius_km", radiusKm, "lost", lost, "help", help)))
                .header("Authorization", "Bearer " + token));
    }

    private String userId(String token) {
        return getJson("/me", token).json().path("id").asString();
    }

    @Test
    void anAreaIsSetReadAndCleared() {
        String token = register("neighbour");
        assertThat(getJson("/me/alert-area", token).status()).isEqualTo(204);

        JsonNode area = watch(token, TUNIS, 5, true, false).json();
        assertThat(area.path("radius_km").asDouble()).isEqualTo(5);
        assertThat(area.path("lost").asBoolean()).isTrue();
        assertThat(area.path("location").path("lat").asDouble()).isCloseTo(36.8065, org.assertj.core.data.Offset.offset(1e-6));
        assertThat(getJson("/me/alert-area", token).json().path("help").asBoolean()).isFalse();

        assertThat(watch(token, TUNIS, 60, true, true).status()).isEqualTo(422); // 25 km at most
        assertThat(delete("/me/alert-area", token).status()).isEqualTo(204);
        assertThat(getJson("/me/alert-area", token).status()).isEqualTo(204);
    }

    @Test
    void peopleWatchingTheAreaHearAboutALostPet() {
        String near = register("near");
        String far = register("far");
        String notLost = register("helpOnly");
        String owner = register("owner");
        watch(near, offset(TUNIS, 2, 0), 5, true, false);
        watch(far, offset(TUNIS, 40, 0), 5, true, true);
        watch(notLost, TUNIS, 5, false, true);
        watch(owner, TUNIS, 5, true, true); // not about their own pet

        lostReport(owner, null);

        assertThat(notifier.lostNearby).containsExactly("Mimi: " + List.of(userId(near)));
    }

    @Test
    void peopleWatchingForAnimalsInNeedHearWithTheAssociations() {
        String watcher = register("watcher");
        String lostOnly = register("lostOnly");
        watch(watcher, TUNIS, 3, false, true);
        watch(lostOnly, TUNIS, 3, true, false);
        Map<String, Object> injured = new HashMap<>(Map.of("condition", "INJURED"));

        String sighting = sighting(register("finder"), injured, null).path("id").asString();

        assertThat(notifier.help).containsExactly(sighting + ": " + List.of(userId(watcher)));
        sighting(register("other"), Map.of("condition", "HEALTHY"), null);
        assertThat(notifier.help).hasSize(1); // healthy animals don't alert anyone
    }

    @Test
    void bannedUsersHearNothing() {
        String admin = postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
        String watcher = register("watcher");
        watch(watcher, TUNIS, 5, true, true);
        postJson("/admin/users/" + userId(watcher) + "/ban", admin, Map.of("days", 7));

        lostReport(register("owner"), null);
        assertThat(notifier.lostNearby).isEmpty();
    }
}
