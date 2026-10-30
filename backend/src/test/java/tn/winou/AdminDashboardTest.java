package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** What tells admins there is work: alerts and counts. The dashboard's numbers, and the admin log. */
class AdminDashboardTest extends ApiTestBase {

    private String admin() {
        return postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
    }

    private void report(String token, String type, String id) {
        postJson("/reports", token, Map.of("target_type", type, "target_id", id, "reason", "SPAM"));
    }

    private Response requestAssociation(String token, String organisation) {
        return postJson("/me/association-request", token, Map.of("organisation", organisation, "city", "Tunis",
                "contact", "+216 20 000 000", "location", TUNIS));
    }

    @Test
    void adminsHearWhenContentIsHiddenOnce() {
        String id = lostReport(register("author"), null).path("id").asString();
        report(register("a"), "LOST_REPORT", id);
        report(register("b"), "LOST_REPORT", id);
        assertThat(notifier.adminHidden).isEmpty();
        report(register("c"), "LOST_REPORT", id);
        assertThat(notifier.adminHidden).containsExactly("LOST_REPORT " + id);
        report(register("d"), "LOST_REPORT", id); // already hidden: no second alert
        assertThat(notifier.adminHidden).hasSize(1);
    }

    @Test
    void adminsHearAboutAssociationRequests() {
        assertThat(requestAssociation(register("refuge"), "Refuge de Tunis").status()).isEqualTo(201);
        assertThat(notifier.adminRequests).containsExactly("Refuge de Tunis");
    }

    @Test
    void theSummaryCountsWhatWaitsOnEachTab() {
        String admin = admin();
        String author = register("author");
        String reported = lostReport(author, null).path("id").asString();
        String hidden = sighting(author, null).path("id").asString();
        report(register("a"), "LOST_REPORT", reported);
        report(register("b"), "LOST_REPORT", reported);
        postJson("/admin/content/SIGHTING/" + hidden + "/hide", admin, Map.of());
        requestAssociation(register("refuge"), "Refuge");

        assertThat(getJson("/admin/summary", author).status()).isEqualTo(403);
        JsonNode summary = getJson("/admin/summary", admin).json();
        assertThat(summary.path("reported").asLong()).isEqualTo(1);
        assertThat(summary.path("requests").asLong()).isEqualTo(1);
        assertThat(summary.path("hidden").asLong()).isEqualTo(1);
        // The same as the tabs' lists
        assertThat(getJson("/admin/reported", admin).json()).hasSize(1);
        assertThat(getJson("/admin/hidden", admin).json()).hasSize(1);
    }

    @Test
    void statsCountUsersCasesAndReunionsPerWeek() {
        String admin = admin();
        String owner = register("owner");
        String found = lostReport(owner, null).path("id").asString();
        lostReport(owner, null);
        sighting(register("finder"), null);
        sighting(register("neighbour"), Map.of("is_stray", true, "seen_at", java.time.OffsetDateTime.now().toString()),
                null);
        assertThat(patchJson("/lost-reports/" + found, owner, Map.of("status", "FOUND")).status()).isEqualTo(200);

        assertThat(getJson("/admin/stats", owner).status()).isEqualTo(403);
        JsonNode stats = getJson("/admin/stats", admin).json();
        assertThat(stats.path("users").asLong()).isEqualTo(4);
        assertThat(stats.path("new_users_this_week").asLong()).isEqualTo(4);
        assertThat(stats.path("lost_reports_total").asLong()).isEqualTo(2);
        assertThat(stats.path("open_lost_reports").asLong()).isEqualTo(1);
        assertThat(stats.path("reunited").asLong()).isEqualTo(1);
        assertThat(stats.path("reunion_rate").asDouble()).isEqualTo(0.5);
        assertThat(stats.path("sightings").asLong()).isEqualTo(2);
        assertThat(stats.path("strays_on_map").asLong()).isEqualTo(1);

        JsonNode weeks = stats.path("weeks");
        assertThat(weeks).hasSize(12);
        JsonNode thisWeek = weeks.get(11);
        assertThat(thisWeek.path("lost_reports").asLong()).isEqualTo(2);
        assertThat(thisWeek.path("sightings").asLong()).isEqualTo(2);
        assertThat(thisWeek.path("reunited").asLong()).isEqualTo(1);
        assertThat(weeks.get(0).path("lost_reports").asLong()).isZero();
    }

    @Test
    void statsBeforeAnyLostReportHaveNoReunionRate() {
        JsonNode stats = getJson("/admin/stats", admin()).json();
        assertThat(stats.path("reunion_rate").isNull()).isTrue();
        assertThat(stats.path("weeks")).hasSize(12);
    }

    @Test
    void theAdminLogListsEveryonesActionsNewestFirst() {
        String admin = admin();
        String spammer = register("spammer");
        String spammerId = getJson("/me", spammer).json().path("id").asString();
        String sighting = sighting(register("author"), null).path("id").asString();
        postJson("/admin/content/SIGHTING/" + sighting + "/hide", admin, Map.of());
        postJson("/admin/users/" + spammerId + "/ban", admin, Map.of("days", 7));

        assertThat(getJson("/admin/actions", spammer).status()).isEqualTo(403);
        JsonNode actions = getJson("/admin/actions", admin).json();
        assertThat(actions).hasSize(2);
        assertThat(actions.get(0).path("action").asString()).isEqualTo("BAN_USER");
        assertThat(actions.get(0).path("user_id").asString()).isEqualTo(spammerId);
        assertThat(actions.get(0).path("user_name").asString()).isEqualTo("spammer");
        assertThat(actions.get(0).path("admin_name").asString()).isEqualTo("Admin");
        assertThat(actions.get(1).path("action").asString()).isEqualTo("HIDE_CONTENT");
        assertThat(actions.get(1).path("user_name").asString()).isEqualTo("author");
        assertThat(getJson("/admin/actions", admin, Map.of("offset", 1)).json()).hasSize(1);
    }
}
