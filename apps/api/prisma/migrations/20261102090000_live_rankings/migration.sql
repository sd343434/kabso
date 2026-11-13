-- CP-016 part A (D99): the popularity boards. `live_host_points_hourly` holds the points a
-- host's lives received in each UTC hour (written in the same transaction as the taps that
-- counted); the boards sum it over the current hour, day and week. Rows older than 15 days are
-- removed by the live sweeper. The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants), so this migration contains no GRANT.

-- CreateTable
CREATE TABLE "live_host_points_hourly" (
    "host_user_id" UUID NOT NULL,
    "hour_start" TIMESTAMPTZ(3) NOT NULL,
    "points" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "live_host_points_hourly_pkey" PRIMARY KEY ("host_user_id","hour_start")
);

-- CreateIndex
CREATE INDEX "live_host_points_hourly_hour_idx" ON "live_host_points_hourly"("hour_start");

-- AddForeignKey
ALTER TABLE "live_host_points_hourly" ADD CONSTRAINT "live_host_points_hourly_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Checks (CONVENTIONS §10.15).
ALTER TABLE "live_host_points_hourly" ADD CONSTRAINT "live_host_points_hourly_points" CHECK (points >= 0);
ALTER TABLE "live_host_points_hourly" ADD CONSTRAINT "live_host_points_hourly_on_the_hour" CHECK (hour_start = date_trunc('hour', hour_start));
