package tn.winou.infra;

import tn.winou.domain.Match;

/** Tells the lost report's owner about a new possible match. */
public interface Notifier {

    void matchFound(Match match);
}
