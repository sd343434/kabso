-- CP-013 (D96): live room chat. Messages (`live_chat_messages`: one row per sent message, the
-- sender's idempotency key, the author's role at sending, soft delete), chat mutes of one live
-- (`live_chat_mutes`), the host's chat switch (`live_rooms.chat_enabled`, on for every room) and
-- LIVE_CHAT_MESSAGE reports. The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants), so this migration contains no GRANT.

-- CreateEnum
CREATE TYPE "live_chat_author_role" AS ENUM ('HOST', 'MODERATOR', 'SPEAKER', 'VIEWER');

-- AlterEnum
ALTER TYPE "report_target_type" ADD VALUE 'LIVE_CHAT_MESSAGE';

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN     "chat_enabled" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "target_live_chat_message_id" UUID;

-- CreateTable
CREATE TABLE "live_chat_messages" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "text" VARCHAR(200) NOT NULL,
    "author_role" "live_chat_author_role" NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),
    "deleted_by_id" UUID,

    CONSTRAINT "live_chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_chat_mutes" (
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "muted_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_chat_mutes_pkey" PRIMARY KEY ("room_id","user_id")
);

-- CreateIndex (the last 50 messages of a room; the retention sweep by room)
CREATE INDEX "live_chat_messages_room_created_idx" ON "live_chat_messages"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "live_chat_messages_deleted_by_idx" ON "live_chat_messages"("deleted_by_id");

-- CreateIndex (clientId is unique per sender: an idempotent retry; also the user_id FK index)
CREATE UNIQUE INDEX "live_chat_messages_client_once" ON "live_chat_messages"("user_id", "client_id");

-- CreateIndex
CREATE INDEX "live_chat_mutes_user_idx" ON "live_chat_mutes"("user_id");

-- CreateIndex
CREATE INDEX "live_chat_mutes_muted_by_idx" ON "live_chat_mutes"("muted_by_id");

-- CreateIndex
CREATE INDEX "reports_target_live_chat_message_idx" ON "reports"("target_live_chat_message_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_live_chat_message_once" ON "reports"("reporter_id", "target_live_chat_message_id") WHERE (status = 'OPEN'::report_status AND target_live_chat_message_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_deleted_by_id_fkey" FOREIGN KEY ("deleted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_chat_mutes" ADD CONSTRAINT "live_chat_mutes_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_chat_mutes" ADD CONSTRAINT "live_chat_mutes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_chat_mutes" ADD CONSTRAINT "live_chat_mutes_muted_by_id_fkey" FOREIGN KEY ("muted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_live_chat_message_id_fkey" FOREIGN KEY ("target_live_chat_message_id") REFERENCES "live_chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- 1–200 code points (CONVENTIONS §10.11; char_length counts code points). A deleter is only
-- recorded on a deleted message (it becomes NULL when that account is removed).
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_text_length" CHECK (char_length(text) BETWEEN 1 AND 200);
ALTER TABLE "live_chat_messages" ADD CONSTRAINT "live_chat_messages_deleted_state" CHECK (deleted_by_id IS NULL OR deleted_at IS NOT NULL);

-- Nobody mutes themselves (the host is never muted; a moderator never mutes a moderator).
ALTER TABLE "live_chat_mutes" ADD CONSTRAINT "live_chat_mutes_not_self" CHECK (muted_by_id IS DISTINCT FROM user_id);

-- A report has exactly one target, now including a live chat message.
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (target_type::text = 'POST' AND target_post_id IS NOT NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL AND target_live_chat_message_id IS NULL)
  OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL AND target_post_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL AND target_live_chat_message_id IS NULL)
  OR (target_type::text = 'USER' AND target_user_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL AND target_live_chat_message_id IS NULL)
  OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_live_room_id IS NULL AND target_live_chat_message_id IS NULL)
  OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_chat_message_id IS NULL)
  OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL AND target_live_room_id IS NULL));
