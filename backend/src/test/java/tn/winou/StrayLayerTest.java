package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Phase 5: what became of strays, associations and their alerts, and the "Report" button. */
class StrayLayerTest extends ApiTestBase {

    private static final String BBOX = "10.05,36.75,10.30,36.90";

    private String recent(int daysAgo) {
        return OffsetDateTime.now().minusDays(daysAgo).toString();
    }

    private JsonNode stray(String token, int daysAgo) {
        return sighting(token, Map.of("is_stray", true, "seen_at", recent(daysAgo)), null);
    }

    private List<String> mapIds() {
        List<String> ids = new java.util.ArrayList<>();
        getJson("/map", null, Map.of("bbox", BBOX)).json().path("items").forEach(i -> ids.add(i.path("id").asString()));
        return ids;
    }

    private Response setStray(String token, String id, String status) {
        return patchJson("/sightings/" + id + "/stray-status", token, Map.of("status", status));
    }

    private String admin() {
        return postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
    }

    private Response requestAssociation(String token, String organisation, Map<String, Object> location) {
        Map<String, Object> body = new HashMap<>(Map.of("organisation", organisation, "city", "Tunis",
                "contact", "+216 20 000 000", "location", location));
        return postJson("/me/association-request", token, body);
    }

    /** A user approved as an association whose alert area is centred on [location]. */
    private String association(String organisation, Map<String, Object> location, String admin) {
        String token = register(organisation.replace(' ', '-')); // the name makes up the email
        String id = requestAssociation(token, organisation, location).json().path("id").asString();
        assertThat(postJson("/admin/association-requests/" + id + "/approve", admin, Map.of()).status()).isEqualTo(200);
        return token;
    }

    private String userId(String token) {
        return getJson("/me", token).json().path("id").asString();
    }

    private Response report(String token, String type, String id) {
        return postJson("/reports", token, Map.of("target_type", type, "target_id", id, "reason", "FAKE"));
    }

    // --- strays ---

    @Test
    void anyoneCanSayWhatBecameOfAStray() {
        String reporter = register("reporter");
        String neighbour = register("neighbour");
        String id = stray(reporter, 1).path("id").asString();
        assertThat(mapIds()).contains(id);

        JsonNode helped = setStray(neighbour, id, "HELPED").json();
        assertThat(helped.path("stray_status").asString()).isEqualTo("HELPED");
        assertThat(helped.path("helped_by").isNull()).isTrue(); // only associations are named
        assertThat(mapIds()).doesNotContain(id);

        assertThat(setStray(neighbour, id, "AROUND").status()).isEqualTo(200);
        assertThat(mapIds()).contains(id);
        assertThat(setStray(neighbour, id, "GONE").status()).isEqualTo(200);
        assertThat(mapIds()).doesNotContain(id);

        assertThat(setStray(null, id, "AROUND").status()).isEqualTo(401);
        assertThat(setStray(neighbour, id, "ADOPTED").status()).isEqualTo(422);
        String loose = sighting(reporter, Map.of("seen_at", recent(1)), null).path("id").asString();
        assertThat(setStray(neighbour, loose, "HELPED").status()).isEqualTo(422);
    }

    @Test
    void straysNotSeenForAMonthFadeUntilSomeoneSeesThemAgain() {
        String reporter = register("reporter");
        String old = stray(reporter, 40).path("id").asString();
        String loose = sighting(reporter, Map.of("seen_at", recent(40)), null).path("id").asString();
        assertThat(mapIds()).doesNotContain(old).contains(loose); // only strays fade

        setStray(register("neighbour"), old, "AROUND"); // "still around"
        assertThat(mapIds()).contains(old);
    }

    // --- associations ---

