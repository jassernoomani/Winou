package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface LostReportRepository extends JpaRepository<LostReport, UUID> {

    List<LostReport> findByOwnerIdOrderByCreatedAtDesc(UUID ownerId);

    long countByOwnerIdAndCreatedAtGreaterThanEqual(UUID ownerId, OffsetDateTime since);

    java.util.Optional<LostReport> findFirstByPetIdAndStatusOrderByCreatedAtDesc(UUID petId, ReportStatus status);
}
