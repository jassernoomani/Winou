package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;

import tools.jackson.databind.JsonNode;

/** "I saw this pet" from a lost report, and the page a shared lost-pet link opens. */
class SharingTest extends ApiTestBase {

    private Response sawThisPet(String token, String reportId) {
        return postJson("/sightings", token, Map.of("species", "cat", "location", TUNIS,
                "seen_at", "2026-10-25T10:00:00+01:00", "lost_report_id", reportId));
    }

    @Test
    void aFinderMatchesTheirSightingToTheLostPet() {
        String owner = register("owner");
        String neighbour = register("neighbour");
        String report = lostReport(owner).path("id").asString();
        work(); // the owner's photo is indexed

        Response sighting = sawThisPet(neighbour, report);
        assertThat(sighting.status()).as(sighting.text()).isEqualTo(201);
        assertThat(notifier.matches).hasSize(1); // the owner hears at once, before any photo

        JsonNode match = getJson("/me/matches", owner).json().get(0);
        assertThat(match.path("source").asString()).isEqualTo("FINDER");
        assertThat(match.path("score").asDouble()).isZero();
        assertThat(match.path("lost_photo_url").asString()).startsWith("/photos/");
        assertThat(match.path("sighting").path("id").asString()).isEqualTo(sighting.json().path("id").asString());

        // Its photo is then scored by the model: same match, no second notification
        upload(neighbour, "/sightings/" + sighting.json().path("id").asString() + "/photos", NEAR_RED);
        work();
        JsonNode scored = getJson("/me/matches", owner).json();
        assertThat(scored).hasSize(1);
        assertThat(scored.get(0).path("source").asString()).isEqualTo("FINDER");
        assertThat(scored.get(0).path("score").asDouble()).isGreaterThan(0.9);
        assertThat(scored.get(0).path("sighting_photo_url").asString()).startsWith("/photos/");
        assertThat(notifier.matches).hasSize(1);
    }

    @Test
    void finderMatchesComeFirst() {
        String owner = register("owner");
        String report = lostReport(owner).path("id").asString();
        sighting(register("model"), Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        sawThisPet(register("finder"), report);

        JsonNode matches = getJson("/me/matches", owner).json();
        assertThat(matches).hasSize(2);
        assertThat(matches.get(0).path("source").asString()).isEqualTo("FINDER");
        assertThat(matches.get(1).path("source").asString()).isEqualTo("MODEL");
    }

    @Test
    void notForYourOwnPetOrACaseAlreadyClosed() {
        String owner = register("owner");
        String report = lostReport(owner, null).path("id").asString();
        Response own = sawThisPet(owner, report);
        assertThat(own.status()).isEqualTo(422);
        assertThat(own.json().path("detail").path("code").asString()).isEqualTo("own_report");

        patchJson("/lost-reports/" + report, owner, Map.of("status", "FOUND"));
        Response closed = sawThisPet(register("neighbour"), report);
        assertThat(closed.status()).isEqualTo(409);
        assertThat(closed.json().path("detail").path("code").asString()).isEqualTo("report_closed");
        assertThat(sawThisPet(register("other"), java.util.UUID.randomUUID().toString()).status()).isEqualTo(404);
    }

    @Test
    void aSharedLinkShowsAPageWithAPreview() {
        String owner = register("owner");
        String report = lostReport(owner).path("id").asString();

        Response page = call(get("/lost/" + report));
        assertThat(page.status()).isEqualTo(200);
        assertThat(page.header(HttpHeaders.CONTENT_TYPE)).startsWith("text/html");
        assertThat(page.text()).contains("<h1>Mimi</h1>", "og:title\" content=\"Lost cat · Mimi\"", "og:image",
                "/photos/", "/download/winou.apk");
        assertThat(page.text()).doesNotContain("36.8065"); // never the position

        Response french = call(get("/lost/" + report).header(HttpHeaders.ACCEPT_LANGUAGE, "fr"));
        assertThat(french.text()).contains("Chat perdu", "lang=\"fr\"");
        Response arabic = call(get("/lost/" + report).header(HttpHeaders.ACCEPT_LANGUAGE, "ar-TN"));
        assertThat(arabic.text()).contains("قطّ ضائع", "lang=\"ar\" dir=\"rtl\"");
    }

    @Test
    void foundOrHiddenPetsArentShown() {
        String owner = register("owner");
        String report = lostReport(owner, null).path("id").asString();
        patchJson("/lost-reports/" + report, owner, Map.of("status", "FOUND"));
        Response found = call(get("/lost/" + report));
        assertThat(found.status()).isEqualTo(404);
        assertThat(found.text()).contains("No longer missing").doesNotContain("Mimi");
        assertThat(call(get("/lost/not-an-id")).status()).isEqualTo(404);
    }

    @Test
    void androidMayOpenSharedLinksInTheApp() {
        JsonNode links = call(get("/.well-known/assetlinks.json")).json();
        assertThat(links.get(0).path("target").path("package_name").asString()).isEqualTo("tn.winou.winou");
        assertThat(links.get(0).path("target").path("sha256_cert_fingerprints").get(0).asString()).contains(":");
    }

    @Test
    void namesAreEscapedOnThePage() {
        String owner = register("owner");
        String report = postJson("/lost-reports", owner, Map.of("name", "<script>x</script>", "species", "cat",
                "last_seen", TUNIS, "last_seen_at", "2026-10-20T10:00:00+01:00")).json().path("id").asString();
        assertThat(call(get("/lost/" + report)).text()).doesNotContain("<script>x").contains("&lt;script&gt;");
    }
}
