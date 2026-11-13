-- CP-016 part C (D99): the live schedule (CONVENTIONS §10.16). A host announces upcoming lives in
-- `live_schedule_slots`; 15 minutes before the start the live sweeper sends `LIVE_SCHEDULED_SOON`
-- to the host's followers (once: `reminded_at`) as notifications pointing at the slot, deleted
-- with it. `notification_settings.lives` switches the reminders off. The runtime role gets DML
-- through the default privileges (20261016120000_runtime_role_grants), so no GRANT here.

-- AlterEnum
ALTER TYPE "notification_type" ADD VALUE 'LIVE_SCHEDULED_SOON';

-- AlterTable
ALTER TABLE "notification_settings" ADD COLUMN     "lives" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "live_schedule_id" UUID;

-- CreateTable
CREATE TABLE "live_schedule_slots" (
    "id" UUID NOT NULL,
    "host_user_id" UUID NOT NULL,
    "title" VARCHAR(60) NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "reminded_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_schedule_slots_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "live_schedule_slots_host_starts_idx" ON "live_schedule_slots"("host_user_id", "starts_at");

-- CreateIndex
CREATE INDEX "live_schedule_slots_due_idx" ON "live_schedule_slots"("starts_at") WHERE (reminded_at IS NULL);

-- CreateIndex
CREATE INDEX "notifications_live_schedule_id_idx" ON "notifications"("live_schedule_id");

-- AddForeignKey
ALTER TABLE "live_schedule_slots" ADD CONSTRAINT "live_schedule_slots_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_live_schedule_id_fkey" FOREIGN KEY ("live_schedule_id") REFERENCES "live_schedule_slots"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Checks (CONVENTIONS §10.16): the title as normalized (1–60 code points); a reminder points at
-- its slot only.
ALTER TABLE "live_schedule_slots" ADD CONSTRAINT "live_schedule_slots_title" CHECK (char_length(title) BETWEEN 1 AND 60);
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_live_schedule_alone" CHECK (
  live_schedule_id IS NULL OR (post_id IS NULL AND comment_id IS NULL AND story_id IS NULL));
