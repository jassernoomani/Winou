package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.AfterEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.web.client.RestClient;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.qdrant.QdrantContainer;
import org.testcontainers.utility.DockerImageName;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tn.winou.domain.AssociationRequest;
import tn.winou.domain.ChatMessage;
import tn.winou.domain.Conversation;
import tn.winou.domain.LostReport;
import tn.winou.domain.Match;
import tn.winou.domain.Sighting;
import tn.winou.infra.Notifications;
import tn.winou.infra.MlClient;
import tn.winou.infra.Notifier;
import tn.winou.infra.Storage;
import tn.winou.infra.VectorIndex;
import tn.winou.matching.PhotoWorker;

/**
 * Tests run against real PostGIS and Qdrant (Testcontainers, started once for all test classes).
 * Storage and the ML service are faked.
 *
 * <p>Fake embeddings come from the image colour, so tests control similarity: two near-identical
 * reds score ~1.0, red vs blue scores 0. A black image has "no animal".
 */
@SpringBootTest(properties = {
        "winou.qdrant.collection=pet_photos_test",
        "winou.qdrant.embed-dim=8",
        "winou.jwt.secret=test-secret-at-least-32-bytes-long!!",
        "winou.privacy.location-fuzz-secret=test-fuzz-secret",
        "winou.admin.emails=" + ApiTestBase.ADMIN_EMAIL,
        // Every test signs people up and in from one address
        "winou.auth.registrations-per-ip-per-hour=1000000",
        "winou.auth.login-attempts-per-ip=1000000",
        "winou.google.client-ids=test-client",
})
@AutoConfigureMockMvc
@Import(ApiTestBase.Fakes.class)
public abstract class ApiTestBase {

    public static final String ADMIN_EMAIL = "admin@winou.test";
    public static final Map<String, Object> TUNIS = Map.of("lat", 36.8065, "lon", 10.1815);
    public static final Color RED = new Color(220, 30, 30);
    public static final Color NEAR_RED = new Color(215, 35, 30);
    public static final Color BLUE = new Color(30, 30, 220);
    public static final Color BLACK = Color.BLACK;

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:18-3.6").asCompatibleSubstituteFor("postgres"));

    static final QdrantContainer QDRANT = new QdrantContainer("qdrant/qdrant:v1.20.0");

    static {
        POSTGRES.start();
        QDRANT.start();
    }

    @DynamicPropertySource
    static void qdrant(DynamicPropertyRegistry registry) {
        registry.add("winou.qdrant.url", () -> "http://" + QDRANT.getHost() + ":" + QDRANT.getMappedPort(6333));
    }

    @Autowired
    protected MockMvc mvc;
    @Autowired
    protected JsonMapper json;
    @Autowired
    protected JdbcClient jdbc;
    @Autowired
    protected FakeStorage storage;
    @Autowired
    protected FakeMl ml;
    @Autowired
    protected RecordingNotifier notifier;
    @Autowired
    protected VectorIndex index;
    @Autowired
    protected PhotoWorker worker;
    @Autowired
    protected RecordingMailer mailer;

    @AfterEach
    void cleanUp() {
        jdbc.sql("TRUNCATE users, lost_reports, sightings, photos, matches CASCADE").update();
        RestClient.create("http://" + QDRANT.getHost() + ":" + QDRANT.getMappedPort(6333))
                .delete().uri("/collections/pet_photos_test").retrieve().toBodilessEntity();
        index.ensureCollection();
        storage.objects.clear();
        ml.calls.set(0);
        ml.down = false;
        notifier.clear();
        mailer.sent.clear();
    }

    // --- fakes ---

    @TestConfiguration
    static class Fakes {

        @Bean
        @Primary
        FakeStorage fakeStorage() {
            return new FakeStorage();
        }

        @Bean
        @Primary
        FakeMl fakeMl() {
            return new FakeMl();
        }

        @Bean
        @Primary
        RecordingNotifier recordingNotifier() {
            return new RecordingNotifier();
        }

        @Bean
        @Primary
        RecordingMailer recordingMailer() {
            return new RecordingMailer();
        }

        /** Google ID tokens are "sub|email|email_verified|name" in tests. */
        @Bean
        @Primary
        tn.winou.security.GoogleTokens fakeGoogle(tn.winou.config.WinouProperties properties) {
            return new tn.winou.security.GoogleTokens(properties) {
                @Override
                public Identity verify(String idToken) {
                    String[] parts = idToken.split("\\|", -1);
                    if (parts.length != 4) {
                        throw tn.winou.common.ApiException.coded(org.springframework.http.HttpStatus.UNAUTHORIZED,
                                "google_invalid", "Google sign-in failed. Try again.");
                    }
                    return new Identity(parts[0], parts[1].isEmpty() ? null : parts[1],
                            Boolean.parseBoolean(parts[2]), parts[3].isEmpty() ? null : parts[3]);
                }
            };
        }

        /** Notifications are sent on the request thread in tests (after commit, as in production). */
        @Bean
        @Primary
        Notifications syncNotifications(RecordingNotifier notifier) {
            return new Notifications(notifier, Runnable::run);
        }
    }

