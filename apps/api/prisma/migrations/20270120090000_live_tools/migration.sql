-- v1.45-live (D201, CONVENTIONS §10.63; owner: «كاميرتان», «موسيقى», «التسجيل»): the host's second camera
-- (a second device of the SAME account publishing into their SOLO video live as `cam2:<hostUserId>`,
-- paired with a short single-use code of which only the HMAC is kept) and the one-time music-rights
-- notice. The clip recorder stores nothing on the server. The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. New enum types only, one migration.

-- CreateEnum
CREATE TYPE "live_second_camera_end_reason" AS ENUM ('REVOKED', 'EXPIRED', 'LEFT', 'ROOM_ENDED', 'PK');

-- CreateEnum
CREATE TYPE "live_second_camera_main" AS ENUM ('HOST', 'SECOND');

-- CreateTable
CREATE TABLE "live_second_cameras" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "code_hash" CHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "redeemed_at" TIMESTAMPTZ(3),
    "connected_at" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "end_reason" "live_second_camera_end_reason",
    "main_feed" "live_second_camera_main" NOT NULL DEFAULT 'HOST',

    CONSTRAINT "live_second_cameras_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_music_rights_acceptances" (
    "user_id" UUID NOT NULL,
    "notice_version" SMALLINT NOT NULL,
    "accepted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_music_rights_acceptances_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "live_second_cameras_room_id_ended_at_idx" ON "live_second_cameras"("room_id", "ended_at");

-- CreateIndex
CREATE INDEX "live_second_cameras_host_user_id_code_hash_idx" ON "live_second_cameras"("host_user_id", "code_hash");

-- One open (not redeemed, not ended) code per live, and one second camera per live.
CREATE UNIQUE INDEX "live_second_cameras_one_code" ON "live_second_cameras"("room_id")
  WHERE "redeemed_at" IS NULL AND "ended_at" IS NULL;
CREATE UNIQUE INDEX "live_second_cameras_one_camera" ON "live_second_cameras"("room_id")
  WHERE "redeemed_at" IS NOT NULL AND "ended_at" IS NULL;

-- The row's life: code → redeemed → (connected) → ended; an ended row has its reason.
ALTER TABLE "live_second_cameras" ADD CONSTRAINT "live_second_cameras_state" CHECK (
  ("ended_at" IS NULL) = ("end_reason" IS NULL)
  AND ("connected_at" IS NULL OR "redeemed_at" IS NOT NULL)
  AND ("redeemed_at" IS NULL OR "redeemed_at" <= "expires_at")
  AND "expires_at" > "created_at"
  AND "code_hash" ~ '^[0-9a-f]{64}$');
ALTER TABLE "live_music_rights_acceptances" ADD CONSTRAINT "live_music_rights_acceptances_version"
  CHECK ("notice_version" >= 1);

-- AddForeignKey
ALTER TABLE "live_second_cameras" ADD CONSTRAINT "live_second_cameras_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_second_cameras" ADD CONSTRAINT "live_second_cameras_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_music_rights_acceptances" ADD CONSTRAINT "live_music_rights_acceptances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
