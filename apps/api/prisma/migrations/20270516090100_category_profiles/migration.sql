-- v1.138-social (D386, owner 2026-11-12: «أن يكون كل شخص تفاصيل صفحته حسب فئة الحساب»; «الموثقة»), CONVENTIONS §10.175.
--
-- 1. `user_profiles.category_verified_at` / `category_verified_by`: the Kabso Team verified the current category (only a
--    verified category changes the profile page); `category_locked_at` / `category_locked_by`: the team locked it.
--    CHECK `user_profiles_category_verified_shape`: a verification needs a category.
-- 2. `category_verification_requests` «طلب توثيق الفئة»: one PENDING per person (partial unique index), decided by
--    the team with a reason the person sees on a rejection.
-- 3. `profile_featured_pins`: up to 6 of the person's own posts or reels in the featured section, in order
--    (CHECK `profile_featured_pins_position` 0–5, unique per person and position); the limit is checked by the API
--    under a per-person lock.
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The verification and the lock.
ALTER TABLE "user_profiles" ADD COLUMN "category_verified_at" TIMESTAMPTZ(3),
ADD COLUMN "category_verified_by" UUID,
ADD COLUMN "category_locked_at" TIMESTAMPTZ(3),
ADD COLUMN "category_locked_by" UUID;

ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_category_verified_shape" CHECK (
  category_verified_at IS NULL OR account_category IS NOT NULL);

ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_category_verified_by_fkey" FOREIGN KEY ("category_verified_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_category_locked_by_fkey" FOREIGN KEY ("category_locked_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 2. The requests.
CREATE TYPE "category_request_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

CREATE TABLE "category_verification_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "category" "account_category" NOT NULL,
    "status" "category_request_status" NOT NULL DEFAULT 'PENDING',
    "note" VARCHAR(300),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decided_by" UUID,
    "reject_reason" VARCHAR(500),
    "cancel_reason" VARCHAR(32),

    CONSTRAINT "category_verification_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "category_verification_requests_note_len" CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 300),
    CONSTRAINT "category_verification_requests_decided" CHECK (
      (status = 'PENDING' AND decided_at IS NULL AND reject_reason IS NULL AND cancel_reason IS NULL)
      OR (status = 'APPROVED' AND decided_at IS NOT NULL AND reject_reason IS NULL AND cancel_reason IS NULL)
      OR (status = 'REJECTED' AND decided_at IS NOT NULL AND reject_reason IS NOT NULL AND cancel_reason IS NULL)
      OR (status = 'CANCELLED' AND decided_at IS NOT NULL AND reject_reason IS NULL AND cancel_reason IS NOT NULL))
);

CREATE UNIQUE INDEX "category_verification_requests_one_pending" ON "category_verification_requests"("user_id") WHERE (status = 'PENDING'::category_request_status);
CREATE INDEX "category_verification_requests_user_idx" ON "category_verification_requests"("user_id", "created_at" DESC);
CREATE INDEX "category_verification_requests_status_idx" ON "category_verification_requests"("status", "created_at" DESC);

ALTER TABLE "category_verification_requests" ADD CONSTRAINT "category_verification_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "category_verification_requests" ADD CONSTRAINT "category_verification_requests_decided_by_fkey" FOREIGN KEY ("decided_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 3. The featured pins.
CREATE TABLE "profile_featured_pins" (
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "position" SMALLINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_featured_pins_pkey" PRIMARY KEY ("user_id", "post_id"),
    CONSTRAINT "profile_featured_pins_position" CHECK (position BETWEEN 0 AND 5)
);

CREATE UNIQUE INDEX "profile_featured_pins_user_position_key" ON "profile_featured_pins"("user_id", "position");
CREATE INDEX "profile_featured_pins_post_idx" ON "profile_featured_pins"("post_id");

ALTER TABLE "profile_featured_pins" ADD CONSTRAINT "profile_featured_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "profile_featured_pins" ADD CONSTRAINT "profile_featured_pins_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
