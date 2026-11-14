-- v1.72-live (D283, CONVENTIONS §10.96.10–11; owner 2026-11-05): the Kabso Team's accounts are limited (no live, no
-- levels, announcements only) and each MODERATION / SUPPORT staff member is responsible for regions (fixed groups of
-- countries). The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no
-- GRANT here.

-- An official announcement post or reel «إعلان رسمي — فريق كابسو». Constant default: metadata-only, no rewrite.
ALTER TABLE "posts" ADD COLUMN "announcement" BOOLEAN NOT NULL DEFAULT false;

-- The Kabso Team's fixed picture (src/modules/live/staff-avatar.ts): set by the API on a grant / revoke and at its
-- start (so no backfill here); the person's own photo waits in staff_saved_avatar_url.
ALTER TABLE "user_profiles" ADD COLUMN "staff_avatar" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "user_profiles" ADD COLUMN "staff_saved_avatar_url" VARCHAR(2048);
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_staff_saved_avatar"
  CHECK (staff_avatar OR staff_saved_avatar_url IS NULL);

CREATE TABLE "admin_staff_regions" (
    "user_id" UUID NOT NULL,
    "region" VARCHAR(24) NOT NULL,
    "assigned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_staff_regions_pkey" PRIMARY KEY ("user_id", "region"),
    -- The catalogue of apps/api/src/modules/live/staff-regions.ts (a new region needs a migration).
    CONSTRAINT "admin_staff_regions_code" CHECK (region IN (
      'ARAB_WORLD', 'GREATER_CHINA', 'TURKEY', 'IRAN', 'SOUTH_ASIA', 'SOUTHEAST_ASIA', 'EAST_ASIA', 'EUROPE',
      'NORTH_AMERICA', 'LATIN_AMERICA', 'SUB_SAHARAN_AFRICA', 'RUSSIA_CENTRAL_ASIA', 'OCEANIA'))
);
CREATE INDEX "admin_staff_regions_region_idx" ON "admin_staff_regions"("region");
ALTER TABLE "admin_staff_regions" ADD CONSTRAINT "admin_staff_regions_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
