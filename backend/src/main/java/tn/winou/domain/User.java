package tn.winou.domain;

import java.time.OffsetDateTime;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User extends BaseEntity {

    private String email;
    private String passwordHash;
    private String displayName;

    @Enumerated(EnumType.STRING)
    private Role role = Role.USER;

    private String fcmToken;
    private OffsetDateTime createdAt = OffsetDateTime.now();

    public User(String email, String passwordHash, String displayName) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.displayName = displayName;
    }
}
