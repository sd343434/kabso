-- v1.81-live (D291, owner: «ما رأيك ان نصمم صفحة التي تعرض الميداليات بحيث يمكن ان يكون للميدالية ايضاً ليفيلات»,
-- CONVENTIONS §10.104): medal levels and the medals page's tabs.
--  - `medals.category`: the page's tab — ACHIEVEMENT «الإنجازات» / ACTIVITY «النشاط»;
--  - `medals.metric`: what the medal's levels count (null = a medal without levels, earned once at level 1);
--  - `medal_levels`: each medal's levels — level k is reached when the metric is at least `threshold`; level 1 is the
--    medal's original award rule (CP-018), the other levels are the CTO defaults (owner decisions, edited in the panel);
--    optional per-level names and hosted art (null = the medal's name / art with the numeral drawn by the app);
--  - `user_medals.level` (never lowered) and `level_reached_at`: every medal held before is level 1 here — correct,
--    since level 1 is the old rule; `medals-admin backfill` (DEPLOYMENT §5.72, PP-50) then raises each holder to the
--    level their current totals reach;
--  - `notifications.medal_level`: the level a MEDAL_AWARDED announces (1 = earned; more = a level-up).
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
CREATE TYPE "MedalCategory" AS ENUM ('ACHIEVEMENT', 'ACTIVITY');
CREATE TYPE "MedalMetric" AS ENUM (
  'LIVES_HOSTED', 'LIVE_HOURS', 'CHARM_LEVEL', 'FAMILY_JOINED', 'CP_FORMED', 'BULLETS_SENT');

ALTER TABLE "medals"
  ADD COLUMN "category" "MedalCategory" NOT NULL DEFAULT 'ACHIEVEMENT',
  ADD COLUMN "metric" "MedalMetric";

CREATE TABLE "medal_levels" (
  "medal_code" VARCHAR(40) NOT NULL,
  "level" SMALLINT NOT NULL,
  "threshold" BIGINT NOT NULL,
  "name_ar" VARCHAR(60),
  "name_en" VARCHAR(60),
  "icon_url" VARCHAR(500),
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "medal_levels_pkey" PRIMARY KEY ("medal_code", "level"),
  CONSTRAINT "medal_levels_medal_code_fkey" FOREIGN KEY ("medal_code")
    REFERENCES "medals"("code") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "medal_levels_level_range" CHECK ("level" BETWEEN 1 AND 20),
  CONSTRAINT "medal_levels_threshold_range" CHECK ("threshold" BETWEEN 1 AND 1000000000000),
  CONSTRAINT "medal_levels_icon_https" CHECK ("icon_url" IS NULL OR "icon_url" LIKE 'https://%')
);

ALTER TABLE "user_medals"
  ADD COLUMN "level" SMALLINT NOT NULL DEFAULT 1,
  ADD COLUMN "level_reached_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
-- Level 1 was reached when the medal was awarded.
UPDATE "user_medals" SET "level_reached_at" = "awarded_at";
ALTER TABLE "user_medals" ADD CONSTRAINT "user_medals_level_range" CHECK ("level" BETWEEN 1 AND 20);

ALTER TABLE "notifications" ADD COLUMN "medal_level" SMALLINT;

-- The tabs and metrics of the nine medals (owner decision: the tab of each).
UPDATE "medals" SET "category" = 'ACTIVITY', "metric" = 'LIVES_HOSTED' WHERE "code" = 'FIRST_LIVE';
UPDATE "medals" SET "category" = 'ACTIVITY', "metric" = 'LIVE_HOURS' WHERE "code" IN ('LIVE_HOURS_10', 'LIVE_HOURS_100');
UPDATE "medals" SET "category" = 'ACHIEVEMENT', "metric" = 'CHARM_LEVEL' WHERE "code" IN ('CHARM_10', 'CHARM_50', 'CHARM_100');
UPDATE "medals" SET "category" = 'ACHIEVEMENT', "metric" = 'FAMILY_JOINED' WHERE "code" = 'FIRST_FAMILY';
UPDATE "medals" SET "category" = 'ACHIEVEMENT', "metric" = 'CP_FORMED' WHERE "code" = 'FIRST_CP';
UPDATE "medals" SET "category" = 'ACTIVITY', "metric" = 'BULLETS_SENT' WHERE "code" = 'BULLET_FIRST';

-- The default levels (medals.catalogue.ts MEDAL_DEFAULT_LEVELS; a unit test keeps the two equal). Level 1 = the
-- original rule. Only for medals that exist (a database seeded differently gets no orphan rows).
INSERT INTO "medal_levels" ("medal_code", "level", "threshold")
SELECT d.code, d.level, d.threshold
  FROM (VALUES
  ('FIRST_LIVE', 1, 1), ('FIRST_LIVE', 2, 10), ('FIRST_LIVE', 3, 50), ('FIRST_LIVE', 4, 100), ('FIRST_LIVE', 5, 500),
  ('LIVE_HOURS_10', 1, 10), ('LIVE_HOURS_10', 2, 25), ('LIVE_HOURS_10', 3, 50),
  ('LIVE_HOURS_100', 1, 100), ('LIVE_HOURS_100', 2, 500), ('LIVE_HOURS_100', 3, 1000),
  ('CHARM_10', 1, 10), ('CHARM_10', 2, 20), ('CHARM_10', 3, 30), ('CHARM_10', 4, 40),
  ('CHARM_50', 1, 50), ('CHARM_50', 2, 60), ('CHARM_50', 3, 70), ('CHARM_50', 4, 80), ('CHARM_50', 5, 90),
  ('CHARM_100', 1, 100),
  ('FIRST_FAMILY', 1, 1),
  ('FIRST_CP', 1, 1),
  ('BULLET_FIRST', 1, 1), ('BULLET_FIRST', 2, 10), ('BULLET_FIRST', 3, 100), ('BULLET_FIRST', 4, 1000)
  ) AS d(code, level, threshold)
  JOIN "medals" m ON m.code = d.code;
