-- v1.87-live (D314, CONVENTIONS §10.119; owner: the boards' periods «هذه الساعة / اليوم / هذا الأسبوع / هذا الشهر / هذه
-- السنة»): the popularity points per host and LOCAL month, written with the hourly row, so a month or a year sums at
-- most 12 rows per host (the hourly rows are kept 15 days only). No GRANT: default privileges.
CREATE TABLE "live_host_points_monthly" (
    "host_user_id" UUID NOT NULL,
    "month_start" TIMESTAMPTZ(3) NOT NULL,
    "points" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "live_host_points_monthly_pkey" PRIMARY KEY ("host_user_id", "month_start"),
    CONSTRAINT "live_host_points_monthly_points" CHECK ("points" >= 0)
);
CREATE INDEX "live_host_points_monthly_month_idx" ON "live_host_points_monthly" ("month_start");
ALTER TABLE "live_host_points_monthly" ADD CONSTRAINT "live_host_points_monthly_host_user_id_fkey"
    FOREIGN KEY ("host_user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill from the hourly rows still kept (the last 15 days): older points are gone, so a month or year board starts
-- from what the hourly table holds. The month is taken in LIVE_RANKINGS_TIME_ZONE as the API computes it; the
-- migration cannot read the API's setting, so it uses the default `UTC` (DEPLOYMENT §5.92: a server with
-- another zone re-runs this backfill with its zone).
INSERT INTO "live_host_points_monthly" ("host_user_id", "month_start", "points")
SELECT host_user_id,
       (date_trunc('month', hour_start AT TIME ZONE 'UTC') AT TIME ZONE 'UTC') AS month_start,
       SUM(points)
  FROM "live_host_points_hourly"
 GROUP BY 1, 2
HAVING SUM(points) > 0
ON CONFLICT DO NOTHING;
