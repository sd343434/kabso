-- v1.5-social (DRAFT, CP-006 M1, D87): media uploads, posts, comments, hashtags, mentions,
-- blocks, mutes, hides, reports and privacy settings (CONVENTIONS §11). Additive.
--
-- Runs as the migration role (KL-013). The runtime group gets SELECT, INSERT, UPDATE and DELETE
-- on the new tables through the default privileges (20261016120000_runtime_role_grants).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- CreateEnum
CREATE TYPE "media_upload_status" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "post_status" AS ENUM ('DRAFT', 'SCHEDULED', 'PUBLISHED');

-- CreateEnum
CREATE TYPE "post_moderation" AS ENUM ('VISIBLE', 'PENDING', 'REMOVED');

-- CreateEnum
CREATE TYPE "who_can_comment" AS ENUM ('EVERYONE', 'FOLLOWERS', 'NOBODY');

-- CreateEnum
CREATE TYPE "who_can_mention" AS ENUM ('EVERYONE', 'FOLLOWING', 'NOBODY');

-- CreateEnum
CREATE TYPE "report_target_type" AS ENUM ('POST', 'COMMENT', 'USER');

-- CreateEnum
CREATE TYPE "report_reason" AS ENUM ('SPAM', 'NUDITY', 'VIOLENCE', 'HATE', 'HARASSMENT', 'ILLEGAL', 'OTHER');

-- CreateEnum
CREATE TYPE "report_status" AS ENUM ('OPEN', 'ACTIONED', 'DISMISSED');

-- AlterEnum
ALTER TYPE "admin_permission" ADD VALUE 'MODERATION';

-- CreateTable
CREATE TABLE "media_uploads" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" VARCHAR(32) NOT NULL,
    "content_type" VARCHAR(64) NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "object_key" VARCHAR(256) NOT NULL,
    "status" "media_upload_status" NOT NULL DEFAULT 'PENDING',
    "media_asset_id" UUID,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ(3),

    CONSTRAINT "media_uploads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "media_assets" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "blurhash" VARCHAR(64),
    "large_key" VARCHAR(256) NOT NULL,
    "thumb_key" VARCHAR(256) NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attached_at" TIMESTAMPTZ(3),

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "posts" (
    "id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "text" VARCHAR(2200) NOT NULL DEFAULT '',
    "location" VARCHAR(80),
    "status" "post_status" NOT NULL DEFAULT 'PUBLISHED',
    "moderation" "post_moderation" NOT NULL DEFAULT 'VISIBLE',
    "publish_at" TIMESTAMPTZ(3),
    "published_at" TIMESTAMPTZ(3),
    "edited_at" TIMESTAMPTZ(3),
    "comments_enabled" BOOLEAN NOT NULL DEFAULT true,
    "who_can_comment" "who_can_comment" NOT NULL DEFAULT 'EVERYONE',
    "hide_like_count" BOOLEAN NOT NULL DEFAULT false,
    "like_count" INTEGER NOT NULL DEFAULT 0,
    "comment_count" INTEGER NOT NULL DEFAULT 0,
    "share_count" INTEGER NOT NULL DEFAULT 0,
    "repost_count" INTEGER NOT NULL DEFAULT 0,
    "save_count" INTEGER NOT NULL DEFAULT 0,
    "view_count" INTEGER NOT NULL DEFAULT 0,
    "idempotency_key" UUID,
    "request_hash" VARCHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "post_media" (
    "post_id" UUID NOT NULL,
    "media_asset_id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,

    CONSTRAINT "post_media_pkey" PRIMARY KEY ("post_id","position")
);

-- CreateTable
CREATE TABLE "post_likes" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_likes_pkey" PRIMARY KEY ("post_id","user_id")
);

-- CreateTable
CREATE TABLE "post_saves" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_saves_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateTable
CREATE TABLE "post_reposts" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_reposts_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateTable
CREATE TABLE "post_views" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "viewed_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "post_views_pkey" PRIMARY KEY ("post_id","user_id")
);

-- CreateTable
CREATE TABLE "post_share_events" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,

    CONSTRAINT "post_share_events_pkey" PRIMARY KEY ("post_id","user_id","day")
);

