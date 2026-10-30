-- v1.53-social (D184, owner 2026-10-30): the Task Center's rewards are paid in cherries (CONVENTIONS
-- §10.41.3). The new cherry ledger reason goes in a migration of its own (a value added by
-- ALTER TYPE … ADD VALUE cannot be used in the same transaction).
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'TASK_REWARD';

-- What a task claim paid in: COINS (every claim before this change) or CHERRIES.
CREATE TYPE "task_reward_currency" AS ENUM ('COINS', 'CHERRIES');
