-- v1.103-social (D339, owner 2026-11-09: «الدردشات، طلبات المراسلة، المؤرشفة، رسائل جماعية»): archived chats and group
-- messages, CONVENTIONS §10.132 and §10.133. Owned by the `messages` module. The runtime role gets DML through the
-- default privileges (20261016130000_per_database_runtime_group), so this migration contains no GRANT.
--
-- * `dm_participants.archived_at`: the caller archived the conversation «المؤرشفة» (per user; a message from the peer
--   clears it). Additive: a nullable column, existing rows not archived.
-- * `dm_groups` (name, photo, the creator and the create's idempotency key, ACTIVE / REMOVED by moderation),
--   `dm_group_members` (role, mute, archive, the read pointer, joined time) and `dm_group_messages`
--   (TEXT / IMAGE / VOICE / EMOJI; hard-deleted by the DM sweeper at `expires_at`, 24 h after sending, with the file).
-- * `reports.target_dm_group_id` (no foreign key, like `target_dm_message_id`; the report keeps `dm_snapshot`).

-- AlterTable
ALTER TABLE "dm_participants" ADD COLUMN "archived_at" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "reports" ADD COLUMN "target_dm_group_id" UUID;

-- CreateEnum
CREATE TYPE "dm_group_role" AS ENUM ('ADMIN', 'MEMBER');

-- CreateEnum
CREATE TYPE "dm_group_status" AS ENUM ('ACTIVE', 'REMOVED');

-- CreateTable
CREATE TABLE "dm_groups" (
    "id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "photo_media_id" UUID,
    "created_by_id" UUID,
    "client_id" UUID NOT NULL,
    "status" "dm_group_status" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_message_at" TIMESTAMPTZ(3) NOT NULL,
    "removed_at" TIMESTAMPTZ(3),

    CONSTRAINT "dm_groups_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "dm_groups_name" CHECK (char_length(btrim("name")) BETWEEN 1 AND 50),
    CONSTRAINT "dm_groups_removed" CHECK (("status" = 'REMOVED') = ("removed_at" IS NOT NULL))
);

-- CreateTable
CREATE TABLE "dm_group_members" (
    "group_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "dm_group_role" NOT NULL DEFAULT 'MEMBER',
    "muted" BOOLEAN NOT NULL DEFAULT false,
    "archived_at" TIMESTAMPTZ(3),
    "read_at" TIMESTAMPTZ(3),
    "joined_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dm_group_members_pkey" PRIMARY KEY ("group_id","user_id")
);

-- CreateTable
CREATE TABLE "dm_group_messages" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "kind" "dm_message_kind" NOT NULL,
    "text" VARCHAR(1000),
    "token" VARCHAR(64),
    "media_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "dm_group_messages_pkey" PRIMARY KEY ("id"),
    -- Exactly the column of its kind; no gifts in a group (D339).
    CONSTRAINT "dm_group_messages_content" CHECK (
        ("kind" = 'TEXT' AND "text" IS NOT NULL AND "token" IS NULL)
        OR ("kind" = 'EMOJI' AND "token" IS NOT NULL AND "text" IS NULL)
        OR ("kind" IN ('IMAGE', 'VOICE') AND "text" IS NULL AND "token" IS NULL)
    )
);

-- CreateIndex
CREATE UNIQUE INDEX "dm_groups_photo_media_id_key" ON "dm_groups"("photo_media_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_groups_client_once" ON "dm_groups"("created_by_id", "client_id");

-- CreateIndex
CREATE INDEX "dm_group_members_user_idx" ON "dm_group_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "dm_group_messages_media_id_key" ON "dm_group_messages"("media_id");

-- CreateIndex
CREATE INDEX "dm_group_messages_group_idx" ON "dm_group_messages"("group_id", "created_at", "id");

-- CreateIndex
CREATE INDEX "dm_group_messages_expires_idx" ON "dm_group_messages"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "dm_group_messages_client_once" ON "dm_group_messages"("sender_id", "client_id");

-- CreateIndex
CREATE INDEX "reports_target_dm_group_idx" ON "reports"("target_dm_group_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_dm_group_once" ON "reports"("reporter_id", "target_dm_group_id") WHERE (status = 'OPEN'::report_status AND target_dm_group_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "dm_groups" ADD CONSTRAINT "dm_groups_photo_media_id_fkey" FOREIGN KEY ("photo_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_groups" ADD CONSTRAINT "dm_groups_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_group_members" ADD CONSTRAINT "dm_group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "dm_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_group_members" ADD CONSTRAINT "dm_group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_group_messages" ADD CONSTRAINT "dm_group_messages_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "dm_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_group_messages" ADD CONSTRAINT "dm_group_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dm_group_messages" ADD CONSTRAINT "dm_group_messages_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- A group's photo is a media asset of its own kind (CHECK from 20270406090000_media_kind_checks_merge plus
-- DM_GROUP_PHOTO; it has no duration and no poster, which the other two CHECKs already require of unlisted kinds).
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO', 'BANNER_VIDEO', 'DM_GROUP_PHOTO'));

-- A DM_GROUP report names its group and keeps a snapshot (CHECK from 20270110110000_account_deletion_retention plus
-- `target_dm_group_id`; a group report is never put under an account's legal hold).
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (
    num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
                 target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
                 target_dm_message_id, target_profile_link_id, target_dm_group_id) = 1
    AND (
      (target_type::text = 'POST' AND target_post_id IS NOT NULL)
      OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL)
      OR (target_type::text = 'USER' AND target_user_id IS NOT NULL)
      OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL)
      OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL)
      OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL)
      OR (target_type::text = 'CP_CONFESSION' AND target_cp_confession_id IS NOT NULL)
      OR (target_type::text = 'FAMILY_CHAT_MESSAGE' AND target_family_chat_message_id IS NOT NULL)
      OR (target_type::text = 'DM_MESSAGE' AND target_dm_message_id IS NOT NULL AND dm_snapshot IS NOT NULL)
      OR (target_type::text = 'PROFILE_LINK' AND target_profile_link_id IS NOT NULL AND link_snapshot IS NOT NULL)
      OR (target_type::text = 'DM_GROUP' AND target_dm_group_id IS NOT NULL AND dm_snapshot IS NOT NULL)))
  OR (
    legal_hold_id IS NOT NULL
    AND target_type::text IN ('POST', 'COMMENT', 'STORY', 'LIVE_CHAT_MESSAGE', 'CP_CONFESSION',
                             'FAMILY_CHAT_MESSAGE')
    AND num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
                     target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
                     target_dm_message_id, target_profile_link_id, target_dm_group_id) = 0));
