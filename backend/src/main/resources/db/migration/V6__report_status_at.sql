-- When a lost report last changed status (found, closed, reopened), for the admin dashboard's
-- "reunited per week". Reports closed before this column existed count from their creation.
ALTER TABLE lost_reports ADD COLUMN status_at timestamptz;
UPDATE lost_reports SET status_at = created_at WHERE status <> 'OPEN';
