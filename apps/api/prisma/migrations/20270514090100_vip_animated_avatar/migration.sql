-- v1.136-social (D384, owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية» — an animated cut-out clip as a VIP perk),
-- CONVENTIONS §10.173.
--
-- 1. The member's clip: `user_profiles.animated_avatar_media_id` is their `ANIMATED_AVATAR` asset (one profile per
--    asset), `animated_avatar_url` its looping animated WebP and `animated_avatar_still_url` its first frame. Replacing
--    or removing the clip deletes the old asset in the API, so the reference never dangles (NO ACTION, like
--    `avatar_media_id` and `cover_media_id`). All three are null or all three set. The clip stays when the VIP ends
--    (the API shows it only while the perk is held).
-- 2. Media kind `ANIMATED_AVATAR` (a PNG strip of square frames re-encoded to an animated WebP with alpha and a still).
--    CHECK from 20270420090000_event_page_design plus ANIMATED_AVATAR; it has no duration and no poster, which
--    `media_assets_duration_shape` / `media_assets_poster_shape` already require of unlisted kinds.
--
-- The perk code itself is only data (`vip_tier_perks.code` is checked by the API's catalogue): nothing to migrate.
-- The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants), so this
-- migration contains no GRANT.

-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "animated_avatar_media_id" UUID,
ADD COLUMN     "animated_avatar_url" VARCHAR(2048),
ADD COLUMN     "animated_avatar_still_url" VARCHAR(2048);

-- CreateIndex
CREATE UNIQUE INDEX "user_profiles_animated_avatar_media_id_key" ON "user_profiles"("animated_avatar_media_id");

-- AddForeignKey
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_animated_avatar_media_id_fkey" FOREIGN KEY ("animated_avatar_media_id") REFERENCES "media_assets"("id") ON DELETE NO ACTION ON UPDATE CASCADE;

-- Checks.
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_animated_avatar_shape" CHECK (
  (animated_avatar_media_id IS NULL) = (animated_avatar_url IS NULL)
  AND (animated_avatar_url IS NULL) = (animated_avatar_still_url IS NULL)
);

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO', 'BANNER_VIDEO', 'DM_GROUP_PHOTO', 'EVENT_BOARD_BG', 'ANIMATED_AVATAR'));
