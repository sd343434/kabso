-- v1.71-live / v1.86-social (D281, owner, CONVENTIONS §10.62.2 and §10.41.4): the smart targets and tasks.
--
-- 1. «الأهداف الذكية»: three daily targets per host (easy / medium / hard) from a generated catalogue of more
--    than 100 000 targets (templates × parameters, regenerated from the enabled gift catalogue at each read —
--    no catalogue rows), chosen from the host's own data and stored for the day in `host_target_assignments`
--    (fixed at the day's first read; deterministic per host and day). A completed target pays its level's share
--    of the platform profit it produced (1.5 % / 2.5 % / 4 %, never more than that share of the ACTUAL profit
--    counted) once, in locked task cherries: a `cherry_ledger` row HOST_TARGET_REWARD (reference
--    `HT:<level>@<day>`), locked like TASK_REWARD (§10.46.1).
-- 2. The owner's knobs (`host_target_settings`, one row; OWNER only in the panel, audited): the level
--    percentiles, the reward shares, the no-repeat days, the history days, the completion shift, and the day the
--    new engine starts (`engine_from`): NULL here — the API sets it to the day AFTER its first read, so today's
--    in-flight targets (D277's two) and their progress are kept and the switch happens at the next day boundary.
-- 3. The Task Center's generated catalogue: seven new pool templates (new measurable actions), and each day's
--    assignment row now stores the generated variant (its amount is `target`), its gift or category, its window
--    of the day, its resolved names and the reasons. Old rows keep NULLs (the template itself, the whole day).
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).

-- The cherry ledger's sign rule: HOST_TARGET_REWARD is a credit. Extended in place (read from the catalogue, not
-- restated), as 20270310090100_store did, so a branch that changed the list before keeps its change.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'HOST_TARGET_REWARD');
END
$$;

-- The new task metrics.
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS',
                   'GIFT_COINS_SENT', 'HOST_LUCKY_COINS', 'HOST_GIFT_CHERRIES', 'HOST_LUCKY_CHERRIES',
                   'GIFT_COUNT_SENT', 'CATEGORY_GIFTS_SENT', 'GIFTED_HOSTS', 'FAMILY_JOIN', 'FAMILY_CHAT_MESSAGES',
                   'PK_BATTLES', 'PK_WINS')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);

-- The new pool templates (an existing row of the same code is left as the owner set it). A chosen gift and a
-- category: the band target is a coin value (the count is that value in the gift's price), the reward D188's rate.
INSERT INTO "task_definitions" ("code", "period", "metric", "target", "reward_cherries", "audience", "name_ar", "name_en", "sort_order", "pool", "pool_group", "band_targets", "band_rewards") VALUES
    ('P_SEND_GIFT_OF', 'DAILY', 'GIFT_COUNT_SENT', 50000, 5000, 'EVERYONE', 'أرسل هدية محددة', 'Send a chosen gift', 430, true, 'GIFT', ARRAY[5000, 10000, 25000, 50000], ARRAY[500, 1000, 2500, 5000]),
    ('P_SEND_CATEGORY', 'DAILY', 'CATEGORY_GIFTS_SENT', 50000, 5000, 'EVERYONE', 'أرسل هدايا من فئة', 'Send gifts from a category', 440, true, 'GIFT', ARRAY[5000, 10000, 25000, 50000], ARRAY[500, 1000, 2500, 5000]),
    ('P_GIFT_HOSTS', 'DAILY', 'GIFTED_HOSTS', 5, 1000, 'EVERYONE', 'أهدِ أشخاصاً مختلفين', 'Gift different people', 450, true, 'GIFT', ARRAY[1, 2, 3, 5], ARRAY[300, 500, 750, 1000]),
    ('P_FAMILY_JOIN', 'DAILY', 'FAMILY_JOIN', 1, 1000, 'EVERYONE', 'انضم إلى عائلة', 'Join a family', 320, true, 'SOCIAL', ARRAY[1, 1, 1, 1], ARRAY[300, 500, 750, 1000]),
    ('P_FAMILY_CHAT', 'DAILY', 'FAMILY_CHAT_MESSAGES', 20, 1000, 'EVERYONE', 'دردش في عائلتك', 'Chat in your family', 330, true, 'SOCIAL', ARRAY[3, 5, 10, 20], ARRAY[300, 500, 750, 1000]),
    ('P_PK_BATTLES', 'DAILY', 'PK_BATTLES', 5, 6000, 'HOSTS', 'ادخل معارك PK', 'Enter PK battles', 730, true, 'HOST', ARRAY[1, 2, 3, 5], ARRAY[2000, 3000, 4000, 6000]),
    ('P_PK_WINS', 'DAILY', 'PK_WINS', 3, 8000, 'HOSTS', 'اربح معارك PK', 'Win PK battles', 740, true, 'HOST', ARRAY[1, 1, 2, 3], ARRAY[3000, 4000, 6000, 8000])
ON CONFLICT ("code") DO NOTHING;

-- The generated variant of a day's task.
ALTER TABLE "task_assignments"
    ADD COLUMN "variant" VARCHAR(120),
    ADD COLUMN "subject" VARCHAR(40),
    ADD COLUMN "window_from" SMALLINT,
    ADD COLUMN "window_to" SMALLINT,
    ADD COLUMN "name_ar" VARCHAR(160),
    ADD COLUMN "name_en" VARCHAR(160),
    ADD COLUMN "reason" JSONB,
    ADD CONSTRAINT "task_assignments_variant_shape" CHECK (
        ("window_from" IS NULL) = ("window_to" IS NULL)
        AND ("window_from" IS NULL OR ("window_from" >= 0 AND "window_from" < "window_to" AND "window_to" <= 1440))
        AND ("name_ar" IS NULL) = ("name_en" IS NULL)
        AND ("variant" IS NULL OR "variant" LIKE 'K.%'));
CREATE INDEX "task_assignments_user_day_idx" ON "task_assignments"("user_id", "day" DESC);

-- The owner's knobs (one row).
CREATE TABLE "host_target_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "easy_percentile" SMALLINT NOT NULL DEFAULT 50,
    "medium_percentile" SMALLINT NOT NULL DEFAULT 75,
    "hard_percentile" SMALLINT NOT NULL DEFAULT 90,
    "easy_reward_bps" INTEGER NOT NULL DEFAULT 150,
    "medium_reward_bps" INTEGER NOT NULL DEFAULT 250,
    "hard_reward_bps" INTEGER NOT NULL DEFAULT 400,
    "no_repeat_days" SMALLINT NOT NULL DEFAULT 7,
    "task_no_repeat_days" SMALLINT NOT NULL DEFAULT 3,
    "history_days" SMALLINT NOT NULL DEFAULT 30,
    "completion_shift" SMALLINT NOT NULL DEFAULT 10,
    "engine_from" DATE,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,
    CONSTRAINT "host_target_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "host_target_settings_one" CHECK ("id" = 1),
    CONSTRAINT "host_target_settings_shape" CHECK (
        1 <= "easy_percentile" AND "easy_percentile" < "medium_percentile"
        AND "medium_percentile" < "hard_percentile" AND "hard_percentile" <= 99
        AND 0 <= "easy_reward_bps" AND "easy_reward_bps" <= "medium_reward_bps"
        AND "medium_reward_bps" <= "hard_reward_bps" AND "hard_reward_bps" <= 2000
        AND "no_repeat_days" BETWEEN 0 AND 60 AND "task_no_repeat_days" BETWEEN 0 AND 60
        AND "history_days" BETWEEN 7 AND 90 AND "completion_shift" BETWEEN 0 AND 30)
);
INSERT INTO "host_target_settings" ("id") VALUES (1) ON CONFLICT DO NOTHING;

