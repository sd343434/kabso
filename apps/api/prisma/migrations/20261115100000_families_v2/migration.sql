-- v1.25-live (CP-022, owner D116, 2026-10-26): families v2, CONVENTIONS §10.25. Owned by the
-- `families` module (presence: `users`). The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group), so this migration contains no GRANT.
--
-- * `users.last_active_at`: the last authenticated request (written at most once a minute); a
--   member is "online" within 5 minutes. `privacy_settings.show_activity_status` hides it.
-- * `families.cover_media_id` / `cover_url` / `tagline`: the family page's cover and tagline.
-- * `family_points_ledger_created_idx`: the monthly family ranking sums a window across families
--   (as `cp_points_ledger_created_idx` for the CP ranking).
-- * `family_chat_messages`, `family_chat_mutes`: the family chat; reports may target a message.

-- AlterTable
ALTER TABLE "families" ADD COLUMN     "cover_media_id" UUID,
ADD COLUMN     "cover_url" VARCHAR(512),
ADD COLUMN     "tagline" VARCHAR(60);

-- AlterTable
ALTER TABLE "privacy_settings" ADD COLUMN     "show_activity_status" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "target_family_chat_message_id" UUID;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "last_active_at" TIMESTAMPTZ(3);

-- CreateTable
CREATE TABLE "family_chat_messages" (
    "id" UUID NOT NULL,
    "family_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "text" VARCHAR(200) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),
    "deleted_by_id" UUID,

    CONSTRAINT "family_chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_chat_mutes" (
    "family_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "muted_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_chat_mutes_pkey" PRIMARY KEY ("family_id","user_id")
);

-- CreateIndex
CREATE INDEX "family_chat_messages_family_idx" ON "family_chat_messages"("family_id", "created_at", "id");

-- CreateIndex
CREATE INDEX "family_chat_messages_deleted_by_idx" ON "family_chat_messages"("deleted_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "family_chat_messages_client_once" ON "family_chat_messages"("author_id", "client_id");

-- CreateIndex
CREATE INDEX "family_chat_mutes_user_idx" ON "family_chat_mutes"("user_id");

-- CreateIndex
CREATE INDEX "family_chat_mutes_muted_by_idx" ON "family_chat_mutes"("muted_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "families_cover_media_id_key" ON "families"("cover_media_id");

-- CreateIndex
CREATE INDEX "family_points_ledger_created_idx" ON "family_points_ledger"("created_at", "family_id");

-- CreateIndex
CREATE INDEX "reports_target_family_chat_message_idx" ON "reports"("target_family_chat_message_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_family_chat_message_once" ON "reports"("reporter_id", "target_family_chat_message_id") WHERE (status = 'OPEN'::report_status AND target_family_chat_message_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_family_chat_message_id_fkey" FOREIGN KEY ("target_family_chat_message_id") REFERENCES "family_chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "families" ADD CONSTRAINT "families_cover_media_id_fkey" FOREIGN KEY ("cover_media_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_messages" ADD CONSTRAINT "family_chat_messages_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_messages" ADD CONSTRAINT "family_chat_messages_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_messages" ADD CONSTRAINT "family_chat_messages_deleted_by_id_fkey" FOREIGN KEY ("deleted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_mutes" ADD CONSTRAINT "family_chat_mutes_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_mutes" ADD CONSTRAINT "family_chat_mutes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_chat_mutes" ADD CONSTRAINT "family_chat_mutes_muted_by_id_fkey" FOREIGN KEY ("muted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "families" ADD CONSTRAINT "families_tagline_length" CHECK (tagline IS NULL OR char_length(tagline) BETWEEN 1 AND 60);
ALTER TABLE "family_chat_messages" ADD CONSTRAINT "family_chat_messages_text_length" CHECK (char_length(text) BETWEEN 1 AND 200);

-- Reports: exactly one target, the one the type names (replaces the rule of
-- 20261113100000_cp_space; FAMILY_CHAT_MESSAGE compared as text, the value comes from the previous
-- migration).
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
               target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id) = 1
  AND (
    (target_type::text = 'POST' AND target_post_id IS NOT NULL)
    OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL)
    OR (target_type::text = 'USER' AND target_user_id IS NOT NULL)
    OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL)
    OR (target_type::text = 'LIVE_ROOM' AND target_live_room_id IS NOT NULL)
    OR (target_type::text = 'LIVE_CHAT_MESSAGE' AND target_live_chat_message_id IS NOT NULL)
    OR (target_type::text = 'CP_CONFESSION' AND target_cp_confession_id IS NOT NULL)
    OR (target_type::text = 'FAMILY_CHAT_MESSAGE' AND target_family_chat_message_id IS NOT NULL)));

-- Media: the family cover kind (processed like a post image, at most 1 080 px on the long side,
-- §11.1).
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER'));
