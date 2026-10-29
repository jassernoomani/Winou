package tn.winou.common;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import tn.winou.domain.GeoPoint;

public final class Geo {

    public static final double EARTH_RADIUS_M = 6_371_000;

    private Geo() {}

    /**
     * Moves a point up to radiusM away, uniformly over the disc.
     *
     * <p>The offset is fixed per report (keyed hash of its id), so reloading the map never shows a
     * different position that could be averaged back to the real one. Same result as the Python API,
     * so public positions did not move when the backend was ported.
     */
    public static GeoPoint fuzz(UUID refId, GeoPoint point, double radiusM, String secret) {
        byte[] digest = hmacSha256(secret, uuidBytes(refId));
        double u1 = unitFraction(digest, 0);
        double u2 = unitFraction(digest, 8);
        double distance = radiusM * Math.sqrt(u1);
        double angle = 2 * Math.PI * u2;
        double dlat = distance * Math.cos(angle) / EARTH_RADIUS_M;
        double dlon = distance * Math.sin(angle) / (EARTH_RADIUS_M * Math.cos(Math.toRadians(point.lat())));
        return new GeoPoint(round5(point.lat() + Math.toDegrees(dlat)), round5(point.lon() + Math.toDegrees(dlon)));
    }

    /** Great-circle distance in metres (haversine). */
    public static double distanceM(GeoPoint a, GeoPoint b) {
        double p1 = Math.toRadians(a.lat());
        double p2 = Math.toRadians(b.lat());
        double h = Math.pow(Math.sin((p2 - p1) / 2), 2)
                + Math.cos(p1) * Math.cos(p2) * Math.pow(Math.sin(Math.toRadians(b.lon() - a.lon()) / 2), 2);
        return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
    }

    private static byte[] hmacSha256(String secret, byte[] data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return mac.doFinal(data);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static byte[] uuidBytes(UUID id) {
        return ByteBuffer.allocate(16)
                .putLong(id.getMostSignificantBits())
                .putLong(id.getLeastSignificantBits())
                .array();
    }

    /** 8 bytes as an unsigned big-endian integer, divided by 2^64: a number in [0, 1). */
    private static double unitFraction(byte[] bytes, int offset) {
        return new BigInteger(1, Arrays.copyOfRange(bytes, offset, offset + 8)).doubleValue() / 0x1p64;
    }

    /** Rounds to 5 decimals (about 1 m) the way Python's round() does. */
    private static double round5(double value) {
        return new BigDecimal(value).setScale(5, RoundingMode.HALF_EVEN).doubleValue();
    }
}
