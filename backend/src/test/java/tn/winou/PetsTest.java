package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** "My pets" made ahead of time and marked lost in one step; and animals found and kept safe. */
class PetsTest extends ApiTestBase {

    private JsonNode pet(String token) {
        Response created = postJson("/me/pets", token, Map.of("name", "Luna", "species", "cat",
                "description", "Grey tabby, notch in the left ear", "microchipped", true));
        assertThat(created.status()).as(created.text()).isEqualTo(201);
        return created.json();
    }

    private Response markLost(String token, String petId) {
        return postJson("/pets/" + petId + "/lost", token, Map.of("last_seen", TUNIS,
                "last_seen_at", "2026-10-20T10:00:00+01:00", "reward_tnd", 100));
    }

    @Test
    void aPetsPhotosAreKeptButNotMatched() {
        String owner = register("owner");
        String id = pet(owner).path("id").asString();
        JsonNode photo = upload(owner, "/pets/" + id + "/photos", RED);
        assertThat(photo.path("status").asString()).isEqualTo("SKIPPED");
        work();
        assertThat(ml.calls.get()).isZero();

        JsonNode mine = getJson("/me/pets", owner).json();
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).path("photos")).hasSize(1);
        assertThat(mine.get(0).path("open_report_id").isNull()).isTrue();
    }

    @Test
    void markingAPetLostMakesAReportFromItsProfile() {
        String owner = register("owner");
        String id = pet(owner).path("id").asString();
        upload(owner, "/pets/" + id + "/photos", RED);
        upload(owner, "/pets/" + id + "/photos", NEAR_RED);
        String finder = register("finder");
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();

        Response lost = markLost(owner, id);
        assertThat(lost.status()).as(lost.text()).isEqualTo(201);
        JsonNode report = lost.json();
        assertThat(report.path("name").asString()).isEqualTo("Luna");
        assertThat(report.path("species").asString()).isEqualTo("cat");
        assertThat(report.path("description").asString()).isEqualTo("Grey tabby, notch in the left ear");
        assertThat(report.path("microchipped").asBoolean()).isTrue();
        assertThat(report.path("reward_tnd").asInt()).isEqualTo(100);
        assertThat(report.path("photos")).hasSize(2);

        work(); // the copies are matched: the finder's sighting comes up
        assertThat(getJson("/me/matches", owner).json()).isNotEmpty();
        assertThat(getJson("/me/pets", owner).json().get(0).path("open_report_id").asString())
                .isEqualTo(report.path("id").asString());

        Response again = markLost(owner, id);
        assertThat(again.status()).isEqualTo(409);
        assertThat(again.json().path("detail").path("code").asString()).isEqualTo("already_lost");
    }

    @Test
    void aPetNeedsAPhotoToBeMarkedLost() {
        String owner = register("owner");
        Response lost = markLost(owner, pet(owner).path("id").asString());
        assertThat(lost.status()).isEqualTo(422);
        assertThat(lost.json().path("detail").path("code").asString()).isEqualTo("no_photos");
    }

    @Test
    void onlyItsOwnerChangesAPet() {
        String owner = register("owner");
        String other = register("other");
        String id = pet(owner).path("id").asString();
        assertThat(patchJson("/pets/" + id, other, Map.of("name", "Mine now")).status()).isEqualTo(403);
        assertThat(markLost(other, id).status()).isEqualTo(403);
        assertThat(delete("/pets/" + id, other).status()).isEqualTo(403);
        assertThat(getJson("/me/pets", other).json()).isEmpty();

        assertThat(patchJson("/pets/" + id, owner, Map.of("name", "Luna Bella")).json().path("name").asString())
                .isEqualTo("Luna Bella");
    }

    @Test
    void deletingAPetRemovesItsPhotosButNotItsReport() {
        String owner = register("owner");
        String id = pet(owner).path("id").asString();
        upload(owner, "/pets/" + id + "/photos", RED);
        String report = markLost(owner, id).json().path("id").asString();
        int filesWithReport = storage.objects.size();

        assertThat(delete("/pets/" + id, owner).status()).isEqualTo(204);
        assertThat(getJson("/me/pets", owner).json()).isEmpty();
        assertThat(storage.objects).hasSize(filesWithReport - 2); // the pet photo's two files
        assertThat(getJson("/lost-reports/" + report, owner).status()).isEqualTo(200);
    }

    @Test
    void anAnimalCanBeFoundAndKeptSafe() {
        String finder = register("finder");
        Map<String, Object> fields = new HashMap<>(Map.of("in_care", true));
        JsonNode sighting = sighting(finder, fields, null);
        assertThat(sighting.path("in_care").asBoolean()).isTrue();

        JsonNode map = getJson("/map", null, Map.of("bbox", "10.05,36.75,10.30,36.90")).json().path("items");
        assertThat(map.get(0).path("in_care").asBoolean()).isTrue();

        String id = sighting.path("id").asString();
        assertThat(patchJson("/sightings/" + id, finder, Map.of("in_care", false)).json().path("in_care").asBoolean())
                .isFalse();
    }
}
