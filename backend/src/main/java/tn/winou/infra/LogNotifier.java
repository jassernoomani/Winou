package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import tn.winou.domain.Match;

/** Logs matches only. Push notifications (Firebase Cloud Messaging) replace it next. */
@Component
public class LogNotifier implements Notifier {

    private static final Logger log = LoggerFactory.getLogger(LogNotifier.class);

    @Override
    public void matchFound(Match match) {
        log.info("match {}: lost report {} <-> sighting {} (score {})",
                match.getId(), match.getLostReportId(), match.getSightingId(), String.format("%.3f", match.getScore()));
    }
}
