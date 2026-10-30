package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import tools.jackson.databind.JsonNode;

/** Admin tools: finding users, banning them, taking back association status, and the admin log. */
class AdminUsersTest extends ApiTestBase {

    private static final String BBOX = "10.05,36.75,10.30,36.90";

    private String admin() {
        return postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
    }

    private String userId(String token) {
        return getJson("/me", token).json().path("id").asString();
    }

    private Response ban(String admin, String userId, Integer days, String reason) {
        Map<String, Object> body = new HashMap<>();
        body.put("days", days);
        body.put("reason", reason);
        return postJson("/admin/users/" + userId + "/ban", admin, body);
    }

    private List<String> ids(JsonNode array) {
        List<String> ids = new ArrayList<>();
        array.forEach(item -> ids.add(item.path("id").asString()));
        return ids;
    }

    private List<String> mapIds() {
        return ids(getJson("/map", null, Map.of("bbox", BBOX)).json().path("items"));
    }

    private List<String> lostIds(String token) {
        return ids(getJson("/lost-reports", token).json());
    }

    @Test
    void onlyAdminsManageUsers() {
        String user = register("user");
        String id = userId(user);
        assertThat(getJson("/admin/users", user).status()).isEqualTo(403);
        assertThat(getJson("/admin/users/" + id, user).status()).isEqualTo(403);
        assertThat(ban(user, id, 7, null).status()).isEqualTo(403);
        assertThat(postJson("/admin/users/" + id + "/unban", user, Map.of()).status()).isEqualTo(403);
        assertThat(delete("/admin/users/" + id + "/association", user).status()).isEqualTo(403);
    }

    @Test
    void adminsFindUsersByNameOrEmail() {
        String admin = admin();
        String alice = register("alice");
        register("bob");
        lostReport(alice, null);

        JsonNode found = getJson("/admin/users", admin, Map.of("q", "ALI")).json();
        assertThat(found).hasSize(1);
        assertThat(found.get(0).path("display_name").asString()).isEqualTo("alice");
        assertThat(found.get(0).path("lost_reports").asLong()).isEqualTo(1);
        assertThat(found.get(0).path("banned_until").isNull()).isTrue();
        assertThat(getJson("/admin/users", admin).json()).hasSize(3); // with the admin
        assertThat(getJson("/admin/users", admin, Map.of("q", "%")).json()).isEmpty(); // not a wildcard
    }

