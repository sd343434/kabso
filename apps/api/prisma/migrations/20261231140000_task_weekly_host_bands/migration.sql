-- v1.57-social (D188 follow-up, owner 2026-10-30: «YES» — an active host should really reach about $5 a
-- month from tasks). The daily cap (50 000) and the monthly cap ($5 = 4 545 454 cherries) stay; since
-- 50 000 × 31 ≈ 1 550 000, most of the rise comes from the weekly host tasks, which sit outside the daily
-- cap. A band-4 host who completes everything reaches the monthly cap; bands 1–3 about $2.5 / $3.3 / $4.2.
--   daily host tasks ×2: live minutes 4 000 · 6 000 · 8 000 · 10 000; gifts received 10 000 · 20 000 ·
--     40 000 · 60 000; accept a guest 2 000 · 3 000 · 4 000 · 6 000 (targets unchanged)
--   weekly host tasks per level band 1 · 2 · 3 · 4 (the caller's band of the day):
--     live   300 · 360 · 480 · 600 min           → 180 000 · 190 000 · 220 000 · 250 000
--     gifts  2 500 000 · 3 500 000 · 4 500 000 · 5 000 000 coins → 220 000 · 270 000 · 290 000 · 430 000
--     (at most 0.77 % of the coins' retail value)
-- A fixed (non-pool) WEEKLY task may now carry one target and reward per band; `target` /
-- `reward_cherries` mirror band 4. Claims already paid keep what they paid; the days' daily offers of the
-- host tasks are re-priced like 20261231130000. No GRANT: default privileges.

ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_pool_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_pool_shape" CHECK (
    (NOT pool AND pool_group IS NULL
        AND ((cardinality(band_targets) = 0 AND cardinality(band_rewards) = 0)
             OR (period = 'WEEKLY' AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
                 AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
                 AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards))))
    OR (pool AND period = 'DAILY'
        AND pool_group IN ('WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST')
        AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
        AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
        AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards)));

-- ---- Daily host pool templates: rewards ×2 ----------------------------------------------------------
UPDATE "task_definitions" AS d
   SET "band_rewards" = v.rewards,
       "reward_cherries" = (SELECT max(x) FROM unnest(v.rewards) AS x),
       "updated_at" = CURRENT_TIMESTAMP
  FROM (VALUES
    ('P_HOST_LIVE_30', ARRAY[4000, 6000, 8000, 10000]),
    ('P_HOST_GIFTS',   ARRAY[10000, 20000, 40000, 60000]),
    ('P_HOST_GUEST',   ARRAY[2000, 3000, 4000, 6000])
  ) AS v(code, rewards)
 WHERE d."code" = v.code AND d."pool";

-- ---- Weekly host tasks: per band ----------------------------------------------------------------------
UPDATE "task_definitions" AS d
   SET "band_targets" = v.targets,
       "band_rewards" = v.rewards,
       "target" = v.targets[4],
       "reward_cherries" = v.rewards[4],
       "name_ar" = v.name_ar,
       "name_en" = v.name_en,
       "updated_at" = CURRENT_TIMESTAMP
  FROM (VALUES
    ('HOST_LIVE_MINUTES', ARRAY[300, 360, 480, 600], ARRAY[180000, 190000, 220000, 250000],
     'ابثّ مباشرة هذا الأسبوع (بالدقائق)', 'Go live this week (minutes)'),
    ('HOST_GIFT_COINS', ARRAY[2500000, 3500000, 4500000, 5000000], ARRAY[220000, 270000, 290000, 430000],
     'استقبل هدايا هذا الأسبوع (بالعملات)', 'Receive gifts this week (coins)')
  ) AS v(code, targets, rewards, name_ar, name_en)
 WHERE d."code" = v.code AND NOT d."pool" AND d."period" = 'WEEKLY';

-- ---- The days' offers of the daily host tasks (offers only) -------------------------------------------
UPDATE "task_assignments" AS a
   SET "target" = d."band_targets"[a."band"],
       "reward_cherries" = d."band_rewards"[a."band"]
  FROM "task_definitions" AS d
 WHERE d."code" = a."task_code" AND d."pool" AND d."code" IN ('P_HOST_LIVE_30', 'P_HOST_GIFTS', 'P_HOST_GUEST')
   AND d."band_targets"[a."band"] > 0 AND d."band_rewards"[a."band"] > 0;
