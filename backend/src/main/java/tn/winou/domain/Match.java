package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** A possible sighting of a lost pet. Inserted by the matcher with plain SQL (see Matcher). */
@Entity
@Table(name = "matches")
@Getter
@Setter
@NoArgsConstructor
public class Match extends BaseEntity {

    private UUID lostReportId;
    private UUID sightingId;
    private double score; // best photo-to-photo cosine similarity of the pair
    private UUID lostPhotoId;
    private UUID sightingPhotoId;

    @Enumerated(EnumType.STRING)
    private MatchStatus status = MatchStatus.PENDING;

    private OffsetDateTime notifiedAt;
    private OffsetDateTime createdAt;
}
