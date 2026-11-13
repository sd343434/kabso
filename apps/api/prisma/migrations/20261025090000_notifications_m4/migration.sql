-- CP-009 (D92, CP-006 M4): in-app notifications. Tables notifications, notification_actors,
-- notification_settings. The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants).

-- CreateEnum
CREATE TYPE "notification_type" AS ENUM ('LIKE_POST', 'LIKE_COMMENT', 'COMMENT', 'REPLY', 'MENTION', 'FOLLOW', 'REPOST', 'POST_PUBLISHED', 'CONTENT_REMOVED');

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "recipient_id" UUID NOT NULL,
    "type" "notification_type" NOT NULL,
    "post_id" UUID,
    "comment_id" UUID,
    "story_id" UUID,
    "group_key" VARCHAR(80),
    "read_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_actors" (
    "notification_id" UUID NOT NULL,
    "actor_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_actors_pkey" PRIMARY KEY ("notification_id","actor_id")
);

-- CreateTable
CREATE TABLE "notification_settings" (
    "user_id" UUID NOT NULL,
    "likes" BOOLEAN NOT NULL DEFAULT true,
    "comments" BOOLEAN NOT NULL DEFAULT true,
    "mentions" BOOLEAN NOT NULL DEFAULT true,
    "follows" BOOLEAN NOT NULL DEFAULT true,
    "reposts" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "notification_settings_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "notifications_recipient_updated_idx" ON "notifications"("recipient_id", "updated_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "notifications_unread_group_idx" ON "notifications"("recipient_id", "group_key") WHERE (read_at IS NULL AND group_key IS NOT NULL);

-- CreateIndex
CREATE INDEX "notifications_unread_idx" ON "notifications"("recipient_id") WHERE (read_at IS NULL);

-- CreateIndex
CREATE INDEX "notifications_updated_idx" ON "notifications"("updated_at");

-- CreateIndex
CREATE INDEX "notifications_post_id_idx" ON "notifications"("post_id");

-- CreateIndex
CREATE INDEX "notifications_comment_id_idx" ON "notifications"("comment_id");

-- CreateIndex
CREATE INDEX "notifications_story_id_idx" ON "notifications"("story_id");

-- CreateIndex
CREATE INDEX "notification_actors_actor_id_idx" ON "notification_actors"("actor_id");

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_actors" ADD CONSTRAINT "notification_actors_notification_id_fkey" FOREIGN KEY ("notification_id") REFERENCES "notifications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_actors" ADD CONSTRAINT "notification_actors_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_settings" ADD CONSTRAINT "notification_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A FOLLOW targets its actor; otherwise at most one of post / comment / story, and a COMMENT
-- target also names its post (CONVENTIONS §11.10).
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_one_target" CHECK (
  (story_id IS NULL OR (post_id IS NULL AND comment_id IS NULL))
  AND (comment_id IS NULL OR post_id IS NOT NULL));
