package tn.winou.infra;

import java.util.List;
import java.util.UUID;

import tn.winou.domain.AssociationRequest;
import tn.winou.domain.ChatMessage;
import tn.winou.domain.Conversation;
import tn.winou.domain.LostReport;
import tn.winou.domain.Match;
import tn.winou.domain.Sighting;
import tn.winou.web.ApiModels.ReportTarget;

/** Tells users what happened to a case. Implementations never throw for a failed delivery. */
public interface Notifier {

    /** To the lost report's owner: someone may have seen their pet. */
    void matchFound(Match match);

    /** To the finder: the owner recognised their pet in the finder's sighting. */
    void matchConfirmed(Match match);

    /** To the finders whose match the owner confirmed: the pet is back home. */
    void petFound(LostReport report, List<UUID> finderIds);

    /** To the other participant of the conversation. */
    void newMessage(Conversation conversation, ChatMessage message);

    /** To associations near an animal reported injured or in need of help. */
    void animalNeedsHelp(Sighting sighting, List<UUID> associationIds);

    /** To the user who asked to be an association: approved or not. */
    void associationDecided(AssociationRequest request);

    /** To admins: enough reports hid this content, it waits for review. */
    void contentHidden(ReportTarget type, UUID id);

    /** To admins: someone asked to be an association. */
    void associationRequested(AssociationRequest request);
}
