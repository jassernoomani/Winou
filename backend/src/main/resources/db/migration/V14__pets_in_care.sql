-- "My pets": owners describe their pets before anything happens. Their photos are kept but not
-- matched; marking a pet lost copies them into a lost report, and those copies are matched.
CREATE TABLE pets (
    id           uuid PRIMARY KEY,
    owner_id     uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name         varchar(80)  NOT NULL,
    species      varchar(16)  NOT NULL CONSTRAINT petspecies CHECK (species IN ('cat', 'dog', 'other')),
    description  text,
    microchipped boolean,
    created_at   timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX ix_pets_owner ON pets (owner_id);

ALTER TABLE photos ADD COLUMN pet_id uuid REFERENCES pets (id) ON DELETE CASCADE;
ALTER TABLE photos DROP CONSTRAINT one_owner;
ALTER TABLE photos ADD CONSTRAINT one_owner CHECK (num_nonnulls(lost_report_id, sighting_id, pet_id) = 1);
CREATE INDEX ix_photos_pet_id ON photos (pet_id);

-- The pet a lost report was made from, if any
ALTER TABLE lost_reports ADD COLUMN pet_id uuid REFERENCES pets (id) ON DELETE SET NULL;

-- "I found it and I'm keeping it safe": the finder has the animal with them
ALTER TABLE sightings ADD COLUMN in_care boolean NOT NULL DEFAULT false;
