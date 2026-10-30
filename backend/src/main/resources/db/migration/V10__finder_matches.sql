-- "I saw this pet": a sighting posted from a lost report's page is matched to it by the person
-- who saw the animal, not by the model. Such matches are listed first; if the model also scores
-- the pair later, the score is filled in and the match keeps its source.
ALTER TABLE matches ADD COLUMN source varchar(16) NOT NULL DEFAULT 'MODEL'
    CONSTRAINT matchsource CHECK (source IN ('MODEL', 'FINDER'));
