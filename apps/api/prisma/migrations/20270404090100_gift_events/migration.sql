-- v1.97-social (D303, owner 2026-11-07; CONVENTIONS §10.114): gift events and animated / video promo banners.
--
-- 1. An EVENT_GIFTS event (`events.metric`) scores only its own gifts (`event_gifts`: points per coin and per gift) sent
--    in its window, on one or more boards (`event_boards`): SENDERS «الداعمين», RECEIVERS «المضيفين» (never a content-
--    creator member, D295), CREATORS «صناع المحتوى» (creator members only), AGENCIES «الوكالات» (the agency of the
--    receiving host at the time of the gift, `agency_earnings`; the prize to the agency's owner) and CP (event gifts the
--    two partners send each other while they are a couple; both partners win the bundle). Each board has a qualification
--    minimum and prize bundles per rank range (coins, cherries, bag items and VIP for N days).
-- 2. The results of a board are `event_results` rows with `board` (MAIN for the D166 events) and an `entrant_key` (the
--    user, agency or couple ranked); one payout per result and winner (`event_prize_payouts`), so a prize is given once.
-- 3. `events.time_zone`: the IANA zone the dates are shown in.
-- 4. Banners: `kind` IMAGE / ANIMATED / VIDEO, a `BANNER_VIDEO` media asset (muted loop; `media_id` its poster) and an
--    optional `event_id` (the banner opens the event). Animated HOME_BANNER assets keep a full-size first frame
--    (`poster_key`, reduced motion) and their loop length (`duration_ms`).
-- 5. Notifications EVENT_PRIZE_WON (target the event).
-- 6. (D303 follow-up) Event badges «وسام فعالية» (`event_badges`, reusable, own picture) held for N days
--    (`user_event_badges`), and the event page's background picture (`events.background_key`).
--
-- New tables get the runtime role's DML through the default privileges of 20261016130000_per_database_runtime_group (no GRANT here).

