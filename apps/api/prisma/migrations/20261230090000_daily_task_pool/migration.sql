-- v1.50-social (D176, owner 2026-10-30): the Task Center's daily task pool and the Event Center's
-- calendar styling (CONVENTIONS §10.41.1, §10.41.2). Owner: «أريد أن تصنع الكثير من المهام اليومية،
-- ترسل لكل شخص بناءً على مستواه» — many daily tasks, each person getting 6–8 a day by level band;
-- rewards are coins only («العملات فقط»). Additive: new columns with defaults, two new tables, the
-- default pool and bands; D166's four fixed daily tasks are switched off (the pool offers the same
-- actions per band; the team can switch them on again with task-admin). The runtime role gets DML
-- through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

-- ---- Task Center: pool templates ---------------------------------------------------------------

-- A pool template (`pool`) is a DAILY row offered through the per-person assignment instead of to
-- everyone; it has one target and one reward per level band (0 = not offered in that band) and a
-- group for variety. For a pool row `target` / `reward_coins` mirror the highest band (not used).
ALTER TABLE "task_definitions"
    ADD COLUMN "pool" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN "pool_group" VARCHAR(10),
    ADD COLUMN "band_targets" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
    ADD COLUMN "band_rewards" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[];

ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS')
    AND target BETWEEN 1 AND 1000000000 AND reward_coins BETWEEN 1 AND 1000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_pool_shape" CHECK (
    (NOT pool AND pool_group IS NULL AND cardinality(band_targets) = 0 AND cardinality(band_rewards) = 0)
    OR (pool AND period = 'DAILY'
        AND pool_group IN ('WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST')
        AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
        AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
        AND 0 <= ALL (band_rewards) AND 1000000 >= ALL (band_rewards)));

