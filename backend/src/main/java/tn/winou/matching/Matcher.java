package tn.winou.matching;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import tn.winou.config.WinouProperties;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoStatus;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.Species;
import tn.winou.infra.MlClient;
import tn.winou.infra.MlClient.NoAnimalDetected;
import tn.winou.infra.Notifier;
import tn.winou.infra.Storage;
import tn.winou.infra.VectorIndex;
import tn.winou.infra.VectorIndex.Hit;

/** Photo processing and matching (brief §6, steps 2–6). Run by the worker, one photo at a time. */
@Component
public class Matcher {

    private static final Logger log = LoggerFactory.getLogger(Matcher.class);
    private static final int SEARCH_LIMIT = 100;

    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final MatchRepository matches;
    private final JdbcClient jdbc;
    private final Storage storage;
    private final VectorIndex index;
    private final MlClient ml;
    private final Notifier notifier;
    private final WinouProperties.Matching settings;

    public Matcher(LostReportRepository reports, SightingRepository sightings, MatchRepository matches,
            JdbcClient jdbc, Storage storage, VectorIndex index, MlClient ml, Notifier notifier,
            WinouProperties properties) {
        this.reports = reports;
        this.sightings = sightings;
        this.matches = matches;
        this.jdbc = jdbc;
        this.storage = storage;
        this.index = index;
        this.ml = ml;
        this.notifier = notifier;
        this.settings = properties.matching();
    }

    /**
     * Embeds one photo, indexes it and creates matches. Sets the photo's status; the caller's
     * transaction saves it. Throws on transient failures (ML service or storage down) so the worker
     * can retry.
     */
    public void process(Photo photo) {
        LostReport report = photo.getLostReportId() == null ? null : reports.findById(photo.getLostReportId()).orElseThrow();
        Sighting sighting = photo.getSightingId() == null ? null : sightings.findById(photo.getSightingId()).orElseThrow();
        Species species = report != null ? report.getSpecies() : sighting.getSpecies();

        if (species == Species.OTHER) {
            index.deletePhoto(photo.getId()); // in case the species was changed to "other"
            photo.setStatus(PhotoStatus.SKIPPED); // the detector only knows cats and dogs
            return;
        }

        // Re-matching after an edit (new place, date or species) reuses the stored vector
        List<Double> vector = photo.getCropKey() != null ? index.getVector(photo.getId()).orElse(null) : null;
        if (vector == null) {
            MlClient.Embedding result;
            try {
                result = ml.embed(storage.get(photo.getPublicKey()));
            } catch (NoAnimalDetected e) {
                photo.setStatus(PhotoStatus.NO_ANIMAL);
                return;
            }
            vector = result.vector();
            photo.setCropKey("crops/" + photo.getId() + ".jpg");
            storage.put(photo.getCropKey(), result.cropJpeg(), "image/jpeg");
            photo.setDetectedSpecies(result.species());
            photo.setDetectionConfidence(result.confidence());
        }

        if (!species.api().equals(photo.getDetectedSpecies())) {
            // Matching uses the species the user chose; a mismatch is kept for review, not auto-corrected
            log.info("photo {}: user said {}, detector saw {}", photo.getId(), species.api(), photo.getDetectedSpecies());
        }

        index.upsert(photo.getId(), vector, report != null ? Records.payload(report) : Records.payload(sighting));
        List<Match> created = report != null ? matchReport(photo, report, vector) : matchSighting(photo, sighting, vector);
        photo.setStatus(PhotoStatus.READY);
        for (Match match : created.subList(0, Math.min(created.size(), settings.maxNotifications()))) {
            notifier.matchFound(match);
            match.setNotifiedAt(OffsetDateTime.now());
            matches.save(match);
        }
    }

    /** A lost report's photo: search sightings from shortly before it was lost onwards. */
    private List<Match> matchReport(Photo photo, LostReport report, List<Double> vector) {
        Set<UUID> banned = bannedUsers();
        if (report.getStatus() != ReportStatus.OPEN || report.getHiddenAt() != null
                || banned.contains(report.getOwnerId())) {
            return List.of();
        }
        OffsetDateTime since = report.getLastSeenAt().minusDays(settings.sightingGraceDays());
        List<Hit> hits = index.search(vector, report.getSpecies(), "sighting", report.getLastSeen(),
                settings.radiusKm() * 1000, since, null, SEARCH_LIMIT);
        Map<UUID, Hit> best = bestPerRecord(hits, photo, report.getSpecies());
        if (best.isEmpty()) {
            return List.of();
        }
        // Not the owner's own sightings of their animal
        List<Sighting> others = sightings.findAllById(best.keySet()).stream()
                .filter(s -> !s.getReporterId().equals(report.getOwnerId()) && s.getHiddenAt() == null
                        && !banned.contains(s.getReporterId()))
                .toList();
        List<Match> created = new ArrayList<>();
        for (Sighting other : others) {
            Hit hit = best.get(other.getId());
            save(report.getId(), other.getId(), hit.score(), photo.getId(), hit.photoId(), created);
        }
        return sorted(created);
    }

