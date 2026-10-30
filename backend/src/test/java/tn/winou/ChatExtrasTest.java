package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Photos and places in the chat, and the owner's map of where their pet was seen. */
class ChatExtrasTest extends ApiTestBase {

    private String owner;
    private String finder;
    private String reportId;
    private String matchId;
    private String conversationId;

    @BeforeEach
    void matchedCase() {
        owner = register("owner");
        finder = register("finder");
        reportId = lostReport(owner).path("id").asString();
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        matchId = getJson("/me/matches", owner).json().get(0).path("id").asString();
        conversationId = postJson("/matches/" + matchId + "/conversation", owner, Map.of()).json().path("id").asString();
    }

    private Response sendPhoto(String token) {
        return uploadRaw("/conversations/" + conversationId + "/photos", token, image(RED, "jpg"), null);
    }

    @Test
    void photoIsSentWithoutExifAndOnlyParticipantsSeeIt() {
        int stored = storage.objects.size();
        Response sent = sendPhoto(finder);

        assertThat(sent.status()).as(sent.text()).isEqualTo(201);
        String url = sent.json().path("photo_url").asString();
        assertThat(url).startsWith("/messages/").endsWith("/photo");
        assertThat(sent.json().path("body").isNull()).isTrue();
        assertThat(storage.objects).hasSize(stored + 1);
        assertThat(notifier.messages).hasSize(1);

        Response seen = getJson(url, owner);
        assertThat(seen.status()).isEqualTo(200);
        assertThat(seen.header("Content-Type")).startsWith("image/jpeg");
        assertThat(seen.bytes()).isNotEmpty();
        assertThat(seen.header("Cache-Control")).contains("private");

        assertThat(getJson(url, register("stranger")).status()).isEqualTo(404);
        assertThat(getJson(url, null).status()).isEqualTo(401);
        assertThat(sendPhoto(register("intruder")).status()).isEqualTo(404);

        JsonNode list = getJson("/conversations/" + conversationId + "/messages", owner).json();
        assertThat(list.get(0).path("photo_url").asString()).isEqualTo(url);
        assertThat(list.get(0).path("mine").asBoolean()).isFalse();
    }

    @Test
    void placeCanBeSentWithOrWithoutWords() {
        Response place = postJson("/conversations/" + conversationId + "/messages", finder,
                Map.of("location", offset(TUNIS, 2, 0)));
        assertThat(place.status()).as(place.text()).isEqualTo(201);
        assertThat(place.json().path("location").path("lat").asDouble()).isGreaterThan(36.8);
        assertThat(place.json().path("body").isNull()).isTrue();

        Response both = postJson("/conversations/" + conversationId + "/messages", finder,
                Map.of("body", "She's sleeping here", "location", TUNIS));
        assertThat(both.json().path("body").asString()).isEqualTo("She's sleeping here");
        assertThat(both.json().path("location").path("lon").asDouble()).isEqualTo(10.1815, org.assertj.core.data.Offset.offset(1e-6));

        // Nothing at all, or a place that isn't one
        assertThat(postJson("/conversations/" + conversationId + "/messages", finder, Map.of()).status()).isEqualTo(422);
        assertThat(postJson("/conversations/" + conversationId + "/messages", finder,
                Map.of("location", Map.of("lat", 120, "lon", 10))).status()).isEqualTo(422);
    }

    @Test
    void deletingTheReportRemovesChatPhotoFiles() {
        String url = sendPhoto(finder).json().path("photo_url").asString();
        String key = "chat/" + url.split("/")[2] + ".jpg";
        assertThat(storage.objects).containsKey(key);

        assertThat(delete("/lost-reports/" + reportId, owner).status()).isEqualTo(204);

        assertThat(storage.objects).doesNotContainKey(key);
    }

    @Test
    void trailShowsWhereThePetWasSeenToTheOwnerOnly() {
        String later = sighting(finder, Map.of("location", offset(TUNIS, 3, 0), "seen_at", "2026-10-26T09:00:00+01:00"),
                NEAR_RED).path("id").asString();
        work();

        JsonNode trail = getJson("/lost-reports/" + reportId + "/trail", owner).json();
        assertThat(trail).hasSize(2);
        assertThat(trail.get(0).path("match_id").asString()).isEqualTo(matchId);
        assertThat(trail.get(0).path("photo_url").asString()).startsWith("/photos/");
        assertThat(trail.get(0).path("location").path("lat").asDouble()).isGreaterThan(36.8);
        assertThat(trail.get(1).path("sighting_id").asString()).isEqualTo(later);

        // A rejected match drops off the map
        patchJson("/matches/" + matchId, owner, Map.of("status", "REJECTED"));
        assertThat(getJson("/lost-reports/" + reportId + "/trail", owner).json()).hasSize(1);

        assertThat(getJson("/lost-reports/" + reportId + "/trail", finder).status()).isEqualTo(403);
    }
}