    public static class FakeStorage implements Storage {

        public final Map<String, byte[]> objects = new HashMap<>();

        @Override
        public synchronized void put(String key, byte[] data, String contentType) {
            objects.put(key, data);
        }

        @Override
        public synchronized byte[] get(String key) {
            byte[] data = objects.get(key);
            if (data == null) {
                throw new IllegalStateException("no object " + key);
            }
            return data;
        }

        @Override
        public synchronized void delete(List<String> keys) {
            keys.forEach(objects::remove);
        }
    }

    public static class FakeMl implements MlClient {

        public final AtomicInteger calls = new AtomicInteger();
        public volatile boolean down;

        @Override
        public Embedding embed(byte[] image) {
            calls.incrementAndGet();
            if (down) {
                throw new IllegalStateException("ml-service unreachable");
            }
            double[] rgb = meanRgb(image);
            if (rgb[0] + rgb[1] + rgb[2] < 10) {
                throw new NoAnimalDetected();
            }
            double norm = Math.sqrt(rgb[0] * rgb[0] + rgb[1] * rgb[1] + rgb[2] * rgb[2]);
            List<Double> vector = new ArrayList<>(List.of(rgb[0] / norm, rgb[1] / norm, rgb[2] / norm));
            while (vector.size() < 8) {
                vector.add(0.0);
            }
            return new Embedding("cat", 0.9, vector, "crop".getBytes());
        }

        @Override
        public byte[] heicToJpeg(byte[] image, int maxSide) {
            return image(RED, "jpg");
        }

        private static double[] meanRgb(byte[] jpeg) {
            try {
                BufferedImage image = ImageIO.read(new ByteArrayInputStream(jpeg));
                double[] sum = new double[3];
                for (int y = 0; y < image.getHeight(); y++) {
                    for (int x = 0; x < image.getWidth(); x++) {
                        Color c = new Color(image.getRGB(x, y));
                        sum[0] += c.getRed();
                        sum[1] += c.getGreen();
                        sum[2] += c.getBlue();
                    }
                }
                int n = image.getWidth() * image.getHeight();
                return new double[] {sum[0] / n, sum[1] / n, sum[2] / n};
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }
    }

    /** Emails "sent", newest last. */
    public static class RecordingMailer implements tn.winou.infra.Mailer {

        public record Sent(String to, String subject, String text) {}

        public final List<Sent> sent = new java.util.concurrent.CopyOnWriteArrayList<>();

        @Override
        public void send(String to, String subject, String text, String html) {
            sent.add(new Sent(to, subject, text));
        }

        /** The 6-digit code in the last email to [to]. */
        public String lastCode(String to) {
            for (int i = sent.size() - 1; i >= 0; i--) {
                if (sent.get(i).to().equals(to)) {
                    var matcher = java.util.regex.Pattern.compile("\\b(\\d{6})\\b").matcher(sent.get(i).text());
                    if (matcher.find()) {
                        return matcher.group(1);
                    }
                }
            }
            throw new IllegalStateException("no code sent to " + to);
        }
    }

    public static class RecordingNotifier implements Notifier {

        public final List<String> matches = new ArrayList<>();
        public final List<String> confirmed = new ArrayList<>();
        /** "pet name: finder ids" */
        public final List<String> found = new ArrayList<>();
        /** "conversation id: message body" */
        public final List<String> messages = new ArrayList<>();
        /** "sighting id: association ids" */
        public final List<String> help = new ArrayList<>();
        /** "organisation: status" */
        public final List<String> associations = new ArrayList<>();
        /** To admins: "TYPE id" hidden, organisations asking */
        public final List<String> adminHidden = new ArrayList<>();
        public final List<String> adminRequests = new ArrayList<>();

        @Override
        public void matchFound(Match match) {
            matches.add(match.getId().toString());
        }

        @Override
        public void matchConfirmed(Match match) {
            confirmed.add(match.getId().toString());
        }

        @Override
        public void petFound(LostReport report, List<UUID> finderIds) {
            found.add(report.getName() + ": " + finderIds);
        }

        @Override
        public void newMessage(Conversation conversation, ChatMessage message) {
            messages.add(conversation.getId() + ": " + message.getBody());
        }

        @Override
        public void animalNeedsHelp(Sighting sighting, List<UUID> associationIds) {
            help.add(sighting.getId() + ": " + associationIds);
        }

        @Override
        public void associationDecided(AssociationRequest request) {
            associations.add(request.getOrganisation() + ": " + request.getStatus());
        }

        @Override
        public void contentHidden(tn.winou.web.ApiModels.ReportTarget type, UUID id) {
            adminHidden.add(type + " " + id);
        }

        @Override
        public void associationRequested(AssociationRequest request) {
            adminRequests.add(request.getOrganisation());
        }

        void clear() {
            matches.clear();
            confirmed.clear();
            found.clear();
            messages.clear();
            help.clear();
            associations.clear();
            adminHidden.clear();
            adminRequests.clear();
        }
    }