-- CreateTable
CREATE TABLE "post_pins" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "pinned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_pins_pkey" PRIMARY KEY ("post_id")
);

-- CreateTable
CREATE TABLE "hashtags" (
    "id" UUID NOT NULL,
    "tag" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "hashtags_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "post_hashtags" (
    "post_id" UUID NOT NULL,
    "hashtag_id" UUID NOT NULL,

    CONSTRAINT "post_hashtags_pkey" PRIMARY KEY ("post_id","hashtag_id")
);

-- CreateTable
CREATE TABLE "post_mentions" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,

    CONSTRAINT "post_mentions_pkey" PRIMARY KEY ("post_id","user_id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "parent_id" UUID,
    "text" VARCHAR(500) NOT NULL,
    "like_count" INTEGER NOT NULL DEFAULT 0,
    "reply_count" INTEGER NOT NULL DEFAULT 0,
    "pinned_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comment_likes" (
    "comment_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "comment_likes_pkey" PRIMARY KEY ("comment_id","user_id")
);

-- CreateTable
CREATE TABLE "comment_mentions" (
    "comment_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,

    CONSTRAINT "comment_mentions_pkey" PRIMARY KEY ("comment_id","user_id")
);

-- CreateTable
CREATE TABLE "user_blocks" (
    "blocker_id" UUID NOT NULL,
    "blocked_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("blocker_id","blocked_id")
);

-- CreateTable
CREATE TABLE "user_mutes" (
    "muter_id" UUID NOT NULL,
    "muted_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_mutes_pkey" PRIMARY KEY ("muter_id","muted_id")
);

-- CreateTable
CREATE TABLE "post_hides" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_hides_pkey" PRIMARY KEY ("user_id","post_id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL,
    "reporter_id" UUID NOT NULL,
    "target_type" "report_target_type" NOT NULL,
    "target_post_id" UUID,
    "target_comment_id" UUID,
    "target_user_id" UUID,
    "reason" "report_reason" NOT NULL,
    "note" VARCHAR(500),
    "status" "report_status" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(3),
    "resolved_by_id" UUID,
    "resolution_note" VARCHAR(500),

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "privacy_settings" (
    "user_id" UUID NOT NULL,
    "who_can_mention" "who_can_mention" NOT NULL DEFAULT 'EVERYONE',
    "default_who_can_comment" "who_can_comment" NOT NULL DEFAULT 'EVERYONE',
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "privacy_settings_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "media_uploads_media_asset_id_key" ON "media_uploads"("media_asset_id");

-- CreateIndex
CREATE INDEX "media_uploads_user_created_idx" ON "media_uploads"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "media_uploads_pending_expiry_idx" ON "media_uploads"("expires_at") WHERE (status = 'PENDING'::media_upload_status);

-- CreateIndex
CREATE INDEX "media_assets_unattached_idx" ON "media_assets"("created_at") WHERE (attached_at IS NULL);

-- CreateIndex
CREATE INDEX "posts_author_published_idx" ON "posts"("author_id", "published_at" DESC, "id" DESC) WHERE (status = 'PUBLISHED'::post_status AND deleted_at IS NULL);

-- CreateIndex
CREATE INDEX "posts_published_idx" ON "posts"("published_at" DESC, "id" DESC) WHERE (status = 'PUBLISHED'::post_status AND deleted_at IS NULL AND moderation = 'VISIBLE'::post_moderation);

-- CreateIndex
CREATE INDEX "posts_scheduled_due_idx" ON "posts"("publish_at") WHERE (status = 'SCHEDULED'::post_status AND deleted_at IS NULL);

-- CreateIndex
CREATE INDEX "posts_author_status_created_idx" ON "posts"("author_id", "status", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "posts_author_idempotency_key" ON "posts"("author_id", "idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "post_media_media_asset_id_key" ON "post_media"("media_asset_id");

-- CreateIndex
CREATE INDEX "post_likes_post_created_idx" ON "post_likes"("post_id", "created_at" DESC, "user_id");

-- CreateIndex
CREATE INDEX "post_likes_user_id_idx" ON "post_likes"("user_id");

-- CreateIndex
CREATE INDEX "post_saves_user_created_idx" ON "post_saves"("user_id", "created_at" DESC, "post_id");

-- CreateIndex
CREATE INDEX "post_saves_post_id_idx" ON "post_saves"("post_id");

-- CreateIndex
CREATE INDEX "post_reposts_user_created_idx" ON "post_reposts"("user_id", "created_at" DESC, "post_id");

-- CreateIndex
CREATE INDEX "post_reposts_post_id_idx" ON "post_reposts"("post_id");

-- CreateIndex
CREATE INDEX "post_views_user_id_idx" ON "post_views"("user_id");

-- CreateIndex
CREATE INDEX "post_share_events_user_id_idx" ON "post_share_events"("user_id");

-- CreateIndex
CREATE INDEX "post_pins_user_pinned_idx" ON "post_pins"("user_id", "pinned_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "hashtags_tag_key" ON "hashtags"("tag");

-- CreateIndex
CREATE INDEX "post_hashtags_hashtag_post_idx" ON "post_hashtags"("hashtag_id", "post_id");

-- CreateIndex
CREATE INDEX "post_mentions_user_id_idx" ON "post_mentions"("user_id");

-- CreateIndex
CREATE INDEX "comments_top_idx" ON "comments"("post_id", "like_count" DESC, "created_at" DESC, "id" DESC) WHERE (parent_id IS NULL AND deleted_at IS NULL);

-- CreateIndex
CREATE INDEX "comments_replies_idx" ON "comments"("parent_id", "created_at", "id") WHERE (deleted_at IS NULL);

-- CreateIndex
CREATE INDEX "comments_author_id_idx" ON "comments"("author_id");

-- CreateIndex
CREATE UNIQUE INDEX "comments_one_pin_per_post" ON "comments"("post_id") WHERE (pinned_at IS NOT NULL AND deleted_at IS NULL);

-- CreateIndex
CREATE INDEX "comment_likes_user_id_idx" ON "comment_likes"("user_id");

-- CreateIndex
CREATE INDEX "comment_mentions_user_id_idx" ON "comment_mentions"("user_id");

-- CreateIndex
CREATE INDEX "user_blocks_blocked_id_idx" ON "user_blocks"("blocked_id");

-- CreateIndex
CREATE INDEX "user_blocks_blocker_created_idx" ON "user_blocks"("blocker_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "user_mutes_muted_id_idx" ON "user_mutes"("muted_id");

-- CreateIndex
CREATE INDEX "post_hides_post_id_idx" ON "post_hides"("post_id");

-- CreateIndex
CREATE INDEX "reports_status_created_idx" ON "reports"("status", "created_at", "id");

-- CreateIndex
CREATE INDEX "reports_target_post_idx" ON "reports"("target_post_id");

-- CreateIndex
CREATE INDEX "reports_target_comment_idx" ON "reports"("target_comment_id");

-- CreateIndex
CREATE INDEX "reports_target_user_idx" ON "reports"("target_user_id");

-- AddForeignKey
ALTER TABLE "media_uploads" ADD CONSTRAINT "media_uploads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_uploads" ADD CONSTRAINT "media_uploads_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "posts" ADD CONSTRAINT "posts_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_media" ADD CONSTRAINT "post_media_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_media" ADD CONSTRAINT "post_media_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_likes" ADD CONSTRAINT "post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_saves" ADD CONSTRAINT "post_saves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_saves" ADD CONSTRAINT "post_saves_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reposts" ADD CONSTRAINT "post_reposts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reposts" ADD CONSTRAINT "post_reposts_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_views" ADD CONSTRAINT "post_views_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_views" ADD CONSTRAINT "post_views_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_share_events" ADD CONSTRAINT "post_share_events_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_share_events" ADD CONSTRAINT "post_share_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_pins" ADD CONSTRAINT "post_pins_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_pins" ADD CONSTRAINT "post_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_hashtags" ADD CONSTRAINT "post_hashtags_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_hashtags" ADD CONSTRAINT "post_hashtags_hashtag_id_fkey" FOREIGN KEY ("hashtag_id") REFERENCES "hashtags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_mentions" ADD CONSTRAINT "post_mentions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_mentions" ADD CONSTRAINT "post_mentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comment_likes" ADD CONSTRAINT "comment_likes_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comment_likes" ADD CONSTRAINT "comment_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comment_mentions" ADD CONSTRAINT "comment_mentions_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "comment_mentions" ADD CONSTRAINT "comment_mentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_mutes" ADD CONSTRAINT "user_mutes_muter_id_fkey" FOREIGN KEY ("muter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_mutes" ADD CONSTRAINT "user_mutes_muted_id_fkey" FOREIGN KEY ("muted_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_hides" ADD CONSTRAINT "post_hides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_hides" ADD CONSTRAINT "post_hides_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_post_id_fkey" FOREIGN KEY ("target_post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_comment_id_fkey" FOREIGN KEY ("target_comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_resolved_by_id_fkey" FOREIGN KEY ("resolved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "privacy_settings" ADD CONSTRAINT "privacy_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Integrity rules the Prisma schema cannot express.
ALTER TABLE "posts" ADD CONSTRAINT "posts_counters_non_negative" CHECK (
  like_count >= 0 AND comment_count >= 0 AND share_count >= 0 AND repost_count >= 0
  AND save_count >= 0 AND view_count >= 0);
ALTER TABLE "posts" ADD CONSTRAINT "posts_scheduled_has_publish_at" CHECK (
  status <> 'SCHEDULED'::post_status OR publish_at IS NOT NULL);
ALTER TABLE "posts" ADD CONSTRAINT "posts_published_has_published_at" CHECK (
  status <> 'PUBLISHED'::post_status OR published_at IS NOT NULL);
ALTER TABLE "post_media" ADD CONSTRAINT "post_media_position_range" CHECK (position BETWEEN 0 AND 9);
ALTER TABLE "comments" ADD CONSTRAINT "comments_counters_non_negative" CHECK (like_count >= 0 AND reply_count >= 0);
ALTER TABLE "comments" ADD CONSTRAINT "comments_no_self_parent" CHECK (parent_id IS NULL OR parent_id <> id);
ALTER TABLE "media_uploads" ADD CONSTRAINT "media_uploads_byte_size_range" CHECK (byte_size BETWEEN 1 AND 15728640);
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_no_self" CHECK (blocker_id <> blocked_id);
ALTER TABLE "user_mutes" ADD CONSTRAINT "user_mutes_no_self" CHECK (muter_id <> muted_id);
ALTER TABLE "reports" ADD CONSTRAINT "reports_one_target" CHECK (
  (target_type = 'POST'::report_target_type AND target_post_id IS NOT NULL AND target_comment_id IS NULL AND target_user_id IS NULL)
  OR (target_type = 'COMMENT'::report_target_type AND target_comment_id IS NOT NULL AND target_post_id IS NULL AND target_user_id IS NULL)
  OR (target_type = 'USER'::report_target_type AND target_user_id IS NOT NULL AND target_post_id IS NULL AND target_comment_id IS NULL));

-- One OPEN report per reporter and target (§11.7).
CREATE UNIQUE INDEX "reports_open_post_once" ON "reports"("reporter_id", "target_post_id")
  WHERE status = 'OPEN'::report_status AND target_post_id IS NOT NULL;
CREATE UNIQUE INDEX "reports_open_comment_once" ON "reports"("reporter_id", "target_comment_id")
  WHERE status = 'OPEN'::report_status AND target_comment_id IS NOT NULL;
CREATE UNIQUE INDEX "reports_open_user_once" ON "reports"("reporter_id", "target_user_id")
  WHERE status = 'OPEN'::report_status AND target_user_id IS NOT NULL;

-- Search (§11.6): caption word prefixes and hashtag / profile prefixes.
CREATE INDEX "posts_text_search_idx" ON "posts" USING GIN (to_tsvector('simple', text))
  WHERE status = 'PUBLISHED'::post_status AND deleted_at IS NULL;
CREATE INDEX "hashtags_tag_prefix_idx" ON "hashtags" (tag text_pattern_ops);
CREATE INDEX "user_profiles_display_name_prefix_idx" ON "user_profiles" (lower(display_name) text_pattern_ops);
CREATE INDEX "user_profiles_username_prefix_idx" ON "user_profiles" (username text_pattern_ops);
