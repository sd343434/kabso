-- D313 (owner 2026-11-08: «ميداليات موجودة: أول لايف، وأول رسالة عامة، وأول عائلة، وأول ثنائي — ازلها», CONVENTIONS
-- §10.104.8): the four «first» medals — FIRST_LIVE «أول لايف», BULLET_FIRST «أول رسالة عامة», FIRST_FAMILY «أول عائلة»,
-- FIRST_CP «أول ثنائي» — are retired exactly as D291 retired the charm and live-hours codes
-- (20270325090300_medal_retire_name_icons):
--  - `medals.retired` = true: left out of the medals page, the catalogue, the lists, the profile, the showcase and the
--    live chat line; never awarded again (no notification); wearing one → 400; the panel shows them read-only;
--  - their rows in `user_medals` are KEPT as history; only their showcase positions are cleared, and each affected
--    person's remaining worn medals are renumbered 1, 2, … in their order (two steps: the unique (user, position)
--    index is checked row by row).
-- No new object; the runtime role's DML comes from the default privileges: no GRANT here.
UPDATE "medals" SET "retired" = true
 WHERE "code" IN ('FIRST_LIVE', 'BULLET_FIRST', 'FIRST_FAMILY', 'FIRST_CP');

CREATE TEMP TABLE "d313_showcase" AS
SELECT um."user_id", um."medal_code",
       row_number() OVER (PARTITION BY um."user_id" ORDER BY um."showcase_position")::smallint AS "pos"
  FROM "user_medals" um JOIN "medals" m ON m."code" = um."medal_code"
 WHERE um."showcase_position" IS NOT NULL AND NOT m."retired"
   AND um."user_id" IN (
     SELECT x."user_id" FROM "user_medals" x JOIN "medals" r ON r."code" = x."medal_code"
      WHERE x."showcase_position" IS NOT NULL AND r."retired");

UPDATE "user_medals" SET "showcase_position" = NULL
 WHERE "showcase_position" IS NOT NULL
   AND "user_id" IN (SELECT DISTINCT "user_id" FROM "d313_showcase")
    OR ("showcase_position" IS NOT NULL
        AND "medal_code" IN (SELECT "code" FROM "medals" WHERE "retired"));

UPDATE "user_medals" um SET "showcase_position" = s."pos"
  FROM "d313_showcase" s
 WHERE um."user_id" = s."user_id" AND um."medal_code" = s."medal_code";
DROP TABLE "d313_showcase";