    @Test
    void aBanLocksTheUserOutAndHidesWhatTheyPosted() {
        String admin = admin();
        String spammer = register("spammer");
        String neighbour = register("neighbour");
        String spammerId = userId(spammer);
        String report = lostReport(spammer, null).path("id").asString();
        String sighting = sighting(spammer, null).path("id").asString();
        assertThat(lostIds(neighbour)).contains(report);
        assertThat(mapIds()).contains(report, sighting);

        JsonNode banned = ban(admin, spammerId, 7, "Fake posts").json();
        assertThat(banned.path("banned_until").isNull()).isFalse();
        assertThat(banned.path("ban_reason").asString()).isEqualTo("Fake posts");

        // Locked out, with the token they already had, and when signing in again
        Response me = getJson("/me", spammer);
        assertThat(me.status()).isEqualTo(403);
        assertThat(me.json().path("detail").path("code").asString()).isEqualTo("banned");
        assertThat(me.json().path("detail").path("reason").asString()).isEqualTo("Fake posts");
        String email = getJson("/admin/users/" + spammerId, admin).json().path("user").path("email").asString();
        Response login = call(post("/auth/login").contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", email).param("password", "password123"));
        assertThat(login.status()).isEqualTo(403);
        assertThat(login.json().path("detail").path("code").asString()).isEqualTo("banned");

        // Their content is gone for others, still there for admins
        assertThat(lostIds(neighbour)).doesNotContain(report);
        assertThat(mapIds()).doesNotContain(report, sighting);
        assertThat(getJson("/lost-reports/" + report, neighbour).status()).isEqualTo(404);
        assertThat(getJson("/sightings/" + sighting, neighbour).status()).isEqualTo(404);
        assertThat(getJson("/lost-reports/" + report, admin).status()).isEqualTo(200);
        JsonNode detail = getJson("/admin/users/" + spammerId, admin).json();
        assertThat(ids(detail.path("lost_reports"))).containsExactly(report);
        assertThat(ids(detail.path("sightings"))).containsExactly(sighting);
        assertThat(ids(getJson("/admin/users", admin, Map.of("banned", true)).json())).containsExactly(spammerId);

        assertThat(postJson("/admin/users/" + spammerId + "/unban", admin, Map.of()).status()).isEqualTo(200);
        assertThat(getJson("/me", spammer).status()).isEqualTo(200);
        assertThat(lostIds(neighbour)).contains(report);
        assertThat(mapIds()).contains(report, sighting);
        assertThat(postJson("/admin/users/" + spammerId + "/unban", admin, Map.of()).status()).isEqualTo(409);

        List<String> history = new ArrayList<>();
        getJson("/admin/users/" + spammerId, admin).json().path("history")
                .forEach(a -> history.add(a.path("action").asString() + " " + a.path("note").asString()));
        assertThat(history).containsExactly("UNBAN_USER ", "BAN_USER 7 days: Fake posts");
    }

    @Test
    void bansEndOnTheirOwn() {
        String admin = admin();
        String user = register("user");
        String id = userId(user);
        ban(admin, id, 1, null);
        assertThat(getJson("/me", user).status()).isEqualTo(403);
        jdbc.sql("UPDATE users SET banned_until = now() - interval '1 minute' WHERE id = :id::uuid")
                .param("id", id).update();
        assertThat(getJson("/me", user).status()).isEqualTo(200);
        assertThat(getJson("/admin/users/" + id, admin).json().path("user").path("banned_until").isNull()).isTrue();
    }

    @Test
    void aBanWithoutDaysIsForGood() {
        String admin = admin();
        String id = userId(register("user"));
        JsonNode banned = ban(admin, id, null, " ").json();
        assertThat(banned.path("banned_until").asString()).startsWith("9999-12-31");
        assertThat(banned.path("ban_reason").isNull()).isTrue();
        assertThat(ban(admin, id, 0, null).status()).isEqualTo(422);
    }

    @Test
    void adminsCantBeBanned() {
        String admin = admin();
        assertThat(ban(admin, userId(admin), 7, null).status()).isEqualTo(422);
        assertThat(getJson("/me", admin).status()).isEqualTo(200);
    }

    @Test
    void adminsCanTakeBackAssociationStatus() {
        String admin = admin();
        String refuge = register("refuge");
        String id = userId(refuge);
        Map<String, Object> body = Map.of("organisation", "Refuge", "city", "Tunis", "contact", "+216 20 000 000",
                "location", TUNIS);
        String request = postJson("/me/association-request", refuge, body).json().path("id").asString();
        postJson("/admin/association-requests/" + request + "/approve", admin, Map.of());
        assertThat(getJson("/me", refuge).json().path("role").asString()).isEqualTo("ASSOCIATION");

        JsonNode revoked = delete("/admin/users/" + id + "/association", admin).json();
        assertThat(revoked.path("role").asString()).isEqualTo("USER");
        assertThat(revoked.path("association_name").isNull()).isTrue();
        assertThat(delete("/admin/users/" + id + "/association", admin).status()).isEqualTo(409);
        // They can apply again
        assertThat(postJson("/me/association-request", refuge, body).status()).isEqualTo(201);

        List<String> history = new ArrayList<>();
        getJson("/admin/users/" + id, admin).json().path("history")
                .forEach(a -> history.add(a.path("action").asString() + " " + a.path("admin_name").asString()));
        assertThat(history).containsExactly("REVOKE_ASSOCIATION Admin", "APPROVE_ASSOCIATION Admin");
    }

    @Test
    void deletingReportedContentIsLoggedAgainstItsAuthor() {
        String admin = admin();
        String author = register("author");
        String report = lostReport(author, null).path("id").asString();
        for (String reporter : List.of(register("a"), register("b"), register("c"))) {
            postJson("/reports", reporter, Map.of("target_type", "LOST_REPORT", "target_id", report, "reason", "SPAM"));
        }
        assertThat(delete("/admin/hidden/LOST_REPORT/" + report, admin).status()).isEqualTo(204);

        JsonNode history = getJson("/admin/users/" + userId(author), admin).json().path("history");
        assertThat(history).hasSize(1);
        assertThat(history.get(0).path("action").asString()).isEqualTo("DELETE_CONTENT");
        assertThat(history.get(0).path("target_type").asString()).isEqualTo("LOST_REPORT");
        assertThat(history.get(0).path("target_id").asString()).isEqualTo(report);
    }
}
