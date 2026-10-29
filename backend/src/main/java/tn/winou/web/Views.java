package tn.winou.web;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Component;

import tn.winou.common.Geo;
import tn.winou.config.WinouProperties;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.LostReport;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.User;
import tn.winou.web.ApiModels.Location;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.ApiModels.SightingOut;

/** Entities to response bodies. Applies the privacy rules: fuzzed positions, hidden reporters. */
@Component
public class Views {

    private final PhotoRepository photos;
    private final WinouProperties.Privacy privacy;

    public Views(PhotoRepository photos, WinouProperties properties) {
        this.photos = photos;
        this.privacy = properties.privacy();
    }

    public static String imageUrl(UUID photoId) {
        return photoId == null ? null : "/photos/" + photoId + "/image";
    }

    public static PhotoOut photo(Photo photo) {
        return new PhotoOut(photo.getId(), photo.getStatus(), photo.getDetectedSpecies(), imageUrl(photo.getId()),
                photo.getCropKey() != null ? "/photos/" + photo.getId() + "/crop" : null, photo.getCreatedAt());
    }

    /** Exact for the owner, moved up to LOCATION_FUZZ_M for everyone else. */
    public GeoPoint shownPosition(UUID reportId, UUID ownerId, GeoPoint exact, User viewer) {
        if (viewer != null && viewer.getId().equals(ownerId)) {
            return exact;
        }
        return publicPosition(reportId, exact);
    }

    public GeoPoint publicPosition(UUID reportId, GeoPoint exact) {
        return Geo.fuzz(reportId, exact, privacy.locationFuzzM(), privacy.locationFuzzSecret());
    }

    public LostReportOut report(LostReport report, User viewer) {
        return reports(List.of(report), viewer).getFirst();
    }

    public List<LostReportOut> reports(List<LostReport> reports, User viewer) {
        Map<UUID, List<Photo>> byReport = group(
                photos.findByLostReportIdInOrderByCreatedAt(ids(reports, LostReport::getId)), Photo::getLostReportId);
        return reports.stream().map(r -> {
            boolean exact = viewer != null && viewer.getId().equals(r.getOwnerId());
            GeoPoint shown = shownPosition(r.getId(), r.getOwnerId(), r.getLastSeen(), viewer);
            return new LostReportOut(r.getId(), r.getName(), r.getSpecies(), r.getDescription(), Location.of(shown),
                    !exact, r.getLastSeenAt(), r.getStatus(), photoList(byReport.get(r.getId())), r.getCreatedAt());
        }).toList();
    }

    public SightingOut sighting(Sighting sighting, User viewer) {
        return sightings(List.of(sighting), viewer).getFirst();
    }

    /**
     * Sightings are about the animal, not a home address: the location is shown as reported.
     * The reporter is never exposed.
     */
    public List<SightingOut> sightings(List<Sighting> sightings, User viewer) {
        Map<UUID, List<Photo>> bySighting = group(
                photos.findBySightingIdInOrderByCreatedAt(ids(sightings, Sighting::getId)), Photo::getSightingId);
        return sightings.stream().map(s -> new SightingOut(s.getId(), s.getSpecies(), Location.of(s.getLocation()),
                s.getSeenAt(), s.getCondition(), s.getNote(), s.isStray(),
                viewer != null && viewer.getId().equals(s.getReporterId()),
                photoList(bySighting.get(s.getId())), s.getCreatedAt())).toList();
    }

    private static List<PhotoOut> photoList(List<Photo> photos) {
        return photos == null ? List.of() : photos.stream().map(Views::photo).toList();
    }

    private static <T> List<UUID> ids(Collection<T> items, java.util.function.Function<T, UUID> id) {
        return items.stream().map(id).toList();
    }

    private static Map<UUID, List<Photo>> group(List<Photo> photos, java.util.function.Function<Photo, UUID> key) {
        // groupingBy keeps the encounter order, so each list stays sorted by creation time
        return photos.stream().collect(Collectors.groupingBy(key));
    }
}