-- ---- 1. events ---------------------------------------------------------------------------------------------------
ALTER TABLE "events" ADD COLUMN "time_zone" VARCHAR(64);
ALTER TABLE "events" ADD COLUMN "created_by_id" UUID;
-- D297 kept events off the CREATORS audience (no creators' board then); a gift event may now be for creators only.
ALTER TABLE "events" DROP CONSTRAINT "events_audience_not_creators";
ALTER TABLE "events" ADD CONSTRAINT "events_audience_not_creators" CHECK ("audience"::text <> 'CREATORS' OR "metric"::text = 'EVENT_GIFTS');
ALTER TABLE "events" ADD CONSTRAINT "events_time_zone_shape" CHECK (time_zone IS NULL OR time_zone ~ '^[A-Za-z_]+(/[A-Za-z0-9_+-]+){0,2}$');

CREATE TABLE "event_gifts" (
    "event_id" UUID NOT NULL,
    "gift_code" VARCHAR(40) NOT NULL,
    "points_per_coin" INTEGER NOT NULL DEFAULT 1,
    "points_per_gift" INTEGER NOT NULL DEFAULT 0,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "event_gifts_pkey" PRIMARY KEY ("event_id", "gift_code")
);
CREATE INDEX "event_gifts_gift_idx" ON "event_gifts"("gift_code");
ALTER TABLE "event_gifts" ADD CONSTRAINT "event_gifts_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_gifts" ADD CONSTRAINT "event_gifts_gift_code_fkey" FOREIGN KEY ("gift_code") REFERENCES "gifts"("code") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "event_gifts" ADD CONSTRAINT "event_gifts_points" CHECK (
    points_per_coin BETWEEN 0 AND 1000 AND points_per_gift BETWEEN 0 AND 1000000
    AND (points_per_coin > 0 OR points_per_gift > 0) AND sort_order BETWEEN 0 AND 1000);

CREATE TABLE "event_boards" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "kind" VARCHAR(10) NOT NULL,
    "min_points" BIGINT NOT NULL DEFAULT 0,
    "prizes" JSONB NOT NULL DEFAULT '[]',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "event_boards_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "event_boards_kind_once" ON "event_boards"("event_id", "kind");
ALTER TABLE "event_boards" ADD CONSTRAINT "event_boards_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_boards" ADD CONSTRAINT "event_boards_kind" CHECK (kind IN ('SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'));
ALTER TABLE "event_boards" ADD CONSTRAINT "event_boards_min_points" CHECK (
    min_points BETWEEN 0 AND 1000000000000 AND jsonb_typeof(prizes) = 'array' AND sort_order BETWEEN 0 AND 10);

-- ---- 2. results and payouts ---------------------------------------------------------------------------------------
ALTER TABLE "event_results" ADD COLUMN "board" VARCHAR(10) NOT NULL DEFAULT 'MAIN';
ALTER TABLE "event_results" ADD COLUMN "entrant_key" VARCHAR(36);
UPDATE "event_results" SET "entrant_key" = "user_id"::text;
ALTER TABLE "event_results" ALTER COLUMN "entrant_key" SET NOT NULL;
ALTER TABLE "event_results" ADD COLUMN "agency_id" UUID;
ALTER TABLE "event_results" ADD COLUMN "couple_id" UUID;
ALTER TABLE "event_results" ADD COLUMN "partner_id" UUID;
ALTER TABLE "event_results" ADD COLUMN "prize" JSONB NOT NULL DEFAULT '[]';
DROP INDEX "event_results_rank_once";
DROP INDEX "event_results_user_once";
CREATE UNIQUE INDEX "event_results_rank_once" ON "event_results"("event_id", "board", "rank");
CREATE UNIQUE INDEX "event_results_entrant_once" ON "event_results"("event_id", "board", "entrant_key");
ALTER TABLE "event_results" ADD CONSTRAINT "event_results_board" CHECK (
    board IN ('MAIN', 'SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP') AND jsonb_typeof(prize) = 'array'
    AND ((board = 'AGENCIES') = (agency_id IS NOT NULL))
    AND ((board = 'CP') = (couple_id IS NOT NULL AND partner_id IS NOT NULL)));

CREATE TABLE "event_prize_payouts" (
    "id" UUID NOT NULL,
    "result_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" VARCHAR(10) NOT NULL,
    "granted" JSONB NOT NULL DEFAULT '[]',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "event_prize_payouts_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "event_prize_payouts_once" ON "event_prize_payouts"("result_id", "user_id");
CREATE INDEX "event_prize_payouts_user_idx" ON "event_prize_payouts"("user_id");
ALTER TABLE "event_prize_payouts" ADD CONSTRAINT "event_prize_payouts_result_id_fkey" FOREIGN KEY ("result_id") REFERENCES "event_results"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_prize_payouts" ADD CONSTRAINT "event_prize_payouts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_prize_payouts" ADD CONSTRAINT "event_prize_payouts_status" CHECK (status IN ('PAID', 'FORFEITED') AND jsonb_typeof(granted) = 'array');

-- An event prize in cherries is a credit (the reason/sign rule, extended as 20270329090100 does).
DO $$
DECLARE def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'EVENT_PRIZE');
END
$$;

-- ---- 3b. event badges «وسام فعالية» and the page background (D303 follow-up, owner 2026-11-07) ------------------
ALTER TABLE "events" ADD COLUMN "background_key" VARCHAR(200);
ALTER TABLE "events" ADD COLUMN "background_poster_key" VARCHAR(200);
ALTER TABLE "events" ADD COLUMN "title_key" VARCHAR(200);
ALTER TABLE "events" ADD COLUMN "overlay_key" VARCHAR(200);
ALTER TABLE "events" ADD CONSTRAINT "events_art_keys" CHECK (
    (background_key IS NULL OR background_key ~ '^media/events/bg/[0-9a-f-]{36}(\.anim)?\.(webp|mp4|mov)$')
    AND (background_poster_key IS NULL OR background_poster_key ~ '^media/events/bg/[0-9a-f-]{36}\.webp$')
    AND ((background_key ~ '\.(mp4|mov)$') IS NOT DISTINCT FROM (background_poster_key IS NOT NULL) OR background_key IS NULL)
    AND (title_key IS NULL OR title_key ~ '^media/events/title/[0-9a-f-]{36}\.webp$')
    AND (overlay_key IS NULL OR overlay_key ~ '^media/events/overlay/[0-9a-f-]{36}\.(svga|json)$'));
CREATE TABLE "event_badges" (
    "code" VARCHAR(40) NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "event_badges_pkey" PRIMARY KEY ("code")
);
ALTER TABLE "event_badges" ADD CONSTRAINT "event_badges_shape" CHECK (
    code ~ '^[a-z0-9_]{2,40}$' AND char_length(name_ar) BETWEEN 1 AND 40 AND char_length(name_en) BETWEEN 1 AND 40);
CREATE TABLE "event_badge_levels" (
    "badge_code" VARCHAR(40) NOT NULL,
    "level" SMALLINT NOT NULL,
    "image_key" VARCHAR(200) NOT NULL,
    CONSTRAINT "event_badge_levels_pkey" PRIMARY KEY ("badge_code", "level")
);
ALTER TABLE "event_badge_levels" ADD CONSTRAINT "event_badge_levels_badge_code_fkey" FOREIGN KEY ("badge_code") REFERENCES "event_badges"("code") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_badge_levels" ADD CONSTRAINT "event_badge_levels_shape" CHECK (
    level BETWEEN 1 AND 10 AND image_key ~ '^media/events/badge/[0-9a-f-]{36}\.webp$');