    /** A sighting's photo: search lost reports from the last weeks, still open. */
    private List<Match> matchSighting(Photo photo, Sighting sighting, List<Double> vector) {
        Set<UUID> banned = bannedUsers();
        if (sighting.getHiddenAt() != null || banned.contains(sighting.getReporterId())) {
            return List.of();
        }
        List<Hit> hits = index.search(vector, sighting.getSpecies(), "lost", sighting.getLocation(),
                settings.radiusKm() * 1000, sighting.getSeenAt().minusDays(settings.lostWindowDays()),
                sighting.getSeenAt().plusDays(settings.sightingGraceDays()), SEARCH_LIMIT);
        Map<UUID, Hit> best = bestPerRecord(hits, photo, sighting.getSpecies());
        if (best.isEmpty()) {
            return List.of();
        }
        List<LostReport> others = reports.findAllById(best.keySet()).stream()
                .filter(r -> r.getStatus() == ReportStatus.OPEN && r.getHiddenAt() == null
                        && !r.getOwnerId().equals(sighting.getReporterId()) && !banned.contains(r.getOwnerId()))
                .toList();
        List<Match> created = new ArrayList<>();
        for (LostReport other : others) {
            Hit hit = best.get(other.getId());
            save(other.getId(), sighting.getId(), hit.score(), hit.photoId(), photo.getId(), created);
        }
        return sorted(created);
    }

    /** Their content isn't matched while they're banned (it's hidden from everyone else). */
    private Set<UUID> bannedUsers() {
        return jdbc.sql("SELECT id FROM users WHERE banned_until > now()").query(UUID.class).set();
    }

        /** The best score per (report, sighting) pair, above the species threshold. */
    private Map<UUID, Hit> bestPerRecord(List<Hit> hits, Photo photo, Species species) {
        double threshold = settings.threshold(species);
        Map<UUID, Hit> best = new LinkedHashMap<>();
        for (Hit hit : hits) {
            if (hit.score() >= threshold && !hit.photoId().equals(photo.getId())) {
                best.merge(hit.refId(), hit, (a, b) -> b.score() > a.score() ? b : a);
            }
        }
        return best;
    }

    /**
     * Inserts the match, or raises its score if the pair is already matched. In one SQL statement
     * each: two workers may match the same pair at the same time.
     */
    private void save(UUID reportId, UUID sightingId, double score, UUID lostPhotoId, UUID sightingPhotoId,
            List<Match> created) {
        var newId = jdbc.sql("""
                        INSERT INTO matches (id, lost_report_id, sighting_id, score, lost_photo_id, sighting_photo_id,
                                             status, created_at)
                        VALUES (:id, :report, :sighting, :score, :lostPhoto, :sightingPhoto, 'PENDING', now())
                        ON CONFLICT (lost_report_id, sighting_id) DO NOTHING
                        RETURNING id""")
                .param("id", UUID.randomUUID())
                .param("report", reportId)
                .param("sighting", sightingId)
                .param("score", score)
                .param("lostPhoto", lostPhotoId)
                .param("sightingPhoto", sightingPhotoId)
                .query(UUID.class)
                .optional();
        if (newId.isPresent()) {
            created.add(matches.findById(newId.get()).orElseThrow());
        } else {
            jdbc.sql("""
                            UPDATE matches SET score = :score, lost_photo_id = :lostPhoto, sighting_photo_id = :sightingPhoto
                            WHERE lost_report_id = :report AND sighting_id = :sighting AND score < :score""")
                    .param("score", score)
                    .param("lostPhoto", lostPhotoId)
                    .param("sightingPhoto", sightingPhotoId)
                    .param("report", reportId)
                    .param("sighting", sightingId)
                    .update();
        }
    }

    private static List<Match> sorted(List<Match> created) {
        created.sort(Comparator.comparingDouble(Match::getScore).reversed());
        return created;
    }
}
