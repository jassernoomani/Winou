package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import com.drew.imaging.ImageMetadataReader;
import com.drew.metadata.exif.ExifIFD0Directory;

import tools.jackson.databind.JsonNode;

/** Auth, CRUD, photos, map and privacy. Port of the Python API's tests/test_api.py. */
class ApiTest extends ApiTestBase {

    // --- auth ---

    @Test
    void registerLoginMe() {
        assertThat(postJson("/auth/register", null, Map.of("email", "Sami@Example.com", "password", "password123",
                "display_name", "Sami")).status()).isEqualTo(201);
        Response login = call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", "sami@example.com")
                .param("password", "password123"));
        assertThat(login.status()).isEqualTo(200);
        assertThat(login.json().path("token_type").asString()).isEqualTo("bearer");
        JsonNode me = getJson("/me", login.json().path("access_token").asString()).json();
        assertThat(me.path("email").asString()).isEqualTo("sami@example.com");
        assertThat(me.path("role").asString()).isEqualTo("USER");
        assertThat(me.has("password_hash")).isFalse();
        assertThat(me.has("fcm_token")).isFalse();
    }

    @Test
    void duplicateEmailAndWrongPassword() {
        Map<String, String> body = Map.of("email", "a@example.com", "password", "password123", "display_name", "A");
        assertThat(postJson("/auth/register", null, body).status()).isEqualTo(201);
        Response again = postJson("/auth/register", null, body);
        assertThat(again.status()).isEqualTo(409);
        assertThat(again.json().path("detail").path("code").asString()).isEqualTo("email_taken");
        assertThat(login("a@example.com", "wrong-pass").status()).isEqualTo(401);
        assertThat(login("nobody@example.com", "password123").status()).isEqualTo(401);
    }

    private Response login(String email, String password) {
        return call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED).param("username", email).param("password", password));
    }

    @Test
    void requiresToken() {
        assertThat(getJson("/me", null).status()).isEqualTo(401);
        Response garbage = getJson("/me", "garbage");
        assertThat(garbage.status()).isEqualTo(401);
        assertThat(garbage.header("WWW-Authenticate")).startsWith("Bearer");
        assertThat(garbage.json().path("detail").asString()).isEqualTo("Invalid or expired token");
    }

    @Test
    void publicEndpointsIgnoreABadToken() {
        assertThat(getJson("/map", "expired-or-garbage", Map.of("bbox", "10.05,36.75,10.30,36.90")).status())
                .isEqualTo(200);
    }

    @Test
    void updateMe() {
        String auth = register("user");
        JsonNode me = patchJson("/me", auth, Map.of("display_name", "New", "fcm_token", "tok")).json();
        assertThat(me.path("display_name").asString()).isEqualTo("New");
        assertThat(jdbc.sql("SELECT fcm_token FROM users").query(String.class).single()).isEqualTo("tok");

        java.util.Map<String, Object> clear = new java.util.HashMap<>();
        clear.put("display_name", null);
        clear.put("fcm_token", null);
        assertThat(patchJson("/me", auth, clear).status()).isEqualTo(200);
        assertThat(jdbc.sql("SELECT fcm_token FROM users").query(String.class).optional()).isEmpty();
        assertThat(getJson("/me", auth).json().path("display_name").asString()).isEqualTo("New"); // kept
    }

    // --- lost reports ---

    @Test
    void lostReportLocationIsExactOnlyForOwner() {
        String owner = register("owner");
        String other = register("other");
        JsonNode report = lostReport(owner, null);
        assertThat(report.path("last_seen").path("lat").asDouble()).isEqualTo(36.8065);
        assertThat(report.path("last_seen").path("lon").asDouble()).isEqualTo(10.1815);
        assertThat(report.path("location_is_approximate").asBoolean()).isFalse();

        String path = "/lost-reports/" + report.path("id").asString();
        JsonNode seen = getJson(path, other).json();
        assertThat(seen.path("location_is_approximate").asBoolean()).isTrue();
        double moved = distanceM(seen.path("last_seen"), TUNIS);
        assertThat(moved).isGreaterThan(0).isLessThanOrEqualTo(302);
        // Same position every time, so it can't be averaged out
        assertThat(getJson(path, other).json().path("last_seen")).isEqualTo(seen.path("last_seen"));
    }

    @Test
    void lostReportValidation() {
        String auth = register("user");
        Map<String, Object> base = Map.of("name", "Rex", "species", "dog", "last_seen", TUNIS);
        assertThat(postJson("/lost-reports", auth, with(base, "last_seen_at", "2099-01-01T00:00:00+00:00")).status())
                .isEqualTo(422); // future
        assertThat(postJson("/lost-reports", auth, with(base, "last_seen_at", "2026-10-20T10:00:00")).status())
                .isEqualTo(422); // no timezone
        Map<String, Object> outOfRange = with(with(base, "last_seen_at", "2026-10-20T10:00:00Z"),
                "last_seen", Map.of("lat", 91, "lon", 0));
        Response invalid = postJson("/lost-reports", auth, outOfRange);
        assertThat(invalid.status()).isEqualTo(422);
        assertThat(invalid.json().path("detail").get(0).path("msg").asString()).isNotEmpty();
        assertThat(postJson("/lost-reports", auth, with(with(base, "last_seen_at", "2026-10-20T10:00:00Z"),
                "species", "hamster")).status()).isEqualTo(422);
    }

    private static Map<String, Object> with(Map<String, Object> base, String key, Object value) {
        var copy = new java.util.HashMap<>(base);
        copy.put(key, value);
        return copy;
    }

    @Test
    void onlyOwnerCanEditOrDelete() {
        String owner = register("owner");
        String other = register("other");
        String path = "/lost-reports/" + lostReport(owner, null).path("id").asString();
        assertThat(patchJson(path, other, Map.of("name", "X")).status()).isEqualTo(403);
        assertThat(delete(path, other).status()).isEqualTo(403);
        JsonNode edited = patchJson(path, owner, Map.of("name", "Minou", "status", "FOUND")).json();
        assertThat(edited.path("status").asString()).isEqualTo("FOUND");
        assertThat(edited.path("name").asString()).isEqualTo("Minou");
        assertThat(delete(path, owner).status()).isEqualTo(204);
        assertThat(getJson(path, owner).status()).isEqualTo(404);
    }

    @Test
    void listOpenReportsNewestFirst() {
        String owner = register("owner");
        String viewer = register("viewer");
        JsonNode older = lostReport(owner, TUNIS, "cat", "2026-10-20T10:00:00Z", null);
        JsonNode newer = lostReport(owner, TUNIS, "dog", "2026-10-22T10:00:00Z", null);
        JsonNode found = lostReport(owner, null);
        patchJson("/lost-reports/" + found.path("id").asString(), owner, Map.of("status", "FOUND"));
        lostReport(owner, Map.of("lat", 34.74, "lon", 10.76), "cat", "2026-10-21T10:00:00Z", null); // Sfax, ~230 km

        Map<String, Object> nearTunis = Map.of("lat", 36.8065, "lon", 10.1815);
        assertThat(ids(viewer, Map.of())).hasSize(3).first().isEqualTo(newer.path("id").asString());
        assertThat(ids(viewer, nearTunis)).containsExactly(newer.path("id").asString(), older.path("id").asString());
        assertThat(ids(viewer, with(nearTunis, "species", "cat"))).containsExactly(older.path("id").asString());
        assertThat(ids(viewer, with(with(nearTunis, "limit", 1), "offset", 1)))
                .containsExactly(older.path("id").asString());
        JsonNode listed = getJson("/lost-reports", viewer, Map.of("limit", 1)).json().get(0);
        assertThat(listed.path("location_is_approximate").asBoolean()).isTrue();
        assertThat(getJson("/lost-reports", viewer, Map.of("lat", 36.8)).status()).isEqualTo(422);
        assertThat(getJson("/lost-reports", viewer, Map.of("limit", 500)).status()).isEqualTo(422);
    }

    @Test
    void listRadiusUsesTheShownPosition() {
        String owner = register("owner");
        String viewer = register("viewer");
        JsonNode report = lostReport(owner, null);
        String id = report.path("id").asString();
        JsonNode shown = getJson("/lost-reports/" + id, viewer).json().path("last_seen");
        Map<String, Object> nearShown = Map.of("lat", shown.path("lat").asDouble(), "lon", shown.path("lon").asDouble(),
                "radius_km", 0.01);
        assertThat(ids(viewer, nearShown)).containsExactly(id);
        // A tiny circle around the real point misses it, unless the fuzz happened to land inside
        List<String> nearReal = ids(viewer, with(TUNIS, "radius_km", 0.01));
        assertThat(nearReal.isEmpty() || distanceM(shown, TUNIS) <= 10).isTrue();
        assertThat(ids(owner, with(TUNIS, "radius_km", 0.01))).containsExactly(id); // owners see the exact point
    }

    private List<String> ids(String token, Map<String, ?> params) {
        List<String> ids = new ArrayList<>();
        getJson("/lost-reports", token, params).json().forEach(r -> ids.add(r.path("id").asString()));
        return ids;
    }

    // --- photos ---

    @Test
    void uploadStripsExifButKeepsOriginal() throws Exception {
        String auth = register("user");
        JsonNode report = lostReport(auth, null);
        byte[] withExif = getClass().getResourceAsStream("/rotated-with-gps.jpg").readAllBytes();
        JsonNode photo = uploadRaw("/lost-reports/" + report.path("id").asString() + "/photos", auth, withExif, null)
                .json();
        assertThat(photo.path("status").asString()).isEqualTo("PENDING");

        Response served = call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get(photo.path("url").asString()));
        assertThat(served.status()).isEqualTo(200);
        assertThat(served.header("Content-Type")).isEqualTo("image/jpeg");
        assertThat(served.header("Cache-Control")).contains("immutable");
        var metadata = ImageMetadataReader.readMetadata(new ByteArrayInputStream(served.bytes()));
        assertThat(metadata.getFirstDirectoryOfType(ExifIFD0Directory.class)).isNull();
        // EXIF orientation 6 (rotate 90° clockwise) is applied: 64x48 becomes 48x64
        BufferedImage upright = ImageIO.read(new ByteArrayInputStream(served.bytes()));
        assertThat(upright.getWidth()).isEqualTo(48);
        assertThat(upright.getHeight()).isEqualTo(64);

        byte[] original = storage.get("originals/" + photo.path("id").asString() + ".jpg");
        assertThat(original).isEqualTo(withExif); // kept privately, never served
    }

    @Test
    void uploadAcceptsPngAndRejectsBadFiles() {
        String auth = register("user");
        String path = "/lost-reports/" + lostReport(auth, null).path("id").asString() + "/photos";
        assertThat(uploadRaw(path, auth, image(RED, "png"), null).status()).isEqualTo(201);
        Response bad = uploadRaw(path, auth, "not an image".getBytes(), null);
        assertThat(bad.status()).isEqualTo(415);
        assertThat(bad.json().path("detail").path("code").asString()).isEqualTo("invalid_image");
        Response gif = uploadRaw(path, auth, image(RED, "gif"), null);
        assertThat(gif.json().path("detail").path("code").asString()).isEqualTo("unsupported_format");
    }

    @Test
    void heicIsConvertedByTheMlService() {
        String auth = register("user");
        String path = "/lost-reports/" + lostReport(auth, null).path("id").asString() + "/photos";
        byte[] heic = new byte[64];
        System.arraycopy("\0\0\0\u0018ftypheic".getBytes(java.nio.charset.StandardCharsets.US_ASCII), 0, heic, 0, 12);
        Response response = uploadRaw(path, auth, heic, "GALLERY");
        assertThat(response.status()).isEqualTo(201);
        String id = response.json().path("id").asString();
        assertThat(storage.objects).containsKey("originals/" + id + ".heic");
        assertThat(storage.objects.get("public/" + id + ".jpg")).isEqualTo(image(RED, "jpg")); // from FakeMl
    }

    @Test
    void uploadLimitsCount() {
        String auth = register("user");
        String path = "/lost-reports/" + lostReport(auth, null).path("id").asString() + "/photos";
        for (int i = 0; i < 5; i++) {
            upload(auth, path, RED);
        }
        Response tooMany = uploadRaw(path, auth, image(RED, "jpg"), null);
        assertThat(tooMany.status()).isEqualTo(409);
        assertThat(tooMany.json().path("detail").path("code").asString()).isEqualTo("too_many_photos");
    }

    @Test
    void cannotUploadToSomeoneElsesReport() {
        String owner = register("owner");
        String other = register("other");
        String path = "/lost-reports/" + lostReport(owner, null).path("id").asString() + "/photos";
        assertThat(uploadRaw(path, other, image(RED, "jpg"), null).status()).isEqualTo(403);
    }

    @Test
    void deleteReportRemovesFilesAndVectors() {
        String auth = register("user");
        JsonNode report = lostReport(auth);
        work();
        assertThat(index.count()).isEqualTo(1);
        assertThat(storage.objects).isNotEmpty();
        delete("/lost-reports/" + report.path("id").asString(), auth);
        assertThat(index.count()).isZero();
        assertThat(storage.objects).isEmpty();
    }

    @Test
    void photoStatusIsPrivate() {
        String owner = register("owner");
        String other = register("other");
        JsonNode photo = upload(owner, "/lost-reports/" + lostReport(owner, null).path("id").asString() + "/photos",
                RED);
        String path = "/photos/" + photo.path("id").asString();
        assertThat(getJson(path, owner).status()).isEqualTo(200);
        assertThat(getJson(path, other).status()).isEqualTo(403);
    }

    @Test
    void photoSourceIsStoredButNotExposed() {
        String auth = register("user");
        String path = "/sightings/" + sighting(auth, null).path("id").asString() + "/photos";
        Response gallery = uploadRaw(path, auth, image(RED, "jpg"), "GALLERY");
        assertThat(gallery.status()).isEqualTo(201);
        assertThat(gallery.json().has("source")).isFalse();
        upload(auth, path, RED); // older clients: no source
        assertThat(jdbc.sql("SELECT coalesce(source, '-') FROM photos ORDER BY 1").query(String.class).list())
                .containsExactly("-", "GALLERY");
        assertThat(uploadRaw(path, auth, image(RED, "jpg"), "INTERNET").status()).isEqualTo(422);
    }

    // --- sightings and map ---

    @Test
    void sightingIsPublicButReporterIsHidden() {
        String reporter = register("reporter");
        String viewer = register("viewer");
        JsonNode item = sighting(reporter, BLUE);
        JsonNode seen = getJson("/sightings/" + item.path("id").asString(), viewer).json();
        assertThat(seen.path("location").path("lat").asDouble()).isEqualTo(36.8065);
        assertThat(seen.path("mine").asBoolean()).isFalse();
        assertThat(seen.has("reporter_id")).isFalse();
        assertThat(seen.path("is_stray").isBoolean()).isTrue();
        assertThat(getJson("/me/sightings", reporter).json().get(0).path("mine").asBoolean()).isTrue();
    }

    @Test
    void mapFilters() {
        String auth = register("user");
        lostReport(auth, null);
        sighting(auth, Map.of("condition", "INJURED"), null);
        // Recent: strays not seen for STRAY_FADE_DAYS leave the map
        sighting(auth, Map.of("species", "dog", "is_stray", true,
                "seen_at", java.time.OffsetDateTime.now().minusDays(1).toString()), null);
        sighting(auth, Map.of("location", Map.of("lat", 34.74, "lon", 10.76)), null); // Sfax, outside the box
        JsonNode closed = lostReport(auth, null);
        patchJson("/lost-reports/" + closed.path("id").asString(), auth, Map.of("status", "CLOSED"));

        String bbox = "10.05,36.75,10.30,36.90";
        JsonNode everything = getJson("/map", null, Map.of("bbox", bbox)).json(); // public: no token
        assertThat(types(everything)).containsExactly("lost", "sighting", "stray");
        everything.path("items").forEach(item -> {
            if (item.path("type").asString().equals("lost")) {
                assertThat(item.path("location").path("lat").asDouble()).isNotEqualTo(36.8065); // fuzzed
                assertThat(item.path("name").asString()).isEqualTo("Mimi");
            }
        });
        assertThat(types(getJson("/map", null, Map.of("bbox", bbox, "type", "stray")).json()))
                .containsExactly("stray");
        assertThat(types(getJson("/map", null, Map.of("bbox", bbox, "species", "dog")).json()))
                .containsExactly("stray");
        assertThat(types(getJson("/map", null, Map.of("bbox", bbox, "condition", "INJURED")).json()))
                .containsExactly("sighting");
        assertThat(types(getJson("/map", null, Map.of("bbox", bbox, "since", "2026-10-24T00:00:00Z")).json()))
                .containsExactly("sighting", "stray");
        assertThat(types(getJson("/map", null, Map.of("bbox", bbox, "type", List.of("lost", "stray"))).json()))
                .containsExactly("lost", "stray");
        assertThat(getJson("/map", null, Map.of("bbox", "10.3,36.9,10.0,36.7")).status()).isEqualTo(422);
        assertThat(getJson("/map", null, Map.of("bbox", "nonsense")).status()).isEqualTo(422);
    }

    private static List<String> types(JsonNode map) {
        List<String> types = new ArrayList<>();
        map.path("items").forEach(i -> types.add(i.path("type").asString()));
        return types.stream().sorted().toList();
    }

    @Test
    void unknownIdsAre404AndBadIds422() {
        String auth = register("user");
        assertThat(getJson("/lost-reports/" + java.util.UUID.randomUUID(), auth).status()).isEqualTo(404);
        assertThat(getJson("/lost-reports/not-a-uuid", auth).status()).isEqualTo(422);
    }
}
