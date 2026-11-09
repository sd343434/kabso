-- v1.102-social (D334, owner 2026-11-09; CONVENTIONS §10.127.11): events v2 follow-ups.
--
-- 1. `events.creators_as_hosts` (owner: «صناع المحتوى يعتبرون مضيفين، والمضيفون ليسوا صناع محتوى»): a content creator
--    is inside a HOSTS audience (sees the event, gets its start notification) and ranks on a D166 HOSTS board. Every
--    event that exists now keeps D295's rule (false: creators out of host-only events); every event made from now on
--    gets the new rule (the column's default becomes true after the existing rows are written false).
-- 2. `event_boards.shown` «عدد المعروضين»: how many places a board lists (1–100; 20 by default — every existing board,
--    D303's included, keeps showing 20 until the panel changes it).
-- No data is changed beyond the two new columns.

ALTER TABLE "events" ADD COLUMN "creators_as_hosts" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "events" ALTER COLUMN "creators_as_hosts" SET DEFAULT true;

ALTER TABLE "event_boards" ADD COLUMN "shown" INTEGER NOT NULL DEFAULT 20;
ALTER TABLE "event_boards" ADD CONSTRAINT "event_boards_shown" CHECK (shown BETWEEN 1 AND 100);
