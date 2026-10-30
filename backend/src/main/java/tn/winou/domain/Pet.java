package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** A pet as its owner describes it before anything happens: one tap turns it into a lost report. */
@Entity
@Table(name = "pets")
@Getter
@Setter
@NoArgsConstructor
public class Pet extends BaseEntity {

    private UUID ownerId;
    private String name;
    private Species species;
    private String description;
    private Boolean microchipped; // null: not said
    private OffsetDateTime createdAt = OffsetDateTime.now();
}
