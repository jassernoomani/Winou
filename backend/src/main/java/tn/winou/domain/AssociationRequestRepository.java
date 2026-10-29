package tn.winou.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AssociationRequestRepository extends JpaRepository<AssociationRequest, UUID> {

    Optional<AssociationRequest> findFirstByUserIdOrderByCreatedAtDesc(UUID userId);

    boolean existsByUserIdAndStatus(UUID userId, RequestStatus status);

    List<AssociationRequest> findByStatusOrderByCreatedAt(RequestStatus status);
}
