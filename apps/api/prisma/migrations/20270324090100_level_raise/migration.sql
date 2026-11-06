-- v1.89-social (D290, owner 2026-11-06, CONVENTIONS §10.103): level-raise requests «طلب رفع ليفيل».
--
-- 1. `level_raise_source_apps`: each source app's data for the proposal (OWNER-editable, audited). MONEY: the price of
--    1 000 000 of the app's coins (USD cents), the coins per XP point (× 1 000) and the known points of its level table
--    (`xp_table` JSON: [{level, xp, confidence}]); FACTOR: a conservative factor (× 1 000). `confidence` is CONFIRMED
--    only with a source (the owner or a cited page); everything else is ESTIMATE and the panel says so. Exactly one row
--    (`is_other`) serves an app that is not in the list.
-- 2. `level_raise_settings`: the proposal's weights (one row, OWNER-editable, audited). Defaults reproduce the owner's
--    examples (1 000 000 recharged → 15–20; 32 000 000 in the first week → 40).
-- 3. `level_raise_requests`: a MODERATION / SUPPORT staff member's request (app or panel) with the supporter, the
--    source app, its account ID and level, the video (`LEVEL_RAISE_VIDEO`, one request per video) and a note; the
--    OWNER approves (≥ the current level, ≤ the proposal, ≤ 40 — or the current level unchanged) or rejects with a
--    reason. One PENDING request per supporter. The owner (2026-11-06): the video is deleted after the decision
--    (`video_deleted_at`; the media sweeper removes the objects and the asset row, `video_media_id` → NULL) while its
--    evidence stays (`video_asset_id`, length, size, display size). A source account (canonical app
--    `source_app_key` + `source_account_key`) has at most one PENDING / APPROVED request (unique partial index
--    `level_raise_requests_source_once`); after a REJECTED one a new request is allowed and points at it
--    (`previous_rejected_id`).
-- 4. `notifications.level_raise_request_id` (the three new notification types).
-- 5. Media kind `LEVEL_RAISE_VIDEO`: a video like a post video (MP4 / QuickTime, ≤ 200 MiB, ≤ 90 s; the panel's raw
--    upload ≤ 100 MiB and without a poster).
--
-- The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants), so this migration
-- contains no GRANT.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TYPE "level_raise_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- 1. Source apps.
CREATE TABLE "level_raise_source_apps" (
    "id" UUID NOT NULL,
    "code" VARCHAR(32) NOT NULL,
    "name_ar" VARCHAR(60) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "mode" VARCHAR(8) NOT NULL,
    "usd_per_million_cents" BIGINT,
    "coins_per_xp_milli" BIGINT,
    "xp_table" JSONB NOT NULL DEFAULT '[]',
    "factor_milli" INTEGER,
    "confidence" VARCHAR(10) NOT NULL,
    "aliases" VARCHAR(60)[] NOT NULL DEFAULT '{}',
    "source_note" VARCHAR(1000) NOT NULL DEFAULT '',
    "source_url" VARCHAR(500),
    "source_date" DATE,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "is_other" BOOLEAN NOT NULL DEFAULT false,
    "sort" INTEGER NOT NULL DEFAULT 100,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "level_raise_source_apps_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "level_raise_source_apps_shape" CHECK (
        "code" ~ '^[A-Z0-9_]{2,32}$'
        AND "mode" IN ('MONEY', 'FACTOR')
        AND "confidence" IN ('CONFIRMED', 'ESTIMATE')
        AND jsonb_typeof("xp_table") = 'array'
        AND ("usd_per_million_cents" IS NULL OR "usd_per_million_cents" > 0)
        AND ("coins_per_xp_milli" IS NULL OR "coins_per_xp_milli" > 0)
        AND ("factor_milli" IS NULL OR "factor_milli" BETWEEN 1 AND 2000)
        AND ("mode" <> 'MONEY' OR ("usd_per_million_cents" IS NOT NULL AND "coins_per_xp_milli" IS NOT NULL))
        AND ("mode" <> 'FACTOR' OR "factor_milli" IS NOT NULL)
        AND (NOT "is_other" OR ("mode" = 'FACTOR' AND "enabled")))
);
CREATE UNIQUE INDEX "level_raise_source_apps_code_key" ON "level_raise_source_apps"("code");
CREATE UNIQUE INDEX "level_raise_source_apps_one_other" ON "level_raise_source_apps"("is_other") WHERE "is_other";
ALTER TABLE "level_raise_source_apps" ADD CONSTRAINT "level_raise_source_apps_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 2. The weights.
CREATE TABLE "level_raise_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "min_recharge_coins" BIGINT NOT NULL DEFAULT 1000000,
    "first_days" INTEGER NOT NULL DEFAULT 7,
    "anchor_coins" BIGINT NOT NULL DEFAULT 1000000,
    "first_days_base_level" INTEGER NOT NULL DEFAULT 20,
    "total_base_level" INTEGER NOT NULL DEFAULT 15,
    "levels_per_doubling_tenths" INTEGER NOT NULL DEFAULT 40,
    "support_bonus_per_10" INTEGER NOT NULL DEFAULT 1,
    "support_bonus_max" INTEGER NOT NULL DEFAULT 2,
    "charm_bonus_per_10" INTEGER NOT NULL DEFAULT 1,
    "charm_bonus_max" INTEGER NOT NULL DEFAULT 2,
    "below_table_exponent_tenths" INTEGER NOT NULL DEFAULT 30,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "level_raise_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "level_raise_settings_one_row" CHECK ("id" = 1),
    CONSTRAINT "level_raise_settings_shape" CHECK (
        "min_recharge_coins" >= 0
        AND "first_days" BETWEEN 1 AND 90
        AND "anchor_coins" > 0
        AND "first_days_base_level" BETWEEN 0 AND 40
        AND "total_base_level" BETWEEN 0 AND 40
        AND "levels_per_doubling_tenths" BETWEEN 0 AND 200
        AND "support_bonus_per_10" BETWEEN 0 AND 10 AND "support_bonus_max" BETWEEN 0 AND 10
        AND "charm_bonus_per_10" BETWEEN 0 AND 10 AND "charm_bonus_max" BETWEEN 0 AND 10
        AND "below_table_exponent_tenths" BETWEEN 10 AND 100)
);
INSERT INTO "level_raise_settings" ("id") VALUES (1);

