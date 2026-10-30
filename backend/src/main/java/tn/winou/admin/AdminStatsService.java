package tn.winou.admin;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.config.WinouProperties;
import tn.winou.domain.User;
import tn.winou.security.Admins;
import tn.winou.web.ApiModels.AdminActionOut;
import tn.winou.web.ApiModels.AdminStatsOut;
import tn.winou.web.ApiModels.AdminSummaryOut;
import tn.winou.web.ApiModels.WeekStats;

/** What waits for admins, how Winou is doing, and what admins did. */
@Service
public class AdminStatsService {

    static final int WEEKS = 12;

    private final JdbcClient jdbc;
    private final AdminLog log;
    private final int strayFadeDays;

    public AdminStatsService(JdbcClient jdbc, AdminLog log, WinouProperties properties) {
        this.jdbc = jdbc;
        this.log = log;
        this.strayFadeDays = properties.strays().fadeDays();
    }

    /** The same lists as the Reported, Requests and Hidden tabs, counted. */
    @Transactional(readOnly = true)
    public AdminSummaryOut summary(User admin) {
        Admins.require(admin);
        return jdbc.sql("""
                        SELECT
                          (SELECT count(DISTINCT c.target_id) FROM content_reports c
                           WHERE c.target_id IN (SELECT id FROM lost_reports WHERE hidden_at IS NULL)
                              OR c.target_id IN (SELECT id FROM sightings WHERE hidden_at IS NULL)
                              OR c.target_id IN (SELECT id FROM messages WHERE hidden_at IS NULL)) AS reported,
                          (SELECT count(*) FROM association_requests WHERE status = 'PENDING') AS requests,
                          (SELECT count(*) FROM lost_reports WHERE hidden_at IS NOT NULL)
                            + (SELECT count(*) FROM sightings WHERE hidden_at IS NOT NULL)
                            + (SELECT count(*) FROM messages WHERE hidden_at IS NOT NULL) AS hidden""")
                .query((rs, i) -> new AdminSummaryOut(rs.getLong("reported"), rs.getLong("requests"),
                        rs.getLong("hidden")))
                .single();
    }

    @Transactional(readOnly = true)
    public AdminStatsOut stats(User admin) {
        Admins.require(admin);
        AdminStatsOut totals = jdbc.sql("""
                        SELECT
                          (SELECT count(*) FROM users) AS users,
                          (SELECT count(*) FROM users WHERE created_at >= now() - interval '7 days') AS new_users,
                          (SELECT count(*) FROM lost_reports WHERE status = 'OPEN' AND hidden_at IS NULL) AS open_lost,
                          (SELECT count(*) FROM lost_reports) AS lost_total,
                          (SELECT count(*) FROM lost_reports WHERE status = 'FOUND') AS reunited,
                          (SELECT count(*) FROM sightings) AS sightings,
                          (SELECT count(*) FROM sightings
                           WHERE is_stray AND stray_status = 'AROUND' AND hidden_at IS NULL
                             AND COALESCE(stray_status_at, seen_at) >= now() - make_interval(days => :fadeDays)) AS strays,
                          (SELECT count(*) FROM matches WHERE status = 'CONFIRMED') AS confirmed,
                          (SELECT count(*) FROM users WHERE association_name IS NOT NULL) AS associations,
                          (SELECT count(*) FROM sightings s JOIN users u ON u.id = s.stray_status_by
                           WHERE s.stray_status = 'HELPED' AND u.association_name IS NOT NULL) AS helped""")
                .param("fadeDays", strayFadeDays)
                .query((rs, i) -> {
                    long total = rs.getLong("lost_total");
                    long reunited = rs.getLong("reunited");
                    return new AdminStatsOut(rs.getLong("users"), rs.getLong("new_users"), rs.getLong("open_lost"),
                            total, reunited, total == 0 ? null : (double) reunited / total, rs.getLong("sightings"),
                            rs.getLong("strays"), rs.getLong("confirmed"), rs.getLong("associations"),
                            rs.getLong("helped"), List.of());
                })
                .single();
        // The last WEEKS weeks, the current one included, oldest first; empty weeks count 0
        List<WeekStats> weeks = jdbc.sql("""
                        WITH weeks AS (
                          SELECT generate_series(date_trunc('week', now()) - make_interval(weeks => :weeks - 1),
                                                 date_trunc('week', now()), interval '1 week') AS start)
                        SELECT w.start,
                          (SELECT count(*) FROM lost_reports r
                           WHERE r.created_at >= w.start AND r.created_at < w.start + interval '1 week') AS lost,
                          (SELECT count(*) FROM sightings s
                           WHERE s.created_at >= w.start AND s.created_at < w.start + interval '1 week') AS sightings,
                          (SELECT count(*) FROM lost_reports r WHERE r.status = 'FOUND'
                             AND r.status_at >= w.start AND r.status_at < w.start + interval '1 week') AS reunited
                        FROM weeks w ORDER BY w.start""")
                .param("weeks", WEEKS)
                .query((rs, i) -> new WeekStats(rs.getObject("start", OffsetDateTime.class), rs.getLong("lost"),
                        rs.getLong("sightings"), rs.getLong("reunited")))
                .list();
        return new AdminStatsOut(totals.users(), totals.newUsersThisWeek(), totals.openLostReports(),
                totals.lostReportsTotal(), totals.reunited(), totals.reunionRate(), totals.sightings(),
                totals.straysOnMap(), totals.matchesConfirmed(), totals.associations(),
                totals.strayHelpedByAssociations(), weeks);
    }

    @Transactional(readOnly = true)
    public List<AdminActionOut> actions(int limit, int offset, User admin) {
        Admins.require(admin);
        return log.recent(limit, offset);
    }
}
