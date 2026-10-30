-- Admin tools: banning users, and a log of what admins did.

-- A banned user can't sign in or use the API until banned_until (9999-12-31: for good), and their
-- lost reports and sightings are hidden from everyone else meanwhile. An expired ban is left as is.
ALTER TABLE users
    ADD COLUMN banned_until timestamptz,
    ADD COLUMN ban_reason   varchar(500);

-- user_id is the account the action was about (the author of deleted content, the user who asked
-- to be an association...), kept after the content itself is gone.
CREATE TABLE admin_actions (
    id          uuid PRIMARY KEY,
    admin_id    uuid         REFERENCES users (id) ON DELETE SET NULL,
    action      varchar(32)  NOT NULL,
    target_type varchar(32)  NOT NULL,
    target_id   uuid         NOT NULL,
    user_id     uuid         REFERENCES users (id) ON DELETE CASCADE,
    note        varchar(500),
    created_at  timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX ix_admin_actions_created ON admin_actions (created_at DESC);
CREATE INDEX ix_admin_actions_user ON admin_actions (user_id, created_at DESC);
