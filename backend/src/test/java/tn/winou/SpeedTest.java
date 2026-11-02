package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Map;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Smaller photos for lists, and the conversation list in a fixed number of queries. */
class SpeedTest extends ApiTestBase {

    private static byte[] photo(int width, int height) {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        var g = image.createGraphics();
        g.setColor(RED);
        g.fillRect(0, 0, width, height);
        g.setColor(Color.WHITE);
        g.fillOval(width / 4, height / 4, width / 2, height / 2);
        g.dispose();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try {
            ImageIO.write(image, "jpg", out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static int width(byte[] jpeg) {
        try {
            return ImageIO.read(new ByteArrayInputStream(jpeg)).getWidth();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private String uploadedPhoto(String owner, byte[] data) {
        String report = postJson("/lost-reports", owner, Map.of("name", "Mimi", "species", "cat",
                "last_seen", TUNIS, "last_seen_at", "2026-10-20T10:00:00+01:00")).json().path("id").asString();
        Response uploaded = uploadRaw("/lost-reports/" + report + "/photos", owner, data, null);
        assertThat(uploaded.status()).as(uploaded.text()).isEqualTo(201);
        return uploaded.json().path("id").asString();
    }

    @Test
    void smallerCopiesAreMadeOnceAndKept() {
        String owner = register("owner");
        String photo = uploadedPhoto(owner, photo(1200, 900));
        String url = "/photos/" + photo + "/image";

        Response small = getJson(url, null, Map.of("w", 320));
        assertThat(small.status()).isEqualTo(200);
        assertThat(small.header("Content-Type")).startsWith("image/jpeg");
        assertThat(small.header("Cache-Control")).contains("immutable");
        assertThat(width(small.bytes())).isEqualTo(320);
        assertThat(small.bytes().length).isLessThan(getJson(url, null).bytes().length);

        int stored = storage.objects.size();
        assertThat(width(getJson(url, null, Map.of("w", 320)).bytes())).isEqualTo(320);
        assertThat(storage.objects).hasSize(stored); // served from the kept copy
        assertThat(width(getJson(url, null, Map.of("w", 1080)).bytes())).isEqualTo(1080);
        assertThat(width(getJson(url, null).bytes())).isEqualTo(1200); // without w: the photo as it is
    }

    @Test
    void neverEnlargedAndOnlyKnownWidths() {
        String owner = register("owner");
        String photo = uploadedPhoto(owner, photo(200, 150));
        String url = "/photos/" + photo + "/image";
        assertThat(width(getJson(url, null, Map.of("w", 640)).bytes())).isEqualTo(200);
        assertThat(getJson(url, null, Map.of("w", 999)).status()).isEqualTo(422);
    }

    @Test
    void deletingAPhotoRemovesItsSmallerCopies() {
        String owner = register("owner");
        String photo = uploadedPhoto(owner, photo(1200, 900));
        getJson("/photos/" + photo + "/image", null, Map.of("w", 320));
        assertThat(storage.objects.keySet()).anyMatch(key -> key.startsWith("sized/" + photo));

        assertThat(delete("/photos/" + photo, owner).status()).isEqualTo(204);
        assertThat(storage.objects.keySet()).noneMatch(key -> key.contains(photo));
    }

    @Test
    void theConversationListAgreesWithEachConversation() {
        String owner = register("owner");
        lostReport(owner);
        String finderA = register("finder-a");
        String finderB = register("finder-b");
        sighting(finderA, Map.of("location", offset(TUNIS, 1, 0)), NEAR_RED);
        sighting(finderB, Map.of("location", offset(TUNIS, 0, 1)), NEAR_RED);
        work();
        JsonNode matches = getJson("/me/matches", owner).json();
        assertThat(matches).hasSize(2);
        String first = postJson("/matches/" + matches.get(0).path("id").asString() + "/conversation", owner, Map.of())
                .json().path("id").asString();
        String second = postJson("/matches/" + matches.get(1).path("id").asString() + "/conversation", owner, Map.of())
                .json().path("id").asString();
        postJson("/conversations/" + first + "/messages", owner, Map.of("body", "Hello, is she still with you?"));
        String finderOfFirst = getJson("/conversations/" + first, owner).json().path("other_name").asString()
                .equals("finder-a") ? finderA : finderB;
        postJson("/conversations/" + first + "/messages", finderOfFirst, Map.of("body", "Yes, by the bakery"));
        postJson("/conversations/" + first + "/messages", finderOfFirst, Map.of("body", "Send 50 dt on D17 first"));
        postJson("/conversations/" + second + "/messages", owner, Map.of("body", "Hi!"));

        for (String user : new String[] {owner, finderA, finderB}) {
            for (JsonNode listed : getJson("/conversations", user).json()) {
                JsonNode single = getJson("/conversations/" + listed.path("id").asString(), user).json();
                assertThat(listed).as("conversation list vs single, for " + user).isEqualTo(single);
            }
        }
        JsonNode ownerList = getJson("/conversations", owner).json();
        assertThat(ownerList).hasSize(2);
        JsonNode withReplies = ownerList.get(0).path("id").asString().equals(first) ? ownerList.get(0) : ownerList.get(1);
        assertThat(withReplies.path("unread").asLong()).isEqualTo(2);
        assertThat(withReplies.path("last_message").path("warning").asString()).isEqualTo("payment");
    }
}
