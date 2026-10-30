-- v1.53-social (D184, owner 2026-10-30): the Task Center's daily tasks (and the weekly host tasks) pay
-- cherries instead of coins, at the same value — 1 coin = 10 cherries, so every stored reward is ×10
-- (CONVENTIONS §10.41.3). A reward is credited through the cherry ledger (reason TASK_REWARD, added by
-- 20261231100000_task_cherries_enums) in the claim's transaction. Claims made before this migration keep
-- what they paid (coins, `reward_currency` COINS; their wallet_ledger rows are untouched). The check-in
-- keeps paying coins. The runtime role gets DML through the default privileges: no GRANT here.

-- ---- Task definitions: the reward in cherries ----------------------------------------------------
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_shape";
ALTER TABLE "task_definitions" DROP CONSTRAINT "task_definitions_pool_shape";
ALTER TABLE "task_definitions" RENAME COLUMN "reward_coins" TO "reward_cherries";
UPDATE "task_definitions"
   SET "reward_cherries" = "reward_cherries" * 10,
       "band_rewards" = ARRAY(SELECT r * 10 FROM unnest("band_rewards") WITH ORDINALITY AS t(r, i) ORDER BY i),
       "updated_at" = CURRENT_TIMESTAMP;
-- Larger bounds (owner: rewards may grow a lot): up to 1 000 000 000 cherries a task.
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_shape" CHECK (
    code ~ '^[A-Z][A-Z0-9_]{1,39}$'
    AND metric IN ('WATCH_LIVES', 'FOLLOWS', 'LIVE_CHAT_MESSAGES', 'GIFT_SENDS', 'HOST_LIVE_MINUTES', 'HOST_GIFT_COINS',
                   'WATCH_MINUTES', 'AUDIO_ROOMS', 'LIVE_TAPS', 'NEW_HOST_GIFTS', 'POSTS', 'REELS', 'STORIES',
                   'POST_COMMENTS', 'DM_FRIENDS', 'DM_VOICE_MESSAGES', 'HOST_GIFTS_RECEIVED', 'HOST_GUESTS')
    AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND char_length(name_ar) BETWEEN 1 AND 80 AND char_length(name_en) BETWEEN 1 AND 80);
ALTER TABLE "task_definitions" ADD CONSTRAINT "task_definitions_pool_shape" CHECK (
    (NOT pool AND pool_group IS NULL AND cardinality(band_targets) = 0 AND cardinality(band_rewards) = 0)
    OR (pool AND period = 'DAILY'
        AND pool_group IN ('WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST')
        AND cardinality(band_targets) = 4 AND cardinality(band_rewards) = 4
        AND 0 <= ALL (band_targets) AND 1000000000 >= ALL (band_targets)
        AND 0 <= ALL (band_rewards) AND 1000000000 >= ALL (band_rewards)));

-- ---- Assignments: a day's offered reward in cherries (offers only; nothing was paid from them) ------
ALTER TABLE "task_assignments" DROP CONSTRAINT "task_assignments_shape";
ALTER TABLE "task_assignments" RENAME COLUMN "reward_coins" TO "reward_cherries";
UPDATE "task_assignments" SET "reward_cherries" = "reward_cherries" * 10;
ALTER TABLE "task_assignments" ADD CONSTRAINT "task_assignments_shape" CHECK (
    band BETWEEN 1 AND 4 AND target BETWEEN 1 AND 1000000000 AND reward_cherries BETWEEN 1 AND 1000000000
    AND position BETWEEN 0 AND 11);

-- ---- Claims: what was paid, in its currency (history untouched: existing claims are COINS) -----------
ALTER TABLE "task_claims" DROP CONSTRAINT "task_claims_reward_range";
ALTER TABLE "task_claims" RENAME COLUMN "reward_coins" TO "reward_amount";
ALTER TABLE "task_claims" ADD COLUMN "reward_currency" "task_reward_currency" NOT NULL DEFAULT 'COINS';
ALTER TABLE "task_claims" ALTER COLUMN "reward_currency" DROP DEFAULT;
ALTER TABLE "task_claims" ADD CONSTRAINT "task_claims_reward_range" CHECK (
    (reward_currency = 'COINS' AND reward_amount BETWEEN 0 AND 1000000)
    OR (reward_currency = 'CHERRIES' AND reward_amount BETWEEN 0 AND 1000000000));

-- ---- The cherry ledger: TASK_REWARD is a credit ------------------------------------------------------
ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
ALTER TABLE "cherry_ledger" ADD CONSTRAINT "cherry_ledger_reason_sign" CHECK (
  (reason IN ('GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION', 'WITHDRAWAL_REFUND', 'TASK_REWARD')
      AND delta > 0)
  OR (reason IN ('GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL', 'WITHDRAWAL_HOLD')
      AND delta < 0));

-- The withdrawable balance reads the caller's TASK_REWARD and gift sums (§10.46.1).
CREATE INDEX "cherry_ledger_user_reason_idx" ON "cherry_ledger"("user_id", "reason");
