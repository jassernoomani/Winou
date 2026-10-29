package tn.winou.infra;

import java.util.List;
import java.util.UUID;

import tn.winou.domain.ChatMessage;
import tn.winou.domain.Conversation;
import tn.winou.domain.LostReport;
import tn.winou.domain.Match;

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
}
