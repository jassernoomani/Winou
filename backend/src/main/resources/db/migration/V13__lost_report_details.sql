-- More about a lost pet, all optional: a reward, whether it is microchipped (null: not said), and a
-- phone number the owner chooses to show to people who see the report.
ALTER TABLE lost_reports
    ADD COLUMN reward_tnd    integer CONSTRAINT reward_positive CHECK (reward_tnd > 0),
    ADD COLUMN microchipped  boolean,
    ADD COLUMN contact_phone varchar(32);
