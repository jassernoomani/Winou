package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** The background matching job end to end: upload, worker, Match rows. Port of tests/test_matching.py. */
class MatchingTest extends ApiTestBase {

    private JsonNode matches(String token) {
        return getJson("/me/matches", token).json();
    }

    @Test
    void sightingMatchesNearbyLostReport() {
        String owner = register("owner");
        String finder = register("finder");
        JsonNode report = lostReport(owner);
        JsonNode found = sighting(finder, Map.of("location", offset(TUNIS, 2, 0)), NEAR_RED);
        work();

        JsonNode all = matches(owner);
        assertThat(all).hasSize(1);
        JsonNode match = all.get(0);
        assertThat(match.path("lost_report_id").asString()).isEqualTo(report.path("id").asString());
        assertThat(match.path("lost_report_name").asString()).isEqualTo("Mimi");
        assertThat(match.path("sighting").path("id").asString()).isEqualTo(found.path("id").asString());
        assertThat(match.path("score").asDouble()).isGreaterThan(0.99);
        assertThat(match.path("status").asString()).isEqualTo("PENDING");
        assertThat(match.path("lost_photo_url").asString()).isNotEmpty();
        assertThat(match.path("sighting_photo_url").asString()).isNotEmpty();
        assertThat(notifier.matches).containsExactly(match.path("id").asString());
        assertThat(matches(finder)).isEmpty(); // matches belong to the lost report's owner

        JsonNode photo = getJson("/sightings/" + found.path("id").asString(), finder).json().path("photos").get(0);
        assertThat(photo.path("status").asString()).isEqualTo("READY");
        assertThat(photo.path("detected_species").asString()).isEqualTo("cat");
        Response crop = call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get(photo.path("crop_url").asString()));
        assertThat(crop.bytes()).isEqualTo("crop".getBytes());
    }

    @Test
    void lostReportMatchesEarlierSighting() {
        String owner = register("owner");
        String finder = register("finder");
        sighting(finder, Map.of("seen_at", "2026-10-21T08:00:00Z"), RED);
        work();
        lostReport(owner, TUNIS, "cat", "2026-10-20T10:00:00Z", RED);
        work();
        assertThat(matches(owner)).hasSize(1);
    }

    @Test
    void noMatchWhenFiltersExclude() {
        String owner = register("owner");
        String finder = register("finder");
        lostReport(owner, TUNIS, "cat", "2026-10-20T10:00:00Z", RED);
        sighting(finder, BLUE);                                                    // different animal
        sighting(finder, Map.of("location", offset(TUNIS, 0, 15)), RED);           // outside 10 km
        sighting(finder, Map.of("species", "dog"), RED);                           // other species
        sighting(finder, Map.of("seen_at", "2026-10-10T10:00:00Z"), RED);          // 10 days before it was lost
        sighting(finder, Map.of("seen_at", "2026-01-01T10:00:00Z"), RED);          // > 60 days before
        sighting(owner, RED);                                                      // the owner's own sighting
        work();
        assertThat(matches(owner)).isEmpty();
    }

    @Test
    void closedReportsAreNotMatched() {
        String owner = register("owner");
        String finder = register("finder");
        JsonNode report = lostReport(owner);
        patchJson("/lost-reports/" + report.path("id").asString(), owner, Map.of("status", "FOUND"));
        sighting(finder, RED);
        work();
        assertThat(matches(owner)).isEmpty();
    }

    @Test
    void bestPhotoPairIsKeptOnce() {
        String owner = register("owner");
        String finder = register("finder");
        JsonNode report = lostReport(owner, NEAR_RED);
        JsonNode found = sighting(finder, RED);
        work();
        double first = matches(owner).get(0).path("score").asDouble();
        upload(owner, "/lost-reports/" + report.path("id").asString() + "/photos", RED); // same colour: better
        upload(finder, "/sightings/" + found.path("id").asString() + "/photos", BLUE);
        work();
        JsonNode all = matches(owner);
        assertThat(all).hasSize(1);
        assertThat(all.get(0).path("score").asDouble()).isGreaterThan(first);
    }

    @Test
    void noAnimalPhoto() {
        String auth = register("user");
        JsonNode report = lostReport(auth, BLACK);
        work();
        JsonNode photo = getJson("/lost-reports/" + report.path("id").asString(), auth).json().path("photos").get(0);
        assertThat(photo.path("status").asString()).isEqualTo("NO_ANIMAL");
        assertThat(photo.path("crop_url").isNull()).isTrue();
        assertThat(index.count()).isZero();
    }

    @Test
    void otherSpeciesIsSkipped() {
        String auth = register("user");
        JsonNode report = lostReport(auth, TUNIS, "other", "2026-10-20T10:00:00+01:00", RED);
        work();
        JsonNode photo = getJson("/lost-reports/" + report.path("id").asString(), auth).json().path("photos").get(0);
        assertThat(photo.path("status").asString()).isEqualTo("SKIPPED");
        assertThat(ml.calls.get()).isZero();
    }

    @Test
    void movingASightingRematchesWithoutReEmbedding() {
        String owner = register("owner");
        String finder = register("finder");
        lostReport(owner);
        JsonNode found = sighting(finder, Map.of("location", offset(TUNIS, 0, 30)), RED);
        work();
        assertThat(matches(owner)).isEmpty();
        int calls = ml.calls.get();

        patchJson("/sightings/" + found.path("id").asString(), finder, Map.of("location", offset(TUNIS, 0, 3)));
        work();
        assertThat(matches(owner)).hasSize(1);
        assertThat(ml.calls.get()).isEqualTo(calls); // vector reused from Qdrant
    }

    @Test
    void transientMlFailureIsRetried() {
        String auth = register("user");
        JsonNode report = lostReport(auth);
        String path = "/lost-reports/" + report.path("id").asString();
        ml.down = true;
        work();
        JsonNode photo = getJson(path, auth).json().path("photos").get(0);
        assertThat(photo.path("status").asString()).isEqualTo("PENDING"); // back in the queue, with a delay

        jdbc.sql("UPDATE photos SET next_attempt_at = now()").update();
        ml.down = false;
        work();
        assertThat(getJson(path, auth).json().path("photos").get(0).path("status").asString()).isEqualTo("READY");
    }

    @Test
    void deletingASightingRemovesItsMatches() {
        String owner = register("owner");
        String finder = register("finder");
        lostReport(owner);
        JsonNode found = sighting(finder, RED);
        work();
        assertThat(matches(owner)).hasSize(1);
        assertThat(delete("/sightings/" + found.path("id").asString(), finder).status()).isEqualTo(204);
        assertThat(matches(owner)).isEmpty();
    }
}
