package tn.winou.search;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import io.micrometer.core.instrument.MeterRegistry;
import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.Species;
import tn.winou.domain.User;
import tn.winou.infra.MlClient;
import tn.winou.infra.MlClient.NoAnimalDetected;
import tn.winou.infra.VectorIndex;
import tn.winou.infra.VectorIndex.Hit;
import tn.winou.photos.Images;
import tn.winou.photos.PhotoService;
import tn.winou.security.AttemptLimiter;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.Views;

/**
 * Photo checks before posting, and "is this someone's pet?" searches. Both run the model on the
 * photo and store nothing: no file, no row, no vector.
 */
@Service
public class PhotoSearchService {

    private static final Duration HOUR = Duration.ofHours(1);
    /** Search results reach a bit below the matching threshold: a person looks at them, not a push. */
    static final double POSSIBLE_MARGIN = 0.10;
    private static final int SEARCH_LIMIT = 50;
    private static final int MAX_RESULTS = 10;

    public record CheckOut(String species, double confidence) {}

    public record SearchHit(LostReportOut report, double score, boolean likely, String matchedImageUrl) {}

    public record SearchOut(String species, double confidence, List<SearchHit> results) {}

    private final PhotoService photos;
    private final Images images;
    private final MlClient ml;
    private final VectorIndex index;
    private final LostReportRepository reports;
    private final JdbcClient jdbc;
    private final Views views;
    private final AttemptLimiter limiter;
    private final WinouProperties properties;
    private final MeterRegistry metrics;

    public PhotoSearchService(PhotoService photos, Images images, MlClient ml, VectorIndex index,
            LostReportRepository reports, JdbcClient jdbc, Views views, AttemptLimiter limiter,
            WinouProperties properties, MeterRegistry metrics) {
        this.photos = photos;
        this.images = images;
        this.ml = ml;
        this.index = index;
        this.reports = reports;
        this.jdbc = jdbc;
        this.views = views;
        this.limiter = limiter;
        this.properties = properties;
        this.metrics = metrics;
    }

    /** Is there a cat or dog in this photo? For instant feedback while a post is being written. */
    public CheckOut check(User user, MultipartFile file) {
        limit("photo-check:" + user.getId(), properties.rateLimits().photoChecksPerHour());
        byte[] jpeg = images.publicCopy(photos.bytes(file)).jpeg();
        try {
            MlClient.Detection detection = ml.detect(jpeg);
            count("winou.photo.checks", "animal");
            return new CheckOut(detection.species(), detection.confidence());
        } catch (NoAnimalDetected e) {
            count("winou.photo.checks", "no_animal");
            throw noAnimal();
        }
    }

    /**
     * Open lost reports near [center] whose photos look like this one, best first. The species is
     * the one detected unless the user says otherwise.
     */
    public SearchOut search(User user, MultipartFile file, GeoPoint center, double radiusKm, Species species) {
        limit("photo-search:" + user.getId(), properties.rateLimits().photoSearchesPerHour());
        byte[] jpeg = images.publicCopy(photos.bytes(file)).jpeg();
        MlClient.Embedding embedding;
        try {
            embedding = ml.embed(jpeg);
        } catch (NoAnimalDetected e) {
            count("winou.photo.searches", "no_animal");
            throw noAnimal();
        }
        Species searched = species != null ? species : "dog".equals(embedding.species()) ? Species.DOG : Species.CAT;

        var matching = properties.matching();
        double minScore = matching.threshold(searched) - POSSIBLE_MARGIN;
        List<Hit> hits = index.search(embedding.vector(), searched, "lost", center, radiusKm * 1000,
                OffsetDateTime.now().minusDays(matching.lostWindowDays()), null, SEARCH_LIMIT);
        Map<UUID, Hit> best = new LinkedHashMap<>();
        for (Hit hit : hits) {
            if (hit.score() >= minScore) {
                best.merge(hit.refId(), hit, (a, b) -> b.score() > a.score() ? b : a);
            }
        }

        Set<UUID> banned = jdbc.sql("SELECT id FROM users WHERE banned_until > now()").query(UUID.class).set();
        List<LostReport> found = reports.findAllById(best.keySet()).stream()
                .filter(r -> r.getStatus() == ReportStatus.OPEN && r.getHiddenAt() == null
                        && !banned.contains(r.getOwnerId()))
                .sorted(Comparator.comparingDouble((LostReport r) -> best.get(r.getId()).score()).reversed())
                .limit(MAX_RESULTS)
                .toList();
        Map<UUID, LostReportOut> outs = views.reports(found, user).stream()
                .collect(Collectors.toMap(LostReportOut::id, Function.identity()));
        double threshold = matching.threshold(searched);
        List<SearchHit> results = found.stream().map(r -> {
            Hit hit = best.get(r.getId());
            return new SearchHit(outs.get(r.getId()), hit.score(), hit.score() >= threshold,
                    Views.imageUrl(hit.photoId()));
        }).toList();
        count("winou.photo.searches", results.isEmpty() ? "nothing" : "found");
        return new SearchOut(searched.api(), embedding.confidence(), results);
    }

    private void limit(String key, int perHour) {
        limiter.check(key, perHour, HOUR);
        limiter.record(key, HOUR);
    }

    private void count(String name, String outcome) {
        metrics.counter(name, "outcome", outcome).increment();
    }

    private static ApiException noAnimal() {
        return ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "no_animal_detected",
                "No cat or dog found. Try a closer photo showing the animal's head.");
    }
}
