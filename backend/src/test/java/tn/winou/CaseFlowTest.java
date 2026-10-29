package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Phase 4: "that's my pet", "I got my pet back", and owner <-> finder messages. */
class CaseFlowTest extends ApiTestBase {

    private String owner;
    private String finder;
    private String reportId;
    private String matchId;

    @BeforeEach
    void matchedCase() {
        owner = register("owner");
        finder = register("finder");
        reportId = lostReport(owner).path("id").asString();
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        matchId = matches().get(0).path("id").asString();
    }

    private JsonNode matches() {
        return getJson("/me/matches", owner).json();
    }

    private Response setMatch(String token, String status) {
        return patchJson("/matches/" + matchId, token, Map.of("status", status));
    }

    private void setReport(String status) {
        assertThat(patchJson("/lost-reports/" + reportId, owner, Map.of("status", status)).status()).isEqualTo(200);
    }

    private String startConversation() {
        Response started = postJson("/matches/" + matchId + "/conversation", owner, Map.of());
        assertThat(started.status()).isEqualTo(200);
        return started.json().path("id").asString();
    }

    // --- confirm / reject ---

    @Test
    void confirmingTellsTheFinderButKeepsTheCaseOpen() {
        JsonNode match = setMatch(owner, "CONFIRMED").json();

        assertThat(match.path("status").asString()).isEqualTo("CONFIRMED");
        assertThat(match.path("report_status").asString()).isEqualTo("OPEN");
        assertThat(notifier.confirmed).containsExactly(matchId);
        assertThat(getJson("/lost-reports/" + reportId, owner).json().path("status").asString()).isEqualTo("OPEN");

        setMatch(owner, "CONFIRMED"); // again: no second notification
        assertThat(notifier.confirmed).hasSize(1);
    }

    @Test
    void onlyTheOwnerDecides() {
        assertThat(setMatch(finder, "CONFIRMED").status()).isEqualTo(403);
        assertThat(setMatch(owner, "SURE").status()).isEqualTo(422);
        assertThat(patchJson("/matches/" + java.util.UUID.randomUUID(), owner, Map.of("status", "CONFIRMED")).status())
                .isEqualTo(404);
    }

    @Test
    void rejectedMatchesAreHiddenAndNotSuggestedAgain() {
        setMatch(owner, "REJECTED");
        assertThat(matches()).isEmpty();

        // The same sighting gets another photo: still not suggested
        String sightingId = getJson("/me/sightings", finder).json().get(0).path("id").asString();
        upload(finder, "/sightings/" + sightingId + "/photos", RED);
        work();
        assertThat(matches()).isEmpty();
        assertThat(notifier.matches).hasSize(1); // only the first time

        setMatch(owner, "PENDING"); // undo
        assertThat(matches()).hasSize(1);
    }

    // --- closing the case ---

    @Test
    void gettingThePetBackThanksConfirmedFindersOnly() {
        String otherFinder = register("other");
        sighting(otherFinder, Map.of("location", offset(TUNIS, 2, 0)), NEAR_RED);
        work();
        assertThat(matches()).hasSize(2);
        setMatch(owner, "CONFIRMED");

        setReport("FOUND");

        assertThat(notifier.found).hasSize(1);
        assertThat(notifier.found.getFirst()).startsWith("Mimi: [");
        String finderId = jdbc.sql("SELECT id FROM users WHERE display_name = 'finder'").query(String.class).single();
        assertThat(notifier.found.getFirst()).contains(finderId);
        // Closed case: only the confirmed match is still listed
        JsonNode left = matches();
        assertThat(left).hasSize(1);
        assertThat(left.get(0).path("id").asString()).isEqualTo(matchId);
        assertThat(left.get(0).path("report_status").asString()).isEqualTo("FOUND");

        setReport("FOUND"); // again: no second thanks
        assertThat(notifier.found).hasSize(1);

        setReport("OPEN"); // reopened: the pending match is back
        assertThat(matches()).hasSize(2);
    }