-- 3. The requests.
CREATE TABLE "level_raise_requests" (
    "id" UUID NOT NULL,
    "supporter_user_id" UUID NOT NULL,
    "requested_by_id" UUID NOT NULL,
    "via" VARCHAR(8) NOT NULL,
    "source_app_id" UUID,
    "source_app_name" VARCHAR(60) NOT NULL,
    "source_account_id" VARCHAR(64) NOT NULL,
    "source_level" INTEGER NOT NULL,
    "video_media_id" UUID,
    "video_asset_id" UUID NOT NULL,
    "video_duration_ms" INTEGER,
    "video_byte_size" INTEGER NOT NULL,
    "video_width" INTEGER NOT NULL,
    "video_height" INTEGER NOT NULL,
    "video_deleted_at" TIMESTAMPTZ(3),
    "source_app_key" VARCHAR(80) NOT NULL,
    "source_account_key" VARCHAR(64) NOT NULL,
    "previous_rejected_id" UUID,
    "note" VARCHAR(500),
    "status" "level_raise_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decided_by_id" UUID,
    "reject_reason" VARCHAR(500),
    "proposed_level" INTEGER,
    "approved_level" INTEGER,
    "level_before" INTEGER,
    "level_after" INTEGER,
    "ledger_entry_id" UUID,
    "proposal" JSONB,

    CONSTRAINT "level_raise_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "level_raise_requests_shape" CHECK (
        "via" IN ('app', 'panel')
        AND "supporter_user_id" <> "requested_by_id"
        AND "source_level" BETWEEN 1 AND 999
        AND length(btrim("source_app_name")) > 0
        AND length(btrim("source_account_id")) > 0
        AND "source_account_key" = lower(btrim("source_account_id"))
        AND "source_app_key" ~ '^(APP:[A-Z0-9_]{2,32}|NAME:.+)$'
        AND ("video_media_id" IS NOT NULL OR "video_deleted_at" IS NOT NULL)
        AND ("video_deleted_at" IS NULL OR "status" <> 'PENDING')
        AND ("status" = 'PENDING') = ("decided_at" IS NULL)
        AND ("status" = 'REJECTED') = ("reject_reason" IS NOT NULL)
        AND ("status" = 'APPROVED') = ("approved_level" IS NOT NULL)
        AND ("status" <> 'APPROVED' OR ("proposed_level" IS NOT NULL AND "level_before" IS NOT NULL
             AND "level_after" IS NOT NULL AND "proposal" IS NOT NULL))),
    -- The owner's rule: never above the proposal, never above 40 (unless unchanged), never below the current level.
    CONSTRAINT "level_raise_requests_approved_level" CHECK (
        "approved_level" IS NULL
        OR ("approved_level" >= "level_before"
            AND "level_after" = "approved_level"
            AND ("approved_level" = "level_before"
                 OR ("approved_level" <= "proposed_level" AND "approved_level" <= 40))))
);
CREATE UNIQUE INDEX "level_raise_requests_video_media_id_key" ON "level_raise_requests"("video_media_id");
CREATE UNIQUE INDEX "level_raise_requests_one_pending" ON "level_raise_requests"("supporter_user_id") WHERE ("status" = 'PENDING'::level_raise_status);
CREATE INDEX "level_raise_requests_status_idx" ON "level_raise_requests"("status", "created_at" DESC);
CREATE INDEX "level_raise_requests_requester_idx" ON "level_raise_requests"("requested_by_id", "created_at" DESC);
CREATE INDEX "level_raise_requests_source_idx" ON "level_raise_requests"("source_app_key", "source_account_key");
CREATE UNIQUE INDEX "level_raise_requests_source_once" ON "level_raise_requests"("source_app_key", "source_account_key") WHERE ("status" IN ('PENDING'::level_raise_status, 'APPROVED'::level_raise_status));
CREATE INDEX "level_raise_requests_supporter_idx" ON "level_raise_requests"("supporter_user_id", "created_at" DESC);
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_supporter_user_id_fkey" FOREIGN KEY ("supporter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_requested_by_id_fkey" FOREIGN KEY ("requested_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_source_app_id_fkey" FOREIGN KEY ("source_app_id") REFERENCES "level_raise_source_apps"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_video_media_id_fkey" FOREIGN KEY ("video_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "level_raise_requests" ADD CONSTRAINT "level_raise_requests_previous_rejected_id_fkey" FOREIGN KEY ("previous_rejected_id") REFERENCES "level_raise_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 4. Notifications.
ALTER TABLE "notifications" ADD COLUMN "level_raise_request_id" UUID;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_level_raise_request_id_fkey" FOREIGN KEY ("level_raise_request_id") REFERENCES "level_raise_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX "notifications_level_raise_idx" ON "notifications"("level_raise_request_id") WHERE ("level_raise_request_id" IS NOT NULL);

-- 5. Media kind LEVEL_RAISE_VIDEO (like a post video: ≤ 90 s). From the app it has a poster like any video; from the
--    panel (raw bytes, `POST /admin/level-raise-videos`) it has none — the panel plays the video itself.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO'));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'REEL_VIDEO' AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind = 'LEVEL_RAISE_VIDEO' AND duration_ms BETWEEN 1 AND 90000)
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO', 'LEVEL_RAISE_VIDEO') AND duration_ms IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_poster_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_poster_shape" CHECK (
  (kind IN ('POST_VIDEO', 'REEL_VIDEO') AND poster_key IS NOT NULL)
  OR kind = 'LEVEL_RAISE_VIDEO'
  OR (kind NOT IN ('POST_VIDEO', 'REEL_VIDEO', 'LEVEL_RAISE_VIDEO') AND poster_key IS NULL));

