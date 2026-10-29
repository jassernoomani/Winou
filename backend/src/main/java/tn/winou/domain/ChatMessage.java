package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "messages")
@Getter
@NoArgsConstructor
public class ChatMessage extends BaseEntity {

    private UUID conversationId;
    private UUID senderId;
    private String body;
    private OffsetDateTime createdAt = OffsetDateTime.now();

    public ChatMessage(UUID conversationId, UUID senderId, String body) {
        this.conversationId = conversationId;
        this.senderId = senderId;
        this.body = body;
    }
}
