-- v1.47-social (D175, owner 2026-10-30), CONVENTIONS §10.43, §10.5, §10.6, §11.7.
--
-- 1. Gender (`user_gender`: MALE, FEMALE, UNDISCLOSED = «أفضّل عدم الذكر»), chosen at sign-up from now
--    on (`pending_registrations.gender`, required by the API; rows made before stay null and expire
--    within 2 h) and kept on `user_profiles.gender`; existing accounts stay null until they choose.
--    Private unless `show_gender` (default false).
-- 2. The account category under the name (`account_category`, optional).
-- 3. Profile links: at most 3 per user (`position` 0–2), https only (the API validates and normalises
--    them; the CHECKs are the backstop). `PATCH /me` replaces the whole set.
-- 4. Follow requests to private accounts (`follow_requests`); accepted → a `follows` row.
-- 5. Reports of a profile link: `reports.target_profile_link_id` (no foreign key: the owner may edit the
--    link away) and `reports.link_snapshot` (what the link was).
--
-- The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants), so
-- this migration contains no GRANT.

-- CreateEnum
CREATE TYPE "user_gender" AS ENUM ('MALE', 'FEMALE', 'UNDISCLOSED');

-- CreateEnum
CREATE TYPE "account_category" AS ENUM ('SINGER', 'MUSICIAN', 'POET', 'PRESENTER', 'GAMER', 'CONTENT_CREATOR', 'ATHLETE', 'ARTIST', 'BLOGGER', 'PUBLIC_FIGURE', 'OTHER');

-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "account_category" "account_category",
ADD COLUMN     "gender" "user_gender",
ADD COLUMN     "show_gender" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "pending_registrations" ADD COLUMN     "gender" "user_gender";

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "link_snapshot" JSONB,
ADD COLUMN     "target_profile_link_id" UUID;

-- CreateTable
CREATE TABLE "user_profile_links" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,
    "url" VARCHAR(500) NOT NULL,
    "label" VARCHAR(60),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_profile_links_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "follow_requests" (
    "requester_id" UUID NOT NULL,
    "target_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follow_requests_pkey" PRIMARY KEY ("requester_id","target_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_profile_links_user_position_key" ON "user_profile_links"("user_id", "position");

-- CreateIndex
CREATE INDEX "follow_requests_target_created_idx" ON "follow_requests"("target_id", "created_at" DESC, "requester_id" DESC);

-- CreateIndex
CREATE INDEX "reports_target_profile_link_idx" ON "reports"("target_profile_link_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_profile_link_once" ON "reports"("reporter_id", "target_profile_link_id") WHERE (status = 'OPEN'::report_status AND target_profile_link_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "user_profile_links" ADD CONSTRAINT "user_profile_links_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "follow_requests" ADD CONSTRAINT "follow_requests_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "follow_requests" ADD CONSTRAINT "follow_requests_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Checks.
ALTER TABLE "user_profile_links" ADD CONSTRAINT "user_profile_links_position" CHECK (position BETWEEN 0 AND 2);
ALTER TABLE "user_profile_links" ADD CONSTRAINT "user_profile_links_https" CHECK (url LIKE 'https://%' AND url !~ '[[:space:][:cntrl:]]');
ALTER TABLE "user_profile_links" ADD CONSTRAINT "user_profile_links_label_shape" CHECK (label IS NULL OR char_length(label) BETWEEN 1 AND 30);
ALTER TABLE "follow_requests" ADD CONSTRAINT "follow_requests_not_self" CHECK (requester_id <> target_id);

-- Reports: exactly one target, the one the type names (replaces the rule of
-- 20261210100000_direct_messages; PROFILE_LINK compared as text, the value comes from the previous
-- migration). A PROFILE_LINK report always carries its snapshot.
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  num_nonnulls(target_post_id, target_comment_id, target_user_id, target_story_id, target_live_room_id,
               target_live_chat_message_id, target_cp_confession_id, target_family_chat_message_id,
               target_dm_message_id, target_profile_link_id) = 1
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
    OR (target_type::text = 'PROFILE_LINK' AND target_profile_link_id IS NOT NULL AND link_snapshot IS NOT NULL)));
