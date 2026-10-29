package tn.winou.infra;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tn.winou.domain.ChatMessage;
import tn.winou.domain.Conversation;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.infra.PushSender.Push;

/** Push notifications. A failed push never fails the action that caused it. */
public class PushNotifier implements Notifier {

    private static final Logger log = LoggerFactory.getLogger(PushNotifier.class);
    private static final int PREVIEW_CHARS = 300;

    private final PushSender sender;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final UserRepository users;

    public PushNotifier(PushSender sender, LostReportRepository reports, SightingRepository sightings,
            UserRepository users) {
        this.sender = sender;
        this.reports = reports;
        this.sightings = sightings;
        this.users = users;
    }

    @Override
    public void matchFound(Match match) {
        LostReport report = reports.findById(match.getLostReportId()).orElseThrow();
        String pet = report.getName();
        push(report.getOwnerId(), new Push("match_title", List.of(), "match_body", List.of(pet), null,
                "match-" + match.getId(), Map.of("type", "match", "match_id", match.getId().toString(),
                        "lost_report_id", report.getId().toString(), "pet_name", pet)));
    }

    @Override
    public void matchConfirmed(Match match) {
        String pet = reports.findById(match.getLostReportId()).orElseThrow().getName();
        sightings.findById(match.getSightingId()).ifPresent(sighting -> push(sighting.getReporterId(),
                new Push("confirmed_title", List.of(), "confirmed_body", List.of(pet), null,
                        "confirmed-" + match.getId(), Map.of("type", "confirmed", "pet_name", pet))));
    }

    @Override
    public void petFound(LostReport report, List<UUID> finderIds) {
        String pet = report.getName();
        for (UUID finder : finderIds) {
            push(finder, new Push("found_title", List.of(pet), "found_body", List.of(pet), null,
                    "found-" + report.getId(), Map.of("type", "found", "pet_name", pet)));
        }
    }

    @Override
    public void newMessage(Conversation conversation, ChatMessage message) {
        String pet = reports.findById(conversation.getLostReportId()).map(LostReport::getName).orElse("");
        String sender = users.findById(message.getSenderId()).map(User::getDisplayName).orElse("");
        String body = message.getBody().length() > PREVIEW_CHARS
                ? message.getBody().substring(0, PREVIEW_CHARS) + "…"
                : message.getBody();
        push(conversation.otherParticipant(message.getSenderId()),
                new Push("message_title", List.of(sender, pet), null, List.of(), body,
                        "conversation-" + conversation.getId(), Map.of("type", "message",
                                "conversation_id", conversation.getId().toString(), "sender_name", sender,
                                "pet_name", pet)));
    }

    private void push(UUID userId, Push push) {
        User user = users.findById(userId).orElse(null);
        if (user == null || user.getFcmToken() == null) {
            log.info("{}: user {} has no device registered", push.tag(), userId);
            return;
        }
        switch (sender.send(user.getFcmToken(), push)) {
            case SENT -> log.info("{}: pushed to user {}", push.tag(), userId);
            case TOKEN_GONE -> {
                log.info("{}: device token of user {} is no longer valid, removing it", push.tag(), userId);
                user.setFcmToken(null);
                users.save(user);
            }
            case FAILED -> { } // logged by the sender; the app still shows it
        }
    }
}
