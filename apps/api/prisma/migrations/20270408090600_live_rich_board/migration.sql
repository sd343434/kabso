-- v1.90-live (D320, CONVENTIONS §10.124; owner: «الأغنى» — users ranked by the coins they SENT as gifts, the five
-- periods): the coin value of every gift a user sent (a live, a direct conversation, a CP gift; lucky, custom and bag
-- sends at their coin value), per UTC hour (kept 15 days) and per local month (kept 400 days), written in the send's
-- transaction and taken back by a reversal. No GRANT: default privileges.
CREATE TABLE "gift_coins_sent_hourly" (
    "user_id" UUID NOT NULL,
    "hour_start" TIMESTAMPTZ(3) NOT NULL,
    "coins" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "gift_coins_sent_hourly_pkey" PRIMARY KEY ("user_id", "hour_start"),
    CONSTRAINT "gift_coins_sent_hourly_coins" CHECK ("coins" >= 0)
);
CREATE INDEX "gift_coins_sent_hourly_hour_idx" ON "gift_coins_sent_hourly" ("hour_start");
ALTER TABLE "gift_coins_sent_hourly" ADD CONSTRAINT "gift_coins_sent_hourly_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "gift_coins_sent_monthly" (
    "user_id" UUID NOT NULL,
    "month_start" TIMESTAMPTZ(3) NOT NULL,
    "coins" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "gift_coins_sent_monthly_pkey" PRIMARY KEY ("user_id", "month_start"),
    CONSTRAINT "gift_coins_sent_monthly_coins" CHECK ("coins" >= 0)
);
CREATE INDEX "gift_coins_sent_monthly_month_idx" ON "gift_coins_sent_monthly" ("month_start");
ALTER TABLE "gift_coins_sent_monthly" ADD CONSTRAINT "gift_coins_sent_monthly_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill from the sends themselves (kept): live and direct-conversation gifts not reversed (no GIFT_REVERSAL row in
-- the cherry ledger) and CP gifts — the hourly rows for the last 15 days, the monthly rows for the last 400 days. The
-- month is taken in UTC (a migration cannot read LIVE_RANKINGS_TIME_ZONE; DEPLOYMENT §5.96 re-runs it for another zone).
CREATE TEMP TABLE "d320_sends" AS
SELECT g.sender_id AS user_id, g.created_at, g.total_coins AS coins
  FROM "live_gifts" g
 WHERE g.total_coins > 0
   AND g.created_at >= now() - interval '400 days'
   AND NOT EXISTS (SELECT 1 FROM "cherry_ledger" c
                    WHERE c.reference_id = g.id::text AND c.reason = 'GIFT_REVERSAL')
UNION ALL
SELECT p.sender_id, p.created_at, p.amount::bigint
  FROM "cp_gifts" p
 WHERE p.amount > 0 AND p.created_at >= now() - interval '400 days';

INSERT INTO "gift_coins_sent_hourly" ("user_id", "hour_start", "coins")
SELECT user_id, date_trunc('hour', created_at), SUM(coins)
  FROM "d320_sends"
 WHERE created_at >= now() - interval '15 days'
 GROUP BY 1, 2;

INSERT INTO "gift_coins_sent_monthly" ("user_id", "month_start", "coins")
SELECT user_id, (date_trunc('month', created_at AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'), SUM(coins)
  FROM "d320_sends"
 GROUP BY 1, 2;

DROP TABLE "d320_sends";
