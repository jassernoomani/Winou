package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import tools.jackson.databind.JsonNode;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.UserRepository;
import tn.winou.infra.PushNotifier;
import tn.winou.infra.PushSender;

/** Who gets the push and what happens to dead device tokens. Firebase itself is faked. */
class PushNotifierTest extends ApiTestBase {

    @Autowired LostReportRepository reports;
    @Autowired UserRepository users;
    @Autowired MatchRepository matchRows;

    static class FakeSender implements PushSender {

        record Sent(String token, MatchPush push) {}

        final List<Sent> sent = new ArrayList<>();
        Result result = Result.SENT;

        @Override
        public Result send(String deviceToken, MatchPush push) {
            sent.add(new Sent(deviceToken, push));
            return result;
        }
    }

    private final FakeSender sender = new FakeSender();

    private PushNotifier notifier() {
        return new PushNotifier(sender, reports, users);
    }

    /** The owner's report matched by another user's sighting. */
    private Match match(String owner) {
        String finder = register("finder");
        lostReport(owner);
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        JsonNode match = getJson("/me/matches", owner).json().get(0);
        return matchRows.findById(UUID.fromString(match.path("id").asString())).orElseThrow();
    }

    private String ownerToken() {
        return jdbc.sql("SELECT fcm_token FROM users WHERE display_name = 'owner'").query(String.class).optional()
                .orElse(null);
    }

    @Test
    void pushesToTheOwnersPhone() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "owner-phone"));
        Match match = match(owner);

        notifier().matchFound(match);

        assertThat(sender.sent).hasSize(1);
        FakeSender.Sent sent = sender.sent.getFirst();
        assertThat(sent.token()).isEqualTo("owner-phone");
        assertThat(sent.push().matchId()).isEqualTo(match.getId().toString());
        assertThat(sent.push().lostReportId()).isEqualTo(match.getLostReportId().toString());
        assertThat(sent.push().petName()).isEqualTo("Mimi");
        assertThat(ownerToken()).isEqualTo("owner-phone");
    }

    @Test
    void skipsOwnersWithoutAPhone() {
        Match match = match(register("owner"));
        notifier().matchFound(match);
        assertThat(sender.sent).isEmpty();
    }

    @Test
    void forgetsADeadToken() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "uninstalled"));
        Match match = match(owner);
        sender.result = PushSender.Result.TOKEN_GONE;

        notifier().matchFound(match);

        assertThat(ownerToken()).isNull();
    }

    @Test
    void aFailedPushKeepsTheToken() {
        String owner = register("owner");
        patchJson("/me", owner, Map.of("fcm_token", "owner-phone"));
        Match match = match(owner);
        sender.result = PushSender.Result.FAILED;

        notifier().matchFound(match);

        assertThat(ownerToken()).isEqualTo("owner-phone");
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
