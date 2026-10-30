-- 6-digit codes sent by email: to reset a forgotten password, or to prove an address is yours.
-- Stored hashed; a code works once, for 15 minutes, with 5 tries. Sending a new one ends the old.
CREATE TABLE email_codes (
    id         uuid PRIMARY KEY,
    user_id    uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    purpose    varchar(16)  NOT NULL CONSTRAINT codepurpose CHECK (purpose IN ('RESET', 'VERIFY')),
    code_hash  varchar(64)  NOT NULL,
    attempts   integer      NOT NULL DEFAULT 0,
    created_at timestamptz  NOT NULL DEFAULT now(),
    expires_at timestamptz  NOT NULL,
    used_at    timestamptz
);
CREATE INDEX ix_email_codes_user ON email_codes (user_id, purpose, created_at DESC);
