package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Admins act on any content: reports still below the threshold, hiding now, deleting, and who wrote it. */
class AdminContentTest extends ApiTestBase {

    private String admin() {
        return postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
    }

    private String userId(String token) {
        return getJson("/me", token).json().path("id").asString();
    }

    private void report(String token, String type, String id, String reason) {
        assertThat(postJson("/reports", token, Map.of("target_type", type, "target_id", id, "reason", reason))
                .status()).isEqualTo(201);
    }

    private List<String> history(String admin, String userId) {
        List<String> actions = new ArrayList<>();
        getJson("/admin/users/" + userId, admin).json().path("history")
                .forEach(a -> actions.add(a.path("action").asString() + " " + a.path("note").asString()));
        return actions;
    }

    @Test
    void reportsBelowTheThresholdAreListedForAdmins() {
        String admin = admin();
        String author = register("author");
        String report = lostReport(author, null).path("id").asString();
        String other = sighting(author, null).path("id").asString();
        report(register("a"), "LOST_REPORT", report, "SPAM");
        report(register("b"), "LOST_REPORT", report, "FAKE");
        report(register("c"), "SIGHTING", other, "FAKE");

        assertThat(getJson("/admin/reported", author).status()).isEqualTo(403);
        JsonNode reported = getJson("/admin/reported", admin).json();
        assertThat(reported).hasSize(2);
        JsonNode first = reported.get(0); // the most reported first
        assertThat(first.path("target_id").asString()).isEqualTo(report);
        assertThat(first.path("reports").asLong()).isEqualTo(2);
        assertThat(first.path("hidden_at").isNull()).isTrue();
        assertThat(first.path("author_id").asString()).isEqualTo(userId(author));
        assertThat(first.path("author_name").asString()).isEqualTo("author");
        assertThat(first.path("last_reported_at").isNull()).isFalse();
        assertThat(getJson("/admin/hidden", admin).json()).isEmpty();
    }

    @Test
    void dismissedReportsAreForgottenAndTheContentStays() {
        String admin = admin();
        String author = register("author");
        String neighbour = register("neighbour");
        String report = lostReport(author, null).path("id").asString();
        report(neighbour, "LOST_REPORT", report, "SPAM");
        report(register("b"), "LOST_REPORT", report, "SPAM");

        assertThat(postJson("/admin/content/LOST_REPORT/" + report + "/dismiss", author, Map.of()).status())
                .isEqualTo(403);
        assertThat(postJson("/admin/content/LOST_REPORT/" + report + "/dismiss", admin, Map.of()).status())
                .isEqualTo(204);
        assertThat(getJson("/admin/reported", admin).json()).isEmpty();
        assertThat(getJson("/lost-reports/" + report, neighbour).status()).isEqualTo(200);
        assertThat(postJson("/admin/content/LOST_REPORT/" + report + "/dismiss", admin, Map.of()).status())
                .isEqualTo(409);
        assertThat(history(admin, userId(author))).containsExactly("DISMISS_REPORTS 2 reports");
        // The same people can report it again: their old reports are gone
        report(neighbour, "LOST_REPORT", report, "SPAM");
        assertThat(getJson("/admin/reported", admin).json()).hasSize(1);
    }

    @Test
    void adminsHideContentWithoutWaitingForReports() {
        String admin = admin();
        String author = register("author");
        String neighbour = register("neighbour");
        String sighting = sighting(author, null).path("id").asString();

        assertThat(postJson("/admin/content/SIGHTING/" + sighting + "/hide", neighbour, Map.of()).status())
                .isEqualTo(403);
        assertThat(postJson("/admin/content/SIGHTING/" + sighting + "/hide", admin, Map.of()).status()).isEqualTo(204);
        assertThat(getJson("/sightings/" + sighting, neighbour).status()).isEqualTo(404);
        assertThat(getJson("/sightings/" + sighting, author).json().path("hidden").asBoolean()).isTrue();
        JsonNode hidden = getJson("/admin/hidden", admin).json();
        assertThat(hidden).hasSize(1);
        assertThat(hidden.get(0).path("reports").asLong()).isZero();
        assertThat(postJson("/admin/content/SIGHTING/" + sighting + "/hide", admin, Map.of()).status()).isEqualTo(409);

        assertThat(postJson("/admin/hidden/SIGHTING/" + sighting + "/restore", admin, Map.of()).status())
                .isEqualTo(204);
        assertThat(getJson("/sightings/" + sighting, neighbour).status()).isEqualTo(200);
        assertThat(history(admin, userId(author))).containsExactly("RESTORE_CONTENT ", "HIDE_CONTENT ");
        assertThat(postJson("/admin/content/SIGHTING/" + java.util.UUID.randomUUID() + "/hide", admin, Map.of())
                .status()).isEqualTo(404);
    }

    @Test
    void adminsDeleteAnyContent() {
        String admin = admin();
        String author = register("author");
        String report = lostReport(author, null).path("id").asString();
        assertThat(delete("/admin/content/LOST_REPORT/" + report, register("other")).status()).isEqualTo(403);
        assertThat(delete("/admin/content/LOST_REPORT/" + report, admin).status()).isEqualTo(204);
        assertThat(getJson("/lost-reports/" + report, admin).status()).isEqualTo(404);
        assertThat(history(admin, userId(author))).containsExactly("DELETE_CONTENT ");
    }

    @Test
    void onlyAdminsSeeWhoPostedSomething() {
        String admin = admin();
        String author = register("author");
        String neighbour = register("neighbour");
        String report = lostReport(author, null).path("id").asString();
        String sighting = sighting(author, null).path("id").asString();
        String authorId = userId(author);

        assertThat(getJson("/lost-reports/" + report, neighbour).json().path("author_id").isNull()).isTrue();
        assertThat(getJson("/sightings/" + sighting, neighbour).json().path("author_id").isNull()).isTrue();
        assertThat(getJson("/sightings/" + sighting, author).json().path("author_id").isNull()).isTrue();
        assertThat(getJson("/lost-reports/" + report, admin).json().path("author_id").asString()).isEqualTo(authorId);
        assertThat(getJson("/sightings/" + sighting, admin).json().path("author_id").asString()).isEqualTo(authorId);
    }
}
