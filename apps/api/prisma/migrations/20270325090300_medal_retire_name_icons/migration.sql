-- D291 (owner 2026-11-06: «هذه بالأصل ليست ميدالية يمكن ارتداؤها، فقط تكون أيقونة بجانب الاسم», CONVENTIONS §10.104.8):
-- the charm and live-hours codes are not wearable medals — they are only icons next to the name (the charm level badge
-- of CP-005 already is one; nothing else is added). They are retired from the medals system:
--  - `medals.retired`: left out of the medals page, the catalogue, the lists, the profile, the showcase and the live
--    chat line; never awarded again (no notification); wearing one → 400; the panel shows them read-only;
--  - their rows in `user_medals` are KEPT as history; only their showcase positions are cleared, and each affected
--    person's remaining worn medals are renumbered 1, 2, … in their order (two steps: the unique (user, position) index
--    is checked row by row).
-- The runtime role gets DML through the default privileges: no GRANT here.
ALTER TABLE "medals" ADD COLUMN "retired" BOOLEAN NOT NULL DEFAULT false;

UPDATE "medals" SET "retired" = true
 WHERE "code" IN ('LIVE_HOURS_10', 'LIVE_HOURS_100', 'CHARM_10', 'CHARM_50', 'CHARM_100');

CREATE TEMP TABLE "d291_showcase" AS
SELECT um."user_id", um."medal_code",
       row_number() OVER (PARTITION BY um."user_id" ORDER BY um."showcase_position")::smallint AS "pos"
  FROM "user_medals" um JOIN "medals" m ON m."code" = um."medal_code"
 WHERE um."showcase_position" IS NOT NULL AND NOT m."retired"
   AND um."user_id" IN (
     SELECT x."user_id" FROM "user_medals" x JOIN "medals" r ON r."code" = x."medal_code"
      WHERE x."showcase_position" IS NOT NULL AND r."retired");

UPDATE "user_medals" SET "showcase_position" = NULL
 WHERE "showcase_position" IS NOT NULL
   AND "user_id" IN (SELECT DISTINCT "user_id" FROM "d291_showcase")
    OR ("showcase_position" IS NOT NULL
        AND "medal_code" IN (SELECT "code" FROM "medals" WHERE "retired"));

UPDATE "user_medals" um SET "showcase_position" = s."pos"
  FROM "d291_showcase" s
 WHERE um."user_id" = s."user_id" AND um."medal_code" = s."medal_code";
DROP TABLE "d291_showcase";
