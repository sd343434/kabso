-- v1.105-social (D340, owner 2026-11-09; CONVENTIONS §10.134): an event's final result and its full-screen
-- announcements.
--
-- 1. `events.announce_fullscreen` «إعلان بملء الشاشة عند البدء»: the app shows an event's start full screen once to each
--    person who may see it. Every event that exists now is NOT announced (false: an event running at the deploy does not
--    suddenly cover everyone's screen); every event made from now on is (the column's default becomes true after the
--    existing rows are written false). The panel may switch it on or off at any time.
-- 2. `event_prize_payouts.announced_at`: when the winner saw «مبروك» (once per payout). Every payout made before now is
--    marked announced here, so the deploy brings no burst of old wins.
-- 3. `event_start_announcements` (event, user): who has seen a start announcement (once).

ALTER TABLE "events" ADD COLUMN "announce_fullscreen" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "events" ALTER COLUMN "announce_fullscreen" SET DEFAULT true;

ALTER TABLE "event_prize_payouts" ADD COLUMN "announced_at" TIMESTAMPTZ(3);
UPDATE "event_prize_payouts" SET "announced_at" = "created_at";
CREATE INDEX "event_prize_payouts_unannounced_idx" ON "event_prize_payouts"("user_id")
    WHERE ((announced_at IS NULL) AND ((status)::text = 'PAID'::text));

CREATE TABLE "event_start_announcements" (
    "event_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "seen_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "event_start_announcements_pkey" PRIMARY KEY ("event_id","user_id")
);
CREATE INDEX "event_start_announcements_user_idx" ON "event_start_announcements"("user_id");
ALTER TABLE "event_start_announcements" ADD CONSTRAINT "event_start_announcements_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_start_announcements" ADD CONSTRAINT "event_start_announcements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
