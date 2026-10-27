-- v1.26.2-live (D126, owner 2026-10-26): gift art hosted in object storage and downloaded by the app
-- on demand (CONVENTIONS §10.23), so a new gift needs no app release. The static image (PNG/WebP)
-- and the SVGA effect are uploaded by `gift-admin add|update --image <file> --animation-file <file>`
-- to content-addressed, immutable keys `media/gifts/<code>/<sha256 prefix>.<ext>`; the API answers
-- `MEDIA_PUBLIC_BASE_URL/<key>`. Nullable columns, no default, no rewrite of existing rows: existing
-- gifts keep only their bundled `asset_key` / `animation_key`.

-- AlterTable
ALTER TABLE "gifts" ADD COLUMN "image_object_key" VARCHAR(200),
ADD COLUMN "animation_object_key" VARCHAR(200),
ADD COLUMN "animation_bytes" INTEGER;

ALTER TABLE "gifts" ADD CONSTRAINT "gifts_image_object_key_format" CHECK (
  image_object_key ~ '^media/gifts/[a-z0-9][a-z0-9_]{0,39}/[0-9a-f]{32}\.(png|webp)$'
);
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_animation_object_key_format" CHECK (
  animation_object_key ~ '^media/gifts/[a-z0-9][a-z0-9_]{0,39}/[0-9a-f]{32}\.svga$'
);
-- The size travels with the file (the app decides whether to prefetch it): both set or both null.
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_animation_bytes_set" CHECK (
  (animation_object_key IS NULL AND animation_bytes IS NULL)
  OR (animation_object_key IS NOT NULL AND animation_bytes BETWEEN 1 AND 26214400)
);
