package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import tools.jackson.databind.JsonNode;
import tn.winou.domain.AssociationRequest;
import tn.winou.domain.ChatMessageRepository;
import tn.winou.domain.RequestStatus;
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
    @Autowired tn.winou.infra.Inbox inbox;

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
        return new PushNotifier(sender, reports, sightings, users, inbox);
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
    void skipsUsersWithoutAPhoneButKeepsItInTheirList() {
        String owner = register("owner");
        Match match = match(owner, register("finder"));
        notifier().matchFound(match);
        assertThat(sender.sent).isEmpty();

        JsonNode inbox = getJson("/me/notifications", owner).json();
        assertThat(inbox.path("unread").asLong()).isEqualTo(1);
        JsonNode item = inbox.path("items").get(0);
        assertThat(item.path("title_key").asString()).isEqualTo("match_title");
        assertThat(item.path("body_args").get(0).asString()).isEqualTo("Mimi");
        assertThat(item.path("data").path("match_id").asString()).isEqualTo(match.getId().toString());
        assertThat(item.path("read").asBoolean()).isFalse();

        assertThat(postJson("/me/notifications/read", owner, Map.of()).status()).isEqualTo(204);
        assertThat(getJson("/me/notifications", owner).json().path("unread").asLong()).isZero();
        assertThat(getJson("/me/notifications", owner).json().path("items").get(0).path("read").asBoolean()).isTrue();
    }

    @Test
    void theListKeepsTheLatestHundred() {
        String owner = register("owner");
        Match match = match(owner, register("finder"));
        for (int i = 0; i < 105; i++) {
            notifier().matchFound(match);
        }
        assertThat(jdbc.sql("SELECT count(*) FROM notifications").query(Long.class).single()).isEqualTo(100);
        assertThat(getJson("/me/notifications", owner, Map.of("limit", 30)).json().path("items")).hasSize(30);
        assertThat(getJson("/me/notifications", register("other")).json().path("items")).isEmpty();
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

    @Test
    void hiddenContentAndAssociationRequestsGoToEveryAdminsPhone() {
        String admin = postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
        patchJson("/me", admin, Map.of("fcm_token", "admin-phone"));
        patchJson("/me", register("user"), Map.of("fcm_token", "user-phone"));
        UUID id = UUID.randomUUID();

        notifier().contentHidden(tn.winou.web.ApiModels.ReportTarget.SIGHTING, id);
        AssociationRequest request = new AssociationRequest();
        request.setOrganisation("Refuge de Tunis");
        notifier().associationRequested(request);

        assertThat(sender.sent).extracting(FakeSender.Sent::token).containsExactly("admin-phone", "admin-phone");
        assertThat(sender.sent.getFirst().push().bodyKey()).isEqualTo("admin_hidden_sighting_body");
        assertThat(sender.sent.getFirst().push().tag()).isEqualTo("admin-hidden-" + id);
        assertThat(sender.sent.getFirst().push().data()).containsEntry("type", "admin").containsEntry("tab", "hidden");
        assertThat(sender.sent.get(1).push().bodyArgs()).containsExactly("Refuge de Tunis");
        assertThat(sender.sent.get(1).push().data()).containsEntry("tab", "requests");
    }

    @Test
    void injuredAnimalsAndAssociationDecisionsArePushed() throws Exception {
        String association = register("association");
        patchJson("/me", association, Map.of("fcm_token", "association-phone"));
        UUID associationId = UUID.fromString(getJson("/me", association).json().path("id").asString());
        String sightingId = sighting(register("finder"), Map.of("condition", "INJURED"), null).path("id").asString();

        notifier().animalNeedsHelp(sightings.findById(UUID.fromString(sightingId)).orElseThrow(), List.of(associationId));
        AssociationRequest request = new AssociationRequest();
        request.setUserId(associationId);
        request.setOrganisation("Refuge de Tunis");
        request.setStatus(RequestStatus.APPROVED);
        notifier().associationDecided(request);

        assertThat(sender.sent).extracting(sent -> sent.push().bodyKey())
                .containsExactly("help_injured_body", "association_approved_body");
        assertThat(sender.sent.getFirst().push().data()).containsEntry("type", "help")
                .containsEntry("sighting_id", sightingId);
        assertThat(sender.sent.get(1).push().bodyArgs()).containsExactly("Refuge de Tunis");

        // Every key the backend sends exists in the app, in both languages
        for (String values : List.of("values", "values-fr", "values-ar")) {
            String strings = Files.readString(Path.of("../mobile/android/app/src/main/res/" + values + "/strings.xml"));
            for (String key : List.of("help_title", "help_injured_body", "help_needs_help_body",
                    "association_approved_title", "association_approved_body", "association_rejected_title",
                    "association_rejected_body", "admin_hidden_title", "admin_hidden_lost_body",
                    "admin_hidden_sighting_body", "admin_hidden_message_body", "admin_request_title",
                    "admin_request_body", "nearby_lost_title", "nearby_lost_cat_body", "nearby_lost_dog_body",
                    "nearby_lost_pet_body")) {
                assertThat(strings).as(values + ": " + key).contains("name=\"" + key + "\"");
            }
        }
    }
}
