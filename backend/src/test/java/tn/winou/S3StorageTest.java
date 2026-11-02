package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.stream.IntStream;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import tn.winou.config.WinouProperties;
import tn.winou.infra.S3Storage;
import tn.winou.infra.S3Storage.StorageException;

/** The real storage class against a real MinIO (the API tests use a fake). */
@Testcontainers
class S3StorageTest {

    @Container
    static final GenericContainer<?> MINIO = new GenericContainer<>("cgr.dev/chainguard/minio:latest")
            .withCommand("server", "/data")
            .withEnv("MINIO_ROOT_USER", "winou")
            .withEnv("MINIO_ROOT_PASSWORD", "winou-test-secret")
            .withExposedPorts(9000)
            .waitingFor(Wait.forHttp("/minio/health/live").forPort(9000));

    static S3Storage storage;

    @BeforeAll
    static void connect() {
        WinouProperties properties = mock(WinouProperties.class);
        when(properties.s3()).thenReturn(new WinouProperties.S3(
                MINIO.getHost() + ":" + MINIO.getMappedPort(9000), false, "winou", "winou-test-secret", "photos"));
        storage = new S3Storage(properties);
    }

    @Test
    void storesReadsAndDeletes() {
        storage.put("a.jpg", new byte[] {1, 2, 3}, "image/jpeg");
        assertThat(storage.get("a.jpg")).containsExactly(1, 2, 3);

        storage.delete(List.of("a.jpg", "never-stored.jpg")); // a missing key is not an error in S3
        assertThatThrownBy(() -> storage.get("a.jpg")).isInstanceOf(StorageException.class);
    }

    @Test
    void deletesEveryKeyOfALargeBatch() {
        // More than one S3 delete request (1000 keys each): every batch must be sent
        List<String> keys = IntStream.range(0, 1001).mapToObj(i -> "batch/" + i + ".jpg").toList();
        keys.forEach(key -> storage.put(key, new byte[] {1}, "image/jpeg"));

        storage.delete(keys);

        assertThatThrownBy(() -> storage.get(keys.getFirst())).isInstanceOf(StorageException.class);
        assertThatThrownBy(() -> storage.get(keys.getLast())).isInstanceOf(StorageException.class);
    }
}
