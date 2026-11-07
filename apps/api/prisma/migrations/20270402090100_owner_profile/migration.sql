-- v1.95-social (D301, owner 2026-11-07: «صفحة صاحب البرنامج» — features chosen from five mock-ups; CONVENTIONS §10.112).
-- The owner is an ACTIVE account holding the OWNER panel role; nothing here is shown for anyone else.
--
-- 1. The bilingual cover video «فيديو الغلاف»: media kind PROFILE_COVER_VIDEO (like a reel's video: ≤ 60 s, a poster)
--    and `owner_cover_videos` — one video per owner and language (ar / en). The app picks by its own language.
-- 2. «إعلانات رسمية»: `posts.official_at` (the owner marks his own post «رسمي»; pins stay separate, at most 3).
-- 3. «رحلة Kabso»: `owner_journey_milestones` (≤ 30 per owner, checked by the API; at most one «الأحدث»).
-- 4. «لوحة المؤسس»: `users_last_active_idx`, so «online now» is an index range scan.
-- 5. «اقترح ميزة / أبلغ عن موظف» → «صندوق المؤسس» (OWNER only): `owner_feedback` and `notifications.owner_feedback_id`.
--    Pictures are private objects (`private/owner-feedback/{id}/{n}.webp`, kind OWNER_FEEDBACK_IMAGE, no asset row).
-- Runtime grants come from the default privileges (20261016120000_runtime_role_grants).

-- 1. The cover video.
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER', 'DM_IMAGE', 'DM_VOICE', 'POST_VIDEO', 'REEL_VIDEO', 'VIDEO_POSTER', 'AVATAR', 'PROFILE_COVER', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO'));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_duration_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_duration_shape" CHECK (
  (kind IN ('LIVE_CHAT_VOICE', 'DM_VOICE') AND duration_ms BETWEEN 1 AND 30000)
  OR (kind IN ('REEL_VIDEO', 'PROFILE_COVER_VIDEO') AND duration_ms BETWEEN 1 AND 60000)
  OR (kind = 'POST_VIDEO' AND duration_ms BETWEEN 1 AND 180000)
  OR (kind = 'LEVEL_RAISE_VIDEO' AND duration_ms BETWEEN 1 AND 90000)
  OR (kind NOT IN ('LIVE_CHAT_VOICE', 'DM_VOICE', 'REEL_VIDEO', 'POST_VIDEO', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO') AND duration_ms IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_poster_shape";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_poster_shape" CHECK (
  (kind IN ('POST_VIDEO', 'REEL_VIDEO', 'PROFILE_COVER_VIDEO') AND poster_key IS NOT NULL)
  OR kind = 'LEVEL_RAISE_VIDEO'
  OR (kind NOT IN ('POST_VIDEO', 'REEL_VIDEO', 'LEVEL_RAISE_VIDEO', 'PROFILE_COVER_VIDEO') AND poster_key IS NULL));

CREATE TABLE "owner_cover_videos" (
    "user_id" UUID NOT NULL,
    "lang" VARCHAR(2) NOT NULL,
    "media_id" UUID NOT NULL,
    "set_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_cover_videos_pkey" PRIMARY KEY ("user_id","lang"),
    CONSTRAINT "owner_cover_videos_lang_known" CHECK (lang IN ('ar', 'en'))
);
CREATE UNIQUE INDEX "owner_cover_videos_media_once" ON "owner_cover_videos"("media_id");
ALTER TABLE "owner_cover_videos" ADD CONSTRAINT "owner_cover_videos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "owner_cover_videos" ADD CONSTRAINT "owner_cover_videos_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "media_assets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 2. Official announcements.
ALTER TABLE "posts" ADD COLUMN "official_at" TIMESTAMPTZ(3);
CREATE INDEX "posts_official_author_published_idx" ON "posts"("author_id", "published_at" DESC, "id" DESC) WHERE (official_at IS NOT NULL AND status = 'PUBLISHED'::post_status AND deleted_at IS NULL);

-- 3. «رحلة Kabso».
CREATE TABLE "owner_journey_milestones" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "title_ar" VARCHAR(60) NOT NULL,
    "title_en" VARCHAR(60) NOT NULL,
    "line_ar" VARCHAR(120),
    "line_en" VARCHAR(120),
    "year" SMALLINT NOT NULL,
    "month" SMALLINT NOT NULL,
    "icon" VARCHAR(16) NOT NULL,
    "latest" BOOLEAN NOT NULL DEFAULT false,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_journey_milestones_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "owner_journey_milestones_texts" CHECK (
      char_length(btrim(title_ar)) BETWEEN 1 AND 60 AND char_length(btrim(title_en)) BETWEEN 1 AND 60
      AND (line_ar IS NULL OR char_length(line_ar) BETWEEN 1 AND 120)
      AND (line_en IS NULL OR char_length(line_en) BETWEEN 1 AND 120)),
    CONSTRAINT "owner_journey_milestones_date" CHECK (year BETWEEN 2020 AND 2100 AND month BETWEEN 1 AND 12),
    CONSTRAINT "owner_journey_milestones_icon_known" CHECK (icon IN ('rocket', 'users', 'agency', 'globe', 'sparkles', 'star', 'trophy', 'heart', 'gift', 'live', 'crown', 'flag')),
    CONSTRAINT "owner_journey_milestones_position" CHECK (position >= 0)
);
CREATE INDEX "owner_journey_owner_position_idx" ON "owner_journey_milestones"("owner_id", "position");
-- At most one «الأحدث» per owner.
CREATE UNIQUE INDEX "owner_journey_one_latest" ON "owner_journey_milestones"("owner_id") WHERE latest;
ALTER TABLE "owner_journey_milestones" ADD CONSTRAINT "owner_journey_milestones_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 4. «لوحة المؤسس»: online now.
CREATE INDEX "users_last_active_idx" ON "users"("last_active_at");

