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

/** A user asking to be shown as an association. An admin checks the contact and decides. */
@Entity
@Table(name = "association_requests")
@Getter
@Setter
@NoArgsConstructor
public class AssociationRequest extends BaseEntity {

    private UUID userId;
    private String organisation;
    private String city;
    private String contact;
    private String note;

    @Column(name = "point")
    @ColumnTransformer(read = "ST_AsText(point)", write = "ST_GeogFromText(?)")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private String point;

    @Enumerated(EnumType.STRING)
    private RequestStatus status = RequestStatus.PENDING;

    private OffsetDateTime createdAt = OffsetDateTime.now();
    private OffsetDateTime decidedAt;
    private UUID decidedBy;

    public GeoPoint getLocation() {
        return GeoPoint.parse(point);
    }

    public void setLocation(GeoPoint location) {
        point = location.toEwkt();
    }
}
