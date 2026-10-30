-- A stray's care card, kept by the neighbourhood: a name, whether it is sterilised and vaccinated
-- (null: nobody knows), a few words of care notes, and who feeds it.
ALTER TABLE sightings
    ADD COLUMN nickname        varchar(40),
    ADD COLUMN sterilised      boolean,
    ADD COLUMN vaccinated      boolean,
    ADD COLUMN care_notes      varchar(500),
    ADD COLUMN care_updated_at timestamptz,
    ADD COLUMN care_updated_by uuid REFERENCES users (id) ON DELETE SET NULL;

-- "I feed this animal": one row per person, gone with the person or the stray
CREATE TABLE stray_feeders (
    sighting_id uuid        NOT NULL REFERENCES sightings (id) ON DELETE CASCADE,
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    since       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (sighting_id, user_id)
);
CREATE INDEX ix_stray_feeders_user ON stray_feeders (user_id);
