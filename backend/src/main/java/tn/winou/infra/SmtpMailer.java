package tn.winou.infra;

import java.nio.charset.StandardCharsets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;

/** Through an SMTP server: Gmail with an app password (MAIL_USERNAME, MAIL_PASSWORD). */
public class SmtpMailer implements Mailer {

    private static final Logger log = LoggerFactory.getLogger(SmtpMailer.class);

    private final JavaMailSender sender;
    private final String from;
    private final String fromName;

    public SmtpMailer(JavaMailSender sender, String from, String fromName) {
        this.sender = sender;
        this.from = from;
        this.fromName = fromName;
    }

    @Override
    public void send(String to, String subject, String text, String html) {
        try {
            MimeMessage message = sender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, StandardCharsets.UTF_8.name());
            helper.setFrom(from, fromName);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(text, html);
            sender.send(message);
            log.info("email \"{}\" sent", subject.replaceAll("\\d{6}", "######"));
        } catch (MailException | MessagingException | java.io.UnsupportedEncodingException e) {
            log.warn("email to a user failed: {}", e.getMessage());
        }
    }
}
