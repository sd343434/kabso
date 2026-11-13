-- v1.44-social (D166, owner 2026-10-29): the Me hub's programs — Task Center, Event Center, SVIP and the
-- recharge packages (CP-024, approved with defaults). The new enum values and types go first, in a
-- migration of their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in
-- the same transaction; the same split as 20261205090000_live_boosts_enums).

-- Wallet ledger reasons (credits): a claimed task, a daily check-in, an event prize.
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'TASK_REWARD';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CHECK_IN_REWARD';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'EVENT_PRIZE';

-- How often a task resets (a day or an ISO week in LIVE_RANKINGS_TIME_ZONE).
CREATE TYPE "task_period" AS ENUM ('DAILY', 'WEEKLY');

-- Who a task or an event is for.
CREATE TYPE "program_audience" AS ENUM ('EVERYONE', 'HOSTS');

-- What an event's leaderboard counts (the tables the boards and the data center already read).
CREATE TYPE "event_metric" AS ENUM ('GIFT_COINS_RECEIVED', 'GIFT_COINS_SENT', 'LIVE_MINUTES', 'TAPS_RECEIVED', 'NEW_FOLLOWERS');
