package tn.winou.infra;

/** Sends a push notification to one device. */
public interface PushSender {

    enum Result {
        SENT,
        /** The app was uninstalled or signed out of push: forget the token. */
        TOKEN_GONE,
        FAILED,
    }

    /** "Someone may have seen {petName}"; tapping it opens the match in the app. */
    record MatchPush(String matchId, String lostReportId, String petName) {}

    /** deviceToken: the phone's Firebase installation ID, stored as the user's fcm_token. */
    Result send(String deviceToken, MatchPush push);
}
