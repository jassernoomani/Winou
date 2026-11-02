package tn.winou.sightings;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.alerts.AlertAreas;
import tn.winou.associations.AssociationService;
import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.AdoptionStatus;
import tn.winou.domain.Condition;
import tn.winou.domain.Role;
import tn.winou.domain.GeoPoint;
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
import tn.winou.web.ApiModels.AdoptionIn;
import tn.winou.web.ApiModels.SightingIn;
import tn.winou.web.ApiModels.SightingOut;
import tn.winou.web.ApiModels.StrayCareUpdate;
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
    private final JdbcClient jdbc;

    public SightingService(SightingRepository sightings, PhotoRepository photos, Records records, Views views,
            WinouProperties properties, AssociationService associations, Notifications notifications,
            LostReportRepository reports, MatchRepository matches, AlertAreas areas, JdbcClient jdbc) {
        this.jdbc = jdbc;
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
        sighting.setInCare(Boolean.TRUE.equals(body.inCare()));
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
        if (body.inCare() != null) {
            sighting.setInCare(body.inCare());
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

    /** Anyone signed in keeps a stray's care card up to date, as the neighbourhood learns more. */
    @Transactional
    public SightingOut updateCare(UUID id, StrayCareUpdate body, User user) {
        Sighting sighting = stray(id, user);
        sighting.setNickname(blankToNull(body.nickname()));
        sighting.setSterilised(body.sterilised());
        sighting.setVaccinated(body.vaccinated());
        sighting.setCareNotes(blankToNull(body.notes()));
        sighting.setCareUpdatedAt(OffsetDateTime.now());
        sighting.setCareUpdatedBy(user.getId());
        return views.sighting(sighting, user);
    }

    /** "I feed this animal", or no longer. Feeding it also says it is still around. */
    @Transactional
    public SightingOut setFeeding(UUID id, boolean feeding, User user) {
        Sighting sighting = stray(id, user);
        if (feeding) {
            jdbc.sql("INSERT INTO stray_feeders (sighting_id, user_id) VALUES (:id, :user) ON CONFLICT DO NOTHING")
                    .param("id", id).param("user", user.getId()).update();
            if (sighting.getStrayStatus() == StrayStatus.AROUND) {
                sighting.setStrayStatusAt(OffsetDateTime.now()); // stays on the map
            }
        } else {
            jdbc.sql("DELETE FROM stray_feeders WHERE sighting_id = :id AND user_id = :user")
                    .param("id", id).param("user", user.getId()).update();
        }
        return views.sighting(sighting, user);
    }

    // --- adoption ---

    /** An association (or an admin) offers a stray it looks after for adoption, or updates its offer. */
    @Transactional
    public SightingOut offerAdoption(UUID id, AdoptionIn body, User user) {
        Sighting sighting = stray(id, user);
        if (!user.isAssociation() && user.getRole() != Role.ADMIN) {
            throw ApiException.coded(HttpStatus.FORBIDDEN, "associations_only",
                    "Only animal associations can offer an animal for adoption.");
        }
        if (sighting.getStrayStatus() == StrayStatus.GONE) {
            throw ApiException.invalid("This animal is no longer around");
        }
        if (sighting.getAdoptionStatus() == AdoptionStatus.AVAILABLE && !offeredBy(sighting, user)) {
            throw ApiException.forbidden(); // another association's offer
        }
        sighting.setAdoptionStatus(AdoptionStatus.AVAILABLE);
        sighting.setAdoptionNote(blankToNull(body.note()));
        sighting.setAdoptionContact(body.contact().strip());
        sighting.setAdoptionBy(user.getId());
        sighting.setAdoptionAt(OffsetDateTime.now());
        return views.sighting(sighting, user);
    }

    /** Adopted: a happy ending, which also marks the stray as helped by that association. */
    @Transactional
    public SightingOut markAdopted(UUID id, User user) {
        Sighting sighting = offer(id, user);
        OffsetDateTime now = OffsetDateTime.now();
        sighting.setAdoptionStatus(AdoptionStatus.ADOPTED);
        sighting.setAdoptionAt(now);
        sighting.setStrayStatus(StrayStatus.HELPED);
        sighting.setStrayStatusAt(now);
        sighting.setStrayStatusBy(sighting.getAdoptionBy());
        return views.sighting(sighting, user);
    }

    @Transactional
    public SightingOut withdrawAdoption(UUID id, User user) {
        Sighting sighting = offer(id, user);
        sighting.setAdoptionStatus(null);
        sighting.setAdoptionNote(null);
        sighting.setAdoptionContact(null);
        sighting.setAdoptionBy(null);
        sighting.setAdoptionAt(null);
        return views.sighting(sighting, user);
    }

    /** Animals up for adoption, nearest first around [center] (or newest first without one). */
    @Transactional(readOnly = true)
    public List<SightingOut> adoptable(User viewer, GeoPoint center, double radiusKm) {
        StringBuilder sql = new StringBuilder("""
                SELECT id FROM sightings
                WHERE adoption_status = 'AVAILABLE' AND hidden_at IS NULL AND is_stray AND stray_status <> 'GONE'"""
                + " AND " + Views.notBanned("reporter_id"));
        var query = new java.util.HashMap<String, Object>();
        if (center != null) {
            sql.append(" AND ST_DWithin(point, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius)"
                    + " ORDER BY ST_Distance(point, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography)");
            query.put("lat", center.lat());
            query.put("lon", center.lon());
            query.put("radius", radiusKm * 1000);
        } else {
            sql.append(" ORDER BY adoption_at DESC");
        }
        sql.append(" LIMIT 50");
        List<UUID> ids = jdbc.sql(sql.toString()).params(query).query(UUID.class).list();
        var byId = sightings.findAllById(ids).stream()
                .collect(java.util.stream.Collectors.toMap(Sighting::getId, s -> s));
        return views.sightings(ids.stream().map(byId::get).toList(), viewer);
    }

    private static boolean offeredBy(Sighting sighting, User user) {
        return user.getRole() == Role.ADMIN || user.getId().equals(sighting.getAdoptionBy());
    }

    /** The offer, for the association that made it (or an admin). */
    private Sighting offer(UUID id, User user) {
        Sighting sighting = stray(id, user);
        if (sighting.getAdoptionStatus() == null) {
            throw ApiException.notFound("Adoption offer");
        }
        if (!offeredBy(sighting, user)) {
            throw ApiException.forbidden();
        }
        return sighting;
    }

    private Sighting stray(UUID id, User user) {
        Sighting sighting = visible(id, user);
        if (!sighting.isStray()) {
            throw ApiException.invalid("Only strays have a care card");
        }
        return sighting;
    }

    private static String blankToNull(String text) {
        return text == null || text.isBlank() ? null : text.strip();
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
