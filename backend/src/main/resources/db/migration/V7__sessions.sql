-- Sign-in that lasts: each signed-in phone holds a refresh token (stored here as a SHA-256 hash)
-- that gets it a new access token. A refresh token changes at every use and expires after
-- REFRESH_TOKEN_DAYS without use. Revoking a session signs that phone out.
CREATE TABLE sessions (
    id           uuid PRIMARY KEY,
    user_id      uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash   varchar(64)  NOT NULL UNIQUE,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    last_used_at timestamptz  NOT NULL DEFAULT now(),
    expires_at   timestamptz  NOT NULL,
    revoked_at   timestamptz
);
CREATE INDEX ix_sessions_user ON sessions (user_id);

-- "Sign out everywhere" and a password change raise it: access tokens carry the version they
-- were issued with, and older ones are refused.
ALTER TABLE users ADD COLUMN token_version integer NOT NULL DEFAULT 0;
