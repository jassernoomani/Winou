package tn.winou.sightings;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.Condition;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
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

    public SightingService(SightingRepository sightings, PhotoRepository photos, Records records, Views views,
            WinouProperties properties) {
        this.sightings = sightings;
        this.photos = photos;
        this.records = records;
        this.views = views;
        this.properties = properties;
    }

    public Sighting get(UUID id) {
        return sightings.findById(id).orElseThrow(() -> ApiException.notFound("Sighting"));
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
        return views.sighting(sightings.save(sighting), user);
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
            sighting.setCondition(body.condition());
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

    @Transactional
    public void delete(UUID id, User user) {
        Sighting sighting = get(id);
        CurrentUserResolver.requireOwnerOrAdmin(user, sighting.getReporterId());
        records.deleted(sighting.getId(), photos.findBySightingIdInOrderByCreatedAt(List.of(sighting.getId())));
        sightings.deleteById(sighting.getId()); // photos and matches cascade in Postgres
    }
}
