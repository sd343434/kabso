-- v1.57-social (D188, owner 2026-10-30): rebalance the Task Center's cherry rewards. The ×300 raise of
-- 20261231120000_task_rewards_raise came from wrong pricing. Anchors: 1 000 000 coins = $12.50 retail,
-- 1 000 000 cherries = $1.10 payout. Free actions (watch, comment, follow, post, story, message, hearts)
-- pay a symbolic 300 → 1 000 cherries (band 1 → 4); tasks with money behind them have coin-value targets
-- counted from the stored gift rows (never reported) and pay at most about 1 % of that value:
--   send gifts           GIFT_COINS_SENT   10 000 · 25 000 · 50 000 · 100 000 coins → 1 000 · 2 500 · 5 000 · 10 000
--   support a new host   (target kept)     1 000 · 2 000 · 3 500 · 5 000
--   host: live minutes   60 · 80 · 100 · 120 min → 2 000 · 3 000 · 4 000 · 5 000
--   host: gifts received HOST_GIFT_COINS   100 000 · 250 000 · 500 000 · 1 000 000 coins → 5 000 · 10 000 · 20 000 · 30 000
--   host: accept a guest (target kept)     1 000 · 1 500 · 2 000 · 3 000
--   weekly host tasks    10 h live → 30 000; 5 000 000 coins received → 50 000
-- «Send a gift» (one gift of any price) is switched off: a single cheap gift cannot carry a reward within
-- 1 % of its value; its row becomes a coin-value task for the team (`task-admin set P_SEND_GIFT`).
-- The daily cap (TASK_DAILY_CAP_CHERRIES 50 000), the new monthly cap (TASK_MONTHLY_CAP_MINOR $5) and
-- the withdrawal unlock (TASK_CHERRIES_UNLOCK_GIFT_MINOR $60) are server config, not stored here.
-- Claims already made keep what they paid; the day's offered assignments are re-priced (below).
-- No GRANT: the runtime role has DML through the default privileges.

-- ---- The new metric: the coin value of the gifts a person sent ---------------------------------------
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS',
                   'GIFT_COINS_SENT')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);

