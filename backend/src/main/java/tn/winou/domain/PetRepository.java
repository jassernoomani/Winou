package tn.winou.domain;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface PetRepository extends JpaRepository<Pet, UUID> {

    List<Pet> findByOwnerIdOrderByCreatedAt(UUID ownerId);
}
