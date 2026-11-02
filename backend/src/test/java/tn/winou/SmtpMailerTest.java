package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.concurrent.CountDownLatch;

import org.junit.jupiter.api.Test;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;

import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import tn.winou.infra.SmtpMailer;

/** Emails go out in the background: the request that asked for one does not wait for Gmail. */
class SmtpMailerTest {

    @Test
    void sendReturnsBeforeTheEmailIsSent() throws Exception {
        JavaMailSender sender = mock(JavaMailSender.class);
        when(sender.createMimeMessage()).thenAnswer(i -> new MimeMessage((Session) null));
        CountDownLatch smtpSlow = new CountDownLatch(1);
        doAnswer(i -> {
            smtpSlow.await(); // the SMTP server takes its time
            return null;
        }).when(sender).send(any(MimeMessage.class));

        new SmtpMailer(sender, "winou@example.com", "Winou").send("sami@example.com", "Your code", "123456", "<b>123456</b>");
        // Back already, although the email is still being sent
        smtpSlow.countDown();
        verify(sender, timeout(2000)).send(any(MimeMessage.class));
    }

    @Test
    void aFailedEmailIsLoggedNotThrown() {
        JavaMailSender sender = mock(JavaMailSender.class);
        when(sender.createMimeMessage()).thenAnswer(i -> new MimeMessage((Session) null));
        doAnswer(i -> {
            throw new MailSendException("smtp down");
        }).when(sender).send(any(MimeMessage.class));

        SmtpMailer mailer = new SmtpMailer(sender, "winou@example.com", "Winou");
        mailer.send("sami@example.com", "Your code", "123456", "<b>123456</b>");
        verify(sender, timeout(2000)).send(any(MimeMessage.class));
        assertThat(mailer).isNotNull(); // nothing thrown to the caller
    }
}
