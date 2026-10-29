-- v1.41-social (D162, CP-023, owner 2026-10-28): video posts and reels (CP-006 M2 without
-- transcoding), CONVENTIONS §11.1, §11.2 and §11.14. Additive: a new enum type and column on posts
-- (every existing post is a `POST`), a nullable column on media assets, wider CHECKs. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no
-- GRANT here. A new enum TYPE (not a value added to an existing one) can be used in the same
-- transaction, so no separate `_enums` migration is needed.

-- CreateEnum
CREATE TYPE "post_format" AS ENUM ('POST', 'REEL');

-- AlterTable: a post or a reel.
ALTER TABLE "posts" ADD COLUMN "format" "post_format" NOT NULL DEFAULT 'POST';

-- AlterTable: a video's poster at 1 080 px (thumb_key holds the poster at 320 px, large_key the file).
ALTER TABLE "media_assets" ADD COLUMN "poster_key" VARCHAR(256);

-- CreateIndex: the reels of followed accounts (and the caller's own), newest first.
CREATE INDEX "posts_reels_author_published_idx" ON "posts"("author_id", "published_at" DESC, "id" DESC) WHERE (format = 'REEL'::post_format AND status = 'PUBLISHED'::post_status AND deleted_at IS NULL);

-- Upload slots: a post video may be up to 200 MiB (images stay 15 MiB, checked by the API).
ALTER TABLE "media_uploads" DROP CONSTRAINT "media_uploads_byte_size_range";
ALTER TABLE "media_uploads" ADD CONSTRAINT "media_uploads_byte_size_range" CHECK (byte_size BETWEEN 1 AND 209715200);

-- Media kinds (§11.1, §11.14).
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER'));

-- A length for voice clips (≤ 30 s) and videos (reel ≤ 60 s, post ≤ 180 s), none for images.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'REEL_VIDEO' AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO') AND duration_ms IS NULL));

-- A video always has its poster; nothing else has one.
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_poster_shape" CHECK (
  (kind IN ('POST_VIDEO', 'REEL_VIDEO')) = (poster_key IS NOT NULL));
