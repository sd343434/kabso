-- v1.55-social (D186, owner 2026-10-30): the active-host avatar frames «إطار المضيف» (CONVENTIONS §10.49,
-- CP-029; owner-supplied art, apps/mobile/assets/host_frames/). Nobody owns them until the server gives
-- one: an active agency host (D179's test: ≥ 7 live days and ≥ 10 live hours in the last 30 days) gets the
-- frame of their style (male → blue, female → pink, otherwise the one they chose), source HOST_ACTIVE, not
-- worn; the agency sweeper takes it back when they are no longer active and gives it again when they are.
-- bag.catalogue.ts keeps the same rows (checked by a unit test). The runtime role gets DML through the
-- default privileges (20261016130000_per_database_runtime_group): no GRANT here.

INSERT INTO "bag_items" ("code", "category", "name_ar", "name_en", "asset_key", "sort_order", "free") VALUES
  ('host_frame_blue', 'AVATAR_FRAME', 'إطار المضيف الأزرق', 'Blue host frame', 'host_frame_blue', 1, false),
  ('host_frame_pink', 'AVATAR_FRAME', 'إطار المضيف الوردي', 'Pink host frame', 'host_frame_pink', 2, false);

-- The style a host without a stated gender (none, or «أفضّل عدم الذكر») chose for their frame.
CREATE TYPE "host_frame_style" AS ENUM ('BLUE', 'PINK');

CREATE TABLE "host_frame_choices" (
  "user_id"    UUID               NOT NULL,
  "style"      "host_frame_style" NOT NULL,
  "updated_at" TIMESTAMPTZ(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "host_frame_choices_pkey" PRIMARY KEY ("user_id"),
  CONSTRAINT "host_frame_choices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- HOST_ACTIVE items are the server's: the sweeper finds them by source.
CREATE INDEX "user_bag_items_host_active_idx" ON "user_bag_items" ("user_id") WHERE "source" = 'HOST_ACTIVE';
