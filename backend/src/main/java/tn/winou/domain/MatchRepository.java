package tn.winou.domain;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface MatchRepository extends JpaRepository<Match, UUID> {

    @Query("""
            select m from Match m
            where m.lostReportId in (select r.id from LostReport r where r.ownerId = :ownerId)
            order by m.score desc""")
    List<Match> findForOwner(UUID ownerId);
}
