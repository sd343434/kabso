-- v1.101-social (D325, owner 2026-11-09; CONVENTIONS §10.127): events v2 «الفعاليات» — one events system.
--
-- Every new event is a gift event (`metric = EVENT_GIFTS`) made in the panel step by step. What this adds to D303:
-- 1. `events.status` DRAFT / PUBLISHED: a draft may have no dates («prepare now, set the dates at launch»), is never
--    shown in the app, never scored and never swept. Every existing row is PUBLISHED (it keeps working to its end).
-- 2. `events.recurrence` NONE / WEEKLY / MONTHLY with the current period (`period`, `period_starts_at`,
--    `period_ends_at`); each period is frozen and paid on its own (`event_results.period`, `event_periods`).
-- 3. `events.scoring` COINS (points = coins) / MULTIPLIER (each event gift its own points multiplier, a decimal such as
--    1.2 — `event_gifts.points_per_coin` becomes NUMERIC(7,2); the D303 integers keep their value) and
--    `events.counted_gifts` EVENT_GIFTS (only the event's gifts) / ALL_GIFTS (every gift; others count coins × 1).
-- 4. Gifts and prize items uploaded inside the event: `gifts.event_id` (an event's exclusive gift: sent with coins only
--    while its event runs, then only from bag pieces won as prizes) and `store_items.event_id` (an event-exclusive bag
--    item — frame, entrance, bubble, card, banner — never sold: always off and hidden from the store).
-- 5. Milestones «مراحل» (`event_milestones`, `event_milestone_grants`: once per milestone, person and period).
-- 6. The event's Live home banner (`events.banner_media_id`, a HOME_BANNER asset turned into a banner at publish), the
--    start notification (`events.start_notified_at`, notifications EVENT_STARTED once per person and event) and the
--    extended art keys (an animated or Lottie title, an alpha-MP4 overlay).
--
-- New tables get the runtime role's DML through the default privileges of 20261016130000_per_database_runtime_group (no GRANT here).

-- ---- 1–3. events ----------------------------------------------------------------------------------------------------
ALTER TABLE "events" ADD COLUMN "status" VARCHAR(10) NOT NULL DEFAULT 'PUBLISHED';
ALTER TABLE "events" ADD COLUMN "recurrence" VARCHAR(8) NOT NULL DEFAULT 'NONE';
ALTER TABLE "events" ADD COLUMN "period" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "events" ADD COLUMN "period_starts_at" TIMESTAMPTZ(3);
ALTER TABLE "events" ADD COLUMN "period_ends_at" TIMESTAMPTZ(3);
ALTER TABLE "events" ADD COLUMN "scoring" VARCHAR(10) NOT NULL DEFAULT 'MULTIPLIER';
ALTER TABLE "events" ADD COLUMN "counted_gifts" VARCHAR(12) NOT NULL DEFAULT 'EVENT_GIFTS';
ALTER TABLE "events" ADD COLUMN "banner_media_id" UUID;
ALTER TABLE "events" ADD COLUMN "start_notified_at" TIMESTAMPTZ(3);
ALTER TABLE "events" ADD COLUMN "published_at" TIMESTAMPTZ(3);
-- Existing events started (or will start) under their rules: no start notification is sent for them afterwards.
UPDATE "events" SET "start_notified_at" = "created_at", "published_at" = "created_at";
ALTER TABLE "events" ALTER COLUMN "starts_at" DROP NOT NULL;
ALTER TABLE "events" ADD CONSTRAINT "events_banner_media_id_fkey" FOREIGN KEY ("banner_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- D166's shape, with a draft allowed to have no dates yet.
ALTER TABLE "events" DROP CONSTRAINT "events_shape";
ALTER TABLE "events" ADD CONSTRAINT "events_shape" CHECK (
    char_length(title_ar) BETWEEN 1 AND 120 AND char_length(title_en) BETWEEN 1 AND 120
    AND (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
    AND (permanent OR ends_at IS NOT NULL OR status = 'DRAFT')
    AND (starts_at IS NOT NULL OR status = 'DRAFT')
    AND cardinality(regions) <= 50
    AND array_to_string(regions, ',') ~ '^([A-Z]{2}(,[A-Z]{2})*)?$'
    AND jsonb_typeof(prizes) = 'array');
ALTER TABLE "events" ADD CONSTRAINT "events_v2_shape" CHECK (
    status IN ('DRAFT', 'PUBLISHED')
    AND recurrence IN ('NONE', 'WEEKLY', 'MONTHLY')
    AND scoring IN ('COINS', 'MULTIPLIER')
    AND counted_gifts IN ('EVENT_GIFTS', 'ALL_GIFTS')
    AND period BETWEEN 0 AND 100000
    -- v2 features are gift-event features; D166 metric events stay as they were.
    AND (metric::text = 'EVENT_GIFTS' OR (status = 'PUBLISHED' AND recurrence = 'NONE'))
    -- A published recurring event knows its current period.
    AND (recurrence = 'NONE' OR status = 'DRAFT' OR (period_starts_at IS NOT NULL AND period_ends_at IS NOT NULL
         AND period_ends_at > period_starts_at)));
-- The event's own audience type; AGENCIES and CP audiences (and CREATORS since D303) are gift-event audiences only.
ALTER TABLE "events" DROP CONSTRAINT "events_audience_not_creators";
ALTER TABLE "events" ALTER COLUMN "audience" DROP DEFAULT;
ALTER TABLE "events" ALTER COLUMN "audience" TYPE "event_audience" USING ("audience"::text::"event_audience");
ALTER TABLE "events" ALTER COLUMN "audience" SET DEFAULT 'EVERYONE';
ALTER TABLE "events" ADD CONSTRAINT "events_audience_not_creators" CHECK (
    "audience"::text NOT IN ('CREATORS', 'AGENCIES', 'CP') OR "metric"::text = 'EVENT_GIFTS');
-- The extended art: a title may be animated (WebP) or a Lottie JSON; an overlay may be an alpha MP4.
ALTER TABLE "events" DROP CONSTRAINT "events_art_keys";
ALTER TABLE "events" ADD CONSTRAINT "events_art_keys" CHECK (
    (background_key IS NULL OR background_key ~ '^media/events/bg/[0-9a-f-]{36}(\.anim)?\.(webp|mp4|mov)$')
    AND (background_poster_key IS NULL OR background_poster_key ~ '^media/events/bg/[0-9a-f-]{36}\.webp$')
    AND ((background_key ~ '\.(mp4|mov)$') IS NOT DISTINCT FROM (background_poster_key IS NOT NULL) OR background_key IS NULL)
    AND (title_key IS NULL OR title_key ~ '^media/events/title/[0-9a-f-]{36}((\.anim)?\.webp|\.json)$')
    AND (overlay_key IS NULL OR overlay_key ~ '^media/events/overlay/[0-9a-f-]{36}\.(svga|json|mp4)$'));
CREATE INDEX "events_period_due_idx" ON "events"("period_ends_at") WHERE recurrence <> 'NONE' AND frozen_at IS NULL;
CREATE INDEX "events_status_idx" ON "events"("status");

-- The points multiplier (method 2): a decimal per event gift.
ALTER TABLE "event_gifts" DROP CONSTRAINT "event_gifts_points";
ALTER TABLE "event_gifts" ALTER COLUMN "points_per_coin" DROP DEFAULT;
ALTER TABLE "event_gifts" ALTER COLUMN "points_per_coin" TYPE NUMERIC(7, 2) USING "points_per_coin"::numeric(7, 2);
ALTER TABLE "event_gifts" ALTER COLUMN "points_per_coin" SET DEFAULT 1;
ALTER TABLE "event_gifts" ADD CONSTRAINT "event_gifts_points" CHECK (
    points_per_coin BETWEEN 0 AND 1000 AND points_per_gift BETWEEN 0 AND 1000000
    AND (points_per_coin > 0 OR points_per_gift > 0) AND sort_order BETWEEN 0 AND 1000);

-- ---- 2. periods of the results -------------------------------------------------------------------------------------
ALTER TABLE "event_results" ADD COLUMN "period" INTEGER NOT NULL DEFAULT 0;
DROP INDEX "event_results_rank_once";
DROP INDEX "event_results_entrant_once";
CREATE UNIQUE INDEX "event_results_rank_once" ON "event_results"("event_id", "period", "board", "rank");
CREATE UNIQUE INDEX "event_results_entrant_once" ON "event_results"("event_id", "period", "board", "entrant_key");
ALTER TABLE "event_results" ADD CONSTRAINT "event_results_period" CHECK (period BETWEEN 0 AND 100000);

CREATE TABLE "event_periods" (
    "event_id" UUID NOT NULL,
    "period" INTEGER NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "frozen_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "event_periods_pkey" PRIMARY KEY ("event_id", "period")
);
ALTER TABLE "event_periods" ADD CONSTRAINT "event_periods_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_periods" ADD CONSTRAINT "event_periods_shape" CHECK (period BETWEEN 0 AND 100000 AND ends_at > starts_at);
-- The periods frozen before v2 (period 0 of every frozen gift event).
INSERT INTO "event_periods" ("event_id", "period", "starts_at", "ends_at", "frozen_at")
SELECT id, 0, starts_at, ends_at, frozen_at FROM "events"
 WHERE frozen_at IS NOT NULL AND starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at > starts_at;

-- ---- 4. gifts and items uploaded inside an event -------------------------------------------------------------------
ALTER TABLE "gifts" ADD COLUMN "event_id" UUID;
CREATE INDEX "gifts_event_idx" ON "gifts"("event_id") WHERE event_id IS NOT NULL;
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- An event's gift is never a custom, lucky, quip or PK-booster gift.
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_event_plain" CHECK (
    event_id IS NULL OR (owner_user_id IS NULL AND pk_booster IS NULL AND category NOT IN ('LUCKY', 'QUIPS', 'CUSTOM')));

ALTER TABLE "store_items" ADD COLUMN "event_id" UUID;
CREATE INDEX "store_items_event_idx" ON "store_items"("event_id") WHERE event_id IS NOT NULL;
ALTER TABLE "store_items" ADD CONSTRAINT "store_items_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- Owner (D325): every event prize is exclusive — never sold, never in the store.
ALTER TABLE "store_items" ADD CONSTRAINT "store_items_event_exclusive" CHECK (
    event_id IS NULL OR (NOT enabled AND hidden_at IS NOT NULL));

-- ---- 5. milestones -------------------------------------------------------------------------------------------------
CREATE TABLE "event_milestones" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "board" VARCHAR(10) NOT NULL,
    "points" BIGINT NOT NULL,
    "prizes" JSONB NOT NULL DEFAULT '[]',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "event_milestones_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "event_milestones_once" ON "event_milestones"("event_id", "board", "points");
ALTER TABLE "event_milestones" ADD CONSTRAINT "event_milestones_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_milestones" ADD CONSTRAINT "event_milestones_shape" CHECK (
    board IN ('SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP') AND points BETWEEN 1 AND 1000000000000
    AND jsonb_typeof(prizes) = 'array' AND jsonb_array_length(prizes) BETWEEN 1 AND 6 AND sort_order BETWEEN 0 AND 100);

CREATE TABLE "event_milestone_grants" (
    "id" UUID NOT NULL,
    "milestone_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "period" INTEGER NOT NULL DEFAULT 0,
    "score" BIGINT NOT NULL,
    "status" VARCHAR(10) NOT NULL,
    "granted" JSONB NOT NULL DEFAULT '[]',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "event_milestone_grants_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "event_milestone_grants_once" ON "event_milestone_grants"("milestone_id", "user_id", "period");
CREATE INDEX "event_milestone_grants_user_idx" ON "event_milestone_grants"("user_id");
ALTER TABLE "event_milestone_grants" ADD CONSTRAINT "event_milestone_grants_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "event_milestones"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_milestone_grants" ADD CONSTRAINT "event_milestone_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_milestone_grants" ADD CONSTRAINT "event_milestone_grants_shape" CHECK (
    status IN ('PAID', 'FORFEITED') AND jsonb_typeof(granted) = 'array' AND period BETWEEN 0 AND 100000 AND score >= 0);

-- ---- 6. the start notification -------------------------------------------------------------------------------------
CREATE UNIQUE INDEX "notifications_event_started_once" ON "notifications"("recipient_id", "event_id") WHERE type = 'EVENT_STARTED'::notification_type;
