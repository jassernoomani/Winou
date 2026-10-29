package tn.winou.reports;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.common.Geo;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.MatchStatus;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.Species;
import tn.winou.domain.User;
import tn.winou.infra.Notifications;
import tn.winou.matching.Records;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.LostReportIn;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.ApiModels.LostReportUpdate;
import tn.winou.web.Views;

@Service
public class LostReportService {

    private final LostReportRepository reports;
    private final PhotoRepository photos;
    private final JdbcClient jdbc;
    private final Records records;
    private final Views views;
    private final WinouProperties properties;
    private final MatchRepository matches;
    private final SightingRepository sightings;
    private final Notifications notifications;

    public LostReportService(LostReportRepository reports, PhotoRepository photos, JdbcClient jdbc, Records records,
            Views views, WinouProperties properties, MatchRepository matches, SightingRepository sightings,
            Notifications notifications) {
        this.matches = matches;
        this.sightings = sightings;
        this.notifications = notifications;
        this.reports = reports;
        this.photos = photos;
        this.jdbc = jdbc;
        this.records = records;
        this.views = views;
        this.properties = properties;
    }

    public LostReport get(UUID id) {
        return reports.findById(id).orElseThrow(() -> ApiException.notFound("Lost report"));
    }

    /** As get(), but hidden reports exist only for their owner and admins. */
    public LostReport visible(UUID id, User viewer) {
        LostReport report = get(id);
        if (!Views.canSee(report.getOwnerId(), report.getHiddenAt(), viewer)) {
            throw ApiException.notFound("Lost report");
        }
        return report;
    }

    @Transactional
    public LostReportOut create(LostReportIn body, User user) {
        RateLimits.check(reports.countByOwnerIdAndCreatedAtGreaterThanEqual(user.getId(),
                OffsetDateTime.now().minusDays(1)), properties.rateLimits().lostReportsPerDay(), "lost reports");
        LostReport report = new LostReport();
        report.setOwnerId(user.getId());
        report.setName(body.name().strip());
        report.setSpecies(body.species());
        report.setDescription(body.description());
        report.setLastSeen(body.lastSeen().toPoint());
        report.setLastSeenAt(body.lastSeenAt());
        return views.report(reports.save(report), user);
    }

    @Transactional(readOnly = true)
    public List<LostReportOut> mine(User user) {
        return views.reports(reports.findByOwnerIdOrderByCreatedAtDesc(user.getId()), user);
    }

    /**
     * Open reports, the most recently seen first. With a center, only those within radiusKm. The
     * distance is measured to the position shown (approximate unless it's yours), so moving the
     * search point can't reveal the exact one.
     */
    @Transactional(readOnly = true)
    public List<LostReportOut> list(User viewer, GeoPoint center, double radiusKm, List<Species> species, int limit,
            int offset) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, owner_id, ST_Y(last_seen_point::geometry) AS lat, ST_X(last_seen_point::geometry) AS lon
                FROM lost_reports WHERE status = 'OPEN' AND hidden_at IS NULL""");
        Map<String, Object> params = new HashMap<>();
        if (species != null && !species.isEmpty()) {
            sql.append(" AND species IN (:species)");
            params.put("species", species.stream().map(Species::api).toList());
        }
        double radiusM = radiusKm * 1000;
        if (center != null) {
            // Coarse filter on the exact point, with a margin for the fuzz; the real one is on the shown point
            sql.append(" AND ST_DWithin(last_seen_point, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :within)");
            params.put("lat", center.lat());
            params.put("lon", center.lon());
            params.put("within", radiusM + properties.privacy().locationFuzzM());
        }
        sql.append(" ORDER BY last_seen_at DESC, id");
        if (center == null) {
            sql.append(" LIMIT :limit OFFSET :offset");
            params.put("limit", limit);
            params.put("offset", offset);
        }
        List<UUID> ids = jdbc.sql(sql.toString()).params(params).query((rs, i) -> {
            UUID id = rs.getObject("id", UUID.class);
            if (center != null) {
                GeoPoint shown = views.shownPosition(id, rs.getObject("owner_id", UUID.class),
                        new GeoPoint(rs.getDouble("lat"), rs.getDouble("lon")), viewer);
                if (Geo.distanceM(center, shown) > radiusM) {
                    return null;
                }
            }
            return id;
        }).list().stream().filter(Objects::nonNull).toList();
        if (center != null) {
            ids = ids.subList(Math.min(offset, ids.size()), Math.min(offset + limit, ids.size()));
        }
        Map<UUID, LostReport> byId = reports.findAllById(ids).stream()
                .collect(Collectors.toMap(LostReport::getId, Function.identity()));
        return views.reports(ids.stream().map(byId::get).toList(), viewer);
    }

    @Transactional
    public LostReportOut update(UUID id, LostReportUpdate body, User user) {
        LostReport report = get(id);
        CurrentUserResolver.requireOwnerOrAdmin(user, report.getOwnerId());
        boolean rematch = false;
        if (body.name() != null) {
            report.setName(body.name().strip());
        }
        if (body.description() != null) {
            report.setDescription(body.description());
        }
        if (body.species() != null) {
            report.setSpecies(body.species());
            rematch = true;
        }
        if (body.lastSeen() != null) {
            report.setLastSeen(body.lastSeen().toPoint());
            rematch = true;
        }
        if (body.lastSeenAt() != null) {
            report.setLastSeenAt(body.lastSeenAt());
            rematch = true;
        }
        if (body.status() != null) {
            if (body.status() == ReportStatus.FOUND && report.getStatus() != ReportStatus.FOUND) {
                thankFinders(report);
            }
            report.setStatus(body.status());
            rematch = true; // reopened reports are matched again
        }
        if (rematch) {
            records.rematch(report.getId(), report.getSpecies(), Records.payload(report));
        }
        return views.report(report, user);
    }

    /** The pet is back: tell the people whose sighting the owner confirmed. */
    private void thankFinders(LostReport report) {
        List<UUID> sightingIds = matches.findByLostReportIdAndStatus(report.getId(), MatchStatus.CONFIRMED).stream()
                .map(Match::getSightingId).toList();
        List<UUID> finders = sightings.findAllById(sightingIds).stream()
                .map(s -> s.getReporterId()).distinct().toList();
        if (!finders.isEmpty()) {
            notifications.send(n -> n.petFound(report, finders));
        }
    }

    @Transactional
    public void delete(UUID id, User user) {
        LostReport report = get(id);
        CurrentUserResolver.requireOwnerOrAdmin(user, report.getOwnerId());
        records.deleted(report.getId(), photos.findByLostReportIdInOrderByCreatedAt(List.of(report.getId())));
        reports.deleteById(report.getId()); // photos and matches cascade in Postgres
    }
}
