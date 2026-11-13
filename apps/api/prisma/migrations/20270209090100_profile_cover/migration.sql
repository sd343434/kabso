-- v1.76-social (D218, owner 2026-11-01: «صورة غلاف أعلى الملف»), CONVENTIONS §10.73.3.
--
-- 1. The profile cover: `user_profiles.cover_media_id` is the user's `PROFILE_COVER` asset (one profile per
--    asset) and `cover_url` its public URL (the 1 080 px WebP). Replacing or removing the cover deletes the
--    old asset in the API, so the reference never dangles (NO ACTION, like `avatar_media_id`). A cover always
--    has its asset (there were no URL-only covers before), so both are null or both are set.
-- 2. Media kind `PROFILE_COVER` (processed like a post image: the long side at most 1 080 px, never cropped;
--    the app covers the banner area).
--
-- The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants), so this
-- migration contains no GRANT.

-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "cover_media_id" UUID,
ADD COLUMN     "cover_url" VARCHAR(2048);

-- CreateIndex
CREATE UNIQUE INDEX "user_profiles_cover_media_id_key" ON "user_profiles"("cover_media_id");

-- AddForeignKey
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_cover_media_id_fkey" FOREIGN KEY ("cover_media_id") REFERENCES "media_assets"("id") ON DELETE NO ACTION ON UPDATE CASCADE;

-- Checks.
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_cover_media_has_url" CHECK ((cover_media_id IS NULL) = (cover_url IS NULL));

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER'));