CREATE TABLE "user_event_badges" (
    "user_id" UUID NOT NULL,
    "badge_code" VARCHAR(40) NOT NULL,
    "level" SMALLINT NOT NULL DEFAULT 1,
    "expires_at" TIMESTAMPTZ(3),
    "granted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "event_id" UUID,
    CONSTRAINT "user_event_badges_pkey" PRIMARY KEY ("user_id", "badge_code")
);
ALTER TABLE "user_event_badges" ADD CONSTRAINT "user_event_badges_level" CHECK (level BETWEEN 1 AND 10);
CREATE INDEX "user_event_badges_expires_idx" ON "user_event_badges"("expires_at");
ALTER TABLE "user_event_badges" ADD CONSTRAINT "user_event_badges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "user_event_badges" ADD CONSTRAINT "user_event_badges_badge_code_fkey" FOREIGN KEY ("badge_code") REFERENCES "event_badges"("code") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "user_event_badges" ADD CONSTRAINT "user_event_badges_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ---- 4. banners ---------------------------------------------------------------------------------------------------
ALTER TABLE "home_banners" ADD COLUMN "kind" VARCHAR(8) NOT NULL DEFAULT 'IMAGE';
ALTER TABLE "home_banners" ADD COLUMN "video_media_id" UUID;
ALTER TABLE "home_banners" ADD COLUMN "event_id" UUID;
CREATE UNIQUE INDEX "home_banners_video_media_id_key" ON "home_banners"("video_media_id");
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_video_media_id_fkey" FOREIGN KEY ("video_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- A VIDEO banner whose video asset is gone (SET NULL) is shown as its poster: no CHECK ties kind to the column.
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_kind_shape" CHECK (
    kind IN ('IMAGE', 'ANIMATED', 'VIDEO') AND (kind = 'VIDEO' OR video_media_id IS NULL));

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'BANNER_VIDEO'));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'REEL_VIDEO' AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind = 'LEVEL_RAISE_VIDEO' AND duration_ms BETWEEN 1 AND 90000)
  OR (kind = 'BANNER_VIDEO' AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'HOME_BANNER' AND (duration_ms IS NULL OR duration_ms BETWEEN 1 AND 10000))
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO', 'LEVEL_RAISE_VIDEO', 'BANNER_VIDEO', 'HOME_BANNER')
      AND duration_ms IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_poster_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_poster_shape" CHECK (
  (kind IN ('POST_VIDEO', 'REEL_VIDEO') AND poster_key IS NOT NULL)
  OR kind IN ('LEVEL_RAISE_VIDEO', 'HOME_BANNER')
  OR (kind NOT IN ('POST_VIDEO', 'REEL_VIDEO', 'LEVEL_RAISE_VIDEO', 'HOME_BANNER') AND poster_key IS NULL));

-- ---- 5. notifications ---------------------------------------------------------------------------------------------
ALTER TABLE "notifications" ADD COLUMN "event_id" UUID;
CREATE INDEX "notifications_event_idx" ON "notifications"("event_id") WHERE event_id IS NOT NULL;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
