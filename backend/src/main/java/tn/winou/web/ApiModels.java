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
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import tn.winou.domain.ApiEnum;
import tn.winou.domain.Condition;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.MatchSource;
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

    /** current_password: ignored for an account without one (made with Google). */
    public record PasswordChangeIn(
            @Size(max = 128) String currentPassword,
            @NotNull @Size(min = 8, max = 128) String newPassword) {}

    /** password: ignored for an account without one (made with Google). */
    public record DeleteAccountIn(@Size(max = 128) String password) {}

    /** association_name: set for approved associations, shown with a badge. */
    public record UserOut(
            UUID id,
            String email,
            String displayName,
            Role role,
            String associationName,
            OffsetDateTime createdAt,
            boolean hasPassword, // false for accounts made with Google, until they set one
            boolean emailVerified,
            boolean google) {}

    public record GoogleIn(@NotBlank @Size(max = 4096) String idToken) {}

    public record PasswordResetIn(@NotBlank @Email @Size(max = 320) String email) {}

    public record PasswordResetConfirmIn(
            @NotBlank @Email @Size(max = 320) String email,
            @NotBlank @Size(max = 12) String code,
            @NotNull @Size(min = 8, max = 128) String newPassword) {}

    public record CodeIn(@NotBlank @Size(max = 12) String code) {}

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

    /** reward_tnd, microchipped and contact_phone are optional; the phone is shown to people who see the report. */
    public record LostReportIn(
            @NotNull @Size(min = 1, max = 80) String name,
            @NotNull Species species,
            @Size(max = 2000) String description,
            @NotNull @Valid Location lastSeen,
            @NotNull @PastOrPresent OffsetDateTime lastSeenAt,
            @Min(1) @Max(100000) Integer rewardTnd,
            Boolean microchipped,
            @Pattern(regexp = "^[+0-9 ()-]{6,20}$", message = "a phone number: digits, spaces, + ( ) -") String contactPhone,
            @Size(max = 300) String privateDetail) {}

    /**
     * Null fields are left unchanged. reward_tnd 0 and an empty contact_phone remove them;
     * microchipped can't go back to "not said".
     */
    public record LostReportUpdate(
            @Size(min = 1, max = 80) String name,
            Species species,
            @Size(max = 2000) String description,
            @Valid Location lastSeen,
            @PastOrPresent OffsetDateTime lastSeenAt,
            ReportStatus status,
            @Min(0) @Max(100000) Integer rewardTnd,
            Boolean microchipped,
            @Pattern(regexp = "^([+0-9 ()-]{6,20})?$", message = "a phone number: digits, spaces, + ( ) -")
            String contactPhone,
            @Size(max = 300) String privateDetail) {} // empty removes it

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
            UUID authorId, // for admins only, null for everyone else
            Integer rewardTnd,
            Boolean microchipped, // null: not said
            String contactPhone,
            String privateDetail) {} // the owner's only; null for everyone else

    // --- sightings ---

    public record SightingIn(
            @NotNull Species species,
            @NotNull @Valid Location location,
            @NotNull @PastOrPresent OffsetDateTime seenAt,
            Condition condition,
            @Size(max = 1000) String note,
            Boolean isStray,
            UUID lostReportId, // "I saw this pet": the lost report it's about, matched at once
            Boolean inCare) {} // "I found it and I'm keeping it safe"

    /** Null fields are left unchanged. */
    public record SightingUpdate(
            Species species,
            @Valid Location location,
            @PastOrPresent OffsetDateTime seenAt,
            Condition condition,
            @Size(max = 1000) String note,
            Boolean isStray,
            Boolean inCare) {}

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
            UUID authorId, // for admins only: the reporter is never shown to others
            boolean inCare, // the finder has the animal with them
            StrayCare care) {} // strays only

    /** A stray's care card. sterilised/vaccinated null: nobody knows. */
    public record StrayCare(
            String nickname,
            Boolean sterilised,
            Boolean vaccinated,
            String notes,
            int feeders, // how many people say they feed it
            boolean iFeed,
            OffsetDateTime updatedAt) {}

    /** The whole card, as the form shows it: blank text clears a field. */
    public record StrayCareUpdate(
            @Size(max = 40) String nickname,
            Boolean sterilised,
            Boolean vaccinated,
            @Size(max = 500) String notes) {}

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
            String photoUrl,
            boolean inCare) {} // a sighting whose finder has the animal with them

    public record MapOut(List<MapItem> items, boolean truncated) {} // truncated: more than MAP_MAX_RESULTS, zoom in

    // --- matches ---

    public record MatchOut(
            UUID id,
            UUID lostReportId,
            String lostReportName,
            double score, // 0 for a finder's match the model hasn't scored
            MatchSource source,
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

    /** Words, a place, or both. */
    public record MessageIn(@Size(max = 2000) String body, @Valid Location location) {}

    /** hidden: reported, so the other participant no longer sees it (sent only to its author). */
    /** photo_url needs the user's token (participants only); body is null for a photo or place alone. */
    public record MessageOut(
            UUID id,
            String body,
            boolean mine,
            boolean hidden,
            OffsetDateTime createdAt,
            String photoUrl,
            Location location,
            String warning) {} // for the recipient: "payment" or "link" (chat/ScamCheck), else null

    /** A sighting matched to a lost pet, for the owner's map of where it was seen. */
    public record TrailPoint(
            UUID matchId,
            UUID sightingId,
            Location location,
            OffsetDateTime seenAt,
            MatchStatus status,
            boolean byFinder,
            boolean inCare,
            String photoUrl) {}

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
            OffsetDateTime createdAt,
            boolean matchConfirmed, // the owner said "that's my pet": time to arrange the handover
            String ownerDetail, // the owner's private detail, for the finder once the match is confirmed
            Boolean microchipped) {}

    // --- notifications ---

    /** A push as it was sent: the app writes its text from the keys and args, and opens what data names. */
    public record NotificationOut(
            UUID id,
            String titleKey,
            List<String> titleArgs,
            String bodyKey,
            List<String> bodyArgs,
            String body,
            java.util.Map<String, String> data,
            OffsetDateTime createdAt,
            boolean read) {}

    public record InboxOut(List<NotificationOut> items, long unread) {}

    // --- pets ---

    /** Create: name and species needed. Update: null fields are left unchanged. */
    public record PetIn(
            @Size(min = 1, max = 80) String name,
            Species species,
            @Size(max = 2000) String description,
            Boolean microchipped) {}

    /** open_report_id: the pet's open lost report, if it's missing now. */
    public record PetOut(
            UUID id,
            String name,
            Species species,
            String description,
            Boolean microchipped,
            List<PhotoOut> photos,
            UUID openReportId,
            OffsetDateTime createdAt) {}

    /** Where and when it went missing; the rest comes from the pet's profile. */
    public record PetLostIn(
            @NotNull @Valid Location lastSeen,
            @NotNull @PastOrPresent OffsetDateTime lastSeenAt,
            @Size(max = 2000) String description,
            @Min(1) @Max(100000) Integer rewardTnd,
            @Pattern(regexp = "^([+0-9 ()-]{6,20})?$", message = "a phone number: digits, spaces, + ( ) -")
            String contactPhone,
            @Size(max = 300) String privateDetail) {}

    // --- alert areas ---

    /** radius_km: 1 to 25. lost: pets reported missing; help: animals injured or in need of help. */
    public record AlertAreaIn(
            @NotNull @Valid Location location,
            @NotNull @DecimalMin("1") @DecimalMax("25") Double radiusKm,
            boolean lost,
            boolean help) {}

    public record AlertAreaOut(Location location, double radiusKm, boolean lost, boolean help) {}

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
