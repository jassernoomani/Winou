-- "Is Luna still missing?": the owner is asked two weeks after the report, then at four weeks, so
-- pets back home don't stay on the map. Counts the reminders already sent.
ALTER TABLE lost_reports ADD COLUMN reminders_sent smallint NOT NULL DEFAULT 0;

-- Searching lost pets by name or description
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ix_lost_reports_search ON lost_reports USING gin ((name || ' ' || coalesce(description, '')) gin_trgm_ops);
