package tn.winou.infra;

import java.util.concurrent.Executor;
import java.util.function.Consumer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tn.winou.common.AfterCommit;

/**
 * Sends notifications from API requests once the transaction commits, on another thread: a slow or
 * failing push never delays or fails the request, and nothing is sent for a rolled back change.
 */
public class Notifications {

    private static final Logger log = LoggerFactory.getLogger(Notifications.class);

    private final Notifier notifier;
    private final Executor executor;

    public Notifications(Notifier notifier, Executor executor) {
        this.notifier = notifier;
        this.executor = executor;
    }

    public void send(Consumer<Notifier> event) {
        AfterCommit.run(() -> executor.execute(() -> {
            try {
                event.accept(notifier);
            } catch (RuntimeException e) {
                log.warn("notification failed", e);
            }
        }));
    }
}
