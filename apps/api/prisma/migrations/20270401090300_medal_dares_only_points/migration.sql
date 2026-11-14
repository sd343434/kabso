-- D300 follow-up (owner 2026-11-07, answering the D300 questions; CONVENTIONS §10.111.7):
--  - «لاعب الأحكام» / Dares Player counts ONLY «PK أحكام» (DARES) matches, not every PK type. `pk_host_records.points`
--    sums every type, so a DARES-only total is kept beside it: `pk_host_records.dares_points` — the same once-per-match
--    `pk_point_events` (+3 a win, +1 a draw, −3 a refused or not-done dare, the forfeit, …) of the DARES matches only,
--    added by `addPkPointsIn` in the same statement as `points`; filled here from the history of `pk_point_events`
--    joined to the DARES matches. May be below 0 (levels never drop, D291).
--  - The medal's metric is renamed `PK_POINTS` → `PK_DARES_POINTS` (the value never reached a server: D300 is not
--    deployed; RENAME VALUE keeps every row that uses it).
--  - Both D300 medals go to the tab of the other medals (owner: «هذه ميداليات»): DARES_PLAYER → ACHIEVEMENT (CONTENT_SCHOOL
--    already is).
-- The runtime role gets DML through the default privileges: no GRANT here.
ALTER TYPE "MedalMetric" RENAME VALUE 'PK_POINTS' TO 'PK_DARES_POINTS';

ALTER TABLE "pk_host_records" ADD COLUMN "dares_points" INTEGER NOT NULL DEFAULT 0;

UPDATE "pk_host_records" r
   SET "dares_points" = s.points
  FROM (SELECT e."host_id", sum(e."points")::int AS points
          FROM "pk_point_events" e JOIN "pk_matches" m ON m."id" = e."match_id"
         WHERE m."type" = 'DARES'
         GROUP BY e."host_id") s
 WHERE r."host_id" = s."host_id";

UPDATE "medals" SET "category" = 'ACHIEVEMENT' WHERE "code" IN ('DARES_PLAYER', 'CONTENT_SCHOOL');
