package tn.winou.moderation;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.admin.AdminLog;
import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.ChatMessage;
import tn.winou.domain.ChatMessageRepository;
import tn.winou.domain.ConversationRepository;
import tn.winou.domain.User;
import tn.winou.reports.LostReportService;
import tn.winou.security.Admins;
import tn.winou.sightings.SightingService;
import tn.winou.web.ApiModels.AdminAction;
import tn.winou.web.ApiModels.ContentReportIn;
import tn.winou.web.ApiModels.ContentReportOut;
import tn.winou.web.ApiModels.HiddenItemOut;
import tn.winou.web.ApiModels.ReportReason;
import tn.winou.web.ApiModels.ReportTarget;
import tn.winou.web.Views;

/**
 * The "Report" button. Content reported by enough different people is hidden at once, without
 * waiting for anyone; an admin then restores it (clearing its reports) or deletes it. A message
 * can only be seen, so reported, by its recipient: one report hides it.
 */
@Service
public class ModerationService {

    private final JdbcClient jdbc;
    private final LostReportService reports;
    private final SightingService sightings;
    private final ChatMessageRepository messages;
    private final ConversationRepository conversations;
    private final AdminLog log;
    private final WinouProperties.Moderation settings;

    public ModerationService(JdbcClient jdbc, LostReportService reports, SightingService sightings,
            ChatMessageRepository messages, ConversationRepository conversations, AdminLog log,
            WinouProperties properties) {
        this.log = log;
        this.jdbc = jdbc;
        this.reports = reports;
        this.sightings = sightings;
        this.messages = messages;
        this.conversations = conversations;
        this.settings = properties.moderation();
    }

    @Transactional
    public ContentReportOut report(ContentReportIn body, User user) {
        UUID author = authorOf(body.targetType(), body.targetId(), user);
        if (author.equals(user.getId())) {
            throw ApiException.invalid("You can't report your own content");
        }
        long today = jdbc.sql("SELECT count(*) FROM content_reports WHERE reporter_id = :user AND created_at >= :since")
                .param("user", user.getId())
                .param("since", OffsetDateTime.now().minusDays(1))
                .query(Long.class).single();
        RateLimits.check(today, settings.reportsPerDay(), "reports");
        // Reporting twice changes nothing
        jdbc.sql("""
                        INSERT INTO content_reports (id, reporter_id, target_type, target_id, reason, note, created_at)
                        VALUES (:id, :user, :type, :target, :reason, :note, now())
                        ON CONFLICT (reporter_id, target_type, target_id) DO NOTHING""")
                .param("id", UUID.randomUUID())
                .param("user", user.getId())
                .param("type", body.targetType().name())
                .param("target", body.targetId())
                .param("reason", body.reason().name())
                .param("note", body.note() == null || body.note().isBlank() ? null : body.note().strip())
                .update();
        long reporters = jdbc.sql("""
                        SELECT count(DISTINCT reporter_id) FROM content_reports
                        WHERE target_type = :type AND target_id = :target""")
                .param("type", body.targetType().name())
                .param("target", body.targetId())
                .query(Long.class).single();
        int needed = body.targetType() == ReportTarget.MESSAGE ? 1 : settings.hideAfterReports();
        if (reporters < needed) {
            return new ContentReportOut(false);
        }
        jdbc.sql("UPDATE " + table(body.targetType()) + " SET hidden_at = now() WHERE id = :id AND hidden_at IS NULL")
                .param("id", body.targetId())
                .update();
        return new ContentReportOut(true);
    }

    /** Who wrote it. 404 for content the user can't see, so reporting can't probe for it. */
    private UUID authorOf(ReportTarget type, UUID id, User user) {
        return switch (type) {
            case LOST_REPORT -> reports.visible(id, user).getOwnerId();
            case SIGHTING -> sightings.visible(id, user).getReporterId();
            case MESSAGE -> {
                ChatMessage message = messages.findById(id)
                        .filter(m -> conversations.findById(m.getConversationId())
                                .filter(c -> c.hasParticipant(user.getId())).isPresent())
                        .filter(m -> m.getHiddenAt() == null || m.getSenderId().equals(user.getId()))
                        .orElseThrow(() -> ApiException.notFound("Message"));
                yield message.getSenderId();
            }
        };
    }

