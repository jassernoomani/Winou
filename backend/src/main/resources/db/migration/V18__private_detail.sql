-- A detail only the owner knows (a hidden marking, the collar, a microchip number). Never public:
-- shown to the owner, and to the finder once the owner has confirmed the match, to check it on the
-- animal before handing it over.
ALTER TABLE lost_reports ADD COLUMN private_detail varchar(300);
