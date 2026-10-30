package tn.winou.config;

import java.time.Duration;
import java.util.List;

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
        Worker worker,
        Firebase firebase,
        Strays strays,
        Associations associations,
        Moderation moderation,
        Admin admin,
        Auth auth,
        Google google,
        Share share) {

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

    public record RateLimits(int lostReportsPerDay, int sightingsPerHour, int photosPerHour, int messagesPerHour) {}

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

    /** credentials: path to the service account key; empty means notifications are only logged. */
    public record Firebase(String credentials) {}

    /** Strays not seen or updated for fadeDays leave the map. */
    public record Strays(int fadeDays) {}

    /** Associations hear about injured animals within alertRadiusKm of the place in their request. */
    public record Associations(double alertRadiusKm) {}

    /** Content reported by hideAfterReports different people is hidden until an admin looks at it. */
    public record Moderation(int hideAfterReports, int reportsPerDay) {}

    /**
     * Staying signed in: a refresh token lasts refreshTokenDays without use. Wrong passwords are
     * limited per email and per network address within loginAttemptWindow.
     */
    public record Auth(
            int refreshTokenDays,
            int loginAttemptsPerEmail,
            int loginAttemptsPerIp,
            Duration loginAttemptWindow,
            int registrationsPerIpPerHour) {}

    /** Shared links open the app: Android Digital Asset Links for this package and signing key. */
    public record Share(String androidPackage, String androidCertSha256) {}

    /** Web client IDs whose Google ID tokens are accepted; empty: no Google sign-in. */
    public record Google(List<String> clientIds) {

        public Google {
            clientIds = clientIds == null ? List.of()
                    : clientIds.stream().map(String::strip).filter(id -> !id.isEmpty()).toList();
        }
    }

    /** Accounts with these emails are admins (compared lowercase). */
    public record Admin(List<String> emails) {

        public Admin {
            emails = emails == null ? List.of()
                    : emails.stream().map(e -> e.strip().toLowerCase()).filter(e -> !e.isEmpty()).toList();
        }

        public boolean isAdmin(String email) {
            return emails.contains(email.toLowerCase());
        }
    }
}