    // --- helpers ---

    /** A solid-colour image, 64x48. */
    public static byte[] image(Color color, String format) {
        BufferedImage image = new BufferedImage(64, 48, BufferedImage.TYPE_INT_RGB);
        var g = image.createGraphics();
        g.setColor(color);
        g.fillRect(0, 0, 64, 48);
        g.dispose();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try {
            ImageIO.write(image, format, out);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return out.toByteArray();
    }

    /** Runs the worker until the photo queue is empty. */
    protected void work() {
        while (worker.runOnce()) {
            // next photo
        }
    }

    protected Response call(RequestBuilder request) {
        try {
            return new Response(mvc.perform(request).andReturn(), json);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    protected String body(Object value) {
        return json.writeValueAsString(value);
    }

    protected Response getJson(String path, String token) {
        var request = get(path);
        if (token != null) {
            request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        return call(request);
    }

    protected Response getJson(String path, String token, Map<String, ?> params) {
        var request = get(path);
        params.forEach((k, v) -> {
            if (v instanceof List<?> list) {
                list.forEach(item -> request.queryParam(k, String.valueOf(item)));
            } else {
                request.queryParam(k, String.valueOf(v));
            }
        });
        if (token != null) {
            request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        return call(request);
    }

    protected Response postJson(String path, String token, Object payload) {
        var request = post(path).contentType(MediaType.APPLICATION_JSON).content(body(payload));
        if (token != null) {
            request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        return call(request);
    }

    protected Response patchJson(String path, String token, Object payload) {
        return call(patch(path).contentType(MediaType.APPLICATION_JSON).content(body(payload))
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    protected Response delete(String path, String token) {
        return call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete(path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    protected Response uploadRaw(String path, String token, byte[] data, String source) {
        var request = multipart(path).file(new MockMultipartFile("file", "p.jpg", "image/jpeg", data));
        if (source != null) {
            request.param("source", source);
        }
        return call(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    protected JsonNode upload(String token, String path, Color color) {
        Response response = uploadRaw(path, token, image(color, "jpg"), null);
        assertThat(response.status()).as(response.text()).isEqualTo(201);
        return response.json();
    }

    protected String register(String name) {
        String email = name + "-" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        return postJson("/auth/register", null, Map.of("email", email, "password", "password123",
                "display_name", name)).json().path("access_token").asString();
    }

    protected JsonNode lostReport(String token, Map<String, Object> location, String species, String lastSeenAt,
            Color color) {
        JsonNode report = postJson("/lost-reports", token, Map.of("name", "Mimi", "species", species,
                "last_seen", location, "last_seen_at", lastSeenAt)).json();
        if (color != null) {
            upload(token, "/lost-reports/" + report.path("id").asString() + "/photos", color);
        }
        return report;
    }

    protected JsonNode lostReport(String token) {
        return lostReport(token, TUNIS, "cat", "2026-10-20T10:00:00+01:00", RED);
    }

    protected JsonNode lostReport(String token, Color color) {
        return lostReport(token, TUNIS, "cat", "2026-10-20T10:00:00+01:00", color);
    }

    protected JsonNode sighting(String token, Map<String, Object> fields, Color color) {
        Map<String, Object> payload = new HashMap<>(Map.of("species", "cat", "location", TUNIS,
                "seen_at", "2026-10-25T10:00:00+01:00"));
        payload.putAll(fields);
        Response response = postJson("/sightings", token, payload);
        assertThat(response.status()).as(response.text()).isEqualTo(201);
        JsonNode item = response.json();
        if (color != null) {
            upload(token, "/sightings/" + item.path("id").asString() + "/photos", color);
        }
        return item;
    }

    protected JsonNode sighting(String token, Color color) {
        return sighting(token, Map.of(), color);
    }

    public static Map<String, Object> offset(Map<String, Object> location, double kmNorth, double kmEast) {
        double lat = (double) location.get("lat");
        double lon = (double) location.get("lon");
        return Map.of("lat", lat + kmNorth / 111.0, "lon", lon + kmEast / (111.0 * Math.cos(Math.toRadians(lat))));
    }

    public static double distanceM(JsonNode a, Map<String, Object> b) {
        return distanceM(a.path("lat").asDouble(), a.path("lon").asDouble(), (double) b.get("lat"),
                (double) b.get("lon"));
    }

    public static double distanceM(double lat1, double lon1, double lat2, double lon2) {
        double dlat = Math.toRadians(lat2 - lat1);
        double dlon = Math.toRadians(lon2 - lon1) * Math.cos(Math.toRadians(lat1));
        return 6_371_000 * Math.hypot(dlat, dlon);
    }

    public record Response(MvcResult result, JsonMapper mapper) {

        public int status() {
            return result.getResponse().getStatus();
        }

        public String text() {
            try {
                return result.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        }

        public byte[] bytes() {
            return result.getResponse().getContentAsByteArray();
        }

        public String header(String name) {
            return result.getResponse().getHeader(name);
        }

        public JsonNode json() {
            return mapper.readTree(text());
        }
    }
}
