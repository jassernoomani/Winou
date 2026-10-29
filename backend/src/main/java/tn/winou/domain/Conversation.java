package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Messages between a lost pet's owner and someone whose sighting matched it. */
@Entity
@Table(name = "conversations")
@Getter
@Setter
@NoArgsConstructor
public class Conversation extends BaseEntity {

    private UUID lostReportId;
    private UUID matchId; // null once the sighting is deleted; the conversation stays
    private UUID ownerId;
    private UUID finderId;
    private OffsetDateTime createdAt = OffsetDateTime.now();
    private OffsetDateTime lastMessageAt;
    private OffsetDateTime ownerReadAt;
    private OffsetDateTime finderReadAt;

    public boolean hasParticipant(UUID userId) {
        return ownerId.equals(userId) || finderId.equals(userId);
    }

    public UUID otherParticipant(UUID userId) {
        return ownerId.equals(userId) ? finderId : ownerId;
    }

    public OffsetDateTime readAt(UUID userId) {
        return ownerId.equals(userId) ? ownerReadAt : finderReadAt;
    }

    public void markRead(UUID userId, OffsetDateTime at) {
        if (ownerId.equals(userId)) {
            ownerReadAt = at;
        } else {
            finderReadAt = at;
        }
    }
}