    @Test
    void foundWithoutConfirmedMatchThanksNobody() {
        setReport("FOUND");
        assertThat(notifier.found).isEmpty();
        assertThat(matches()).isEmpty();
    }

    // --- messages ---

    @Test
    void ownerAndFinderTalk() {
        String id = startConversation();
        assertThat(startConversation()).isEqualTo(id); // same conversation the second time
        assertThat(matches().get(0).path("conversation_id").asString()).isEqualTo(id);

        assertThat(postJson("/conversations/" + id + "/messages", owner, Map.of("body", "  Is she wearing a red collar?  "))
                .status()).isEqualTo(201);
        assertThat(notifier.messages).containsExactly(id + ": Is she wearing a red collar?");

        JsonNode finderView = getJson("/conversations", finder).json();
        assertThat(finderView).hasSize(1);
        JsonNode conversation = finderView.get(0);
        assertThat(conversation.path("my_role").asString()).isEqualTo("finder");
        assertThat(conversation.path("other_name").asString()).isEqualTo("owner");
        assertThat(conversation.path("pet_name").asString()).isEqualTo("Mimi");
        assertThat(conversation.path("unread").asLong()).isEqualTo(1);
        assertThat(conversation.path("last_message").path("mine").asBoolean()).isFalse();
        assertThat(conversation.toString()).doesNotContain("@example.com"); // no emails between users

        JsonNode read = getJson("/conversations/" + id + "/messages", finder).json();
        assertThat(read).hasSize(1);
        assertThat(read.get(0).path("body").asString()).isEqualTo("Is she wearing a red collar?");
        assertThat(getJson("/conversations/" + id, finder).json().path("unread").asLong()).isZero();

        postJson("/conversations/" + id + "/messages", finder, Map.of("body", "Yes, a red one"));
        JsonNode both = getJson("/conversations/" + id + "/messages", owner).json();
        assertThat(both).extracting(m -> m.path("body").asString())
                .containsExactly("Is she wearing a red collar?", "Yes, a red one"); // oldest first
        assertThat(both.get(1).path("mine").asBoolean()).isFalse();

        // Scrolling back
        String newest = both.get(1).path("created_at").asString();
        JsonNode older = getJson("/conversations/" + id + "/messages", owner, Map.of("before", newest)).json();
        assertThat(older).hasSize(1);
    }

    @Test
    void onlyTheOwnerStartsAndStrangersSeeNothing() {
        assertThat(postJson("/matches/" + matchId + "/conversation", finder, Map.of()).status()).isEqualTo(403);
        String id = startConversation();

        String stranger = register("stranger");
        assertThat(getJson("/conversations/" + id, stranger).status()).isEqualTo(404);
        assertThat(getJson("/conversations/" + id + "/messages", stranger).status()).isEqualTo(404);
        assertThat(postJson("/conversations/" + id + "/messages", stranger, Map.of("body", "hi")).status())
                .isEqualTo(404);
        assertThat(getJson("/conversations", stranger).json()).isEmpty();
        assertThat(getJson("/conversations", null).status()).isEqualTo(401);
    }

    @Test
    void emptyMessagesAreRejected() {
        String id = startConversation();
        assertThat(postJson("/conversations/" + id + "/messages", owner, Map.of("body", "   ")).status())
                .isEqualTo(422);
        assertThat(postJson("/conversations/" + id + "/messages", owner, Map.of("body", "x".repeat(2001))).status())
                .isEqualTo(422);
    }

    @Test
    void theConversationOutlivesTheSighting() {
        String id = startConversation();
        postJson("/conversations/" + id + "/messages", owner, Map.of("body", "Thanks!"));
        String sightingId = getJson("/me/sightings", finder).json().get(0).path("id").asString();
        delete("/sightings/" + sightingId, finder);

        JsonNode conversation = getJson("/conversations/" + id, owner).json();
        assertThat(conversation.path("match_id").isNull()).isTrue();
        assertThat(getJson("/conversations/" + id + "/messages", finder).json()).hasSize(1);
    }
}
