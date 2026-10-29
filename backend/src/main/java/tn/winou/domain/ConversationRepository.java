package tn.winou.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByMatchId(UUID matchId);

    List<Conversation> findByMatchIdIn(List<UUID> matchIds);

    @Query("""
            select c from Conversation c
            where c.ownerId = :userId or c.finderId = :userId
            order by coalesce(c.lastMessageAt, c.createdAt) desc""")
    List<Conversation> findForUser(UUID userId);
}
