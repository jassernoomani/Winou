-- A stray an association offers for adoption: a few words, a number to call, and who offers it.
-- ADOPTED stays visible as a happy ending; withdrawing clears the offer.
ALTER TABLE sightings
    ADD COLUMN adoption_status  varchar(16)
        CONSTRAINT adoptionstatus CHECK (adoption_status IN ('AVAILABLE', 'ADOPTED')),
    ADD COLUMN adoption_note    varchar(500),
    ADD COLUMN adoption_contact varchar(20),
    ADD COLUMN adoption_by      uuid REFERENCES users (id) ON DELETE SET NULL,
    ADD COLUMN adoption_at      timestamptz;
CREATE INDEX IF NOT EXISTS ix_sightings_adoption ON sightings (adoption_at DESC)
    WHERE adoption_status = 'AVAILABLE';

-- Vets and animal shelters, from OpenStreetMap (refreshed weekly by the worker, see places/)
CREATE TABLE places (
    osm_id        varchar(40)  PRIMARY KEY, -- "node/123", "way/456"
    kind          varchar(16)  NOT NULL CONSTRAINT placekind CHECK (kind IN ('VET', 'SHELTER')),
    name          varchar(200),
    phone         varchar(60),
    opening_hours varchar(200),
    point         geography(Point, 4326) NOT NULL,
    fetched_at    timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_places_point ON places USING gist (point);