-- A host's targets of a day.
CREATE TABLE "host_target_assignments" (
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "level" VARCHAR(6) NOT NULL,
    "code" VARCHAR(120) NOT NULL,
    "kind" VARCHAR(20) NOT NULL,
    "subject" VARCHAR(40),
    "amount" BIGINT NOT NULL,
    "window_from" SMALLINT NOT NULL,
    "window_to" SMALLINT NOT NULL,
    "expected_coins" BIGINT NOT NULL,
    "reward_bps" INTEGER NOT NULL,
    "reward_cherries" BIGINT NOT NULL,
    "title_ar" VARCHAR(160) NOT NULL,
    "title_en" VARCHAR(160) NOT NULL,
    "reason" JSONB NOT NULL,
    "catalogue_version" VARCHAR(16) NOT NULL,
    "completed_at" TIMESTAMPTZ(3),
    "progress" BIGINT,
    "profit_microcents" BIGINT,
    "paid_cherries" BIGINT,
    "paid_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "host_target_assignments_pkey" PRIMARY KEY ("user_id", "day", "level"),
    CONSTRAINT "host_target_assignments_shape" CHECK (
        "level" IN ('EASY', 'MEDIUM', 'HARD')
        AND "kind" IN ('GIFT_CHERRIES', 'LUCKY_CHERRIES', 'GIFT_COUNT', 'CATEGORY_COUNT', 'SUPPORTERS', 'GIFT_SENDS',
                       'COMBO', 'GIFT_COMBO')
        AND ("subject" IS NOT NULL) = ("kind" IN ('GIFT_COUNT', 'CATEGORY_COUNT', 'GIFT_COMBO'))
        AND "code" LIKE 'T.%'
        AND "amount" BETWEEN 1 AND 1000000000
        AND "window_from" >= 0 AND "window_from" < "window_to" AND "window_to" <= 1440
        AND "expected_coins" >= 0 AND "reward_bps" BETWEEN 0 AND 10000 AND "reward_cherries" >= 0
        AND ("paid_at" IS NULL) = ("paid_cherries" IS NULL)
        AND ("paid_cherries" IS NULL OR ("paid_cherries" >= 0 AND "paid_cherries" <= "reward_cherries"))
        AND ("paid_at" IS NULL OR "completed_at" IS NOT NULL))
);
CREATE INDEX "host_target_assignments_day_idx" ON "host_target_assignments"("day");
ALTER TABLE "host_target_assignments" ADD CONSTRAINT "host_target_assignments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
