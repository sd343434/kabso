-- D300 (owner 2026-11-07): «مدرسة المحتوى» / Content School — one medal, four levels, for content creators only
-- (`creator_members`), each level reached when the creator has ALL THREE of its followers, likes and views
-- (CONVENTIONS §10.111). Each level has the owner's own art bundled in the app (`medal_content_school_l1` … `_l4`,
-- apps/mobile/assets/medals/PROVENANCE.md).
--  - `medal_level_requirements`: the several thresholds of one level (one row per metric); a level of a medal on the
--    metric `ALL_REQUIREMENTS` is reached when every one of its rows is met, and its `medal_levels.threshold` is the
--    level number (the value of `ALL_REQUIREMENTS` is the level the requirements reach, so the D291 machinery —
--    `raiseMedalLevelsIn`, levels never lowered, notifications, audit — is reused unchanged). Single-metric medals have
--    no rows here and keep working as before. Deleting a level (the panel replaces the list) deletes its rows.
--  - the medal (tab ACHIEVEMENT, sort 120) and its levels with the owner's thresholds (not provisional):
--      L1  2 000 followers ·    10 000 likes ·    20 000 views
--      L2 10 000           ·    50 000       ·   100 000
--      L3 100 000          ·   200 000       ·   500 000
--      L4 1 000 000        · 2 000 000       · 5 000 000
--  - `post_views.counted_views` (owner 2026-11-07: views count «from ACTIVE accounts, never self»): how many §11.4 views
--    this viewer's row has counted (one per rolling 24 h), so a creator's views can be summed over viewers whose
--    account is ACTIVE now (`posts.view_count` cannot tell who viewed). Existing rows start at 1 — the views counted
--    before this migration that repeated the same viewer cannot be recovered (a lower bound, never more than real).
-- Levels are raised by the sweeper (`MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS`), at a creator's activation and by
-- `medals-admin backfill` (DEPLOYMENT §5.79, PP-57).
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
CREATE TABLE "medal_level_requirements" (
  "medal_code" VARCHAR(40) NOT NULL,
  "level" SMALLINT NOT NULL,
  "metric" "MedalMetric" NOT NULL,
  "threshold" BIGINT NOT NULL,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "medal_level_requirements_pkey" PRIMARY KEY ("medal_code", "level", "metric"),
  CONSTRAINT "medal_level_requirements_level_fkey" FOREIGN KEY ("medal_code", "level")
    REFERENCES "medal_levels"("medal_code", "level") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "medal_level_requirements_threshold_range" CHECK ("threshold" BETWEEN 1 AND 1000000000000),
  CONSTRAINT "medal_level_requirements_not_composite" CHECK ("metric" <> 'ALL_REQUIREMENTS')
);

ALTER TABLE "post_views" ADD COLUMN "counted_views" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "post_views" ADD CONSTRAINT "post_views_counted_views_positive" CHECK ("counted_views" >= 1);

INSERT INTO "medals" ("code", "name_ar", "name_en", "description_ar", "description_en", "icon_key", "sort_order",
                      "category", "metric")
VALUES
  ('CONTENT_SCHOOL', 'مدرسة المحتوى', 'Content School', 'لصنّاع المحتوى: المتابعون والإعجابات والمشاهدات معاً.', 'For content creators: followers, likes and views together.', 'medal_content_school', 120, 'ACHIEVEMENT', 'ALL_REQUIREMENTS')
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "medal_levels" ("medal_code", "level", "threshold", "icon_asset")
SELECT d.code, d.level, d.threshold, d.icon_asset
  FROM (VALUES
  ('CONTENT_SCHOOL', 1, 1, 'medal_content_school_l1'),
  ('CONTENT_SCHOOL', 2, 2, 'medal_content_school_l2'),
  ('CONTENT_SCHOOL', 3, 3, 'medal_content_school_l3'),
  ('CONTENT_SCHOOL', 4, 4, 'medal_content_school_l4')
  ) AS d(code, level, threshold, icon_asset)
  JOIN "medals" m ON m.code = d.code
ON CONFLICT DO NOTHING;

INSERT INTO "medal_level_requirements" ("medal_code", "level", "metric", "threshold")
SELECT d.code, d.level, d.metric::"MedalMetric", d.threshold
  FROM (VALUES
  ('CONTENT_SCHOOL', 1, 'CREATOR_FOLLOWERS', 2000),
  ('CONTENT_SCHOOL', 1, 'CREATOR_LIKES', 10000),
  ('CONTENT_SCHOOL', 1, 'CREATOR_VIEWS', 20000),
  ('CONTENT_SCHOOL', 2, 'CREATOR_FOLLOWERS', 10000),
  ('CONTENT_SCHOOL', 2, 'CREATOR_LIKES', 50000),
  ('CONTENT_SCHOOL', 2, 'CREATOR_VIEWS', 100000),
  ('CONTENT_SCHOOL', 3, 'CREATOR_FOLLOWERS', 100000),
  ('CONTENT_SCHOOL', 3, 'CREATOR_LIKES', 200000),
  ('CONTENT_SCHOOL', 3, 'CREATOR_VIEWS', 500000),
  ('CONTENT_SCHOOL', 4, 'CREATOR_FOLLOWERS', 1000000),
  ('CONTENT_SCHOOL', 4, 'CREATOR_LIKES', 2000000),
  ('CONTENT_SCHOOL', 4, 'CREATOR_VIEWS', 5000000)
  ) AS d(code, level, metric, threshold)
  JOIN "medal_levels" l ON l.medal_code = d.code AND l.level = d.level
ON CONFLICT DO NOTHING;
