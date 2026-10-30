-- Chat messages can carry a photo (stored EXIF-free, shown to the two participants only) or a
-- place ("she's here right now"), with or without text.
ALTER TABLE messages
    ALTER COLUMN body DROP NOT NULL,
    ADD COLUMN photo_key varchar(255),
    ADD COLUMN point     geography(Point, 4326),
    ADD CONSTRAINT message_content CHECK (body IS NOT NULL OR photo_key IS NOT NULL OR point IS NOT NULL);
