-- v1.60-live (D250, CONVENTIONS §10.91; owner 2026-11-02): live moderation from the panel «مراقبة البث» — staff watch
-- lives as hidden observers, see the reported lives, and end a live, ban the host from going live / suspend the
-- account for a while, or ban the host's devices, always with a reason the host is told. The runtime role gets DML
-- through the default privileges (20261016130000_per_database_runtime_group): no GRANT here. No backfill.

CREATE TYPE "live_moderation_kind" AS ENUM ('END', 'NO_LIVE', 'SUSPEND', 'DEVICE_BAN', 'DISMISS');

-- `LIVE_MODERATED` is only added here (never used in this transaction).
ALTER TYPE "notification_type" ADD VALUE 'LIVE_MODERATED';

-- The HMAC (D223's key) of the device key a session signed in with; NULL when none was sent (website, older app).
ALTER TABLE "sessions" ADD COLUMN "device_hash" CHAR(64);
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_device_hash_shape" CHECK (device_hash IS NULL OR device_hash ~ '^[0-9a-f]{64}$');
CREATE INDEX "sessions_device_hash_idx" ON "sessions"("device_hash") WHERE device_hash IS NOT NULL AND revoked_at IS NULL;

CREATE TABLE "live_moderation_actions" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "actor_id" UUID,
    "kind" "live_moderation_kind" NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "ends_at" TIMESTAMPTZ(3),
    "restriction_id" UUID,
    "ended_live" BOOLEAN NOT NULL DEFAULT false,
    "reports_closed" INTEGER NOT NULL DEFAULT 0,
    "devices_banned" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_moderation_actions_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "live_moderation_actions_room_idx" ON "live_moderation_actions"("room_id", "created_at" DESC);
CREATE INDEX "live_moderation_actions_host_idx" ON "live_moderation_actions"("host_user_id", "created_at" DESC);
ALTER TABLE "live_moderation_actions" ADD CONSTRAINT "live_moderation_actions_room_id_fkey"
  FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_moderation_actions" ADD CONSTRAINT "live_moderation_actions_host_user_id_fkey"
  FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_moderation_actions" ADD CONSTRAINT "live_moderation_actions_actor_id_fkey"
  FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "live_moderation_actions" ADD CONSTRAINT "live_moderation_actions_restriction_id_fkey"
  FOREIGN KEY ("restriction_id") REFERENCES "account_restrictions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "live_moderation_actions" ADD CONSTRAINT "live_moderation_actions_shape" CHECK (
  length(btrim(reason)) > 0 AND reports_closed >= 0 AND devices_banned >= 0
  AND (kind IN ('NO_LIVE', 'SUSPEND') OR restriction_id IS NULL)
  AND (kind IN ('NO_LIVE', 'SUSPEND', 'DEVICE_BAN') OR ends_at IS NULL));

CREATE TABLE "device_bans" (
    "id" UUID NOT NULL,
    "device_hash" CHAR(64) NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "source_user_id" UUID,
    "live_moderation_id" UUID,
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMPTZ(3),
    "lifted_at" TIMESTAMPTZ(3),
    "lifted_by_id" UUID,
    "lift_reason" VARCHAR(500),

    CONSTRAINT "device_bans_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "device_bans_open_idx" ON "device_bans"("device_hash") WHERE lifted_at IS NULL;
CREATE INDEX "device_bans_created_idx" ON "device_bans"("created_at" DESC);
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_source_user_id_fkey"
  FOREIGN KEY ("source_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_live_moderation_id_fkey"
  FOREIGN KEY ("live_moderation_id") REFERENCES "live_moderation_actions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_lifted_by_id_fkey"
  FOREIGN KEY ("lifted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "device_bans" ADD CONSTRAINT "device_bans_shape" CHECK (
  device_hash ~ '^[0-9a-f]{64}$' AND length(btrim(reason)) > 0
  AND (ends_at IS NULL OR ends_at > created_at)
  AND (lifted_at IS NULL OR lift_reason IS NOT NULL));

-- The notification of LIVE_MODERATED points at the action (deleted with it).
ALTER TABLE "notifications" ADD COLUMN "live_moderation_id" UUID;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_live_moderation_id_fkey"
  FOREIGN KEY ("live_moderation_id") REFERENCES "live_moderation_actions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX "notifications_live_moderation_idx" ON "notifications"("live_moderation_id") WHERE live_moderation_id IS NOT NULL;
