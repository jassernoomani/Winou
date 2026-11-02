package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** The owner's private detail, and warnings on messages that ask for money. */
class TrustTest extends ApiTestBase {

    private static final String DETAIL = "A small white star under her chin";

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
        assertThat(patchJson("/lost-reports/" + reportId, owner, Map.of("private_detail", DETAIL)).status())
                .isEqualTo(200);
        sighting(finder, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        work();
        matchId = getJson("/me/matches", owner).json().get(0).path("id").asString();
        conversationId = postJson("/matches/" + matchId + "/conversation", owner, Map.of()).json().path("id").asString();
    }

    private JsonNode conversation(String token) {
        return getJson("/conversations/" + conversationId, token).json();
    }

    @Test
    void privateDetailIsTheOwnersOnly() {
        assertThat(getJson("/lost-reports/" + reportId, owner).json().path("private_detail").asString())
                .isEqualTo(DETAIL);
        assertThat(getJson("/lost-reports/" + reportId, finder).json().path("private_detail").isNull()).isTrue();
        JsonNode list = getJson("/lost-reports", register("neighbour")).json();
        assertThat(list.toString()).as(list.toString()).contains(reportId).doesNotContain(DETAIL);
        assertThat(getJson("/lost-reports/" + reportId, null).status()).isEqualTo(401);
        Response sharePage = getJson("/lost/" + reportId, null); // the public page a shared link opens
        assertThat(sharePage.status()).isEqualTo(200);
        assertThat(sharePage.text()).contains("Mimi").doesNotContain(DETAIL);
    }

    @Test
    void theFinderSeesItOnceTheOwnerConfirms() {
        assertThat(conversation(finder).path("match_confirmed").asBoolean()).isFalse();
        assertThat(conversation(finder).path("owner_detail").isNull()).isTrue(); // anyone could claim it otherwise

        patchJson("/matches/" + matchId, owner, Map.of("status", "CONFIRMED"));
        assertThat(conversation(finder).path("match_confirmed").asBoolean()).isTrue();
        assertThat(conversation(finder).path("owner_detail").asString()).isEqualTo(DETAIL);
        assertThat(conversation(owner).path("match_confirmed").asBoolean()).isTrue();
        assertThat(conversation(owner).path("owner_detail").isNull()).isTrue(); // the owner knows it
    }

    @Test
    void emptyDetailRemovesIt() {
        patchJson("/lost-reports/" + reportId, owner, Map.of("private_detail", " "));
        assertThat(getJson("/lost-reports/" + reportId, owner).json().path("private_detail").isNull()).isTrue();
    }

    @Test
    void detailIsLimited() {
        Response tooLong = patchJson("/lost-reports/" + reportId, owner, Map.of("private_detail", "x".repeat(301)));
        assertThat(tooLong.status()).isEqualTo(422);
    }

    @Test
    void theRecipientIsWarnedAboutPaymentRequests() {
        postJson("/conversations/" + conversationId + "/messages", finder,
                Map.of("body", "Send 100 dt on D17 first, then I bring her"));
        postJson("/conversations/" + conversationId + "/messages", owner, Map.of("body", "Where can we meet?"));

        JsonNode ownerView = getJson("/conversations/" + conversationId + "/messages", owner).json();
        JsonNode askedMoney = ownerView.get(0).path("mine").asBoolean() ? ownerView.get(1) : ownerView.get(0);
        assertThat(askedMoney.path("warning").asString()).isEqualTo("payment");

        JsonNode finderView = getJson("/conversations/" + conversationId + "/messages", finder).json();
        for (JsonNode message : finderView) {
            assertThat(message.path("warning").isNull()).isTrue(); // own message, and a fine one
        }
    }
}
