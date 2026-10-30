-- v1.44-social (D166, owner 2026-10-29): the Me hub's programs (CP-024, approved with defaults),
-- CONVENTIONS §10.41. Additive: new tables, the default tasks, and the wallet reason/sign rule extended;
-- no existing row changes. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

-- ---- Task Center «مركز المهام» -----------------------------------------------------------------

-- CreateTable: the tasks on offer (admin-managed with the task-admin CLI; seeded below).
CREATE TABLE "task_definitions" (
    "code" VARCHAR(40) NOT NULL,
    "period" "task_period" NOT NULL,
    "metric" VARCHAR(40) NOT NULL,
    "target" INTEGER NOT NULL,
    "reward_coins" INTEGER NOT NULL,
    "audience" "program_audience" NOT NULL DEFAULT 'EVERYONE',
    "name_ar" VARCHAR(80) NOT NULL,
    "name_en" VARCHAR(80) NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_definitions_pkey" PRIMARY KEY ("code")
);

-- CreateTable: a task's reward, paid once per person, task and period (day or week).
CREATE TABLE "task_claims" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "task_code" VARCHAR(40) NOT NULL,
    "period_start" DATE NOT NULL,
    "reward_coins" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_claims_pkey" PRIMARY KEY ("id")
);

-- CreateTable: a person checked in that day (the streak counts consecutive days).
CREATE TABLE "daily_check_ins" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "streak" INTEGER NOT NULL,
    "reward_coins" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "daily_check_ins_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "task_claims_once" ON "task_claims"("user_id", "task_code", "period_start");
CREATE INDEX "task_claims_user_period_idx" ON "task_claims"("user_id", "period_start");
CREATE INDEX "task_claims_task_idx" ON "task_claims"("task_code");
CREATE UNIQUE INDEX "daily_check_ins_once" ON "daily_check_ins"("user_id", "day");

ALTER TABLE "task_claims" ADD CONSTRAINT "task_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "task_claims" ADD CONSTRAINT "task_claims_task_code_fkey" FOREIGN KEY ("task_code") REFERENCES "task_definitions"("code") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "daily_check_ins" ADD CONSTRAINT "daily_check_ins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS')
    AND target BETWEEN 1 AND 1000000000 AND reward_coins BETWEEN 1 AND 1000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);
ALTER TABLE "task_claims" ADD CONSTRAINT "task_claims_reward_range" CHECK (reward_coins BETWEEN 0 AND 1000000);
ALTER TABLE "daily_check_ins" ADD CONSTRAINT "daily_check_ins_shape" CHECK (streak >= 1 AND reward_coins BETWEEN 0 AND 1000000);

-- The defaults (owner 2026-10-29, the reference's tasks adapted to Kabso; CP-024 T7/T8 for hosts).
-- "Share a live room" is left out: a share is a copy of a link on the phone, which the server
-- cannot see, so it could only be counted from what the app says (never self-reported).
INSERT INTO "task_definitions" ("code", "period", "metric", "target", "reward_coins", "audience", "name_ar", "name_en", "sort_order") VALUES
    ('WATCH_LIVE', 'DAILY', 'WATCH_LIVES', 1, 5, 'EVERYONE', 'شاهد بثاً لمدة 15 ثانية', 'Watch a live for 15 seconds', 10),
    ('FOLLOW_USERS', 'DAILY', 'FOLLOWS', 10, 5, 'EVERYONE', 'تابع مستخدمين آخرين', 'Follow other users', 20),
    ('LIVE_CHAT', 'DAILY', 'LIVE_CHAT_MESSAGES', 10, 5, 'EVERYONE', 'دردش في غرفة بث', 'Chat in a live room', 30),
    ('SEND_GIFTS', 'DAILY', 'GIFT_SENDS', 10, 15, 'EVERYONE', 'أرسل هدايا', 'Send gifts', 40),
    ('HOST_LIVE_MINUTES', 'WEEKLY', 'HOST_LIVE_MINUTES', 60, 100, 'HOSTS', 'ابثّ 60 دقيقة هذا الأسبوع', 'Go live for 60 minutes this week', 50),
    ('HOST_GIFT_COINS', 'WEEKLY', 'HOST_GIFT_COINS', 1000, 100, 'HOSTS', 'استقبل هدايا بقيمة 1000 عملة', 'Receive gifts worth 1,000 coins', 60);

-- ---- Event Center «مركز الفعاليات» -------------------------------------------------------------

-- CreateTable: an event created by the team (event-admin CLI).
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "title_ar" VARCHAR(120) NOT NULL,
    "title_en" VARCHAR(120) NOT NULL,
    "banner_url" VARCHAR(2048),
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3),
    "rules_ar" VARCHAR(4000) NOT NULL,
    "rules_en" VARCHAR(4000) NOT NULL,
    "metric" "event_metric" NOT NULL,
    "audience" "program_audience" NOT NULL DEFAULT 'EVERYONE',
    "permanent" BOOLEAN NOT NULL DEFAULT false,
    "regions" CHAR(2)[] NOT NULL DEFAULT ARRAY[]::CHAR(2)[],
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "prizes" JSONB NOT NULL DEFAULT '[]',
    "frozen_at" TIMESTAMPTZ(3),
    "payout_due_at" TIMESTAMPTZ(3),
    "payout_hold" BOOLEAN NOT NULL DEFAULT false,
    "paid_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable: an ended event's frozen leaderboard (top 100) and each prize's payout.
