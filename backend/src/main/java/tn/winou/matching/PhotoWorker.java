package tn.winou.matching;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.SmartLifecycle;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import tn.winou.config.WinouProperties;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.PhotoStatus;

/**
 * Processes uploaded photos. Runs when WINOU_WORKER_ENABLED=true (the "worker" container).
 *
 * <p>The queue is the photos table itself. A photo is claimed with FOR UPDATE SKIP LOCKED, so
 * several workers can run side by side. Claiming sets a lease (next_attempt_at in the future): if a
 * worker dies mid-photo, the lease runs out and another one retries it.
 */
@Component
public class PhotoWorker implements SmartLifecycle {

    private static final Logger log = LoggerFactory.getLogger(PhotoWorker.class);
    private static final Duration LEASE = Duration.ofMinutes(10);

    private final JdbcClient jdbc;
    private final TransactionTemplate tx;
    private final PhotoRepository photos;
    private final Matcher matcher;
    private final WinouProperties.Worker settings;
    private volatile Thread thread;

    public PhotoWorker(JdbcClient jdbc, TransactionTemplate tx, PhotoRepository photos, Matcher matcher,
            WinouProperties properties) {
        this.jdbc = jdbc;
        this.tx = tx;
        this.photos = photos;
        this.matcher = matcher;
        this.settings = properties.worker();
    }

    /** Processes one photo if any is waiting. Returns false when the queue is empty. */
    public boolean runOnce() {
        Optional<UUID> claimed = claim();
        if (claimed.isEmpty()) {
            return false;
        }
        UUID photoId = claimed.get();
        try {
            PhotoStatus status = tx.execute(t -> {
                Photo photo = photos.findById(photoId).orElseThrow();
                matcher.process(photo);
                photo.setError(null);
                photo.setProcessedAt(OffsetDateTime.now());
                return photo.getStatus();
            });
            log.info("photo {}: {}", photoId, status);
        } catch (RuntimeException e) {
            fail(photoId, e);
        }
        return true;
    }

    private Optional<UUID> claim() {
        return tx.execute(t -> jdbc.sql("""
                        UPDATE photos SET status = 'PROCESSING', attempts = attempts + 1,
                                          next_attempt_at = now() + make_interval(secs => :lease)
                        WHERE id = (SELECT id FROM photos
                                    WHERE status IN ('PENDING', 'PROCESSING') AND next_attempt_at <= now()
                                    ORDER BY next_attempt_at
                                    LIMIT 1
                                    FOR UPDATE SKIP LOCKED)
                        RETURNING id""")
                .param("lease", LEASE.toSeconds())
                .query(UUID.class)
                .optional());
    }

    /** Back in the queue with an exponential delay, or FAILED after the last attempt. */
    private void fail(UUID photoId, RuntimeException error) {
        tx.executeWithoutResult(t -> {
            Photo photo = photos.findById(photoId).orElse(null);
            if (photo == null) {
                return; // deleted meanwhile
            }
            boolean failed = photo.getAttempts() >= settings.maxAttempts();
            photo.setStatus(failed ? PhotoStatus.FAILED : PhotoStatus.PENDING);
            String message = error.getClass().getSimpleName() + ": " + error.getMessage();
            photo.setError(message.length() > 2000 ? message.substring(0, 2000) : message);
            photo.setNextAttemptAt(OffsetDateTime.now().plusSeconds(30L << photo.getAttempts()));
            if (failed) {
                log.warn("photo {} failed after {} attempts", photoId, photo.getAttempts(), error);
            } else {
                log.warn("photo {} attempt {} failed: {}", photoId, photo.getAttempts(), photo.getError());
            }
        });
    }

    private void loop() {
        log.info("worker started");
        while (thread != null) {
            boolean busy;
            try {
                busy = runOnce();
            } catch (RuntimeException e) {
                log.error("worker loop error", e); // e.g. database briefly unavailable
                busy = false;
            }
            if (!busy) {
                try {
                    Thread.sleep(settings.poll());
                } catch (InterruptedException e) {
                    return;
                }
            }
        }
    }

    @Override
    public void start() {
        if (settings.enabled()) {
            thread = Thread.ofPlatform().name("photo-worker").start(this::loop);
        }
    }

    @Override
    public void stop() {
        Thread running = thread;
        thread = null;
        if (running != null) {
            running.interrupt();
            try {
                running.join(Duration.ofSeconds(30)); // finish the current photo
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    @Override
    public boolean isRunning() {
        return thread != null;
    }
}
