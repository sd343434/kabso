-- D291 (owner 2026-11-06): «سيد الحظ» / Lucky Master — one medal, four levels, each with the owner's own art bundled in
-- the app (CONVENTIONS §10.104.9). Metric LUCKY_GIFTS_SENT_COINS (running totals in `medal_metric_totals`, added in each
-- lucky send's transaction; `medals-admin backfill` recomputes them from `live_gifts`). The owner's thresholds (not
-- provisional): 500 M / 1.5 B / 3 B / 10 B coins (BIGINT; above 2^31 and 2^32 by design).
-- The runtime role gets DML through the default privileges: no GRANT here.
INSERT INTO "medals" ("code", "name_ar", "name_en", "description_ar", "description_en", "icon_key", "sort_order",
                      "category", "metric")
VALUES
  ('LUCKY_MASTER', 'سيد الحظ', 'Lucky Master', 'مجموع قيمة هدايا الحظ التي أرسلتها.', 'Total value of lucky gifts you sent.', 'medal_lucky_master', 110, 'ACHIEVEMENT', 'LUCKY_GIFTS_SENT_COINS')
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "medal_levels" ("medal_code", "level", "threshold", "icon_asset")
SELECT d.code, d.level, d.threshold, d.icon_asset
  FROM (VALUES
  ('LUCKY_MASTER', 1, 500000000, 'medal_lucky_l1'),
  ('LUCKY_MASTER', 2, 1500000000, 'medal_lucky_l2'),
  ('LUCKY_MASTER', 3, 3000000000, 'medal_lucky_l3'),
  ('LUCKY_MASTER', 4, 10000000000, 'medal_lucky_l4')
  ) AS d(code, level, threshold, icon_asset)
  JOIN "medals" m ON m.code = d.code
ON CONFLICT DO NOTHING;
