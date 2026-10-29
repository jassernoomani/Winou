package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tn.winou.domain.Match;

/** Logs matches only: used when no Firebase key is configured. */
public class LogNotifier implements Notifier {

    private static final Logger log = LoggerFactory.getLogger(LogNotifier.class);

    @Override
    public void matchFound(Match match) {
        log.info("match {}: lost report {} <-> sighting {} (score {})",
                match.getId(), match.getLostReportId(), match.getSightingId(), String.format("%.3f", match.getScore()));
    }
}
