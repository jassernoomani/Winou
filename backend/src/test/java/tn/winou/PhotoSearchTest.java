package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.awt.Color;
import java.time.OffsetDateTime;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockMultipartFile;

import tools.jackson.databind.JsonNode;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;

/** Checking a photo before posting, and searching open lost reports by photo. Nothing is stored. */
class PhotoSearchTest extends ApiTestBase {

    /** Cosine ~0.66 with RED in the fake model: below the cat threshold (0.70), within the margin. */
    static final Color GREYISH_BLUE = new Color(130, 150, 170);

    private static final Map<String, Object> FAR = Map.of("lat", 37.2744, "lon", 9.8739); // Bizerte, ~60 km

    private String recently() {
        return OffsetDateTime.now().minusDays(1).withNano(0).toString();
    }

    private Response search(String token, Color color, Map<String, Object> at) {
        var request = multipart("/search/by-photo")
                .file(new MockMultipartFile("file", "p.jpg", "image/jpeg", image(color, "jpg")))
                .param("lat", at.get("lat").toString())
                .param("lon", at.get("lon").toString());
        return call(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    private long storedPhotos() {
        return jdbc.sql("SELECT count(*) FROM photos").query(Long.class).single();
    }

    @Test
    void checkSaysWhichAnimalAndStoresNothing() {
        String user = register("user");
        Response response = uploadRaw("/photos/check", user, image(RED, "jpg"), null);
        assertThat(response.status()).isEqualTo(200);
        assertThat(response.json().path("species").asString()).isEqualTo("cat");
        assertThat(response.json().path("confidence").asDouble()).isEqualTo(0.9);
        assertThat(storedPhotos()).isZero();
        assertThat(index.count()).isZero();
    }

    @Test
    void checkWithoutAnimal() {
        String user = register("user");
        Response response = uploadRaw("/photos/check", user, image(BLACK, "jpg"), null);
        assertThat(response.status()).isEqualTo(422);
        assertThat(response.json().path("detail").path("code").asString()).isEqualTo("no_animal_detected");
    }

    @Test
    void checkNeedsAnAccountAndAnImage() {
        assertThat(uploadRaw("/photos/check", "not-a-token", image(RED, "jpg"), null).status()).isEqualTo(401);
        String user = register("user");
        assertThat(uploadRaw("/photos/check", user, "not an image".getBytes(), null).status()).isIn(400, 415, 422);
        assertThat(ml.detectCalls.get()).isZero();
    }

    @Test
    void searchFindsTheNearbyOpenReport() {
        String owner = register("owner");
        String reportId = lostReport(owner, TUNIS, "cat", recently(), RED).path("id").asString();
        work();
        long before = storedPhotos();

        String finder = register("finder");
        JsonNode body = search(finder, NEAR_RED, TUNIS).json();
        assertThat(body.path("species").asString()).isEqualTo("cat");
        JsonNode results = body.path("results");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).path("report").path("id").asString()).isEqualTo(reportId);
        assertThat(results.get(0).path("likely").asBoolean()).isTrue();
        assertThat(results.get(0).path("score").asDouble()).isGreaterThan(0.99);
        assertThat(results.get(0).path("matched_image_url").asString()).startsWith("/photos/");
        assertThat(storedPhotos()).isEqualTo(before); // the search photo is not kept
        assertThat(jdbc.sql("SELECT count(*) FROM matches").query(Long.class).single()).isZero();
    }

    @Test
    void weakerLookAlikesAreMarkedNotLikely() {
        String owner = register("owner");
        lostReport(owner, TUNIS, "cat", recently(), RED);
        work();
        JsonNode results = search(register("finder"), GREYISH_BLUE, TUNIS).json().path("results");
        assertThat(results).hasSize(1);
        assertThat(results.get(0).path("likely").asBoolean()).isFalse();

        assertThat(search(register("other"), BLUE, TUNIS).json().path("results")).isEmpty(); // too different
    }

    @Test
    void searchLeavesOutFarClosedAndHiddenReports() {
        String owner = register("owner");
        lostReport(owner, FAR, "cat", recently(), RED);
        String found = lostReport(owner, TUNIS, "cat", recently(), RED).path("id").asString();
        String hidden = lostReport(register("owner2"), TUNIS, "cat", recently(), RED).path("id").asString();
        String dog = lostReport(register("owner3"), TUNIS, "dog", recently(), RED).path("id").asString();
        work();
        jdbc.sql("UPDATE lost_reports SET status = 'FOUND' WHERE id = :id::uuid").param("id", found).update();
        jdbc.sql("UPDATE lost_reports SET hidden_at = now() WHERE id = :id::uuid").param("id", hidden).update();

        JsonNode results = search(register("finder"), RED, TUNIS).json().path("results");
        assertThat(results).isEmpty(); // the dog report is another species; the rest are far, found or hidden
        assertThat(dog).isNotBlank();
    }

    @Test
    void searchWithoutAnimal() {
        Response response = search(register("finder"), BLACK, TUNIS);
        assertThat(response.status()).isEqualTo(422);
        assertThat(response.json().path("detail").path("code").asString()).isEqualTo("no_animal_detected");
    }

    @Test
    void searchesAreRateLimited() {
        String finder = register("finder");
        for (int i = 0; i < 20; i++) {
            assertThat(search(finder, RED, TUNIS).status()).isEqualTo(200);
        }
        Response limited = search(finder, RED, TUNIS);
        assertThat(limited.status()).isEqualTo(429);
        assertThat(search(register("someone-else"), RED, TUNIS).status()).isEqualTo(200);
    }
}
