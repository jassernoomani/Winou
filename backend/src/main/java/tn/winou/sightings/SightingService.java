package tn.winou.sightings;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.alerts.AlertAreas;
import tn.winou.associations.AssociationService;
import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.Condition;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.MatchSource;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.StrayStatus;
import tn.winou.domain.User;
import tn.winou.infra.Notifications;
import tn.winou.matching.Records;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.SightingIn;
import tn.winou.web.ApiModels.SightingOut;
import tn.winou.web.ApiModels.SightingUpdate;
import tn.winou.web.Views;

@Service
public class SightingService {

    private final SightingRepository sightings;
    private final PhotoRepository photos;
    private final Records records;
    private final Views views;
    private final WinouProperties properties;
    private final AssociationService associations;
    private final Notifications notifications;

    private final LostReportRepository reports;
    private final MatchRepository matches;
    private final AlertAreas areas;

    public SightingService(SightingRepository sightings, PhotoRepository photos, Records records, Views views,
            WinouProperties properties, AssociationService associations, Notifications notifications,
            LostReportRepository reports, MatchRepository matches, AlertAreas areas) {
        this.areas = areas;
        this.reports = reports;
        this.matches = matches;
        this.sightings = sightings;
        this.photos = photos;
        this.records = records;
        this.views = views;
        this.properties = properties;
        this.associations = associations;
        this.notifications = notifications;
    }

    public Sighting get(UUID id) {
        return sightings.findById(id).orElseThrow(() -> ApiException.notFound("Sighting"));
    }

    /** As get(), but hidden sightings, and those of banned users, exist only for their reporter and admins. */
    public Sighting visible(UUID id, User viewer) {
        Sighting sighting = get(id);
        if (!views.canSee(sighting.getReporterId(), sighting.getHiddenAt(), viewer)) {
            throw ApiException.notFound("Sighting");
        }
        return sighting;
    }

    @Transactional
    public SightingOut create(SightingIn body, User user) {
        RateLimits.check(sightings.countByReporterIdAndCreatedAtGreaterThanEqual(user.getId(),
                OffsetDateTime.now().minusHours(1)), properties.rateLimits().sightingsPerHour(), "sightings");
        Sighting sighting = new Sighting();
        sighting.setReporterId(user.getId());
        sighting.setSpecies(body.species());
        sighting.setLocation(body.location().toPoint());
        sighting.setSeenAt(body.seenAt());
        sighting.setCondition(body.condition() != null ? body.condition() : Condition.HEALTHY);
        sighting.setNote(body.note());
        sighting.setStray(Boolean.TRUE.equals(body.isStray()));
        LostReport report = body.lostReportId() == null ? null : seenPet(body.lostReportId(), user);
        sightings.save(sighting);
        alertIfUrgent(sighting);
        if (report != null) {
            matchToReport(report, sighting);
        }
        return views.sighting(sighting, user);
    }

    /** "I saw this pet": an open report the user can see, and not their own. */
    private LostReport seenPet(UUID reportId, User user) {
        LostReport report = reports.findById(reportId)
                .filter(r -> views.canSee(r.getOwnerId(), r.getHiddenAt(), user))
                .orElseThrow(() -> ApiException.notFound("Lost report"));
        if (report.getOwnerId().equals(user.getId())) {
            throw ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "own_report", "This is your own lost pet.");
        }
        if (report.getStatus() != ReportStatus.OPEN) {
            throw ApiException.coded(HttpStatus.CONFLICT, "report_closed", "This pet isn't missing anymore.");
        }
        return report;
    }

    /** The finder says it's this pet: the owner hears about it now, photos or not. */
    private void matchToReport(LostReport report, Sighting sighting) {
        Match match = new Match();
        match.setLostReportId(report.getId());
        match.setSightingId(sighting.getId());
        match.setSource(MatchSource.FINDER);
        match.setNotifiedAt(OffsetDateTime.now());
        match.setCreatedAt(OffsetDateTime.now());
        matches.save(match);
        notifications.send(n -> n.matchFound(match));
    }

    @Transactional(readOnly = true)
    public List<SightingOut> mine(User user) {
        return views.sightings(sightings.findByReporterIdOrderByCreatedAtDesc(user.getId()), user);
    }

    @Transactional
    public SightingOut update(UUID id, SightingUpdate body, User user) {
        Sighting sighting = get(id);
        CurrentUserResolver.requireOwnerOrAdmin(user, sighting.getReporterId());
        boolean rematch = false;
        if (body.species() != null) {
            sighting.setSpecies(body.species());
            rematch = true;
        }
        if (body.location() != null) {
            sighting.setLocation(body.location().toPoint());
            rematch = true;
        }
        if (body.seenAt() != null) {
            sighting.setSeenAt(body.seenAt());
            rematch = true;
        }
        if (body.condition() != null) {
            boolean wasUrgent = isUrgent(sighting.getCondition());
            sighting.setCondition(body.condition());
            if (!wasUrgent) {
                alertIfUrgent(sighting);
            }
        }
        if (body.note() != null) {
            sighting.setNote(body.note());
        }
        if (body.isStray() != null) {
            sighting.setStray(body.isStray());
        }
        if (rematch) {
            records.rematch(sighting.getId(), sighting.getSpecies(), Records.payload(sighting));
        }
        return views.sighting(sighting, user);
    }

    /**
     * Anyone may say what became of a stray: still around (which also keeps it on the map), helped,
     * or not seen anymore. The last person to update it is kept, to credit associations.
     */
    @Transactional
    public SightingOut setStrayStatus(UUID id, StrayStatus status, User user) {
        Sighting sighting = visible(id, user);
        if (!sighting.isStray()) {
            throw ApiException.invalid("Only strays have a status");
        }
        sighting.setStrayStatus(status);
        sighting.setStrayStatusAt(OffsetDateTime.now());
        sighting.setStrayStatusBy(user.getId());
        return views.sighting(sighting, user);
    }

    private static boolean isUrgent(Condition condition) {
        return condition == Condition.INJURED || condition == Condition.NEEDS_HELP;
    }

    /** Injured or in need of help: associations nearby hear about it. */
    private void alertIfUrgent(Sighting sighting) {
        if (!isUrgent(sighting.getCondition())) {
            return;
        }
        // Associations around, and users who asked to hear about animals in need near them
        List<UUID> near = java.util.stream.Stream.concat(
                        associations.near(sighting.getLocation(), sighting.getReporterId()).stream(),
                        areas.watchingHelp(sighting.getLocation(), sighting.getReporterId()).stream())
                .distinct().toList();
        if (!near.isEmpty()) {
            notifications.send(n -> n.animalNeedsHelp(sighting, near));
        }
    }

    @Transactional
    public void delete(UUID id, User user) {
        Sighting sighting = get(id);
        CurrentUserResolver.requireOwnerOrAdmin(user, sighting.getReporterId());
        records.deleted(sighting.getId(), photos.findBySightingIdInOrderByCreatedAt(List.of(sighting.getId())));
        sightings.deleteById(sighting.getId()); // photos and matches cascade in Postgres
    }
}
