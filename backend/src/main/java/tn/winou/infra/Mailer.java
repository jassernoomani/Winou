package tn.winou.infra;

/** Sends an email. Implementations never throw for a failed delivery: they log it. */
public interface Mailer {

    void send(String to, String subject, String text, String html);
}
