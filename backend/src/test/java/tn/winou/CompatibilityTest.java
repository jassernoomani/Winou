package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.api.Test;

import tn.winou.common.Geo;
import tn.winou.domain.GeoPoint;
import tn.winou.security.Passwords;

/** Data written by the Python API must keep working: password hashes and public positions. */
class CompatibilityTest {

    @Test
    void verifiesArgon2HashesFromThePythonApi() {
        String fromPython = "$argon2id$v=19$m=65536,t=3,p=4$36cj50GRq61DmSjebKwF+Q$kypL3YFAcXPH01XAZ44mTcfElfTHtZhqx4lOMZY5oFs";
        Passwords passwords = new Passwords();
        assertThat(passwords.verify(fromPython, "password123")).isTrue();
        assertThat(passwords.verify(fromPython, "wrong-pass")).isFalse();
        assertThat(passwords.verify(null, "password123")).isFalse();
        assertThat(passwords.hash("password123")).startsWith("$argon2id$v=19$m=65536,t=3,p=4$");
    }

    /** Values printed by app.geo.fuzz in the Python API: public positions must not move. */
    @ParameterizedTest
    @CsvSource({
        "3f2b8c1e-9d4a-4e6b-8a71-2c5d9e0f1a2b, 36.80687, 10.17988",
        "00000000-0000-0000-0000-000000000001, 36.80709, 10.18202",
        "ffffffff-ffff-ffff-ffff-ffffffffffff, 36.80542, 10.18283",
    })
    void fuzzMatchesThePythonApi(String id, double lat, double lon) {
        GeoPoint fuzzed = Geo.fuzz(UUID.fromString(id), new GeoPoint(36.8065, 10.1815), 300, "test-fuzz-secret");
        assertThat(fuzzed).isEqualTo(new GeoPoint(lat, lon));
    }

    @Test
    void fuzzStaysWithinRadius() {
        GeoPoint tunis = new GeoPoint(36.8065, 10.1815);
        for (int i = 0; i < 500; i++) {
            GeoPoint fuzzed = Geo.fuzz(UUID.randomUUID(), tunis, 300, "s");
            assertThat(Geo.distanceM(tunis, fuzzed)).isLessThanOrEqualTo(302); // rounding to 5 decimals ≈ 1 m
        }
    }

    @Test
    void wktRoundTrip() {
        GeoPoint point = new GeoPoint(36.8065, 10.1815);
        assertThat(point.toEwkt()).isEqualTo("SRID=4326;POINT(10.1815 36.8065)");
        assertThat(GeoPoint.parse("POINT(10.1815 36.8065)")).isEqualTo(point);
        assertThat(new GeoPoint(0.00001, -0.00001).toEwkt()).isEqualTo("SRID=4326;POINT(-0.00001 0.00001)");
    }
}
