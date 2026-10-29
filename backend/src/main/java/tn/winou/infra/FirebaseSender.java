package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;

/**
 * Firebase Cloud Messaging. The text is not sent: the app's Android string resources
 * (match_title, match_body) hold it, so the phone shows it in its own language.
 */
public class FirebaseSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FirebaseSender.class);

    private final FirebaseMessaging messaging;

    public FirebaseSender(FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    @Override
    public Result send(String deviceToken, MatchPush push) {
        Message message = Message.builder()
                .setFid(deviceToken) // the app registers with its installation ID (direct send)
                .putData("type", "match")
                .putData("match_id", push.matchId())
                .putData("lost_report_id", push.lostReportId())
                .putData("pet_name", push.petName())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setTitleLocalizationKey("match_title")
                                .setBodyLocalizationKey("match_body")
                                .addBodyLocalizationArg(push.petName())
                                .setTag("match-" + push.matchId())
                                .build())
                        .build())
                .build();
        try {
            messaging.send(message);
            return Result.SENT;
        } catch (FirebaseMessagingException e) {
            MessagingErrorCode code = e.getMessagingErrorCode();
            if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.SENDER_ID_MISMATCH) {
                return Result.TOKEN_GONE;
            }
            log.warn("push for match {} failed: {} {}", push.matchId(), code, e.getMessage());
            return Result.FAILED;
        }
    }
}