    @Test
    void usersAskToBeAnAssociationAndAnAdminDecides() {
        String user = register("refuge");
        String admin = admin();
        assertThat(getJson("/me", admin).json().path("role").asString()).isEqualTo("ADMIN");
        assertThat(getJson("/me/association-request", user).status()).isEqualTo(204);

        Response sent = requestAssociation(user, "Refuge de Tunis", TUNIS);
        assertThat(sent.status()).as(sent.text()).isEqualTo(201);
        assertThat(sent.json().path("status").asString()).isEqualTo("PENDING");
        assertThat(requestAssociation(user, "Again", TUNIS).json().path("detail").path("code").asString())
                .isEqualTo("request_pending");
        assertThat(getJson("/me/association-request", user).json().path("organisation").asString())
                .isEqualTo("Refuge de Tunis");

        assertThat(getJson("/admin/association-requests", user).status()).isEqualTo(403);
        JsonNode pending = getJson("/admin/association-requests", admin).json();
        assertThat(pending).hasSize(1);
        assertThat(pending.get(0).path("user_email").asString()).endsWith("@example.com");

        String id = sent.json().path("id").asString();
        assertThat(postJson("/admin/association-requests/" + id + "/approve", user, Map.of()).status()).isEqualTo(403);
        assertThat(postJson("/admin/association-requests/" + id + "/approve", admin, Map.of()).status()).isEqualTo(200);
        assertThat(postJson("/admin/association-requests/" + id + "/reject", admin, Map.of()).status()).isEqualTo(409);

        JsonNode me = getJson("/me", user).json();
        assertThat(me.path("role").asString()).isEqualTo("ASSOCIATION");
        assertThat(me.path("association_name").asString()).isEqualTo("Refuge de Tunis");
        assertThat(notifier.associations).containsExactly("Refuge de Tunis: APPROVED");
        assertThat(requestAssociation(user, "Another", TUNIS).json().path("detail").path("code").asString())
                .isEqualTo("already_association");
    }

    @Test
    void rejectedUsersCanAskAgain() {
        String user = register("maybe");
        String admin = admin();
        String id = requestAssociation(user, "Unknown group", TUNIS).json().path("id").asString();
        postJson("/admin/association-requests/" + id + "/reject", admin, Map.of());

        assertThat(getJson("/me", user).json().path("role").asString()).isEqualTo("USER");
        assertThat(notifier.associations).containsExactly("Unknown group: REJECTED");
        assertThat(requestAssociation(user, "Known group", TUNIS).status()).isEqualTo(201);
    }

    @Test
    void associationsNearbyHearAboutInjuredAnimals() {
        String admin = admin();
        String near = association("Near", TUNIS, admin);
        association("Far", offset(TUNIS, 40, 0), admin);
        String finder = register("finder");

        String injured = sighting(finder, Map.of("condition", "INJURED", "location", offset(TUNIS, 3, 0)), null)
                .path("id").asString();
        assertThat(notifier.help).containsExactly(injured + ": [" + userId(near) + "]");

        notifier.clear();
        String healthy = sighting(finder, Map.of("location", offset(TUNIS, 3, 0)), null).path("id").asString();
        assertThat(notifier.help).isEmpty();
        patchJson("/sightings/" + healthy, finder, Map.of("condition", "NEEDS_HELP")); // got worse
        assertThat(notifier.help).containsExactly(healthy + ": [" + userId(near) + "]");

        notifier.clear();
        sighting(near, Map.of("condition", "INJURED"), null); // the association's own report
        assertThat(notifier.help).isEmpty();
    }

    @Test
    void strayHelpedByAnAssociationNamesIt() {
        String association = association("Refuge de Tunis", TUNIS, admin());
        String id = stray(register("reporter"), 1).path("id").asString();

        setStray(association, id, "HELPED");
        assertThat(getJson("/sightings/" + id, null).status()).isEqualTo(401);
        assertThat(getJson("/sightings/" + id, register("someone")).json().path("helped_by").asString())
                .isEqualTo("Refuge de Tunis");
    }

    // --- moderation ---

