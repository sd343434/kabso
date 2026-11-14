-- v1.26-live (D124, 2026-10-26): promo banners on the live hub, CONVENTIONS §10.26. Managed only with
-- the `banner-admin` CLI (migration role); the API reads them (`GET /home/banners`). The runtime role
-- gets DML through the default privileges (20261016130000_per_database_runtime_group), so this
-- migration contains no GRANT. Additive: a new table and a new media kind; no existing row changes.

-- Media: the home banner kind (1 500 × 500 WebP, cover-cropped to 3:1, §11.1).
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER', 'LIVE_CHAT_IMAGE', 'LIVE_CHAT_VOICE', 'FAMILY_EMBLEM', 'FAMILY_COVER', 'HOME_BANNER'));

-- CreateTable
CREATE TABLE "home_banners" (
    "id" UUID NOT NULL,
    "media_id" UUID NOT NULL,
    "title_ar" VARCHAR(80),
    "title_en" VARCHAR(80),
    "title_side" VARCHAR(8) NOT NULL DEFAULT 'RIGHT',
    "link" VARCHAR(512) NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMPTZ(3),
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "home_banners_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "home_banners_media_id_key" ON "home_banners"("media_id");

-- CreateIndex
CREATE INDEX "home_banners_enabled_idx" ON "home_banners"("sort_order", "starts_at") WHERE enabled;

-- AddForeignKey
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "media_assets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Rules the CLI also checks (the database is the last line).
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_title_side_known" CHECK (title_side IN ('LEFT', 'RIGHT'));
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_window" CHECK (ends_at IS NULL OR ends_at > starts_at);
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_titles_present" CHECK (
  (title_ar IS NULL OR length(btrim(title_ar)) > 0) AND (title_en IS NULL OR length(btrim(title_en)) > 0)
);
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_link_shape" CHECK (link ~ '^(/|https://)');
