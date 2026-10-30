package tn.winou.web;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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
import tn.winou.domain.RequestStatus;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.Role;
import tn.winou.domain.Species;
import tn.winou.domain.StrayStatus;

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

    /** refresh_token gets a new pair from POST /auth/refresh when the access token expires. */
    public record TokenOut(String accessToken, String tokenType, String refreshToken) {

        public static TokenOut of(String accessToken, String refreshToken) {
            return new TokenOut(accessToken, "bearer", refreshToken);
        }
    }

    public record RefreshIn(@NotBlank @Size(max = 200) String refreshToken) {}

    public record PasswordChangeIn(
            @NotNull @Size(max = 128) String currentPassword,
            @NotNull @Size(min = 8, max = 128) String newPassword) {}

    public record DeleteAccountIn(@NotNull @Size(max = 128) String password) {}

    /** association_name: set for approved associations, shown with a badge. */
    public record UserOut(
            UUID id, String email, String displayName, Role role, String associationName, OffsetDateTime createdAt) {}

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
            boolean hidden, // reported by several people: only the owner and admins see it
            OffsetDateTime createdAt,
            UUID authorId) {} // for admins only, null for everyone else

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
            StrayStatus strayStatus, // strays only; AROUND for other sightings
            OffsetDateTime strayStatusAt,
            String helpedBy, // the association that marked the stray as helped, if any
            boolean mine,
            List<PhotoOut> photos,
            boolean hidden,
            OffsetDateTime createdAt,
            UUID authorId) {} // for admins only: the reporter is never shown to others

    /** AROUND also says "seen again today": it keeps the stray on the map. */
    public record StrayStatusUpdate(@NotNull StrayStatus status) {}

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

    /** hidden: reported, so the other participant no longer sees it (sent only to its author). */
    public record MessageOut(UUID id, String body, boolean mine, boolean hidden, OffsetDateTime createdAt) {}

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
            String otherAssociation, // the other person's association, if they are one
            MessageOut lastMessage,
            long unread,
            OffsetDateTime createdAt) {}

    // --- associations ---

    public record AssociationRequestIn(
            @NotBlank @Size(max = 120) String organisation,
            @NotBlank @Size(max = 80) String city,
            @NotBlank @Size(max = 200) String contact,
            @Size(max = 1000) String note,
            @NotNull @Valid Location location) {}

    /** user_name and user_email are for the admin reviewing it. */
    public record AssociationRequestOut(
            UUID id,
            String organisation,
            String city,
            String contact,
            String note,
            Location location,
            RequestStatus status,
            String userName,
            String userEmail,
            OffsetDateTime createdAt,
            OffsetDateTime decidedAt) {}

    // --- moderation ---

    public enum ReportTarget {
        LOST_REPORT, SIGHTING, MESSAGE
    }

    public enum ReportReason {
        SPAM, INAPPROPRIATE, FAKE, DANGEROUS, OTHER
    }

    public record ContentReportIn(
            @NotNull ReportTarget targetType,
            @NotNull UUID targetId,
            @NotNull ReportReason reason,
            @Size(max = 500) String note) {}

    /** hidden: this report was one too many, the item is now hidden. */
    public record ContentReportOut(boolean hidden) {}

    /** Reported or hidden content for the admin: what it is, who wrote it, and why people reported it. */
    public record HiddenItemOut(
            ReportTarget targetType,
            UUID targetId,
            String title,
            String text,
            String photoUrl,
            OffsetDateTime hiddenAt, // null while it's still shown
            long reports,
            List<ReportReason> reasons,
            List<String> notes,
            UUID authorId,
            String authorName,
            OffsetDateTime lastReportedAt) {}

    // --- admin ---

    /** banned_until is null unless a ban is running; 9999-12-31 means for good. */
    public record AdminUserOut(
            UUID id,
            String email,
            String displayName,
            Role role,
            String associationName,
            OffsetDateTime createdAt,
            OffsetDateTime bannedUntil,
            String banReason,
            long lostReports,
            long sightings,
            long reportsReceived) {}

    /** What an admin did, and to whom. */
    public record AdminActionOut(
            UUID id,
            AdminAction action,
            String targetType,
            UUID targetId,
            String adminName,
            UUID userId,
            String userName,
            String note,
            OffsetDateTime createdAt) {}

    /** What waits for an admin: the counts on the Admin screen's tabs. */
    public record AdminSummaryOut(long reported, long requests, long hidden) {}

    public record WeekStats(OffsetDateTime weekStart, long lostReports, long sightings, long reunited) {}

    /** The admin dashboard. reunion_rate: found / all lost reports, null before the first one. */
    public record AdminStatsOut(
            long users,
            long newUsersThisWeek,
            long openLostReports,
            long lostReportsTotal,
            long reunited,
            Double reunionRate,
            long sightings,
            long straysOnMap,
            long matchesConfirmed,
            long associations,
            long strayHelpedByAssociations,
            List<WeekStats> weeks) {}

    public record AdminUserDetailOut(
            AdminUserOut user,
            List<LostReportOut> lostReports,
            List<SightingOut> sightings,
            List<AdminActionOut> history) {}

    /** days: how long; none for good. */
    public record BanIn(@Min(1) @Max(3650) Integer days, @Size(max = 500) String reason) {}

    public enum AdminAction {
        APPROVE_ASSOCIATION, REJECT_ASSOCIATION, REVOKE_ASSOCIATION, HIDE_CONTENT, RESTORE_CONTENT,
        DISMISS_REPORTS, DELETE_CONTENT, BAN_USER, UNBAN_USER
    }
}
