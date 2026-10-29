package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.infra.PushSender.MatchPush;

/** Pushes a notification to the lost report owner's phone. A failed push never fails matching. */
public class PushNotifier implements Notifier {

    private static final Logger log = LoggerFactory.getLogger(PushNotifier.class);

    private final PushSender sender;
    private final LostReportRepository reports;
    private final UserRepository users;

    public PushNotifier(PushSender sender, LostReportRepository reports, UserRepository users) {
        this.sender = sender;
        this.reports = reports;
        this.users = users;
    }

    @Override
    public void matchFound(Match match) {
        LostReport report = reports.findById(match.getLostReportId()).orElseThrow();
        User owner = users.findById(report.getOwnerId()).orElseThrow();
        if (owner.getFcmToken() == null) {
            log.info("match {}: owner has no device registered", match.getId());
            return;
        }
        var push = new MatchPush(match.getId().toString(), report.getId().toString(), report.getName());
        switch (sender.send(owner.getFcmToken(), push)) {
            case SENT -> log.info("match {}: notified the owner", match.getId());
            case TOKEN_GONE -> {
                log.info("match {}: device token is no longer valid, removing it", match.getId());
                owner.setFcmToken(null);
                users.save(owner);
            }
            case FAILED -> { } // logged by the sender; the match is still in the app
        }
    }
}
