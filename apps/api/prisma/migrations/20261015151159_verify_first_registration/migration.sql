-- AlterTable
ALTER TABLE "sessions" ADD COLUMN     "rotated_refresh_token_hashes" CHAR(64)[] DEFAULT ARRAY[]::CHAR(64)[];

-- AlterTable
ALTER TABLE "user_profiles" ALTER COLUMN "display_name" SET DATA TYPE VARCHAR(100);

-- CreateTable
CREATE TABLE "pending_registrations" (
    "id" UUID NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "locale" VARCHAR(8) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "device_name" VARCHAR(100),
    "platform" VARCHAR(16),
    "app_version" VARCHAR(32),
    "ip" VARCHAR(64),
    "user_agent" VARCHAR(512),
    "code_hash" CHAR(64) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pending_registrations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pending_registrations_email_key" ON "pending_registrations"("email");

-- CreateIndex
CREATE UNIQUE INDEX "pending_registrations_username_key" ON "pending_registrations"("username");

-- CreateIndex
CREATE INDEX "pending_registrations_expires_at_idx" ON "pending_registrations"("expires_at");

-- Hand-written CHECK constraints (not modelled by Prisma).
-- SEC-022: the rotated-secret history is bounded to the last 10 hashes.
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_rotated_hashes_bounded"
    CHECK (cardinality("rotated_refresh_token_hashes") <= 10);

-- Pending registrations mirror the account constraints (contract v1.2 §6).
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_username_format"
    CHECK ("username" ~ '^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$');
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_email_normalized"
    CHECK ("email" = lower(btrim("email")));
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_locale_valid"
    CHECK ("locale" IN ('ar', 'en'));
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_platform_valid"
    CHECK ("platform" IS NULL OR "platform" IN ('android', 'ios', 'web', 'other'));
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_attempts_range"
    CHECK ("attempts" BETWEEN 0 AND 5);
