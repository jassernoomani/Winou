package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    /** Newest first; the caller reverses the page. */
    List<ChatMessage> findByConversationIdOrderByCreatedAtDesc(UUID conversationId, Limit limit);

    List<ChatMessage> findByConversationIdAndCreatedAtLessThanOrderByCreatedAtDesc(UUID conversationId,
            OffsetDateTime before, Limit limit);

    /** The newest message the viewer can see: theirs, or the other's unless hidden. */
    @Query("""
            select m from ChatMessage m
            where m.conversationId = :conversationId and (m.hiddenAt is null or m.senderId = :viewerId)
            order by m.createdAt desc""")
    List<ChatMessage> findVisible(UUID conversationId, UUID viewerId, Limit limit);

    long countByConversationIdAndSenderIdNotAndHiddenAtIsNullAndCreatedAtGreaterThan(UUID conversationId,
            UUID senderId, OffsetDateTime since);

    long countByConversationIdAndSenderIdNotAndHiddenAtIsNull(UUID conversationId, UUID senderId);

    long countBySenderIdAndCreatedAtGreaterThanEqual(UUID senderId, OffsetDateTime since);
}
