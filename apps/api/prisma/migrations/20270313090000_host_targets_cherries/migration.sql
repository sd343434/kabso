-- v1.69-live (D277, CONVENTIONS §10.62.1; owner): the host's two daily targets «تارجت» are measured and stored
-- in CHERRIES — what the cherry ledger credited the host for the gifts (GIFT_RECEIVED net of GIFT_REVERSAL).
--   «هدف الهدايا» (P_HOST_GIFTS, was «استقبل هدايا في بثك (بالعملات)»): gifts OUTSIDE the lucky category from
--     other ACTIVE people (metric HOST_GIFT_CHERRIES). Its coin targets were shown in cherries at the POPULAR
--     host share; they are now stored that way: coins × 10 cherries per coin × 65 %, floored
--     (100 000 → 650 000, 250 000 → 1 625 000, 500 000 → 3 250 000, 1 000 000 → 6 500 000).
--   «هدف هدايا الحظ» (HOST_LUCKY_COINS, the code kept: claims are keyed by it): lucky gifts only, the host's own
--     sends to themself included (metric HOST_LUCKY_CHERRIES). Coins × 10 cherries per coin × the lucky host
--     share 10 % = the same numbers (20 000 / 50 000 / 100 000 / 200 000).
-- Values an owner changed with `task-admin` are converted the same way (only rows still on the old metric, so
-- the migration changes nothing twice). Rewards and caps are unchanged. The conversion assumes the defaults
-- CHERRIES_PER_COIN=10, GIFT_HOST_SHARE_PERCENTS POPULAR=65 and LUCKY_GIFT_HOST_SHARE_PERCENT=10 (DEPLOYMENT).

-- The two new metrics.
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS',
                   'GIFT_COINS_SENT', 'HOST_LUCKY_COINS', 'HOST_GIFT_CHERRIES', 'HOST_LUCKY_CHERRIES')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);

-- The days' offers of «هدف الهدايا» first (they hold a copy of the band's target), while the definition is
-- still on the coin metric.
UPDATE "task_assignments" AS a
   SET "target" = LEAST(1000000000, GREATEST(1, a."target"::bigint * 10 * 6500 / 10000))::int
  FROM "task_definitions" AS d
 WHERE d."code" = a."task_code" AND d."code" = 'P_HOST_GIFTS' AND d."metric" = 'HOST_GIFT_COINS';

-- «هدف الهدايا»: coins × 10 × 65 %.
UPDATE "task_definitions"
   SET "metric" = 'HOST_GIFT_CHERRIES',
       "band_targets" = ARRAY(SELECT LEAST(1000000000, t::bigint * 10 * 6500 / 10000)::int FROM unnest("band_targets") WITH ORDINALITY AS u(t, i) ORDER BY i),
       "target" = LEAST(1000000000, GREATEST(1, "target"::bigint * 10 * 6500 / 10000))::int,
       "name_ar" = 'هدف الهدايا (بالكرز)',
       "name_en" = 'Gifts target (cherries)',
       "updated_at" = CURRENT_TIMESTAMP
 WHERE "code" = 'P_HOST_GIFTS' AND "metric" = 'HOST_GIFT_COINS';

-- «هدف هدايا الحظ»: coins × 10 × 10 % (the same numbers).
UPDATE "task_definitions"
   SET "metric" = 'HOST_LUCKY_CHERRIES',
       "band_targets" = ARRAY(SELECT (t::bigint * 10 * 1000 / 10000)::int FROM unnest("band_targets") WITH ORDINALITY AS u(t, i) ORDER BY i),
       "target" = GREATEST(1, ("target"::bigint * 10 * 1000 / 10000))::int,
       "name_ar" = 'هدف هدايا الحظ (بالكرز)',
       "name_en" = 'Lucky gifts target (cherries)',
       "updated_at" = CURRENT_TIMESTAMP
 WHERE "code" = 'HOST_LUCKY_COINS' AND "metric" = 'HOST_LUCKY_COINS';
