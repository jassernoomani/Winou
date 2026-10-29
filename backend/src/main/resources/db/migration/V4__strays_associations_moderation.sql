-- Phase 5: what became of a stray, association accounts, and reported content.

-- A stray is still around, was helped (taken in, treated, adopted) or hasn't been seen for a while.
-- stray_status_at is the last update: "still around" refreshes it, and the map drops strays not
-- updated or seen for STRAY_FADE_DAYS.
ALTER TABLE sightings
    ADD COLUMN stray_status    varchar(16) NOT NULL DEFAULT 'AROUND'
        CONSTRAINT straystatus CHECK (stray_status IN ('AROUND', 'HELPED', 'GONE')),
    ADD COLUMN stray_status_at timestamptz,
    ADD COLUMN stray_status_by uuid REFERENCES users (id) ON DELETE SET NULL,
    ADD COLUMN hidden_at       timestamptz;

ALTER TABLE lost_reports ADD COLUMN hidden_at timestamptz;
ALTER TABLE messages ADD COLUMN hidden_at timestamptz;

-- Set when an admin approves an association request: the name shown next to theirs, and where
-- they want to hear about injured animals.
ALTER TABLE users
    ADD COLUMN association_name varchar(120),
    ADD COLUMN alert_point      geography(Point, 4326);
CREATE INDEX idx_users_alert_point ON users USING gist (alert_point);

CREATE TABLE association_requests (
    id           uuid PRIMARY KEY,
    user_id      uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    organisation varchar(120)  NOT NULL,
    city         varchar(80)   NOT NULL,
    contact      varchar(200)  NOT NULL,  -- phone, website or social page, for the admin to check
    note         varchar(1000),
    point        geography(Point, 4326) NOT NULL,
    status       varchar(16)   NOT NULL CONSTRAINT requeststatus CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at   timestamptz   NOT NULL DEFAULT now(),
    decided_at   timestamptz,
    decided_by   uuid REFERENCES users (id) ON DELETE SET NULL
);
-- One open request per user at a time
CREATE UNIQUE INDEX ux_association_requests_pending ON association_requests (user_id) WHERE status = 'PENDING';
CREATE INDEX ix_association_requests_status ON association_requests (status, created_at);

-- "Report" button: one report per user and item. Enough distinct reporters hide the item until an
-- admin restores it (which clears its reports) or deletes it.
CREATE TABLE content_reports (
    id          uuid PRIMARY KEY,
    reporter_id uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    target_type varchar(16)  NOT NULL CONSTRAINT targettype CHECK (target_type IN ('LOST_REPORT', 'SIGHTING', 'MESSAGE')),
    target_id   uuid         NOT NULL,
    reason      varchar(16)  NOT NULL
        CONSTRAINT reportreason CHECK (reason IN ('SPAM', 'INAPPROPRIATE', 'FAKE', 'DANGEROUS', 'OTHER')),
    note        varchar(500),
    created_at  timestamptz  NOT NULL DEFAULT now(),
    UNIQUE (reporter_id, target_type, target_id)
);
CREATE INDEX ix_content_reports_target ON content_reports (target_type, target_id);
CREATE INDEX ix_content_reports_reporter_created ON content_reports (reporter_id, created_at);
