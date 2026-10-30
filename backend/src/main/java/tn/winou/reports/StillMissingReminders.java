package tn.winou.reports;

import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import tn.winou.domain.LostReportRepository;
import tn.winou.infra.Notifications;

/**
 * "Is Luna still missing?", two weeks after the report and again at four weeks, so the owner closes
 * reports of pets already back home (or shares the poster again). The worker runs it every hour.
 */
@Component
public class StillMissingReminders {

    private final JdbcClient jdbc;
    private final LostReportRepository reports;
    private final Notifications notifications;

    public StillMissingReminders(JdbcClient jdbc, LostReportRepository reports, Notifications notifications) {
        this.jdbc = jdbc;
        this.reports = reports;
        this.notifications = notifications;
    }

    /**
     * Sends the reminders that are due and returns how many. One UPDATE claims them, so two workers
     * never send the same one; a report already past four weeks gets one reminder, not two.
     */
    public int sendDue() {
        List<UUID> due = jdbc.sql("""
                UPDATE lost_reports
                SET reminders_sent = CASE WHEN created_at < now() - interval '28 days' THEN 2 ELSE 1 END
                WHERE status = 'OPEN' AND hidden_at IS NULL
                  AND ((reminders_sent = 0 AND created_at < now() - interval '14 days')
                    OR (reminders_sent = 1 AND created_at < now() - interval '28 days'))
                RETURNING id""").query(UUID.class).list();
        reports.findAllById(due).forEach(report -> notifications.send(n -> n.stillMissing(report)));
        return due.size();
    }
}
