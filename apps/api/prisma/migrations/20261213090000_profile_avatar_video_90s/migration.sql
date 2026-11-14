-- v1.45-social (D168, owner 2026-10-29), CONVENTIONS §10.42, §11.1, §11.14.
--
-- 1. The profile photo: `user_profiles.avatar_media_id` is the user's `AVATAR` asset (one profile per
--    asset); `avatar_url` keeps being the public URL every read already uses (its 640 px square).
--    Replacing or removing the photo deletes the old asset in the API, so the reference never dangles
--    (NO ACTION, like `live_hosts.cover_media_id`). A URL without an asset stays allowed (accounts
--    seeded with a URL before); an asset without a URL is not.
-- 2. Media kind `AVATAR` (processed like `LIVE_COVER`).
-- 3. Post videos at most 90 s (was 180 s). Rows stored before keep their length: the existing
--    `media_assets_duration_shape` (1–180 000 ms for `POST_VIDEO`) is kept and still holds for every
--    row; the new 90 s check is added `NOT VALID`, so PostgreSQL enforces it on every INSERT and
--    UPDATE from now on but does not check (or reject) the rows already stored. The API never updates
--    such a row: `claimAssetsIn` refuses to attach a `POST_VIDEO` longer than 90 s, and attached rows
--    are not updated. Do not run `VALIDATE CONSTRAINT` while longer post videos exist.
--
-- The runtime role gets DML through the default privileges (20261016120000_runtime_role_grants), so
-- this migration contains no GRANT.

-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "avatar_media_id" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "user_profiles_avatar_media_id_key" ON "user_profiles"("avatar_media_id");

-- AddForeignKey
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_avatar_media_id_fkey" FOREIGN KEY ("avatar_media_id") REFERENCES "media_assets"("id") ON DELETE NO ACTION ON UPDATE CASCADE;

-- Checks.
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_avatar_media_has_url" CHECK (avatar_media_id IS NULL OR avatar_url IS NOT NULL);

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR'));

ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_post_video_90s" CHECK (kind <> 'POST_VIDEO' OR duration_ms <= 90000) NOT VALID;
