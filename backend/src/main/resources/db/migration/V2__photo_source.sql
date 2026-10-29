-- Where the app got the photo (camera or gallery). Internal only, never exposed by the API.
ALTER TABLE photos ADD COLUMN IF NOT EXISTS source varchar(16);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'photosource') THEN
        ALTER TABLE photos ADD CONSTRAINT photosource CHECK (source IN ('CAMERA', 'GALLERY'));
    END IF;
END $$;

-- Alembic's bookkeeping, left over from the Python API
DROP TABLE IF EXISTS alembic_version;
