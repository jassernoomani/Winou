package tn.winou.domain;

import java.time.OffsetDateTime;
import java.util.UUID;

import org.hibernate.annotations.ColumnTransformer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "messages")
@Getter
@NoArgsConstructor
public class ChatMessage extends BaseEntity {

    private UUID conversationId;
    private UUID senderId;
    private String body; // null for a photo or a place without words
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Setter
    private String photoKey; // a photo, EXIF-free, for the two participants only

    @Column(name = "point")
    @ColumnTransformer(read = "ST_AsText(point)", write = "ST_GeogFromText(?)")
    @Getter(AccessLevel.NONE)
    private String point; // a place shared in the chat

    @Setter
    private OffsetDateTime hiddenAt; // reported: the recipient no longer sees it

    public ChatMessage(UUID conversationId, UUID senderId, String body) {
        this.conversationId = conversationId;
        this.senderId = senderId;
        this.body = body;
    }

    public GeoPoint getLocation() {
        return point == null ? null : GeoPoint.parse(point);
    }

    public void setLocation(GeoPoint location) {
        point = location == null ? null : location.toEwkt();
    }
}