-- CreateTable: the level bands (the higher of a person's Support and Charm levels).
CREATE TABLE "task_pool_bands" (
    "band" SMALLINT NOT NULL,
    "min_level" INTEGER NOT NULL,
    "daily_count" SMALLINT NOT NULL,
    "host_count" SMALLINT NOT NULL,
    "name_ar" VARCHAR(40) NOT NULL,
    "name_en" VARCHAR(40) NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_pool_bands_pkey" PRIMARY KEY ("band"),
    CONSTRAINT "task_pool_bands_shape" CHECK (
        band BETWEEN 1 AND 4 AND min_level BETWEEN 0 AND 200 AND daily_count BETWEEN 1 AND 12
        AND host_count BETWEEN 0 AND daily_count
        AND char_length(name_ar) BETWEEN 1 AND 40 AND char_length(name_en) BETWEEN 1 AND 40)
);

-- CreateTable: a person's tasks of a day, fixed at the day's first read (deterministic from the person
-- and the day), with the band's target and reward at that moment.
CREATE TABLE "task_assignments" (
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "task_code" VARCHAR(40) NOT NULL,
    "band" SMALLINT NOT NULL,
    "target" INTEGER NOT NULL,
    "reward_coins" INTEGER NOT NULL,
    "position" SMALLINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_assignments_pkey" PRIMARY KEY ("user_id", "day", "task_code"),
    CONSTRAINT "task_assignments_shape" CHECK (
        band BETWEEN 1 AND 4 AND target BETWEEN 1 AND 1000000000 AND reward_coins BETWEEN 1 AND 1000000
        AND position BETWEEN 0 AND 11)
);

CREATE INDEX "task_assignments_task_idx" ON "task_assignments"("task_code");
CREATE INDEX "task_assignments_day_idx" ON "task_assignments"("day");

ALTER TABLE "task_assignments" ADD CONSTRAINT "task_assignments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "task_assignments" ADD CONSTRAINT "task_assignments_task_code_fkey" FOREIGN KEY ("task_code") REFERENCES "task_definitions"("code") ON DELETE CASCADE ON UPDATE CASCADE;

-- The default bands (owner-changeable with `task-admin band`).
INSERT INTO "task_pool_bands" ("band", "min_level", "daily_count", "host_count", "name_ar", "name_en") VALUES
    (1, 0, 6, 2, 'مبتدئ', 'Starter'),
    (2, 10, 7, 2, 'نشيط', 'Active'),
    (3, 30, 7, 2, 'متقدّم', 'Advanced'),
    (4, 60, 8, 3, 'نخبة', 'Elite');

-- The default pool (programs-rules.ts DEFAULT_POOL_TASKS; targets and rewards per band 1…4).
-- Left out (the server cannot see them): sharing a room, recharging (no purchases, B5).
INSERT INTO "task_definitions" ("code", "period", "metric", "target", "reward_coins", "audience", "name_ar", "name_en", "sort_order", "pool", "pool_group", "band_targets", "band_rewards") VALUES
    ('P_WATCH_LIVES', 'DAILY', 'WATCH_LIVES', 5, 6, 'EVERYONE', 'شاهد بثوثاً لمدة 15 ثانية', 'Watch lives for 15 seconds', 100, true, 'WATCH', ARRAY[1, 2, 3, 5], ARRAY[3, 4, 5, 6]),
    ('P_WATCH_MINUTES', 'DAILY', 'WATCH_MINUTES', 30, 10, 'EVERYONE', 'شاهد البث (بالدقائق)', 'Watch lives (minutes)', 110, true, 'WATCH', ARRAY[5, 15, 30, 30], ARRAY[4, 6, 8, 10]),
    ('P_AUDIO_ROOMS', 'DAILY', 'AUDIO_ROOMS', 3, 6, 'EVERYONE', 'ادخل غرفاً صوتية', 'Join audio rooms', 120, true, 'WATCH', ARRAY[1, 2, 3, 3], ARRAY[3, 4, 5, 6]),
    ('P_LIVE_COMMENTS', 'DAILY', 'LIVE_CHAT_MESSAGES', 20, 6, 'EVERYONE', 'علّق في بث مباشر', 'Comment in a live', 200, true, 'LIVE', ARRAY[3, 5, 10, 20], ARRAY[3, 4, 5, 6]),
    ('P_LIVE_TAPS', 'DAILY', 'LIVE_TAPS', 200, 5, 'EVERYONE', 'أرسل قلوباً في بث مباشر', 'Send hearts in a live', 210, true, 'LIVE', ARRAY[20, 50, 100, 200], ARRAY[2, 3, 4, 5]),
    ('P_FOLLOW', 'DAILY', 'FOLLOWS', 10, 5, 'EVERYONE', 'تابع مستخدمين آخرين', 'Follow other users', 300, true, 'SOCIAL', ARRAY[1, 3, 5, 10], ARRAY[2, 3, 4, 5]),
    ('P_POST_COMMENTS', 'DAILY', 'POST_COMMENTS', 10, 5, 'EVERYONE', 'علّق على منشورات الآخرين', 'Comment on others'' posts', 310, true, 'SOCIAL', ARRAY[1, 3, 5, 10], ARRAY[2, 3, 4, 5]),
    ('P_SEND_GIFT', 'DAILY', 'GIFT_SENDS', 5, 10, 'EVERYONE', 'أرسل هدية', 'Send a gift', 400, true, 'GIFT', ARRAY[1, 1, 3, 5], ARRAY[5, 6, 8, 10]),
    ('P_SEND_GIFTS', 'DAILY', 'GIFT_SENDS', 15, 20, 'EVERYONE', 'أرسل هدايا', 'Send gifts', 410, true, 'GIFT', ARRAY[0, 10, 10, 15], ARRAY[0, 12, 15, 20]),
    ('P_NEW_HOST', 'DAILY', 'NEW_HOST_GIFTS', 2, 10, 'EVERYONE', 'ادعم مضيفاً جديداً بهدية', 'Support a new host with a gift', 420, true, 'GIFT', ARRAY[1, 1, 1, 2], ARRAY[5, 6, 8, 10]),
    ('P_POST', 'DAILY', 'POSTS', 2, 8, 'EVERYONE', 'انشر منشوراً', 'Share a post', 500, true, 'CONTENT', ARRAY[1, 1, 1, 2], ARRAY[4, 5, 6, 8]),
    ('P_REEL', 'DAILY', 'REELS', 1, 10, 'EVERYONE', 'انشر مقطع ريلز', 'Share a reel', 510, true, 'CONTENT', ARRAY[0, 1, 1, 1], ARRAY[0, 6, 8, 10]),
    ('P_STORY', 'DAILY', 'STORIES', 2, 6, 'EVERYONE', 'انشر قصة', 'Share a story', 520, true, 'CONTENT', ARRAY[1, 1, 1, 2], ARRAY[3, 4, 5, 6]),
    ('P_DM_FRIEND', 'DAILY', 'DM_FRIENDS', 3, 5, 'EVERYONE', 'راسل صديقاً', 'Message a friend', 600, true, 'MESSAGE', ARRAY[1, 1, 2, 3], ARRAY[2, 3, 4, 5]),
    ('P_DM_VOICE', 'DAILY', 'DM_VOICE_MESSAGES', 2, 5, 'EVERYONE', 'أرسل رسالة صوتية', 'Send a voice message', 610, true, 'MESSAGE', ARRAY[1, 1, 1, 2], ARRAY[2, 3, 4, 5]),
    ('P_HOST_LIVE_30', 'DAILY', 'HOST_LIVE_MINUTES', 60, 15, 'HOSTS', 'ابثّ مباشرة (بالدقائق)', 'Go live (minutes)', 700, true, 'HOST', ARRAY[30, 30, 60, 60], ARRAY[8, 10, 12, 15]),
    ('P_HOST_GIFTS', 'DAILY', 'HOST_GIFTS_RECEIVED', 20, 10, 'HOSTS', 'استقبل هدايا في بثك', 'Receive gifts in your live', 710, true, 'HOST', ARRAY[3, 5, 10, 20], ARRAY[5, 6, 8, 10]),
    ('P_HOST_GUEST', 'DAILY', 'HOST_GUESTS', 3, 8, 'HOSTS', 'اقبل ضيفاً على مقعد', 'Accept a guest on a seat', 720, true, 'HOST', ARRAY[1, 1, 2, 3], ARRAY[4, 5, 6, 8]);

-- D166's four fixed daily tasks give way to the pool (the same actions per band).
UPDATE "task_definitions" SET "enabled" = false, "updated_at" = CURRENT_TIMESTAMP
 WHERE "code" IN ('WATCH_LIVE', 'FOLLOW_USERS', 'LIVE_CHAT', 'SEND_GIFTS') AND NOT "pool";

-- ---- Event Center: the calendar bar's second line and tone ------------------------------------

ALTER TABLE "events"
    ADD COLUMN "summary_ar" VARCHAR(80),
    ADD COLUMN "summary_en" VARCHAR(80),
    ADD COLUMN "tone" VARCHAR(6);
ALTER TABLE "events" ADD CONSTRAINT "events_style" CHECK (
    (summary_ar IS NULL OR char_length(summary_ar) BETWEEN 1 AND 80)
    AND (summary_en IS NULL OR char_length(summary_en) BETWEEN 1 AND 80)
    AND (tone IS NULL OR tone IN ('RED', 'GOLD', 'TEAL', 'BLUE', 'PINK', 'AMBER')));

-- ---- Promo banners: the Task Center's slot ---------------------------------------------------

ALTER TABLE "home_banners" DROP CONSTRAINT "home_banners_placement_values";
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_placement_values" CHECK (placement IN ('HOME', 'ROOM', 'TASKS'));
