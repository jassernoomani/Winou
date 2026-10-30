package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** A lost pet's reward, microchip and the phone its owner chooses to show; and editing them. */
class ReportDetailsTest extends ApiTestBase {

    private Response create(String token, Map<String, Object> extra) {
        Map<String, Object> body = new HashMap<>(Map.of("name", "Luna", "species", "cat", "last_seen", TUNIS,
                "last_seen_at", "2026-10-20T10:00:00+01:00"));
        body.putAll(extra);
        return postJson("/lost-reports", token, body);
    }

    @Test
    void theDetailsAreShownToEveryone() {
        String owner = register("owner");
        Response created = create(owner, Map.of("reward_tnd", 200, "microchipped", true,
                "contact_phone", " +216 20 123 456 "));
        assertThat(created.status()).as(created.text()).isEqualTo(201);
        String id = created.json().path("id").asString();

        JsonNode seen = getJson("/lost-reports/" + id, register("neighbour")).json();
        assertThat(seen.path("reward_tnd").asInt()).isEqualTo(200);
        assertThat(seen.path("microchipped").asBoolean()).isTrue();
        assertThat(seen.path("contact_phone").asString()).isEqualTo("+216 20 123 456");
        assertThat(call(get("/lost/" + id)).text()).contains("Reward: 200 TND");
    }

    @Test
    void theyAreOptional() {
        JsonNode report = create(register("owner"), Map.of()).json();
        assertThat(report.path("reward_tnd").isNull()).isTrue();
        assertThat(report.path("microchipped").isNull()).isTrue();
        assertThat(report.path("contact_phone").isNull()).isTrue();
    }

    @Test
    void wrongValuesAreRefused() {
        String owner = register("owner");
        assertThat(create(owner, Map.of("contact_phone", "call me maybe")).status()).isEqualTo(422);
        assertThat(create(owner, Map.of("reward_tnd", 0)).status()).isEqualTo(422);
        assertThat(create(owner, Map.of("reward_tnd", -5)).status()).isEqualTo(422);
    }

    @Test
    void theOwnerEditsAndRemovesThem() {
        String owner = register("owner");
        String id = create(owner, Map.of("reward_tnd", 200, "contact_phone", "20123456")).json()
                .path("id").asString();

        JsonNode edited = patchJson("/lost-reports/" + id, owner, Map.of("name", "Luna Bella", "reward_tnd", 300,
                "microchipped", false, "description", "Grey tabby")).json();
        assertThat(edited.path("name").asString()).isEqualTo("Luna Bella");
        assertThat(edited.path("reward_tnd").asInt()).isEqualTo(300);
        assertThat(edited.path("microchipped").asBoolean()).isFalse();
        assertThat(edited.path("contact_phone").asString()).isEqualTo("20123456"); // left as it was

        JsonNode cleared = patchJson("/lost-reports/" + id, owner, Map.of("reward_tnd", 0, "contact_phone", ""))
                .json();
        assertThat(cleared.path("reward_tnd").isNull()).isTrue();
        assertThat(cleared.path("contact_phone").isNull()).isTrue();

        assertThat(patchJson("/lost-reports/" + id, register("other"), Map.of("reward_tnd", 1)).status())
                .isEqualTo(403);
    }
}
