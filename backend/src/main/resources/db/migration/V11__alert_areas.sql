-- Anyone can watch an area: a push when a pet goes missing there, or an animal is reported injured
-- or in need of help (associations hear about those anyway, within their own area).
ALTER TABLE users
    ADD COLUMN watch_point     geography(Point, 4326),
    ADD COLUMN watch_radius_km real,
    ADD COLUMN watch_lost      boolean NOT NULL DEFAULT false,
    ADD COLUMN watch_help      boolean NOT NULL DEFAULT false;
CREATE INDEX idx_users_watch_point ON users USING gist (watch_point);
