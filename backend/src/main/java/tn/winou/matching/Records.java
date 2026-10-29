package tn.winou.matching;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;

import tn.winou.common.AfterCommit;
import tn.winou.domain.LostReport;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.Species;
import tn.winou.infra.VectorIndex;
import tn.winou.photos.PhotoService;

/** Changes to lost reports and sightings that must reach Qdrant and the matcher. */
@Component
public class Records {

    private final VectorIndex index;
    private final PhotoRepository photos;
    private final PhotoService photoService;

    public Records(VectorIndex index, PhotoRepository photos, PhotoService photoService) {
        this.index = index;
        this.photos = photos;
        this.photoService = photoService;
    }

    public static Map<String, Object> payload(LostReport report) {
        return VectorIndex.payload(report.getSpecies(), "lost", report.getId(), report.getLastSeen(),
                report.getLastSeenAt());
    }

    public static Map<String, Object> payload(Sighting sighting) {
        return VectorIndex.payload(sighting.getSpecies(), "sighting", sighting.getId(), sighting.getLocation(),
                sighting.getSeenAt());
    }

    /**
     * Call inside the transaction that edited what matching depends on (species, place, time, status).
     * Processed photos are queued again: the worker reuses their vectors and searches with the new filters.
     */
    public void rematch(UUID recordId, Species species, Map<String, Object> payload) {
        photos.requeueProcessed(recordId, OffsetDateTime.now());
        AfterCommit.run(() -> {
            if (species == Species.OTHER) {
                index.deleteRef(recordId);
            } else {
                index.updateRef(recordId, payload);
            }
        });
    }

    /** Call inside the transaction that deletes the record. Photos and matches cascade in Postgres. */
    public void deleted(UUID recordId, List<Photo> recordPhotos) {
        index.deleteRef(recordId);
        photoService.deleteFilesAfterCommit(recordPhotos);
    }
}
