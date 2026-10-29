package tn.winou.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

import tn.winou.domain.Species;

/** Settings under "winou" in application.yml, each overridable by an environment variable. */
@ConfigurationProperties("winou")
public record WinouProperties(
        Jwt jwt,
        Ml ml,
        Qdrant qdrant,
        S3 s3,
        Uploads uploads,
        Privacy privacy,
        Map map,
        RateLimits rateLimits,
        Matching matching,
        Worker worker) {

    public record Jwt(String secret, Duration expiry) {}

    public record Ml(String url, Duration timeout) {}

    public record Qdrant(String url, String apiKey, String collection, int embedDim) {}

    public record S3(String endpoint, boolean secure, String accessKey, String secretKey, String bucket) {}

    public record Uploads(double maxMb, long maxImagePixels, int publicImageMaxSide) {

        public long maxBytes() {
            return (long) (maxMb * 1_000_000);
        }
    }

    public record Privacy(double locationFuzzM, String locationFuzzSecret) {}

    public record Map(int maxResults) {}

    public record RateLimits(int lostReportsPerDay, int sightingsPerHour, int photosPerHour) {}

    public record Matching(
            double thresholdDog,
            double thresholdCat,
            double radiusKm,
            int lostWindowDays,
            int sightingGraceDays,
            int maxNotifications) {

        public double threshold(Species species) {
            return switch (species) {
                case DOG -> thresholdDog;
                case CAT -> thresholdCat;
                case OTHER -> throw new IllegalArgumentException("species 'other' is never matched");
            };
        }
    }

    public record Worker(boolean enabled, Duration poll, int maxAttempts) {}
}
