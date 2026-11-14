-- v1.23.4-live (CP-020, D117, 2026-10-26): an optional sub-category (tag) per gift, CONVENTIONS §10.23.
-- The gift panel shows "All" plus the distinct tags of the open tab as chips. Managed only with the
-- `gift-admin` CLI (`--tag <code> --tag-ar <text> --tag-en <text>`, `--tag none`); existing gifts
-- keep no tag. Nullable columns, no default, no rewrite of existing rows.

-- AlterTable
ALTER TABLE "gifts" ADD COLUMN "tag_code" VARCHAR(40),
ADD COLUMN "tag_name_ar" VARCHAR(30),
ADD COLUMN "tag_name_en" VARCHAR(30);

-- A tag is its code and both names, or nothing.
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_tag_complete" CHECK (
  (tag_code IS NULL AND tag_name_ar IS NULL AND tag_name_en IS NULL)
  OR (tag_code IS NOT NULL AND tag_name_ar IS NOT NULL AND tag_name_en IS NOT NULL)
);
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_tag_code_format" CHECK (tag_code ~ '^[a-z0-9][a-z0-9_]{0,39}$');
ALTER TABLE "gifts" ADD CONSTRAINT "gifts_tag_names_present" CHECK (
  tag_code IS NULL OR (length(btrim(tag_name_ar)) > 0 AND length(btrim(tag_name_en)) > 0)
);
