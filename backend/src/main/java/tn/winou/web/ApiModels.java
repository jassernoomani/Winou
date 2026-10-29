package tn.winou.web;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import tn.winou.domain.ApiEnum;
import tn.winou.domain.Condition;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.MatchStatus;
import tn.winou.domain.PhotoStatus;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.Role;
import tn.winou.domain.Species;

/** Request and response bodies. JSON names are snake_case (spring.jackson.property-naming-strategy). */
public final class ApiModels {

    private ApiModels() {}

    public record Location(
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double lon) {

        public static Location of(GeoPoint point) {
            return new Location(point.lat(), point.lon());
        }

        public GeoPoint toPoint() {
            return new GeoPoint(lat, lon);
        }
    }

    // --- auth ---

    public record RegisterIn(
            @NotBlank @Email @Size(max = 320) String email,
            @NotNull @Size(min = 8, max = 128) String password,
            @NotNull @Size(min = 1, max = 80) String displayName) {}

    public record TokenOut(String accessToken, String tokenType) {

        public static TokenOut bearer(String token) {
            return new TokenOut(token, "bearer");
        }
    }

    public record UserOut(UUID id, String email, String displayName, Role role, OffsetDateTime createdAt) {}

    /** fcm_token may be cleared with an explicit null; the name may not. */
    @Getter
    public static final class UserUpdate {

        @Size(min = 1, max = 80)
        private String displayName;

        @Size(max = 4096)
        private String fcmToken;

        private boolean fcmTokenSent;

        public void setDisplayName(String displayName) {
            this.displayName = displayName;
        }

        public void setFcmToken(String fcmToken) {
            this.fcmToken = fcmToken;
            this.fcmTokenSent = true; // called for an explicit null too, not for a missing field
        }
    }

    // --- photos ---

    public record PhotoOut(
            UUID id, PhotoStatus status, String detectedSpecies, String url, String cropUrl, OffsetDateTime createdAt) {}

    // --- lost reports ---

    public record LostReportIn(
            @NotNull @Size(min = 1, max = 80) String name,
            @NotNull Species species,
            @Size(max = 2000) String description,
            @NotNull @Valid Location lastSeen,
            @NotNull @PastOrPresent OffsetDateTime lastSeenAt) {}

    /** Null fields are left unchanged. */
    public record LostReportUpdate(
            @Size(min = 1, max = 80) String name,
            Species species,
            @Size(max = 2000) String description,
            @Valid Location lastSeen,
            @PastOrPresent OffsetDateTime lastSeenAt,
            ReportStatus status) {}

    public record LostReportOut(
            UUID id,
            String name,
            Species species,
            String description,
            Location lastSeen,
            boolean locationIsApproximate, // true unless you own the report
            OffsetDateTime lastSeenAt,
            ReportStatus status,
            List<PhotoOut> photos,
            OffsetDateTime createdAt) {}

    // --- sightings ---

    public record SightingIn(
            @NotNull Species species,
            @NotNull @Valid Location location,
            @NotNull @PastOrPresent OffsetDateTime seenAt,
            Condition condition,
            @Size(max = 1000) String note,
            Boolean isStray) {}

    /** Null fields are left unchanged. */
    public record SightingUpdate(
            Species species,
            @Valid Location location,
            @PastOrPresent OffsetDateTime seenAt,
            Condition condition,
            @Size(max = 1000) String note,
            Boolean isStray) {}

    public record SightingOut(
            UUID id,
            Species species,
            Location location,
            OffsetDateTime seenAt,
            Condition condition,
            String note,
            boolean isStray,
            boolean mine,
            List<PhotoOut> photos,
            OffsetDateTime createdAt) {}

    // --- map ---

    public enum MapType implements ApiEnum {
        LOST, SIGHTING, STRAY;

        @Override
        public String api() {
            return name().toLowerCase();
        }
    }

    public record MapItem(
            MapType type,
            UUID id,
            Species species,
            Location location,
            OffsetDateTime date, // last seen (lost) or seen (sighting/stray)
            String name,
            Condition condition,
            String photoUrl) {}

    public record MapOut(List<MapItem> items, boolean truncated) {} // truncated: more than MAP_MAX_RESULTS, zoom in

    // --- matches ---

    public record MatchOut(
            UUID id,
            UUID lostReportId,
            String lostReportName,
            double score,
            MatchStatus status,
            SightingOut sighting,
            String lostPhotoUrl,
            String sightingPhotoUrl,
            ReportStatus reportStatus,
            UUID conversationId, // null until the owner starts one
            OffsetDateTime createdAt) {}

    /** PENDING undoes a rejection. */
    public record MatchUpdate(@NotNull MatchStatus status) {}

    // --- conversations ---

    public enum ConversationRole implements ApiEnum {
        OWNER("owner"), FINDER("finder");

        private final String api;

        ConversationRole(String api) {
            this.api = api;
        }

        @Override
        public String api() {
            return api;
        }
    }

    public record MessageIn(@NotBlank @Size(max = 2000) String body) {}

    public record MessageOut(UUID id, String body, boolean mine, OffsetDateTime createdAt) {}

    /** Seen by one participant: "other" is the person they talk to (display name only, never an email). */
    public record ConversationOut(
            UUID id,
            UUID lostReportId,
            String petName,
            ReportStatus reportStatus, // not OPEN: the case is closed
            UUID matchId,
            String sightingPhotoUrl,
            ConversationRole myRole,
            String otherName,
            MessageOut lastMessage,
            long unread,
            OffsetDateTime createdAt) {}
}
