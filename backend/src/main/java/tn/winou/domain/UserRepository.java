package tn.winou.domain;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    /** A phone gets notifications for one account only: the last one that signed in on it. */
    @Modifying
    @Query("UPDATE User u SET u.fcmToken = NULL WHERE u.fcmToken = :token AND u.id <> :keep")
    int releaseFcmToken(String token, UUID keep);
}
