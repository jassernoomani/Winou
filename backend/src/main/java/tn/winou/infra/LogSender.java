package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** No Firebase key configured: pushes are logged, not sent (they still reach the notifications list). */
public class LogSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(LogSender.class);

    @Override
    public Result send(String deviceToken, Push push) {
        log.info("{}: not pushed (no FIREBASE_CREDENTIALS)", push.tag());
        return Result.SENT;
    }
}