-- 5. «صندوق المؤسس».
CREATE TABLE "owner_feedback" (
    "id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "kind" VARCHAR(16) NOT NULL,
    "text" VARCHAR(1000) NOT NULL,
    "staff_user_id" UUID,
    "category" VARCHAR(24),
    "image_keys" VARCHAR(160)[] DEFAULT ARRAY[]::VARCHAR(160)[],
    "status" VARCHAR(8) NOT NULL DEFAULT 'NEW',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMPTZ(3),
    "done_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_feedback_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "owner_feedback_status_known" CHECK (status IN ('NEW', 'READ', 'DONE')),
    CONSTRAINT "owner_feedback_text" CHECK (char_length(btrim(text)) BETWEEN 1 AND 1000),
    -- A suggestion names nobody and has at most one picture; a staff report names the staff member (until that
    -- account is gone: SET NULL keeps the report) and a category, with at most four pictures.
    CONSTRAINT "owner_feedback_shape" CHECK (
      (kind = 'FEATURE' AND staff_user_id IS NULL AND category IS NULL AND coalesce(cardinality(image_keys), 0) <= 1)
      OR (kind = 'STAFF_REPORT' AND category IN ('RUDENESS', 'ABUSE_OF_POWER', 'UNFAIR_ACTION', 'NO_RESPONSE', 'CORRUPTION', 'OTHER')
          AND coalesce(cardinality(image_keys), 0) <= 4))
);
CREATE INDEX "owner_feedback_created_idx" ON "owner_feedback"("created_at" DESC, "id" DESC);
CREATE INDEX "owner_feedback_sender_created_idx" ON "owner_feedback"("sender_id", "created_at");
ALTER TABLE "owner_feedback" ADD CONSTRAINT "owner_feedback_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "owner_feedback" ADD CONSTRAINT "owner_feedback_staff_user_id_fkey" FOREIGN KEY ("staff_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "notifications" ADD COLUMN "owner_feedback_id" UUID;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_owner_feedback_id_fkey" FOREIGN KEY ("owner_feedback_id") REFERENCES "owner_feedback"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX "notifications_owner_feedback_idx" ON "notifications"("owner_feedback_id") WHERE ("owner_feedback_id" IS NOT NULL);
