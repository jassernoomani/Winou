package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import tn.winou.reports.StillMissingReminders;
import tools.jackson.databind.JsonNode;

/** Searching and sorting the lost pets list, and "is your pet still missing?" reminders. */
class SearchAndRemindersTest extends ApiTestBase {

    @Autowired StillMissingReminders reminders;

    private String report(String token, String name, String description, Map<String, Object> place, Integer reward) {
        Map<String, Object> body = new java.util.HashMap<>(Map.of("name", name, "species", "cat", "last_seen", place,
                "last_seen_at", "2026-10-20T10:00:00+01:00", "description", description));
        if (reward != null) {
            body.put("reward_tnd", reward);
        }
        Response created = postJson("/lost-reports", token, body);
        assertThat(created.status()).as(created.text()).isEqualTo(201);
        return created.json().path("id").asString();
    }

    private List<String> names(Map<String, ?> params) {
        Response response = getJson("/lost-reports", register("viewer" + params.hashCode()), params);
        assertThat(response.status()).as(response.text()).isEqualTo(200);
        List<String> names = new ArrayList<>();
        for (JsonNode r : response.json()) {
            names.add(r.path("name").asString());
        }
        return names;
    }

    @Test
    void searchesNameAndDescriptionIgnoringCase() {
        String owner = register("owner");
        report(owner, "Luna", "Grey tabby with a RED collar", TUNIS, null);
        report(owner, "Rex", "Sandy terrier", offset(TUNIS, 1, 0), null);
        report(owner, "Mimi 100%", "White cat", offset(TUNIS, 2, 0), null);

        assertThat(names(Map.of("q", "red collar"))).containsExactly("Luna");
        assertThat(names(Map.of("q", "REX"))).containsExactly("Rex");
        assertThat(names(Map.of("q", "100%"))).containsExactly("Mimi 100%"); // % is a character, not a wildcard
        assertThat(names(Map.of("q", "_"))).isEmpty();
        assertThat(names(Map.of("q", "  "))).hasSize(3);
    }

    @Test
    void sortsByDistanceOrReward() {
        String owner = register("owner");
        report(owner, "Far", "", offset(TUNIS, 8, 0), 50);
        report(owner, "Near", "", offset(TUNIS, 1, 0), null);
        report(owner, "Middle", "", offset(TUNIS, 4, 0), 300);

        Map<String, Object> near = Map.of("lat", TUNIS.get("lat"), "lon", TUNIS.get("lon"), "sort", "nearest");
        assertThat(names(near)).containsExactly("Near", "Middle", "Far");
        assertThat(names(Map.of("sort", "reward"))).containsExactly("Middle", "Far", "Near");

        assertThat(getJson("/lost-reports", owner, Map.of("sort", "nearest")).status()).isEqualTo(422); // where from?
        assertThat(getJson("/lost-reports", owner, Map.of("sort", "cheapest")).status()).isEqualTo(422);
    }

    @Test
    void asksTheOwnerAtTwoWeeksThenAtFourWeeks() {
        String owner = register("owner");
        String id = report(owner, "Luna", "", TUNIS, null);
        String closed = report(owner, "Rex", "", TUNIS, null);
        patchJson("/lost-reports/" + closed, owner, Map.of("status", "FOUND"));
        assertThat(reminders.sendDue()).isZero(); // too early

        age(id, 15);
        age(closed, 15);
        assertThat(reminders.sendDue()).isEqualTo(1);
        assertThat(reminders.sendDue()).isZero(); // not twice
        assertThat(notifier.stillMissing).containsExactly("Luna");

        age(id, 29);
        assertThat(reminders.sendDue()).isEqualTo(1);
        age(id, 60);
        assertThat(reminders.sendDue()).isZero(); // two at most
        assertThat(notifier.stillMissing).containsExactly("Luna", "Luna");
    }

    @Test
    void anOldReportGetsOneReminderNotTwo() {
        String id = report(register("owner"), "Luna", "", TUNIS, null);
        age(id, 40);

        assertThat(reminders.sendDue()).isEqualTo(1);
        assertThat(reminders.sendDue()).isZero();
    }

    private void age(String reportId, int days) {
        jdbc.sql("UPDATE lost_reports SET created_at = now() - make_interval(days => :days) WHERE id = :id::uuid")
                .param("days", days).param("id", reportId).update();
    }
}
