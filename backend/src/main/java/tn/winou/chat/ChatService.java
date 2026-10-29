package tn.winou.chat;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Limit;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.ChatMessage;
import tn.winou.domain.ChatMessageRepository;
import tn.winou.domain.Conversation;
import tn.winou.domain.ConversationRepository;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.infra.Notifications;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.ConversationOut;
import tn.winou.web.ApiModels.ConversationRole;
import tn.winou.web.ApiModels.MessageOut;
import tn.winou.web.Views;

/**
 * Owner <-> finder messaging. Only the owner can start a conversation, from a match, so nobody
 * can message an owner out of the blue; the finder answers. Participants see each other's display
 * name only.
 */
@Service
public class ChatService {

    private final ConversationRepository conversations;
    private final ChatMessageRepository messages;
    private final MatchRepository matches;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final UserRepository users;
    private final Notifications notifications;
    private final WinouProperties properties;
    private final JdbcClient jdbc;

    public ChatService(ConversationRepository conversations, ChatMessageRepository messages, MatchRepository matches,
            LostReportRepository reports, SightingRepository sightings, UserRepository users,
            Notifications notifications, WinouProperties properties, JdbcClient jdbc) {
        this.jdbc = jdbc;
        this.conversations = conversations;
        this.messages = messages;
        this.matches = matches;
        this.reports = reports;
        this.sightings = sightings;
        this.users = users;
        this.notifications = notifications;
        this.properties = properties;
    }

    /** The match's conversation, created on first use. */
    @Transactional
    public ConversationOut start(UUID matchId, User user) {
        Match match = matches.findById(matchId).orElseThrow(() -> ApiException.notFound("Match"));
        LostReport report = reports.findById(match.getLostReportId()).orElseThrow();
        CurrentUserResolver.requireOwnerOrAdmin(user, report.getOwnerId());
        if (conversations.findByMatchId(matchId).isEmpty()) {
            Sighting sighting = sightings.findById(match.getSightingId()).orElseThrow();
            // ON CONFLICT: two taps at the same time open the same conversation
            jdbc.sql("""
                            INSERT INTO conversations (id, lost_report_id, match_id, owner_id, finder_id, created_at)
                            VALUES (:id, :report, :match, :owner, :finder, now())
                            ON CONFLICT (match_id) DO NOTHING""")
                    .param("id", UUID.randomUUID())
                    .param("report", report.getId())
                    .param("match", matchId)
                    .param("owner", report.getOwnerId())
                    .param("finder", sighting.getReporterId())
                    .update();
        }
        return out(conversations.findByMatchId(matchId).orElseThrow(), user);
    }

    @Transactional(readOnly = true)
    public List<ConversationOut> mine(User user) {
        return conversations.findForUser(user.getId()).stream().map(c -> out(c, user)).toList();
    }

    @Transactional(readOnly = true)
    public ConversationOut get(UUID id, User user) {
        return out(participantOf(id, user), user);
    }

    /** Oldest first: the newest `limit` messages, or those before `before` to scroll back. Reading marks them read. */
    @Transactional
    public List<MessageOut> messages(UUID id, OffsetDateTime before, int limit, User user) {
        Conversation conversation = participantOf(id, user);
        List<ChatMessage> page = before == null
                ? messages.findByConversationIdOrderByCreatedAtDesc(id, Limit.of(limit))
                : messages.findByConversationIdAndCreatedAtLessThanOrderByCreatedAtDesc(id, before, Limit.of(limit));
        if (before == null) {
            conversation.markRead(user.getId(), OffsetDateTime.now());
            conversations.save(conversation);
        }
        List<MessageOut> out = new ArrayList<>(page.stream()
                .filter(m -> m.getHiddenAt() == null || m.getSenderId().equals(user.getId()))
                .map(m -> out(m, user)).toList());
        Collections.reverse(out);
        return out;
    }

    @Transactional
    public MessageOut send(UUID id, String body, User user) {
        Conversation conversation = participantOf(id, user);
        RateLimits.check(messages.countBySenderIdAndCreatedAtGreaterThanEqual(user.getId(),
                OffsetDateTime.now().minusHours(1)), properties.rateLimits().messagesPerHour(), "messages");
        ChatMessage message = messages.save(new ChatMessage(id, user.getId(), body.strip()));
        conversation.setLastMessageAt(message.getCreatedAt());
        conversation.markRead(user.getId(), message.getCreatedAt());
        conversations.save(conversation);
        notifications.send(n -> n.newMessage(conversation, message));
        return out(message, user);
    }

    /** 404 for strangers, so they can't even tell the conversation exists. */
    private Conversation participantOf(UUID id, User user) {
        return conversations.findById(id)
                .filter(c -> c.hasParticipant(user.getId()))
                .orElseThrow(() -> ApiException.notFound("Conversation"));
    }

    private ConversationOut out(Conversation c, User viewer) {
        LostReport report = reports.findById(c.getLostReportId()).orElseThrow();
        Match match = c.getMatchId() == null ? null : matches.findById(c.getMatchId()).orElse(null);
        UUID other = c.otherParticipant(viewer.getId());
        User otherUser = users.findById(other).orElse(null);
        ChatMessage last = messages.findVisible(c.getId(), viewer.getId(), Limit.of(1)).stream().findFirst().orElse(null);
        OffsetDateTime readAt = c.readAt(viewer.getId());
        long unread = readAt == null
                ? messages.countByConversationIdAndSenderIdNotAndHiddenAtIsNull(c.getId(), viewer.getId())
                : messages.countByConversationIdAndSenderIdNotAndHiddenAtIsNullAndCreatedAtGreaterThan(c.getId(),
                        viewer.getId(), readAt);
        return new ConversationOut(c.getId(), report.getId(), report.getName(), report.getStatus(), c.getMatchId(),
                match == null ? null : Views.imageUrl(match.getSightingPhotoId()),
                c.getOwnerId().equals(viewer.getId()) ? ConversationRole.OWNER : ConversationRole.FINDER,
                otherUser == null ? "" : otherUser.getDisplayName(),
                otherUser != null && otherUser.isAssociation() ? otherUser.getAssociationName() : null,
                last == null ? null : out(last, viewer), unread, c.getCreatedAt());
    }

    private static MessageOut out(ChatMessage m, User viewer) {
        return new MessageOut(m.getId(), m.getBody(), m.getSenderId().equals(viewer.getId()), m.getHiddenAt() != null,
                m.getCreatedAt());
    }
}
