-- Every push is also kept here, so people find it again in the app's notifications list. Stored as
-- the same keys and arguments as the push: the app writes the text in its own language. The latest
-- 100 per user are kept.
CREATE TABLE notifications (
    id         uuid PRIMARY KEY,
    user_id    uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title_key  varchar(64)  NOT NULL,
    title_args jsonb        NOT NULL DEFAULT '[]',
    body_key   varchar(64),
    body_args  jsonb        NOT NULL DEFAULT '[]',
    body       text,                     -- a chat message, shown as is
    data       jsonb        NOT NULL DEFAULT '{}',
    created_at timestamptz  NOT NULL DEFAULT now(),
    read_at    timestamptz
);
CREATE INDEX ix_notifications_user ON notifications (user_id, created_at DESC);
