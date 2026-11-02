-- The home feed: open, visible reports, most recently seen first
CREATE INDEX IF NOT EXISTS ix_lost_reports_feed ON lost_reports (last_seen_at DESC)
    WHERE status = 'OPEN' AND hidden_at IS NULL;

-- The worker claims the next photos due: only the queue, not every photo ever processed
CREATE INDEX IF NOT EXISTS ix_photos_queue ON photos (next_attempt_at)
    WHERE status IN ('PENDING', 'PROCESSING');
