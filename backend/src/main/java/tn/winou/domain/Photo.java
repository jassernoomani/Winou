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

/** A photo of a lost report or a sighting (exactly one). Its id is also its Qdrant point id. */
@Entity
@Table(name = "photos")
@Getter
@Setter
@NoArgsConstructor
public class Photo extends BaseEntity {

    private UUID uploaderId;
    private UUID lostReportId;
    private UUID sightingId;
    private String originalKey; // as uploaded, may hold GPS EXIF: never served
    private String publicKey;   // re-encoded JPEG without EXIF
    private String cropKey;

    @Enumerated(EnumType.STRING)
    private PhotoSource source; // null: the client did not say

    @Enumerated(EnumType.STRING)
    private PhotoStatus status = PhotoStatus.PENDING;

    private String detectedSpecies;
    private Double detectionConfidence;
    private String error;
    private int attempts;
    private OffsetDateTime nextAttemptAt = OffsetDateTime.now();
    private OffsetDateTime processedAt;
    private OffsetDateTime createdAt = OffsetDateTime.now();
}
