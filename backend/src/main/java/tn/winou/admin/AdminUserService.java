package tn.winou.admin;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Role;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.security.Admins;
import tn.winou.web.ApiModels.AdminAction;
import tn.winou.web.ApiModels.AdminUserDetailOut;
import tn.winou.web.ApiModels.AdminUserOut;
import tn.winou.web.ApiModels.BanIn;
import tn.winou.web.Views;

/** Admins look users up, ban and unban them, and take back association status. */
@Service
public class AdminUserService {

    private static final int HISTORY = 50;

    /** With how much they posted, and how often what they posted was reported. */
    private static final String SUMMARY = """
            SELECT u.id, u.email, u.display_name, u.role, u.association_name, u.created_at,
                   CASE WHEN u.banned_until > now() THEN u.banned_until END AS banned_until,
                   CASE WHEN u.banned_until > now() THEN u.ban_reason END AS ban_reason,
                   (SELECT count(*) FROM lost_reports r WHERE r.owner_id = u.id) AS lost_reports,
                   (SELECT count(*) FROM sightings s WHERE s.reporter_id = u.id) AS sightings,
                   (SELECT count(*) FROM content_reports c
                    WHERE c.target_type = 'LOST_REPORT' AND c.target_id IN (SELECT id FROM lost_reports WHERE owner_id = u.id)
                       OR c.target_type = 'SIGHTING' AND c.target_id IN (SELECT id FROM sightings WHERE reporter_id = u.id)
                       OR c.target_type = 'MESSAGE' AND c.target_id IN (SELECT id FROM messages WHERE sender_id = u.id)
                   ) AS reports_received
            FROM users u""";

    private final JdbcClient jdbc;
    private final UserRepository users;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final Views views;
    private final AdminLog log;

    public AdminUserService(JdbcClient jdbc, UserRepository users, LostReportRepository reports,
            SightingRepository sightings, Views views, AdminLog log) {
        this.jdbc = jdbc;
        this.users = users;
        this.reports = reports;
        this.sightings = sightings;
        this.views = views;
        this.log = log;
    }

    /** Newest accounts first. [query] matches the name or the email; [banned]: only those banned now. */
    @Transactional(readOnly = true)
    public List<AdminUserOut> search(String query, boolean banned, int limit, int offset, User admin) {
        Admins.require(admin);
        StringBuilder sql = new StringBuilder(SUMMARY).append(" WHERE true");
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            sql.append(" AND (u.email ILIKE :like ESCAPE '\\' OR u.display_name ILIKE :like ESCAPE '\\')");
            params.put("like", "%" + query.strip().replaceAll("([\\\\%_])", "\\\\$1") + "%");
        }
        if (banned) {
            sql.append(" AND u.banned_until > now()");
        }
        sql.append(" ORDER BY u.created_at DESC, u.id LIMIT :limit OFFSET :offset");
        params.put("limit", limit);
        params.put("offset", offset);
        return jdbc.sql(sql.toString()).params(params).query((rs, i) -> summary(rs)).list();
    }

    /** The account, everything they posted (hidden too), and what admins did about them. */
    @Transactional(readOnly = true)
    public AdminUserDetailOut detail(UUID id, User admin) {
        Admins.require(admin);
        return new AdminUserDetailOut(summary(id),
                views.reports(reports.findByOwnerIdOrderByCreatedAtDesc(id), admin),
                views.sightings(sightings.findByReporterIdOrderByCreatedAtDesc(id), admin),
                log.about(id, HISTORY));
    }

    @Transactional
    public AdminUserOut ban(UUID id, BanIn body, User admin) {
        Admins.require(admin);
        User user = find(id);
        if (user.getRole() == Role.ADMIN) {
            throw ApiException.invalid("Admins can't be banned");
        }
        user.setBannedUntil(body.days() == null ? User.BANNED_FOREVER : OffsetDateTime.now().plusDays(body.days()));
        user.setBanReason(body.reason() == null || body.reason().isBlank() ? null : body.reason().strip());
        users.saveAndFlush(user); // summary() reads it back with SQL
        log.record(admin, AdminAction.BAN_USER, "USER", id, id,
                (body.days() == null ? "permanent" : body.days() + " days")
                        + (user.getBanReason() == null ? "" : ": " + user.getBanReason()));
        return summary(id);
    }

    @Transactional
    public AdminUserOut unban(UUID id, User admin) {
        Admins.require(admin);
        User user = find(id);
        if (!user.isBanned()) {
            throw ApiException.coded(HttpStatus.CONFLICT, "not_banned", "This account isn't banned.");
        }
        user.setBannedUntil(null);
        user.setBanReason(null);
        users.saveAndFlush(user); // summary() reads it back with SQL
        log.record(admin, AdminAction.UNBAN_USER, "USER", id, id, null);
        return summary(id);
    }

    /** No more badge or injured-animal alerts. They can apply again. An admin stays admin. */
    @Transactional
    public AdminUserOut revokeAssociation(UUID id, User admin) {
        Admins.require(admin);
        User user = find(id);
        if (user.getAssociationName() == null) {
            throw ApiException.coded(HttpStatus.CONFLICT, "not_association", "This account isn't an association.");
        }
        String name = user.getAssociationName();
        if (user.getRole() == Role.ASSOCIATION) {
            user.setRole(Role.USER);
        }
        user.setAssociationName(null);
        user.setAlertLocation(null);
        users.saveAndFlush(user); // summary() reads it back with SQL
        log.record(admin, AdminAction.REVOKE_ASSOCIATION, "USER", id, id, name);
        return summary(id);
    }

    private User find(UUID id) {
        return users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
    }

    private AdminUserOut summary(UUID id) {
        return jdbc.sql(SUMMARY + " WHERE u.id = :id").param("id", id).query((rs, i) -> summary(rs)).optional()
                .orElseThrow(() -> ApiException.notFound("User"));
    }

    private static AdminUserOut summary(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new AdminUserOut(rs.getObject("id", UUID.class), rs.getString("email"), rs.getString("display_name"),
                Role.valueOf(rs.getString("role")), rs.getString("association_name"),
                rs.getObject("created_at", OffsetDateTime.class), rs.getObject("banned_until", OffsetDateTime.class),
                rs.getString("ban_reason"), rs.getLong("lost_reports"), rs.getLong("sightings"),
                rs.getLong("reports_received"));
    }
}
