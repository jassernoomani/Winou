package tn.winou.infra;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tn.winou.domain.AssociationRequest;
import tn.winou.domain.ChatMessage;
import tn.winou.domain.Conversation;
import tn.winou.domain.LostReport;
import tn.winou.domain.Match;
import tn.winou.domain.Sighting;
import tn.winou.web.ApiModels.ReportTarget;

/** Logs events only: used when no Firebase key is configured. */
public class LogNotifier implements Notifier {

    private static final Logger log = LoggerFactory.getLogger(LogNotifier.class);

    @Override
    public void matchFound(Match match) {
        log.info("match {}: lost report {} <-> sighting {} (score {})",
                match.getId(), match.getLostReportId(), match.getSightingId(), String.format("%.3f", match.getScore()));
    }

    @Override
    public void matchConfirmed(Match match) {
        log.info("match {}: confirmed by the owner", match.getId());
    }

    @Override
    public void petFound(LostReport report, List<UUID> finderIds) {
        log.info("lost report {}: found, thanking {} finder(s)", report.getId(), finderIds.size());
    }

    @Override
    public void newMessage(Conversation conversation, ChatMessage message) {
        log.info("conversation {}: new message {}", conversation.getId(), message.getId());
    }

    @Override
    public void animalNeedsHelp(Sighting sighting, List<UUID> associationIds) {
        log.info("sighting {}: {}, alerting {} association(s)", sighting.getId(), sighting.getCondition(),
                associationIds.size());
    }

    @Override
    public void lostNearby(LostReport report, List<UUID> userIds) {
        log.info("lost report {}: telling {} user(s) watching the area", report.getId(), userIds.size());
    }

    @Override
    public void associationDecided(AssociationRequest request) {
        log.info("association request {}: {}", request.getId(), request.getStatus());
    }

    @Override
    public void contentHidden(ReportTarget type, UUID id) {
        log.info("{} {}: hidden after reports, telling admins", type, id);
    }

    @Override
    public void associationRequested(AssociationRequest request) {
        log.info("association request {}: telling admins", request.getId());
    }
}
