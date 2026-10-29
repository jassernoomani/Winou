package tn.winou.domain;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface MatchRepository extends JpaRepository<Match, UUID> {

    /**
     * Matches to show the owner: not the rejected ones, and once a case is closed only the
     * confirmed ones (the others come back if the report is reopened).
     */
    @Query("""
            select m from Match m join LostReport r on r.id = m.lostReportId
            where r.ownerId = :ownerId
              and m.status <> tn.winou.domain.MatchStatus.REJECTED
              and (r.status = tn.winou.domain.ReportStatus.OPEN or m.status = tn.winou.domain.MatchStatus.CONFIRMED)
            order by m.score desc""")
    List<Match> findForOwner(UUID ownerId);

    List<Match> findByLostReportIdAndStatus(UUID lostReportId, MatchStatus status);
}