CREATE TABLE "event_results" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "rank" INTEGER NOT NULL,
    "user_id" UUID NOT NULL,
    "score" BIGINT NOT NULL,
    "prize_coins" INTEGER NOT NULL DEFAULT 0,
    "prize_status" VARCHAR(10) NOT NULL DEFAULT 'NONE',
    "paid_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_results_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "events_starts_idx" ON "events"("starts_at");
CREATE INDEX "events_due_idx" ON "events"("ends_at") WHERE (paid_at IS NULL);
CREATE UNIQUE INDEX "event_results_rank_once" ON "event_results"("event_id", "rank");
CREATE UNIQUE INDEX "event_results_user_once" ON "event_results"("event_id", "user_id");
CREATE INDEX "event_results_user_idx" ON "event_results"("user_id");

ALTER TABLE "event_results" ADD CONSTRAINT "event_results_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_results" ADD CONSTRAINT "event_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "events" ADD CONSTRAINT "events_shape" CHECK (
    char_length(title_ar) BETWEEN 1 AND 120 AND char_length(title_en) BETWEEN 1 AND 120
    AND (ends_at IS NULL OR ends_at > starts_at)
    AND (permanent OR ends_at IS NOT NULL)
    AND cardinality(regions) <= 50
    AND array_to_string(regions, ',') ~ '^([A-Z]{2}(,[A-Z]{2})*)?$'
    AND jsonb_typeof(prizes) = 'array');
ALTER TABLE "event_results" ADD CONSTRAINT "event_results_shape" CHECK (
    rank BETWEEN 1 AND 100 AND score >= 0 AND prize_coins BETWEEN 0 AND 100000000
    AND prize_status IN ('NONE', 'PENDING', 'PAID', 'FORFEITED')
    AND ((prize_status = 'PAID') = (paid_at IS NOT NULL)));

-- ---- Wallet ---------------------------------------------------------------------------------------

-- TASK_REWARD, CHECK_IN_REWARD and EVENT_PRIZE are credits (the reason/sign rule of
-- 20261210100000_direct_messages, extended).
ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
ALTER TABLE "wallet_ledger" ADD CONSTRAINT "wallet_ledger_reason_sign" CHECK (
  (reason IN ('ADMIN_GRANT', 'CP_REFUND', 'LUCKY_GIFT_WIN', 'LIVE_BOOST_REFUND', 'TASK_REWARD', 'CHECK_IN_REWARD',
              'EVENT_PRIZE') AND delta > 0)
  OR (reason IN ('ADMIN_REVOKE', 'BULLET_MESSAGE', 'FAMILY_CREATE', 'CP_REQUEST', 'CP_GIFT', 'LIVE_GIFT', 'LUCKY_GIFT',
                 'PREMIUM_USERNAME_RENT', 'PREMIUM_USERNAME_RENEW', 'LIVE_BOOST', 'DM_GIFT') AND delta < 0));
