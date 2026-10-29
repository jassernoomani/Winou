package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SightingRepository extends JpaRepository<Sighting, UUID> {

    List<Sighting> findByReporterIdOrderByCreatedAtDesc(UUID reporterId);

    long countByReporterIdAndCreatedAtGreaterThanEqual(UUID reporterId, OffsetDateTime since);
}
