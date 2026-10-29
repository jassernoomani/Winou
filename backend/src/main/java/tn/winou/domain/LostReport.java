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
@Table(name = "lost_reports")
@Getter
@Setter
@NoArgsConstructor
public class LostReport extends BaseEntity {

    private UUID ownerId;
    private String name;
    private Species species;
    private String description;

    @Column(name = "last_seen_point")
    @ColumnTransformer(read = "ST_AsText(last_seen_point)", write = "ST_GeogFromText(?)")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private String lastSeenPoint;

    private OffsetDateTime lastSeenAt;

    @Enumerated(EnumType.STRING)
    private ReportStatus status = ReportStatus.OPEN;

    private OffsetDateTime createdAt = OffsetDateTime.now();

    public GeoPoint getLastSeen() {
        return GeoPoint.parse(lastSeenPoint);
    }

    public void setLastSeen(GeoPoint point) {
        lastSeenPoint = point.toEwkt();
    }
}
