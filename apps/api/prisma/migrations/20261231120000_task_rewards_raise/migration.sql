-- v1.53-social (D184, owner 2026-10-30): raise the Task Center's cherry rewards. Target: at most about $5 a
-- month from tasks — at $1.10 per 1 000 000 cherries ≈ 4 500 000 cherries a month ≈ 150 000 a day (the daily
-- cap TASK_DAILY_CAP_CHERRIES, server config). Every stored task reward ×300 from the values of
-- 20261231110000_task_cherries (e.g. 30 → 9 000), so a band's full daily list lands near the cap; the weekly
-- host tasks 1 000 → 300 000 each (outside the daily cap). Claims already made keep what they paid.
-- Bounds: the largest default becomes 300 000 (fixed) / 60 000 (band), far inside the CHECKs' 1 000 000 000
-- and INTEGER; a team-set value above 3 333 333 would exceed the CHECK, so it is capped there (none exists).

UPDATE "task_definitions"
   SET "reward_cherries" = LEAST("reward_cherries"::bigint * 300, 1000000000)::integer,
       "band_rewards" = ARRAY(SELECT LEAST(r::bigint * 300, 1000000000)::integer
                                FROM unnest("band_rewards") WITH ORDINALITY AS t(r, i) ORDER BY i),
       "updated_at" = CURRENT_TIMESTAMP;

-- The day's offers (nothing was paid from them).
UPDATE "task_assignments"
   SET "reward_cherries" = LEAST("reward_cherries"::bigint * 300, 1000000000)::integer;
