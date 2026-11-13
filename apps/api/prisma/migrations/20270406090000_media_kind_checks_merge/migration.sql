-- Integration of D301 (v1.95-social) and D303 (v1.97-social) on `claude/kl-int17`.
--
-- Both branches redefined the same three CHECKs of `media_assets` from the same base:
-- `20270402090100_owner_profile` added PROFILE_COVER_VIDEO (the owner's cover video: ≤ 60 s, a poster) and
-- `20270404090100_gift_events` added BANNER_VIDEO (≤ 30 s, no poster) and HOME_BANNER durations / posters. Applied
-- in order, the later one dropped PROFILE_COVER_VIDEO again. This migration restores the union of both, unchanged
-- otherwise. Existing rows satisfy it (it only accepts more). No GRANT (an existing table).

ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO', 'BANNER_VIDEO'));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind IN ('REEL_VIDEO', 'PROFILE_COVER_VIDEO') AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind = 'LEVEL_RAISE_VIDEO' AND duration_ms BETWEEN 1 AND 90000)
  OR (kind = 'BANNER_VIDEO' AND duration_ms BETWEEN 1 AND 30000)
  OR (kind = 'HOME_BANNER' AND (duration_ms IS NULL OR duration_ms BETWEEN 1 AND 10000))
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO',
                   'BANNER_VIDEO', 'HOME_BANNER')
      AND duration_ms IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_poster_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_poster_shape" CHECK (
  (kind IN ('POST_VIDEO', 'REEL_VIDEO', 'PROFILE_COVER_VIDEO') AND poster_key IS NOT NULL)
  OR kind IN ('LEVEL_RAISE_VIDEO', 'HOME_BANNER')
  OR (kind NOT IN ('POST_VIDEO', 'REEL_VIDEO', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO', 'HOME_BANNER') AND poster_key IS NULL));