    @Test
    void threeReportsHideASightingUntilAnAdminReviewsIt() {
        String author = register("author");
        String id = sighting(author, Map.of("seen_at", recent(1)), null).path("id").asString();
        String first = register("first");

        assertThat(report(author, "SIGHTING", id).status()).isEqualTo(422); // not your own
        assertThat(report(first, "SIGHTING", id).json().path("hidden").asBoolean()).isFalse();
        assertThat(report(first, "SIGHTING", id).json().path("hidden").asBoolean()).isFalse(); // twice: still one
        assertThat(report(register("second"), "SIGHTING", id).json().path("hidden").asBoolean()).isFalse();
        assertThat(report(register("third"), "SIGHTING", id).json().path("hidden").asBoolean()).isTrue();

        assertThat(getJson("/sightings/" + id, first).status()).isEqualTo(404);
        assertThat(getJson("/sightings/" + id, author).json().path("hidden").asBoolean()).isTrue();
        assertThat(mapIds()).doesNotContain(id);
        assertThat(report(register("fourth"), "SIGHTING", id).status()).isEqualTo(404);

        String admin = admin();
        assertThat(getJson("/admin/hidden", first).status()).isEqualTo(403);
        JsonNode hidden = getJson("/admin/hidden", admin).json();
        assertThat(hidden).hasSize(1);
        assertThat(hidden.get(0).path("target_type").asString()).isEqualTo("SIGHTING");
        assertThat(hidden.get(0).path("reports").asInt()).isEqualTo(3);
        assertThat(hidden.get(0).path("reasons").get(0).asString()).isEqualTo("FAKE");

        assertThat(postJson("/admin/hidden/SIGHTING/" + id + "/restore", admin, Map.of()).status()).isEqualTo(204);
        assertThat(getJson("/sightings/" + id, first).status()).isEqualTo(200);
        assertThat(mapIds()).contains(id);
        assertThat(getJson("/admin/hidden", admin).json()).isEmpty();
        // Its reports were cleared: one new report doesn't hide it again
        assertThat(report(first, "SIGHTING", id).json().path("hidden").asBoolean()).isFalse();
    }

    @Test
    void hiddenLostReportsLeaveTheListAndAdminsCanDeleteThem() {
        String owner = register("owner");
        String id = lostReport(owner, null).path("id").asString();
        for (String name : List.of("a", "b", "c")) {
            report(register(name), "LOST_REPORT", id);
        }
        assertThat(getJson("/lost-reports", register("viewer")).json()).isEmpty();
        assertThat(getJson("/lost-reports/" + id, owner).json().path("hidden").asBoolean()).isTrue();

        String admin = admin();
        assertThat(delete("/admin/hidden/LOST_REPORT/" + id, admin).status()).isEqualTo(204);
        assertThat(getJson("/lost-reports/" + id, owner).status()).isEqualTo(404);
    }

    @Test
    void aReportedMessageDisappearsForItsRecipient() {
        String owner = register("owner");
        String finder = register("finder");
        lostReport(owner);
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        String matchId = getJson("/me/matches", owner).json().get(0).path("id").asString();
        String conversation = postJson("/matches/" + matchId + "/conversation", owner, Map.of()).json()
                .path("id").asString();
        String messageId = postJson("/conversations/" + conversation + "/messages", finder,
                Map.of("body", "Send me money first")).json().path("id").asString();

        assertThat(report(register("stranger"), "MESSAGE", messageId).status()).isEqualTo(404);
        assertThat(report(owner, "MESSAGE", messageId).json().path("hidden").asBoolean()).isTrue();

        assertThat(getJson("/conversations/" + conversation + "/messages", owner).json()).isEmpty();
        assertThat(getJson("/conversations/" + conversation, owner).json().path("unread").asInt()).isZero();
        JsonNode own = getJson("/conversations/" + conversation + "/messages", finder).json();
        assertThat(own.get(0).path("hidden").asBoolean()).isTrue();

        JsonNode hidden = getJson("/admin/hidden", admin()).json();
        assertThat(hidden.get(0).path("text").asString()).isEqualTo("Send me money first");
    }

    @Test
    void reportsAreRateLimited() {
        String reporter = register("busy");
        List<String> authors = List.of(register("author"), register("other-author")); // 20 sightings an hour each
        String author = authors.get(0);
        for (int i = 0; i < 20; i++) {
            String id = sighting(authors.get(i % 2), Map.of("seen_at", recent(1)), null).path("id").asString();
            assertThat(report(reporter, "SIGHTING", id).status()).isEqualTo(201);
        }
        String last = sighting(author, Map.of("seen_at", recent(1)), null).path("id").asString();
        assertThat(report(reporter, "SIGHTING", last).status()).isEqualTo(429);
        assertThat(report(reporter, "SIGHTING", UUID.randomUUID().toString()).status()).isEqualTo(404);
    }
}
