package tn.winou.infra;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import tn.winou.domain.MatchStatus;
import tn.winou.domain.PhotoStatus;
import tn.winou.domain.ReportStatus;

/**
 * App state for Prometheus, read from the database: the photo queue (the worker has no web server
 * to scrape, but its work shows here), matches, reports and users. Counts are totals; Grafana turns
 * them into rates. One query per scrape at most, cached for a few seconds.
 */
@Component
@ConditionalOnWebApplication
public class AppMetrics {

    private static final Duration MAX_AGE = Duration.ofSeconds(10);

    private final JdbcClient jdbc;
    private volatile Map<String, Long> counts = Map.of();
    private volatile Instant readAt = Instant.MIN;

    public AppMetrics(JdbcClient jdbc, MeterRegistry registry) {
        this.jdbc = jdbc;
        for (PhotoStatus status : PhotoStatus.values()) {
            gauge(registry, "winou.photos", "Photos by processing status", "photos." + status, "status", status.name());
        }
        for (MatchStatus status : MatchStatus.values()) {
            gauge(registry, "winou.matches", "Matches by status", "matches." + status, "status", status.name());
        }
        for (ReportStatus status : ReportStatus.values()) {
            gauge(registry, "winou.lost.reports", "Lost pet reports by status", "reports." + status, "status",
                    status.name());
        }
        gauge(registry, "winou.sightings", "Sightings, strays included", "sightings", "kind", "all");
        gauge(registry, "winou.users", "Accounts", "users", "kind", "all");
    }

    private void gauge(MeterRegistry registry, String name, String description, String key, String tag,
            String value) {
        Gauge.builder(name, this, m -> m.count(key)).description(description).tag(tag, value).register(registry);
    }

    double count(String key) {
        if (readAt.plus(MAX_AGE).isBefore(Instant.now())) {
            refresh();
        }
        return counts.getOrDefault(key, 0L);
    }

    /** Reads the counts now (scrapes otherwise reuse them for a few seconds). */
    public synchronized void refresh() {
        readAt = Instant.now();
        counts = jdbc.sql("""
                SELECT 'photos.' || status AS key, count(*) AS n FROM photos GROUP BY status
                UNION ALL SELECT 'matches.' || status, count(*) FROM matches GROUP BY status
                UNION ALL SELECT 'reports.' || status, count(*) FROM lost_reports GROUP BY status
                UNION ALL SELECT 'sightings', count(*) FROM sightings
                UNION ALL SELECT 'users', count(*) FROM users
                """).query((rs, i) -> Map.entry(rs.getString("key"), rs.getLong("n")))
                .list().stream().collect(Collectors.toUnmodifiableMap(Map.Entry::getKey, Map.Entry::getValue));
    }
}
