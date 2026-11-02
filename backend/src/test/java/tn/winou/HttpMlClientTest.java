package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.sun.net.httpserver.HttpServer;

import tn.winou.config.WinouProperties;
import tn.winou.infra.HttpMlClient;
import tn.winou.infra.MlClient.NoAnimalDetected;

/** The HTTP client of the ML service against a stand-in server that answers like it. */
class HttpMlClientTest {

    private HttpServer server;
    private HttpMlClient client;
    private final AtomicReference<String> path = new AtomicReference<>();
    private volatile int status = 200;
    private volatile String body = "{}";

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            path.set(exchange.getRequestURI().toString());
            exchange.getRequestBody().readAllBytes();
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
        WinouProperties properties = mock(WinouProperties.class);
        when(properties.ml()).thenReturn(new WinouProperties.Ml(
                "http://127.0.0.1:" + server.getAddress().getPort(), Duration.ofSeconds(5)));
        client = new HttpMlClient(properties);
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private static final String NO_ANIMAL = """
            {"detail": {"code": "no_animal_detected", "message": "No cat or dog found."}}""";

    @Test
    void detect() {
        body = """
                {"species": "dog", "confidence": 0.93, "box": [1, 2, 30, 40]}""";
        var detection = client.detect(new byte[] {1});
        assertThat(path.get()).isEqualTo("/detect");
        assertThat(detection.species()).isEqualTo("dog");
        assertThat(detection.confidence()).isEqualTo(0.93);
    }

    @Test
    void detectWithoutAnimal() {
        status = 422;
        body = NO_ANIMAL;
        assertThatThrownBy(() -> client.detect(new byte[] {1})).isInstanceOf(NoAnimalDetected.class);
    }

    @Test
    void detectWhenTheServiceFails() {
        status = 500;
        body = "{\"detail\": \"boom\"}";
        assertThatThrownBy(() -> client.detect(new byte[] {1}))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("/detect");
    }

    @Test
    void embed() {
        String crop = Base64.getEncoder().encodeToString(new byte[] {9, 8, 7});
        body = """
                {"detection": {"species": "cat", "confidence": 0.8, "box": [0, 0, 5, 5]},
                 "model": "m", "dim": 3, "vector": [0.6, 0.8, 0.0], "crop_jpeg_base64": "%s"}"""
                .formatted(crop);
        var embedding = client.embed(new byte[] {1});
        assertThat(path.get()).isEqualTo("/embed?return_crop=true");
        assertThat(embedding.species()).isEqualTo("cat");
        assertThat(embedding.vector()).containsExactly(0.6, 0.8, 0.0);
        assertThat(embedding.cropJpeg()).containsExactly(9, 8, 7);
    }

    @Test
    void embedWithoutAnimal() {
        status = 422;
        body = NO_ANIMAL;
        assertThatThrownBy(() -> client.embed(new byte[] {1})).isInstanceOf(NoAnimalDetected.class);
    }

    @Test
    void embedWhenTheServiceFails() {
        status = 503;
        assertThatThrownBy(() -> client.embed(new byte[] {1})).isInstanceOf(IllegalStateException.class);
    }
}
