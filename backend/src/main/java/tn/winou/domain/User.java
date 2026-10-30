package tn.winou.domain;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

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
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User extends BaseEntity {

    /** banned_until for a ban without an end. */
    public static final OffsetDateTime BANNED_FOREVER = OffsetDateTime.of(9999, 12, 31, 0, 0, 0, 0, ZoneOffset.UTC);

    private String email;
    private String passwordHash;
    private String displayName;

    @Enumerated(EnumType.STRING)
    private Role role = Role.USER;

    private String fcmToken;

    /** Set once an admin approves the user's association request. */
    private String associationName;

    @Column(name = "alert_point")
    @ColumnTransformer(read = "ST_AsText(alert_point)", write = "ST_GeogFromText(?)")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private String alertPoint;
    private OffsetDateTime createdAt = OffsetDateTime.now();

    /** Set by an admin; the ban is over once this has passed. */
    private OffsetDateTime bannedUntil;
    private String banReason;

    public User(String email, String passwordHash, String displayName) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.displayName = displayName;
    }

    /** Where an association hears about injured animals; null for everyone else. */
    public GeoPoint getAlertLocation() {
        return alertPoint == null ? null : GeoPoint.parse(alertPoint);
    }

    public void setAlertLocation(GeoPoint location) {
        alertPoint = location == null ? null : location.toEwkt();
    }

    public boolean isAssociation() {
        return role == Role.ASSOCIATION && associationName != null;
    }

    public boolean isBanned() {
        return bannedUntil != null && bannedUntil.isAfter(OffsetDateTime.now());
    }
}
