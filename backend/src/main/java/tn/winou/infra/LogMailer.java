package tn.winou.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** No mail server configured (local development): the email, code included, goes to the log. */
public class LogMailer implements Mailer {

    private static final Logger log = LoggerFactory.getLogger(LogMailer.class);

    @Override
    public void send(String to, String subject, String text, String html) {
        log.info("email to {} (no MAIL_USERNAME, not sent): {}\n{}", to, subject, text);
    }
}
