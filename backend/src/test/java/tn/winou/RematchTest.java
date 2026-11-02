package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * A photo added later to an open report is compared with every sighting since the pet went
 * missing, not only with the ones posted after the photo.
 */
class RematchTest extends ApiTestBase {

    @Test
    void aBetterPhotoAddedLaterFindsAnOlderSighting() {
        String owner = register("owner");
        String finder = register("finder");
        JsonNode report = lostReport(owner, BLUE); // a poor photo: looks nothing like the sighting
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        assertThat(getJson("/me/matches", owner).json()).isEmpty();

        upload(owner, "/lost-reports/" + report.path("id").asString() + "/photos", RED); // a better one, days later
        work();

        JsonNode matches = getJson("/me/matches", owner).json();
        assertThat(matches).hasSize(1);
        assertThat(matches.get(0).path("lost_report_id").asString()).isEqualTo(report.path("id").asString());
        assertThat(notifier.matches).hasSize(1);
    }

    @Test
    void notWithSightingsFromBeforeThePetWentMissing() {
        String finder = register("finder");
        // Seen long before the pet was lost (beyond the grace days): someone else's animal
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0), "seen_at", "2026-09-01T10:00:00+01:00"), RED);
        String owner = register("owner");
        lostReport(owner, RED);
        work();
        assertThat(getJson("/me/matches", owner).json()).isEmpty();
    }
}
