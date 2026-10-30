package tn.winou.infra;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;
import tn.winou.infra.PushSender.Push;
import tn.winou.web.ApiModels.InboxOut;
import tn.winou.web.ApiModels.NotificationOut;

/** The notifications list: every push a user was sent, the latest [KEEP] of them. */
@Component
public class Inbox {

    static final int KEEP = 100;

    private final JdbcClient jdbc;
    private final JsonMapper json;

    public Inbox(JdbcClient jdbc, JsonMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public void save(UUID userId, Push push) {
        jdbc.sql("""
                        INSERT INTO notifications (id, user_id, title_key, title_args, body_key, body_args, body, data,
                                                   created_at)
                        VALUES (:id, :user, :titleKey, CAST(:titleArgs AS jsonb), :bodyKey, CAST(:bodyArgs AS jsonb),
                                :body, CAST(:data AS jsonb), now())""")
                .param("id", UUID.randomUUID())
                .param("user", userId)
                .param("titleKey", push.titleKey())
                .param("titleArgs", json.writeValueAsString(push.titleArgs()))
                .param("bodyKey", push.bodyKey())
                .param("bodyArgs", json.writeValueAsString(push.bodyArgs()))
                .param("body", push.body())
                .param("data", json.writeValueAsString(push.data()))
                .update();
        jdbc.sql("""
                        DELETE FROM notifications WHERE user_id = :user AND id NOT IN (
                          SELECT id FROM notifications WHERE user_id = :user ORDER BY created_at DESC LIMIT :keep)""")
                .param("user", userId)
                .param("keep", KEEP)
                .update();
    }

    /** Newest first, before [before] if given; with how many are unread in all. */
    public InboxOut list(UUID userId, OffsetDateTime before, int limit) {
        List<NotificationOut> items = jdbc.sql("""
                        SELECT id, title_key, title_args::text, body_key, body_args::text, body, data::text, created_at,
                               read_at
                        FROM notifications
                        WHERE user_id = :user AND (CAST(:before AS timestamptz) IS NULL OR created_at < :before)
                        ORDER BY created_at DESC LIMIT :limit""")
                .param("user", userId)
                .param("before", before)
                .param("limit", limit)
                .query((rs, i) -> new NotificationOut(rs.getObject("id", UUID.class), rs.getString("title_key"),
                        strings(rs.getString("title_args")), rs.getString("body_key"),
                        strings(rs.getString("body_args")), rs.getString("body"), map(rs.getString("data")),
                        rs.getObject("created_at", OffsetDateTime.class), rs.getObject("read_at") != null))
                .list();
        long unread = jdbc.sql("SELECT count(*) FROM notifications WHERE user_id = :user AND read_at IS NULL")
                .param("user", userId)
                .query(Long.class).single();
        return new InboxOut(items, unread);
    }

    public void markAllRead(UUID userId) {
        jdbc.sql("UPDATE notifications SET read_at = now() WHERE user_id = :user AND read_at IS NULL")
                .param("user", userId)
                .update();
    }

    private List<String> strings(String text) {
        return json.readValue(text, new TypeReference<List<String>>() {});
    }

    private Map<String, String> map(String text) {
        return json.readValue(text, new TypeReference<Map<String, String>>() {});
    }
}
