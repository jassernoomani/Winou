package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;

/** Firebase Cloud Messaging, Android notifications. */
public class FirebaseSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FirebaseSender.class);

    private final FirebaseMessaging messaging;

    public FirebaseSender(FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    @Override
    public Result send(String deviceToken, Push push) {
        AndroidNotification.Builder notification = AndroidNotification.builder()
                .setTitleLocalizationKey(push.titleKey())
                .addAllTitleLocalizationArgs(push.titleArgs())
                .setTag(push.tag());
        if (push.bodyKey() != null) {
            notification.setBodyLocalizationKey(push.bodyKey()).addAllBodyLocalizationArgs(push.bodyArgs());
        } else {
            notification.setBody(push.body());
        }
        Message message = Message.builder()
                .setFid(deviceToken) // the app registers with its installation ID (direct send)
                .putAllData(push.data())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(notification.build())
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
            log.warn("push {} failed: {} {}", push.tag(), code, e.getMessage());
            return Result.FAILED;
        }
    }
}
