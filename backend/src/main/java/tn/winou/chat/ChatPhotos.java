package tn.winou.chat;

import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import tn.winou.common.AfterCommit;
import tn.winou.infra.Storage;

/**
 * Chat photo files, removed with what they belong to. Messages cascade in Postgres (with their
 * conversation, its lost report or either participant), so the files are collected first.
 */
@Component
public class ChatPhotos {

    private final JdbcClient jdbc;
    private final Storage storage;

    public ChatPhotos(JdbcClient jdbc, Storage storage) {
        this.jdbc = jdbc;
        this.storage = storage;
    }

    /** Call inside the transaction that deletes the lost report. */
    public void reportDeleted(UUID reportId) {
        deleteAfterCommit(jdbc.sql("""
                SELECT m.photo_key FROM messages m JOIN conversations c ON c.id = m.conversation_id
                WHERE c.lost_report_id = :id AND m.photo_key IS NOT NULL""")
                .param("id", reportId).query(String.class).list());
    }

    /** Call inside the transaction that deletes the account (either side of a conversation). */
    public void userDeleted(UUID userId) {
        deleteAfterCommit(jdbc.sql("""
                SELECT m.photo_key FROM messages m JOIN conversations c ON c.id = m.conversation_id
                WHERE (c.owner_id = :id OR c.finder_id = :id) AND m.photo_key IS NOT NULL""")
                .param("id", userId).query(String.class).list());
    }

    /** Call inside the transaction that deletes one message. */
    public void messageDeleted(String photoKey) {
        if (photoKey != null) {
            deleteAfterCommit(List.of(photoKey));
        }
    }

    private void deleteAfterCommit(List<String> keys) {
        if (!keys.isEmpty()) {
            AfterCommit.run(() -> storage.delete(keys));
        }
    }
}
