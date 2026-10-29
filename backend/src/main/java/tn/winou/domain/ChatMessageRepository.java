package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    /** Newest first; the caller reverses the page. */
    List<ChatMessage> findByConversationIdOrderByCreatedAtDesc(UUID conversationId, Limit limit);

    List<ChatMessage> findByConversationIdAndCreatedAtLessThanOrderByCreatedAtDesc(UUID conversationId,
            OffsetDateTime before, Limit limit);

    ChatMessage findFirstByConversationIdOrderByCreatedAtDesc(UUID conversationId);

    long countByConversationIdAndSenderIdNotAndCreatedAtGreaterThan(UUID conversationId, UUID senderId,
            OffsetDateTime since);

    long countByConversationIdAndSenderIdNot(UUID conversationId, UUID senderId);

    long countBySenderIdAndCreatedAtGreaterThanEqual(UUID senderId, OffsetDateTime since);
}