-- 6. The source apps known on 2026-11-06. Only Zafa is CONFIRMED (the owner's screenshot); every other row is an
--    ESTIMATE with the conservative factor × 0.5 — no level table of those apps could be cited (CONVENTIONS §10.103.4
--    lists what was searched). Prices seen only in search-result snippets of app-store pages are kept in the note,
--    never used by the formula (FACTOR mode ignores the price).
INSERT INTO "level_raise_source_apps" ("id", "code", "name_ar", "name_en", "mode", "usd_per_million_cents", "coins_per_xp_milli", "xp_table", "factor_milli", "confidence", "aliases", "source_note", "source_url", "source_date", "is_other", "sort") VALUES
  (gen_random_uuid(), 'ZAFA', 'زفة', 'Zafa', 'MONEY', 2000, 10000, '[{"level": 32, "xp": 27742536, "confidence": "CONFIRMED"}]', NULL, 'CONFIRMED', ARRAY['زافا', 'زفه', 'Zafa Live', 'زفة لايف']::VARCHAR(60)[],
   'Owner (Zafa), 2026-11-06, from a screenshot of the Zafa app: 1 000 000 coins = $20; 10 coins = 1 XP; level 32 = 27 742 536 XP. Only this one table point is known: other levels are DERIVED (below 32 a power curve from 0, above 32 held at the level-32 XP) — add points here as they become known.', NULL, '2026-11-06', false, 10),
  (gen_random_uuid(), 'BIGO_LIVE', 'بيقو لايف', 'Bigo Live', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Bigo', 'بيجو', 'بيغو', 'بيقو', 'بيجو لايف', 'بيغو لايف']::VARCHAR(60)[],
   'Estimate. No official price list or wealth-level table found (web search 2026-11-06: only reseller pages, quoting 30–60 diamonds per $1 and contradicting each other). Conservative factor × 0.5.', NULL, '2026-11-06', false, 20),
  (gen_random_uuid(), 'MICO', 'ميكو', 'MICO', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Mico Live', 'ميكو لايف']::VARCHAR(60)[],
   'Estimate. A web-search snippet of the US App Store listing (2026-11-06; the page itself could not be opened) shows «900 coins $9.99» (≈ $11 100 per 1 000 000 coins, store price, unverified). No level table found. Conservative factor × 0.5.', 'https://apps.apple.com/us/app/mico-chat-video-live-chat/id908023218', '2026-11-06', false, 30),
  (gen_random_uuid(), 'YALLA', 'يلا', 'Yalla', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['يلّا', 'Yalla Live', 'Yalla Chat', 'يلا لايف']::VARCHAR(60)[],
   'Estimate. No official coin price or level table found (web search 2026-11-06: reseller pages only). Conservative factor × 0.5.', NULL, '2026-11-06', false, 40),
  (gen_random_uuid(), 'AHLAN', 'أهلاً', 'Ahlan', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['اهلا', 'أهلاً', 'Ahlan Chat', 'اهلا شات']::VARCHAR(60)[],
   'Estimate. Only a reseller price found (web search 2026-11-06), no official price or level table. Conservative factor × 0.5.', NULL, '2026-11-06', false, 50),
  (gen_random_uuid(), 'TANGO', 'تانغو', 'Tango', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['تانجو', 'Tango Live']::VARCHAR(60)[],
   'Estimate. Web-search snippets of App Store listings (2026-11-06; pages not opened) show «1000 Coins USD 9.99» in some regions and other prices elsewhere (≈ $10 000 per 1 000 000 coins, unverified). No level table found. Conservative factor × 0.5.', 'https://apps.apple.com/tj/app/id372513032?l=en-gb', '2026-11-06', false, 60),
  (gen_random_uuid(), 'POPPO', 'بوبو لايف', 'Poppo Live', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Poppo', 'بوبو']::VARCHAR(60)[],
   'Estimate. No price or level table found (web search 2026-11-06). Conservative factor × 0.5.', NULL, '2026-11-06', false, 70),
  (gen_random_uuid(), 'SOULCHILL', 'سول تشيل', 'SoulChill', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Soul Chill', 'سول شيل', 'سولتشيل']::VARCHAR(60)[],
   'Estimate. Only reseller prices found (web search 2026-11-06), no official price or level table. Conservative factor × 0.5.', NULL, '2026-11-06', false, 80),
  (gen_random_uuid(), 'JACO', 'جاكو', 'Jaco', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Jaco Live', 'جاكو لايف']::VARCHAR(60)[],
   'Estimate. No data found. Conservative factor × 0.5.', NULL, '2026-11-06', false, 90),
  (gen_random_uuid(), 'LAMI', 'لامي', 'Lami', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Lami Live', 'لامي لايف']::VARCHAR(60)[],
   'Estimate. No data found (web search 2026-11-06). Conservative factor × 0.5.', NULL, '2026-11-06', false, 100),
  (gen_random_uuid(), 'HALA', 'هلا', 'Hala', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Hala Chat', 'هلا شات']::VARCHAR(60)[],
   'Estimate. No data found. Conservative factor × 0.5.', NULL, '2026-11-06', false, 110),
  (gen_random_uuid(), 'YOHO', 'يوهو', 'Yoho', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['Yoho Live', 'يوهو لايف']::VARCHAR(60)[],
   'Estimate. No data found. Conservative factor × 0.5.', NULL, '2026-11-06', false, 120),
  (gen_random_uuid(), 'SUGO', 'سوجو', 'Sugo', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', ARRAY['سوقو', 'Sugo Live']::VARCHAR(60)[],
   'Estimate. No data found. Conservative factor × 0.5.', NULL, '2026-11-06', false, 130),
  (gen_random_uuid(), 'OTHER', 'تطبيق آخر', 'Other app', 'FACTOR', NULL, NULL, '[]', 500, 'ESTIMATE', '{}'::VARCHAR(60)[],
   'The default for an app not in the list (the staff member types its name): a conservative factor × 0.5 so nobody is over-levelled. Editable; add the app as its own row once its data is known.', NULL, '2026-11-06', true, 1000);