-- ---- Pool templates (a pool row's target / reward mirror its highest band) -----------------------------
UPDATE "task_definitions" AS d
   SET "band_targets" = v.targets,
       "band_rewards" = v.rewards,
       "target" = (SELECT max(x) FROM unnest(v.targets) AS x),
       "reward_cherries" = (SELECT max(x) FROM unnest(v.rewards) AS x),
       "metric" = COALESCE(v.metric, d."metric"),
       "name_ar" = COALESCE(v.name_ar, d."name_ar"),
       "name_en" = COALESCE(v.name_en, d."name_en"),
       "enabled" = COALESCE(v.enabled, d."enabled"),
       "updated_at" = CURRENT_TIMESTAMP
  FROM (VALUES
    ('P_WATCH_LIVES',   NULL::varchar, NULL::varchar, NULL::varchar, NULL::boolean, ARRAY[1, 2, 3, 5],    ARRAY[300, 500, 750, 1000]),
    ('P_WATCH_MINUTES', NULL, NULL, NULL, NULL, ARRAY[5, 15, 30, 30],   ARRAY[300, 500, 750, 1000]),
    ('P_AUDIO_ROOMS',   NULL, NULL, NULL, NULL, ARRAY[1, 2, 3, 3],      ARRAY[300, 500, 750, 1000]),
    ('P_LIVE_COMMENTS', NULL, NULL, NULL, NULL, ARRAY[3, 5, 10, 20],    ARRAY[300, 500, 750, 1000]),
    ('P_LIVE_TAPS',     NULL, NULL, NULL, NULL, ARRAY[20, 50, 100, 200], ARRAY[300, 500, 750, 1000]),
    ('P_FOLLOW',        NULL, NULL, NULL, NULL, ARRAY[1, 3, 5, 10],     ARRAY[300, 500, 750, 1000]),
    ('P_POST_COMMENTS', NULL, NULL, NULL, NULL, ARRAY[1, 3, 5, 10],     ARRAY[300, 500, 750, 1000]),
    ('P_POST',          NULL, NULL, NULL, NULL, ARRAY[1, 1, 1, 2],      ARRAY[300, 500, 750, 1000]),
    ('P_REEL',          NULL, NULL, NULL, NULL, ARRAY[0, 1, 1, 1],      ARRAY[0, 500, 750, 1000]),
    ('P_STORY',         NULL, NULL, NULL, NULL, ARRAY[1, 1, 1, 2],      ARRAY[300, 500, 750, 1000]),
    ('P_DM_FRIEND',     NULL, NULL, NULL, NULL, ARRAY[1, 1, 2, 3],      ARRAY[300, 500, 750, 1000]),
    ('P_DM_VOICE',      NULL, NULL, NULL, NULL, ARRAY[1, 1, 1, 2],      ARRAY[300, 500, 750, 1000]),
    ('P_SEND_GIFT',     'GIFT_COINS_SENT', 'أرسل هدية (بالعملات)', 'Send a gift (coins)', false,
                        ARRAY[1000, 2500, 5000, 10000], ARRAY[100, 250, 500, 1000]),
    ('P_SEND_GIFTS',    'GIFT_COINS_SENT', 'أرسل هدايا (بالعملات)', 'Send gifts (coins)', NULL,
                        ARRAY[10000, 25000, 50000, 100000], ARRAY[1000, 2500, 5000, 10000]),
    ('P_NEW_HOST',      NULL, NULL, NULL, NULL, ARRAY[1, 1, 1, 2],      ARRAY[1000, 2000, 3500, 5000]),
    ('P_HOST_LIVE_30',  NULL, NULL, NULL, NULL, ARRAY[60, 80, 100, 120], ARRAY[2000, 3000, 4000, 5000]),
    ('P_HOST_GIFTS',    'HOST_GIFT_COINS', 'استقبل هدايا في بثك (بالعملات)', 'Receive gifts in your live (coins)', NULL,
                        ARRAY[100000, 250000, 500000, 1000000], ARRAY[5000, 10000, 20000, 30000]),
    ('P_HOST_GUEST',    NULL, NULL, NULL, NULL, ARRAY[1, 1, 2, 3],      ARRAY[1000, 1500, 2000, 3000])
  ) AS v(code, metric, name_ar, name_en, enabled, targets, rewards)
 WHERE d."code" = v.code AND d."pool";

-- ---- D166's fixed tasks (the four daily ones stay switched off by the pool) and the weekly host tasks ---
UPDATE "task_definitions" AS d
   SET "target" = v.target,
       "reward_cherries" = v.reward,
       "metric" = COALESCE(v.metric, d."metric"),
       "name_ar" = COALESCE(v.name_ar, d."name_ar"),
       "name_en" = COALESCE(v.name_en, d."name_en"),
       "updated_at" = CURRENT_TIMESTAMP
  FROM (VALUES
    ('WATCH_LIVE',        1,       300,   NULL::varchar, NULL::varchar, NULL::varchar),
    ('FOLLOW_USERS',      10,      300,   NULL, NULL, NULL),
    ('LIVE_CHAT',         10,      300,   NULL, NULL, NULL),
    ('SEND_GIFTS',        10000,   1000,  'GIFT_COINS_SENT', 'أرسل هدايا بقيمة 10,000 عملة', 'Send gifts worth 10,000 coins'),
    ('HOST_LIVE_MINUTES', 600,     30000, NULL, 'ابثّ 10 ساعات هذا الأسبوع', 'Go live for 10 hours this week'),
    ('HOST_GIFT_COINS',   5000000, 50000, NULL, 'استقبل هدايا بقيمة 5,000,000 عملة هذا الأسبوع',
                          'Receive gifts worth 5,000,000 coins this week')
  ) AS v(code, target, reward, metric, name_ar, name_en)
 WHERE d."code" = v.code AND NOT d."pool";

-- ---- The days' offered assignments (offers only: claims are separate rows and keep what they paid) ----
-- Re-priced from their template for their band, so an offer made before this migration (e.g. «send
-- gifts» with a count target of 10, now a coin value) can never pay the old reward. An offer whose
-- template is not offered in that band any more is left as it was (none with these defaults).
UPDATE "task_assignments" AS a
   SET "target" = d."band_targets"[a."band"],
       "reward_cherries" = d."band_rewards"[a."band"]
  FROM "task_definitions" AS d
 WHERE d."code" = a."task_code" AND d."pool"
   AND d."band_targets"[a."band"] > 0 AND d."band_rewards"[a."band"] > 0;
