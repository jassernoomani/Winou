package tn.winou.domain;

import java.util.UUID;

import org.springframework.data.domain.Persistable;

import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Transient;
import lombok.Getter;

/**
 * Ids are assigned in Java, before saving (a photo's storage keys contain its id).
 * Persistable tells Spring Data the entity is new anyway, so save() inserts instead of merging.
 */
@MappedSuperclass
@Getter
public abstract class BaseEntity implements Persistable<UUID> {

    @Id
    private UUID id = UUID.randomUUID();

    @Transient
    private boolean isNew = true;

    @Override
    public boolean isNew() {
        return isNew;
    }

    @PostLoad
    @PostPersist
    void markNotNew() {
        isNew = false;
    }
}