    /** Hidden content, the most recently hidden first, with why people reported it. */
    @Transactional(readOnly = true)
    public List<HiddenItemOut> hidden(User admin) {
        Admins.require(admin);
        record Item(ReportTarget type, UUID id, String title, String text, UUID photoId, OffsetDateTime hiddenAt) {}
        List<Item> items = new ArrayList<>();
        items.addAll(jdbc.sql("""
                        SELECT r.id, r.name, r.description, r.hidden_at,
                               (SELECT p.id FROM photos p WHERE p.lost_report_id = r.id ORDER BY p.created_at LIMIT 1) AS photo_id
                        FROM lost_reports r WHERE r.hidden_at IS NOT NULL""")
                .query((rs, i) -> new Item(ReportTarget.LOST_REPORT, rs.getObject("id", UUID.class),
                        rs.getString("name"), rs.getString("description"), rs.getObject("photo_id", UUID.class),
                        rs.getObject("hidden_at", OffsetDateTime.class))).list());
        items.addAll(jdbc.sql("""
                        SELECT s.id, s.species, s.note, s.hidden_at,
                               (SELECT p.id FROM photos p WHERE p.sighting_id = s.id ORDER BY p.created_at LIMIT 1) AS photo_id
                        FROM sightings s WHERE s.hidden_at IS NOT NULL""")
                .query((rs, i) -> new Item(ReportTarget.SIGHTING, rs.getObject("id", UUID.class),
                        rs.getString("species"), rs.getString("note"), rs.getObject("photo_id", UUID.class),
                        rs.getObject("hidden_at", OffsetDateTime.class))).list());
        items.addAll(jdbc.sql("""
                        SELECT m.id, u.display_name, m.body, m.hidden_at
                        FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.hidden_at IS NOT NULL""")
                .query((rs, i) -> new Item(ReportTarget.MESSAGE, rs.getObject("id", UUID.class),
                        rs.getString("display_name"), rs.getString("body"), null,
                        rs.getObject("hidden_at", OffsetDateTime.class))).list());
        if (items.isEmpty()) {
            return List.of();
        }

        record Reason(UUID target, ReportReason reason, String note) {}
        Map<UUID, List<Reason>> reasons = jdbc.sql("""
                        SELECT target_id, reason, note FROM content_reports
                        WHERE target_id IN (:ids) ORDER BY created_at""")
                .param("ids", items.stream().map(Item::id).toList())
                .query((rs, i) -> new Reason(rs.getObject("target_id", UUID.class),
                        ReportReason.valueOf(rs.getString("reason")), rs.getString("note")))
                .list().stream().collect(Collectors.groupingBy(Reason::target));
        return items.stream()
                .sorted(Comparator.comparing(Item::hiddenAt).reversed())
                .map(item -> {
                    List<Reason> why = reasons.getOrDefault(item.id(), List.of());
                    return new HiddenItemOut(item.type(), item.id(), item.title(), item.text(),
                            Views.imageUrl(item.photoId()), item.hiddenAt(), why.size(),
                            why.stream().map(Reason::reason).distinct().toList(),
                            why.stream().map(Reason::note).filter(n -> n != null).toList());
                }).toList();
    }

    /** Shows it again and forgets its reports, so the same reports can't hide it at once. */
    @Transactional
    public void restore(ReportTarget type, UUID id, User admin) {
        Admins.require(admin);
        int restored = jdbc.sql("UPDATE " + table(type) + " SET hidden_at = NULL WHERE id = :id AND hidden_at IS NOT NULL")
                .param("id", id)
                .update();
        if (restored == 0) {
            throw ApiException.notFound("Hidden content");
        }
        log.record(admin, AdminAction.RESTORE_CONTENT, type.name(), id, authorId(type, id), null);
        forgetReports(type, id);
    }

    @Transactional
    public void delete(ReportTarget type, UUID id, User admin) {
        Admins.require(admin);
        UUID author = authorId(type, id);
        switch (type) {
            case LOST_REPORT -> reports.delete(id, admin);
            case SIGHTING -> sightings.delete(id, admin);
            case MESSAGE -> messages.delete(messages.findById(id).orElseThrow(() -> ApiException.notFound("Message")));
        }
        log.record(admin, AdminAction.DELETE_CONTENT, type.name(), id, author, null);
        forgetReports(type, id);
    }

    /** Who wrote it, null if it doesn't exist. */
    private UUID authorId(ReportTarget type, UUID id) {
        String column = switch (type) {
            case LOST_REPORT -> "owner_id";
            case SIGHTING -> "reporter_id";
            case MESSAGE -> "sender_id";
        };
        return jdbc.sql("SELECT " + column + " FROM " + table(type) + " WHERE id = :id")
                .param("id", id)
                .query(UUID.class).optional().orElse(null);
    }

        private void forgetReports(ReportTarget type, UUID id) {
        jdbc.sql("DELETE FROM content_reports WHERE target_type = :type AND target_id = :id")
                .param("type", type.name())
                .param("id", id)
                .update();
    }

    private static String table(ReportTarget type) {
        return switch (type) {
            case LOST_REPORT -> "lost_reports";
            case SIGHTING -> "sightings";
            case MESSAGE -> "messages";
        };
    }
}
