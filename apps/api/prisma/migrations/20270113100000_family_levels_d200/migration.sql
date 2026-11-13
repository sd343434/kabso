-- D200 (owner, 2026-10-31): the family level ladder repriced for the new coin price (retail
-- 1 000 000 coins = $12.50): level 2 at 4 000 000 points (≈ $50) … level 10 at 24 000 000 000
-- (≈ $300 000) — `FAMILY_LEVELS` in families.constants.ts, CONVENTIONS §10.21. Creating a family
-- now costs 1 000 000 coins (code only, no data here).
--
-- No family drops a level: the stored `families.level` is a floor (`level = max(stored, ladder)`,
-- `familyLevelAfter`). This migration therefore only ever RAISES a level — to what the family's
-- points reach on the new ladder, when that is higher (the new thresholds are all higher than the
-- old ones, so in practice nothing changes) — and never lowers one. `points` are not touched.
-- Disbanded families are left as they are.

UPDATE "families" AS f
   SET "level" = l.ladder_level
  FROM (
    SELECT "id",
           CASE
             WHEN "points" >= 24000000000 THEN 10
             WHEN "points" >= 9600000000 THEN 9
             WHEN "points" >= 4000000000 THEN 8
             WHEN "points" >= 1600000000 THEN 7
             WHEN "points" >= 640000000 THEN 6
             WHEN "points" >= 240000000 THEN 5
             WHEN "points" >= 80000000 THEN 4
             WHEN "points" >= 20000000 THEN 3
             WHEN "points" >= 4000000 THEN 2
             ELSE 1
           END AS ladder_level
      FROM "families"
     WHERE "disbanded_at" IS NULL
  ) AS l
 WHERE f."id" = l."id"
   AND l.ladder_level > f."level";
