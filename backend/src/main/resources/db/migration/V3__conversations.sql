-- Owner <-> finder messaging. The owner starts a conversation from a match; it outlives the match
-- (a deleted sighting) but not the lost report.
CREATE TABLE conversations (
    id              uuid PRIMARY KEY,
    lost_report_id  uuid        NOT NULL REFERENCES lost_reports (id) ON DELETE CASCADE,
    match_id        uuid        UNIQUE REFERENCES matches (id) ON DELETE SET NULL,
    owner_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    finder_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    last_message_at timestamptz,
    owner_read_at   timestamptz,
    finder_read_at  timestamptz
);
CREATE INDEX ix_conversations_owner_id ON conversations (owner_id);
CREATE INDEX ix_conversations_finder_id ON conversations (finder_id);

CREATE TABLE messages (
    id              uuid PRIMARY KEY,
    conversation_id uuid          NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    sender_id       uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    body            varchar(2000) NOT NULL,
    created_at      timestamptz   NOT NULL DEFAULT now()
);
CREATE INDEX ix_messages_conversation_created ON messages (conversation_id, created_at);
CREATE INDEX ix_messages_sender_created ON messages (sender_id, created_at);
