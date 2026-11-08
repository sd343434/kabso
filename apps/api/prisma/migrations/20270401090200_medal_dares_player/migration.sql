-- D300 (owner 2026-11-07: «عندما يكون نقاط PK تحدي = 1500 / 3000 / 5000 / 20000»): «لاعب الأحكام» / Dares Player —
-- one single-metric medal, four levels, each with the owner's own art bundled in the app (`medal_dares_player_l1` …
-- `_l4`, apps/mobile/assets/medals/PROVENANCE.md; CONVENTIONS §10.111.7). Metric `PK_POINTS`: the host's PK points
-- (`pk_host_records.points`, D229 / D276 «نقاط PK»: every PK type, as the record sums them; it can fall — a refused
-- dare — but a level never goes down, D291). Raised in the transaction that writes each `pk_point_events` row
-- (`addPkPointsIn`); `medals-admin backfill` reads `pk_host_records.points`. Anyone with a PK record (no creator gate).
-- The owner's thresholds (not provisional): 1 500 / 3 000 / 5 000 / 20 000 points. Tab ACTIVITY, sort 130.
-- The runtime role gets DML through the default privileges: no GRANT here.
INSERT INTO "medals" ("code", "name_ar", "name_en", "description_ar", "description_en", "icon_key", "sort_order",
                      "category", "metric")
VALUES
  ('DARES_PLAYER', 'لاعب الأحكام', 'Dares Player', 'نقاط PK التي جمعتها في التحديات.', 'PK points you earned in battles.', 'medal_dares_player', 130, 'ACTIVITY', 'PK_POINTS')
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "medal_levels" ("medal_code", "level", "threshold", "icon_asset")
SELECT d.code, d.level, d.threshold, d.icon_asset
  FROM (VALUES
  ('DARES_PLAYER', 1, 1500, 'medal_dares_player_l1'),
  ('DARES_PLAYER', 2, 3000, 'medal_dares_player_l2'),
  ('DARES_PLAYER', 3, 5000, 'medal_dares_player_l3'),
  ('DARES_PLAYER', 4, 20000, 'medal_dares_player_l4')
  ) AS d(code, level, threshold, icon_asset)
  JOIN "medals" m ON m.code = d.code
ON CONFLICT DO NOTHING;
