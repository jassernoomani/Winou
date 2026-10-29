package tn.winou.infra;

import java.util.List;
import java.util.Map;

/** Sends a push notification to one device. */
public interface PushSender {

    enum Result {
        SENT,
        /** The app was uninstalled or signed out of push: forget the token. */
        TOKEN_GONE,
        FAILED,
    }

    /**
     * titleKey and bodyKey name the app's Android string resources (filled with the args), so the
     * phone shows the text in its own language. Without bodyKey, body is shown as is (a chat
     * message). Notifications with the same tag replace each other. The app reads data on tap.
     */
    record Push(String titleKey, List<String> titleArgs, String bodyKey, List<String> bodyArgs, String body,
            String tag, Map<String, String> data) {}

    /** deviceToken: the phone's Firebase installation ID, stored as the user's fcm_token. */
    Result send(String deviceToken, Push push);
}
