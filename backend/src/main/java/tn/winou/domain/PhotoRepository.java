package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface PhotoRepository extends JpaRepository<Photo, UUID> {

    List<Photo> findByLostReportIdInOrderByCreatedAt(Collection<UUID> lostReportIds);

    List<Photo> findBySightingIdInOrderByCreatedAt(Collection<UUID> sightingIds);

    long countByLostReportId(UUID lostReportId);

    long countBySightingId(UUID sightingId);

    long countByUploaderIdAndCreatedAtGreaterThanEqual(UUID uploaderId, OffsetDateTime since);

    /** Queues processed photos again: the worker reuses their vectors and searches with new filters. */
    @Modifying(flushAutomatically = true)
    @Query("""
            update Photo p set p.status = tn.winou.domain.PhotoStatus.PENDING, p.attempts = 0, p.nextAttemptAt = :now
            where (p.lostReportId = :recordId or p.sightingId = :recordId)
              and p.status in (tn.winou.domain.PhotoStatus.READY, tn.winou.domain.PhotoStatus.SKIPPED)""")
    int requeueProcessed(UUID recordId, OffsetDateTime now);
}
