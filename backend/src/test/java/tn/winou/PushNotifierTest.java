package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import tools.jackson.databind.JsonNode;
import tn.winou.domain.ChatMessageRepository;
import tn.winou.domain.ConversationRepository;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.UserRepository;
import tn.winou.infra.PushNotifier;
import tn.winou.infra.PushSender;

/** Who gets each push, what it says and what happens to dead device tokens. Firebase itself is faked. */
class PushNotifierTest extends ApiTestBase {

    @Autowired LostReportRepository reports;
    @Autowired SightingRepository sightings;
    @Autowired UserRepository users;
    @Autowired MatchRepository matchRows;
    @Autowired ConversationRepository conversations;
    @Autowired ChatMessageRepository messageRows;

    static class FakeSender implements PushSender {

        record Sent(String token, Push push) {}

        final List<Sent> sent = new ArrayList<>();
        Result result = Result.SENT;

        @Override
        public Result send(String deviceToken, Push push) {
            sent.add(new Sent(deviceToken, push));
            return result;
        }
    }

    private final FakeSender sender = new FakeSender();

    private PushNotifier notifier() {
        return new PushNotifier(sender, reports, sightings, users);
    }

    /** The owner's report "Mimi" matched by the finder's sighting. */
    private Match match(String owner, String finder) {
        lostReport(owner);
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        JsonNode match = getJson("/me/matches", owner).json().get(0);
        return matchRows.findById(UUID.fromString(match.path("id").asString())).orElseThrow();
    }

    private String tokenOf(String name) {
        return jdbc.sql("SELECT fcm_token FROM users WHERE display_name = :name").param("name", name)
                .query(String.class).optional().orElse(null);
    }

    @Test
    void matchGoesToTheOwnersPhone() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "owner-phone"));
        Match match = match(owner, register("finder"));

        notifier().matchFound(match);

        assertThat(sender.sent).hasSize(1);
        FakeSender.Sent sent = sender.sent.getFirst();
        assertThat(sent.token()).isEqualTo("owner-phone");
        assertThat(sent.push().titleKey()).isEqualTo("match_title");
        assertThat(sent.push().bodyArgs()).containsExactly("Mimi");
        assertThat(sent.push().data()).containsEntry("type", "match")
                .containsEntry("match_id", match.getId().toString())
                .containsEntry("lost_report_id", match.getLostReportId().toString());
    }

    @Test
    void confirmationAndThanksGoToTheFinder() {
        String owner = register("owner");
        String finder = register("finder");
        patchJson("/me", finder, Map.of("fcm_token", "finder-phone"));
        Match match = match(owner, finder);

        notifier().matchConfirmed(match);
        notifier().petFound(reports.findById(match.getLostReportId()).orElseThrow(),
                List.of(sightings.findById(match.getSightingId()).orElseThrow().getReporterId()));

        assertThat(sender.sent).extracting(FakeSender.Sent::token).containsExactly("finder-phone", "finder-phone");
        assertThat(sender.sent).extracting(s -> s.push().titleKey()).containsExactly("confirmed_title", "found_title");
        assertThat(sender.sent.get(1).push().titleArgs()).containsExactly("Mimi");
    }

    @Test
    void messageGoesToTheOtherParticipant() {
        String owner = register("owner");
        String finder = register("finder");
        patchJson("/me", owner, Map.of("fcm_token", "owner-phone"));
        patchJson("/me", finder, Map.of("fcm_token", "finder-phone"));
        Match match = match(owner, finder);
        String conversationId = postJson("/matches/" + match.getId() + "/conversation", owner, Map.of())
                .json().path("id").asString();
        postJson("/conversations/" + conversationId + "/messages", finder, Map.of("body", "I saw it near the souk"));

        var conversation = conversations.findById(UUID.fromString(conversationId)).orElseThrow();
        notifier().newMessage(conversation, messageRows.findAll().getFirst());

        FakeSender.Sent sent = sender.sent.getFirst();
        assertThat(sent.token()).isEqualTo("owner-phone");
        assertThat(sent.push().titleArgs()).containsExactly("finder", "Mimi");
        assertThat(sent.push().body()).isEqualTo("I saw it near the souk");
        assertThat(sent.push().data()).containsEntry("type", "message").containsEntry("conversation_id", conversationId);
    }

    @Test
    void skipsUsersWithoutAPhone() {
        Match match = match(register("owner"), register("finder"));
        notifier().matchFound(match);
        assertThat(sender.sent).isEmpty();
    }

    @Test
    void forgetsADeadToken() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "uninstalled"));
        Match match = match(owner, register("finder"));
        sender.result = PushSender.Result.TOKEN_GONE;

        notifier().matchFound(match);

        assertThat(tokenOf("owner")).isNull();
    }

    @Test
    void aFailedPushKeepsTheToken() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "owner-phone"));
        Match match = match(owner, register("finder"));
        sender.result = PushSender.Result.FAILED;

        notifier().matchFound(match);

        assertThat(tokenOf("owner")).isEqualTo("owner-phone");
    }

    @Test
    void aPhoneBelongsToTheLastAccountSignedInOnIt() {
        String first = register("first");
        String second = register("second");
        patchJson("/me", first, Map.of("fcm_token", "shared-phone"));
        patchJson("/me", second, Map.of("fcm_token", "shared-phone"));

        assertThat(jdbc.sql("SELECT display_name FROM users WHERE fcm_token = 'shared-phone'")
                .query(String.class).list()).containsExactly("second");
    }
}
