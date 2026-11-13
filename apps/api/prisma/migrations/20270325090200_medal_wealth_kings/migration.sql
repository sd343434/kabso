-- D291 (owner 2026-11-06): «ملوك الثروة» / Wealth Kings — one medal, six levels, each with the owner's own art bundled
-- in the app (CONVENTIONS §10.104.7).
--  - `medal_levels.icon_asset`: a level's bundled art key (the app maps it to a file under assets/medals/; an unknown key
--    falls back to the medal's art); `icon_url` (hosted) still wins when both are set;
--  - `medal_metric_totals`: running totals of a metric too costly to recount per event — GIFTS_SENT_COINS, added in each
--    gift send's transaction (once per send) and recomputed from `live_gifts` by `medals-admin backfill`;
--  - the medal and its levels, the owner's thresholds (not provisional): 50 M / 150 M / 300 M / 500 M / 1 B / 3 B coins.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
ALTER TABLE "medal_levels" ADD COLUMN "icon_asset" VARCHAR(60);
ALTER TABLE "medal_levels"
  ADD CONSTRAINT "medal_levels_icon_asset_format" CHECK ("icon_asset" IS NULL OR "icon_asset" ~ '^[a-z0-9_]{1,60}$');

CREATE TABLE "medal_metric_totals" (
  "user_id" UUID NOT NULL,
  "metric" "MedalMetric" NOT NULL,
  "value" BIGINT NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "medal_metric_totals_pkey" PRIMARY KEY ("user_id", "metric"),
  CONSTRAINT "medal_metric_totals_user_id_fkey" FOREIGN KEY ("user_id")
    REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "medal_metric_totals_value_nonnegative" CHECK ("value" >= 0)
);

INSERT INTO "medals" ("code", "name_ar", "name_en", "description_ar", "description_en", "icon_key", "sort_order",
                      "category", "metric")
VALUES
  ('WEALTH_KINGS', 'ملوك الثروة', 'Wealth Kings', 'مجموع قيمة الهدايا التي أرسلتها لأي مستخدم، عدا هدايا الحظ.', 'Total value of gifts you sent to anyone, except lucky gifts.', 'medal_wealth_kings', 100, 'ACHIEVEMENT', 'GIFTS_SENT_COINS')
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "medal_levels" ("medal_code", "level", "threshold", "icon_asset")
SELECT d.code, d.level, d.threshold, d.icon_asset
  FROM (VALUES
  ('WEALTH_KINGS', 1, 50000000, 'medal_wealth_l1'),
  ('WEALTH_KINGS', 2, 150000000, 'medal_wealth_l2'),
  ('WEALTH_KINGS', 3, 300000000, 'medal_wealth_l3'),
  ('WEALTH_KINGS', 4, 500000000, 'medal_wealth_l4'),
  ('WEALTH_KINGS', 5, 1000000000, 'medal_wealth_l5'),
  ('WEALTH_KINGS', 6, 3000000000, 'medal_wealth_l6')
  ) AS d(code, level, threshold, icon_asset)
  JOIN "medals" m ON m.code = d.code
ON CONFLICT DO NOTHING;
