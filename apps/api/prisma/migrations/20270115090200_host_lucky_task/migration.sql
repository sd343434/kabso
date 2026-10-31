-- v1.44-live (D199, CONVENTIONS §10.62; owner «تارجت»): the host's daily lucky target «استقبل هدايا الحظ» — the
-- coin value of the lucky gifts received (metric HOST_LUCKY_COINS: sends with a stored lucky draw), one
-- target and reward per level band like the weekly host tasks (the row mirrors band 4). Owner-confirmable
-- values; the daily and monthly cherry caps are unchanged. A fixed daily task (not in the pool), so the
-- seeded daily picks of D176 do not move. `task-admin` can change or switch it off.
-- The new metric.
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS',
                   'GIFT_COINS_SENT', 'HOST_LUCKY_COINS')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);

-- A fixed task with per-band values may now be DAILY too (D188's follow-up allowed WEEKLY only).
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_pool_shape";
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_pool_shape" CHECK (
    (NOT pool AND pool_group IS NULL
        AND ((cardinality(band_targets) = 0 AND cardinality(band_rewards) = 0)
             OR (period IN ('DAILY', 'WEEKLY') AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
                 AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
                 AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards))))
    OR (pool AND period = 'DAILY'
        AND pool_group IN ('WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST')
        AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
        AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
        AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards)));

INSERT INTO "task_definitions" ("code", "period", "metric", "target", "reward_cherries", "audience", "name_ar",
                                "name_en", "sort_order", "band_targets", "band_rewards")
VALUES ('HOST_LUCKY_COINS', 'DAILY', 'HOST_LUCKY_COINS', 200000, 6000, 'HOSTS', 'استقبل هدايا الحظ (بالعملات)',
        'Receive lucky gifts (coins)', 70, ARRAY[20000, 50000, 100000, 200000], ARRAY[1000, 2000, 4000, 6000])
ON CONFLICT ("code") DO NOTHING;
