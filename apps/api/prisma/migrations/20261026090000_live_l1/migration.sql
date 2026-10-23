-- CP-010 (D93, Live L1): live video. The hosting permission (live_hosts), who is connected to a
-- room's media session (live_room_viewers), the room's guests switch, LIVE_ROOM reports and the
-- LIVE_HOSTS admin permission. The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants).

-- CreateEnum
CREATE TYPE "live_host_source" AS ENUM ('ADMIN', 'AGENCY', 'IDENTITY');

-- AlterEnum
ALTER TYPE "admin_permission" ADD VALUE 'LIVE_HOSTS';

-- AlterEnum
ALTER TYPE "report_target_type" ADD VALUE 'LIVE_ROOM';

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN     "allow_guests" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "target_live_room_id" UUID;

-- CreateTable
CREATE TABLE "live_hosts" (
    "user_id" UUID NOT NULL,
    "source" "live_host_source" NOT NULL,
    "granted_by_id" UUID,
    "granted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_hosts_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "live_room_viewers" (
    "room_id" UUID NOT NULL,
    "identity" VARCHAR(80) NOT NULL,
    "user_id" UUID,
    "guest_id" UUID,
    "joined_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_viewers_pkey" PRIMARY KEY ("room_id","identity")
);

-- CreateIndex
CREATE INDEX "live_hosts_granted_by_idx" ON "live_hosts"("granted_by_id");

-- CreateIndex
CREATE INDEX "live_room_viewers_room_joined_idx" ON "live_room_viewers"("room_id", "joined_at" DESC, "identity" DESC);

-- CreateIndex
CREATE INDEX "live_room_viewers_user_idx" ON "live_room_viewers"("user_id");

-- CreateIndex
CREATE INDEX "reports_target_live_room_idx" ON "reports"("target_live_room_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_live_room_once" ON "reports"("reporter_id", "target_live_room_id") WHERE (status = 'OPEN'::report_status AND target_live_room_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_granted_by_id_fkey" FOREIGN KEY ("granted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_viewers" ADD CONSTRAINT "live_room_viewers_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_viewers" ADD CONSTRAINT "live_room_viewers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_live_room_id_fkey" FOREIGN KEY ("target_live_room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A report has exactly one target, now including a live room.
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (target_type::text = 'POST' AND target_post_id IS NOT NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL)
  OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL AND target_post_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL)
  OR (target_type::text = 'USER' AND target_user_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL)
  OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_live_room_id IS NULL)
  OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL));

-- A viewer is either an account (identity = its id) or a guest (identity = 'guest:' || its id).
ALTER TABLE "live_room_viewers" ADD CONSTRAINT "live_room_viewers_one_kind" CHECK (
  (user_id IS NOT NULL AND guest_id IS NULL AND identity = user_id::text)
  OR (guest_id IS NOT NULL AND user_id IS NULL AND identity = 'guest:' || guest_id::text));
