package tn.winou.chat;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Limit;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

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
import tn.winou.domain.MatchStatus;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.infra.Notifications;
import tn.winou.infra.Storage;
import tn.winou.photos.Images;
import tn.winou.photos.PhotoService;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.ConversationOut;
import tn.winou.web.ApiModels.ConversationRole;
import tn.winou.web.ApiModels.Location;
import tn.winou.web.ApiModels.MessageIn;
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
    private final PhotoService photos;
    private final Images images;
    private final Storage storage;

    public ChatService(ConversationRepository conversations, ChatMessageRepository messages, MatchRepository matches,
            LostReportRepository reports, SightingRepository sightings, UserRepository users,
            Notifications notifications, WinouProperties properties, JdbcClient jdbc, PhotoService photos,
            Images images, Storage storage) {
        this.jdbc = jdbc;
        this.photos = photos;
        this.images = images;
        this.storage = storage;
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
        List<Conversation> found = conversations.findForUser(user.getId());
        if (found.isEmpty()) {
            return List.of();
        }
        // A fixed number of queries for the whole list, not five per conversation
        List<UUID> ids = found.stream().map(Conversation::getId).toList();
        Map<UUID, LostReport> reportsById = byId(reports.findAllById(
                found.stream().map(Conversation::getLostReportId).distinct().toList()), LostReport::getId);
        Map<UUID, Match> matchesById = byId(matches.findAllById(
                found.stream().map(Conversation::getMatchId).filter(Objects::nonNull).toList()), Match::getId);
        Map<UUID, User> usersById = byId(users.findAllById(
                found.stream().map(c -> c.otherParticipant(user.getId())).distinct().toList()), User::getId);
        // The newest message each one can see (as findVisible), per conversation
        List<UUID> lastIds = jdbc.sql("""
                        SELECT DISTINCT ON (conversation_id) id FROM messages
                        WHERE conversation_id IN (:ids) AND (hidden_at IS NULL OR sender_id = :me)
                        ORDER BY conversation_id, created_at DESC""")
                .param("ids", ids).param("me", user.getId()).query(UUID.class).list();
        Map<UUID, ChatMessage> lastByConversation = byId(messages.findAllById(lastIds), ChatMessage::getConversationId);
        // Unread: the other one's visible messages since I last read (as the per-conversation counts)
        Map<UUID, Long> unread = new HashMap<>();
        jdbc.sql("""
                        SELECT m.conversation_id, count(*) AS n FROM messages m
                        JOIN conversations c ON c.id = m.conversation_id
                        WHERE c.id IN (:ids) AND m.sender_id <> :me AND m.hidden_at IS NULL
                          AND m.created_at > coalesce(
                              CASE WHEN c.owner_id = :me THEN c.owner_read_at ELSE c.finder_read_at END,
                              '-infinity'::timestamptz)
                        GROUP BY m.conversation_id""")
                .param("ids", ids).param("me", user.getId())
                .query((rs, i) -> unread.put(rs.getObject("conversation_id", UUID.class), rs.getLong("n"))).list();
        return found.stream().map(c -> out(c, user, reportsById.get(c.getLostReportId()),
                c.getMatchId() == null ? null : matchesById.get(c.getMatchId()),
                usersById.get(c.otherParticipant(user.getId())), lastByConversation.get(c.getId()),
                unread.getOrDefault(c.getId(), 0L))).toList();
    }

    private static <T> Map<UUID, T> byId(List<T> items, Function<T, UUID> id) {
        return items.stream().collect(Collectors.toMap(id, Function.identity(), (a, b) -> a));
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
    public MessageOut send(UUID id, MessageIn body, User user) {
        String text = body.body() == null || body.body().isBlank() ? null : body.body().strip();
        if (text == null && body.location() == null) {
            throw ApiException.invalid("A message needs words or a place");
        }
        return deliver(id, user, message -> {
            message.setLocation(body.location() == null ? null : body.location().toPoint());
        }, text);
    }

    /** A photo, as a message of its own (re-encoded without EXIF: no hidden GPS). */
    @Transactional
    public MessageOut sendPhoto(UUID id, MultipartFile file, User user) {
        participantOf(id, user);
        byte[] jpeg = images.publicCopy(photos.bytes(file)).jpeg();
        return deliver(id, user, message -> {
            message.setPhotoKey("chat/" + message.getId() + ".jpg");
            storage.put(message.getPhotoKey(), jpeg, "image/jpeg");
        }, null);
    }

    /** A message's photo, for the two participants; not once the recipient reported it. */
    @Transactional(readOnly = true)
    public byte[] photo(UUID messageId, User user) {
        ChatMessage message = messages.findById(messageId)
                .filter(m -> m.getPhotoKey() != null)
                .filter(m -> conversations.findById(m.getConversationId()).filter(c -> c.hasParticipant(user.getId()))
                        .isPresent())
                .filter(m -> m.getHiddenAt() == null || m.getSenderId().equals(user.getId()))
                .orElseThrow(() -> ApiException.notFound("Photo"));
        return storage.get(message.getPhotoKey());
    }

    private MessageOut deliver(UUID id, User user, java.util.function.Consumer<ChatMessage> fill, String text) {
        Conversation conversation = participantOf(id, user);
        RateLimits.check(messages.countBySenderIdAndCreatedAtGreaterThanEqual(user.getId(),
                OffsetDateTime.now().minusHours(1)), properties.rateLimits().messagesPerHour(), "messages");
        ChatMessage built = new ChatMessage(id, user.getId(), text);
        fill.accept(built);
        ChatMessage message = messages.save(built);
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
        return out(c, viewer, report, match, otherUser, last, unread);
    }

    private ConversationOut out(Conversation c, User viewer, LostReport report, Match match, User otherUser,
            ChatMessage last, long unread) {
        boolean owner = c.getOwnerId().equals(viewer.getId());
        boolean confirmed = match != null && match.getStatus() == MatchStatus.CONFIRMED;
        return new ConversationOut(c.getId(), report.getId(), report.getName(), report.getStatus(), c.getMatchId(),
                match == null ? null : Views.imageUrl(match.getSightingPhotoId()),
                owner ? ConversationRole.OWNER : ConversationRole.FINDER,
                otherUser == null ? "" : otherUser.getDisplayName(),
                otherUser != null && otherUser.isAssociation() ? otherUser.getAssociationName() : null,
                last == null ? null : out(last, viewer), unread, c.getCreatedAt(), confirmed,
                // Before confirmation it would help anyone claim the animal; afterwards it lets the
                // finder check the claim on the animal itself
                !owner && confirmed ? report.getPrivateDetail() : null, report.getMicrochipped());
    }

    private static MessageOut out(ChatMessage m, User viewer) {
        boolean mine = m.getSenderId().equals(viewer.getId());
        return new MessageOut(m.getId(), m.getBody(), mine, m.getHiddenAt() != null,
                m.getCreatedAt(), m.getPhotoKey() == null ? null : "/messages/" + m.getId() + "/photo",
                m.getLocation() == null ? null : Location.of(m.getLocation()), mine ? null : ScamCheck.warning(m.getBody()));
    }
}
