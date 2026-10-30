package tn.winou.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;

import tn.winou.infra.LogMailer;
import tn.winou.infra.Mailer;
import tn.winou.infra.SmtpMailer;

/** Emails through Gmail SMTP when MAIL_USERNAME is set, into the log otherwise. */
@Configuration
public class MailConfig {

    private static final Logger log = LoggerFactory.getLogger(MailConfig.class);

    @Bean
    Mailer mailer(ObjectProvider<JavaMailSender> sender, @Value("${spring.mail.username:}") String username,
            @Value("${winou.mail.from-name:Winou}") String fromName) {
        if (username.isBlank() || sender.getIfAvailable() == null) {
            log.info("MAIL_USERNAME is not set: emails (sign-in codes) are logged, not sent");
            return new LogMailer();
        }
        log.info("emails are sent from {}", username);
        return new SmtpMailer(sender.getObject(), username, fromName);
    }
}
