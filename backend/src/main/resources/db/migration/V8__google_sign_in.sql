-- "Continue with Google": an account may have no password, and is tied to its Google account by
-- Google's stable user id (the email can change on Google's side).
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE users ADD COLUMN google_sub varchar(255) UNIQUE;

-- Set when we know the address is theirs: Google said so, or they typed a code we emailed.
ALTER TABLE users ADD COLUMN email_verified_at timestamptz;
