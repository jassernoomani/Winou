-- Same schema the Python API created with Alembic. IF NOT EXISTS everywhere, so a database
-- created by Alembic is adopted as is (Flyway baselines at version 0, then runs this).

CREATE EXTENSION IF NOT EXISTS postgis;

-- Enums are VARCHAR + CHECK rather than native Postgres enums, which are awkward to migrate.

CREATE TABLE IF NOT EXISTS users (
    id            uuid PRIMARY KEY,
    email         varchar(320) NOT NULL UNIQUE,
    password_hash varchar(255) NOT NULL,
    display_name  varchar(80)  NOT NULL,
    role          varchar(16)  NOT NULL CONSTRAINT role CHECK (role IN ('USER', 'ASSOCIATION', 'ADMIN')),
    fcm_token     varchar(4096),
    created_at    timestamptz  NOT NULL DEFAULT now()
);

-- Points are geography(Point, 4326): lon/lat in WGS84, distances in metres.
CREATE TABLE IF NOT EXISTS lost_reports (
    id              uuid PRIMARY KEY,
    owner_id        uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name            varchar(80)  NOT NULL,
    species         varchar(16)  NOT NULL CONSTRAINT species CHECK (species IN ('cat', 'dog', 'other')),
    description     text,
    last_seen_point geography(Point, 4326) NOT NULL,
    last_seen_at    timestamptz  NOT NULL,
    status          varchar(16)  NOT NULL CONSTRAINT reportstatus CHECK (status IN ('OPEN', 'FOUND', 'CLOSED')),
    created_at      timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lost_reports_last_seen_point ON lost_reports USING gist (last_seen_point);
CREATE INDEX IF NOT EXISTS ix_lost_reports_owner_id ON lost_reports (owner_id);
CREATE INDEX IF NOT EXISTS ix_lost_reports_status ON lost_reports (status);

CREATE TABLE IF NOT EXISTS sightings (
    id          uuid PRIMARY KEY,
    reporter_id uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    species     varchar(16) NOT NULL CONSTRAINT species CHECK (species IN ('cat', 'dog', 'other')),
    point       geography(Point, 4326) NOT NULL,
    seen_at     timestamptz NOT NULL,
    condition   varchar(16) NOT NULL CONSTRAINT condition CHECK (condition IN ('HEALTHY', 'INJURED', 'NEEDS_HELP')),
    note        text,
    is_stray    boolean     NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sightings_point ON sightings USING gist (point);
CREATE INDEX IF NOT EXISTS ix_sightings_reporter_id ON sightings (reporter_id);
CREATE INDEX IF NOT EXISTS ix_sightings_seen_at ON sightings (seen_at);

-- A photo belongs to exactly one lost report or sighting. Its id is also its Qdrant point id.
CREATE TABLE IF NOT EXISTS photos (
    id                   uuid PRIMARY KEY,
    uploader_id          uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    lost_report_id       uuid REFERENCES lost_reports (id) ON DELETE CASCADE,
    sighting_id          uuid REFERENCES sightings (id) ON DELETE CASCADE,
    original_key         varchar(255) NOT NULL,  -- as uploaded, may hold GPS EXIF: never served
    public_key           varchar(255) NOT NULL,  -- re-encoded JPEG without EXIF
    crop_key             varchar(255),
    status               varchar(16)  NOT NULL CONSTRAINT photostatus
        CHECK (status IN ('PENDING', 'PROCESSING', 'READY', 'NO_ANIMAL', 'SKIPPED', 'FAILED')),
    detected_species     varchar(16),
    detection_confidence double precision,
    error                text,
    attempts             integer      NOT NULL,
    next_attempt_at      timestamptz  NOT NULL DEFAULT now(),
    processed_at         timestamptz,
    created_at           timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT one_owner CHECK ((lost_report_id IS NULL) <> (sighting_id IS NULL))
);
CREATE INDEX IF NOT EXISTS ix_photos_lost_report_id ON photos (lost_report_id);
CREATE INDEX IF NOT EXISTS ix_photos_sighting_id ON photos (sighting_id);
CREATE INDEX IF NOT EXISTS ix_photos_status ON photos (status);
CREATE INDEX IF NOT EXISTS ix_photos_uploader_id ON photos (uploader_id);

CREATE TABLE IF NOT EXISTS matches (
    id                uuid PRIMARY KEY,
    lost_report_id    uuid             NOT NULL REFERENCES lost_reports (id) ON DELETE CASCADE,
    sighting_id       uuid             NOT NULL REFERENCES sightings (id) ON DELETE CASCADE,
    score             double precision NOT NULL,  -- best photo-to-photo cosine similarity of the pair
    lost_photo_id     uuid REFERENCES photos (id) ON DELETE SET NULL,
    sighting_photo_id uuid REFERENCES photos (id) ON DELETE SET NULL,
    status            varchar(16)      NOT NULL CONSTRAINT matchstatus
        CHECK (status IN ('PENDING', 'CONFIRMED', 'REJECTED')),
    notified_at       timestamptz,
    created_at        timestamptz      NOT NULL DEFAULT now(),
    UNIQUE (lost_report_id, sighting_id)
);
CREATE INDEX IF NOT EXISTS ix_matches_lost_report_id ON matches (lost_report_id);
CREATE INDEX IF NOT EXISTS ix_matches_sighting_id ON matches (sighting_id);
