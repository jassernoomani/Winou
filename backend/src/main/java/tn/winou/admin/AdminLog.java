package tn.winou.admin;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import tn.winou.domain.User;
import tn.winou.web.ApiModels.AdminAction;
import tn.winou.web.ApiModels.AdminActionOut;

/** Every admin decision is written down: who did what, to which content, about which user. */
@Component
public class AdminLog {

    private final JdbcClient jdbc;

    public AdminLog(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** [userId]: the account it was about (author, applicant...), null if none. */
    public void record(User admin, AdminAction action, String targetType, UUID targetId, UUID userId, String note) {
        jdbc.sql("""
                        INSERT INTO admin_actions (id, admin_id, action, target_type, target_id, user_id, note, created_at)
                        VALUES (:id, :admin, :action, :type, :target, :user, :note, now())""")
                .param("id", UUID.randomUUID())
                .param("admin", admin.getId())
                .param("action", action.name())
                .param("type", targetType)
                .param("target", targetId)
                .param("user", userId)
                .param("note", note == null || note.isBlank() ? null : note.strip())
                .update();
    }

    /** The latest actions about a user, most recent first. */
    public List<AdminActionOut> about(UUID userId, int limit) {
        return jdbc.sql("""
                        SELECT a.id, a.action, a.target_type, a.target_id, a.note, a.created_at,
                               admin.display_name AS admin_name, u.display_name AS user_name
                        FROM admin_actions a
                        LEFT JOIN users admin ON admin.id = a.admin_id
                        LEFT JOIN users u ON u.id = a.user_id
                        WHERE a.user_id = :user
                        ORDER BY a.created_at DESC LIMIT :limit""")
                .param("user", userId)
                .param("limit", limit)
                .query((rs, i) -> new AdminActionOut(rs.getObject("id", UUID.class),
                        AdminAction.valueOf(rs.getString("action")), rs.getString("target_type"),
                        rs.getObject("target_id", UUID.class), rs.getString("admin_name"), rs.getString("user_name"),
                        rs.getString("note"), rs.getObject("created_at", OffsetDateTime.class)))
                .list();
    }
}
