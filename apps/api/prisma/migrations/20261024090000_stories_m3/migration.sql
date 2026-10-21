-- CP-008 (D91, CP-006 M3): photo stories. New tables stories, story_views, story_mentions;
-- media_assets.kind (POST_IMAGE | STORY_IMAGE; existing rows are POST_IMAGE); report target STORY.
-- The runtime role gets DML on the new tables through the default privileges
-- (20261016120000_runtime_role_grants).

-- AlterEnum
ALTER TYPE "report_target_type" ADD VALUE 'STORY';

-- AlterTable
ALTER TABLE "media_assets" ADD COLUMN     "kind" VARCHAR(32) NOT NULL DEFAULT 'POST_IMAGE';

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "target_story_id" UUID;

-- CreateTable
CREATE TABLE "stories" (
    "id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "media_asset_id" UUID NOT NULL,
    "text" VARCHAR(200) NOT NULL DEFAULT '',
    "view_count" INTEGER NOT NULL DEFAULT 0,
    "idempotency_key" UUID,
    "request_hash" VARCHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),
    "removed_at" TIMESTAMPTZ(3),

    CONSTRAINT "stories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "story_views" (
    "story_id" UUID NOT NULL,
    "viewer_id" UUID NOT NULL,
    "seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "story_views_pkey" PRIMARY KEY ("story_id","viewer_id")
);

-- CreateTable
CREATE TABLE "story_mentions" (
    "story_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,

    CONSTRAINT "story_mentions_pkey" PRIMARY KEY ("story_id","user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "stories_media_asset_id_key" ON "stories"("media_asset_id");

-- CreateIndex
CREATE INDEX "stories_author_active_idx" ON "stories"("author_id", "expires_at") WHERE (deleted_at IS NULL AND removed_at IS NULL);

-- CreateIndex
CREATE INDEX "stories_author_created_idx" ON "stories"("author_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "stories_author_idempotency_key" ON "stories"("author_id", "idempotency_key");

-- CreateIndex
CREATE INDEX "story_views_story_seen_idx" ON "story_views"("story_id", "seen_at" DESC, "viewer_id" DESC);

-- CreateIndex
CREATE INDEX "story_views_viewer_id_idx" ON "story_views"("viewer_id");

-- CreateIndex
CREATE INDEX "story_mentions_user_id_idx" ON "story_mentions"("user_id");

-- CreateIndex
CREATE INDEX "reports_target_story_idx" ON "reports"("target_story_id");

-- CreateIndex
CREATE UNIQUE INDEX "reports_open_story_once" ON "reports"("reporter_id", "target_story_id") WHERE (status = 'OPEN'::report_status AND target_story_id IS NOT NULL);

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_story_id_fkey" FOREIGN KEY ("target_story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stories" ADD CONSTRAINT "stories_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stories" ADD CONSTRAINT "stories_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_views" ADD CONSTRAINT "story_views_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_views" ADD CONSTRAINT "story_views_viewer_id_fkey" FOREIGN KEY ("viewer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_mentions" ADD CONSTRAINT "story_mentions_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_mentions" ADD CONSTRAINT "story_mentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Checks (CONVENTIONS §11.9). The new enum value is compared as text: a value added in this
-- migration cannot be used as an enum literal before it commits.
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE'));
ALTER TABLE "stories" ADD CONSTRAINT "stories_view_count_non_negative" CHECK (view_count >= 0);
ALTER TABLE "stories" ADD CONSTRAINT "stories_expiry_after_creation" CHECK (expires_at > created_at);
ALTER TABLE "reports" DROP CONSTRAINT "reports_one_target";
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (target_type::text = 'POST' AND target_post_id IS NOT NULL AND target_comment_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL)
  OR (target_type::text = 'COMMENT' AND target_comment_id IS NOT NULL AND target_post_id IS NULL AND target_user_id IS NULL AND target_story_id IS NULL)
  OR (target_type::text = 'USER' AND target_user_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_story_id IS NULL)
  OR (target_type::text = 'STORY' AND target_story_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL AND target_user_id IS NULL));
