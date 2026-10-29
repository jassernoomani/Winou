package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import org.hibernate.annotations.ColumnTransformer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "sightings")
@Getter
@Setter
@NoArgsConstructor
public class Sighting extends BaseEntity {

    private UUID reporterId;
    private Species species;

    @Column(name = "point")
    @ColumnTransformer(read = "ST_AsText(point)", write = "ST_GeogFromText(?)")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private String point;

    private OffsetDateTime seenAt;

    @Enumerated(EnumType.STRING)
    private Condition condition = Condition.HEALTHY;

    private String note;

    @Column(name = "is_stray")
    private boolean stray;

    private OffsetDateTime createdAt = OffsetDateTime.now();

    public GeoPoint getLocation() {
        return GeoPoint.parse(point);
    }

    public void setLocation(GeoPoint location) {
        point = location.toEwkt();
    }
}
