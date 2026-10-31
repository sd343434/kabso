-- v1.70-social (D206, CONVENTIONS §10.65; owner 2026-10-31): «افتح وكالة» — a person opens a host agency
-- themselves (free; ID card + selfie as the D185 private uploads; no approval: the agency exists at once) and must
-- activate AGENCY_PROBATION_MIN_HOSTS hosts (joined, went live and received gifts) before `probation_ends_at`, or a
-- sweeper closes it (`status` CLOSED, `close_reason` PROBATION_FAILED; the hosts are released). Closed agencies stay
-- (earnings history; the owner's row is reused when they reopen, `agencies_owner_once` unchanged). Existing agencies
-- are OPEN, made by the team (ADMIN), without a probation. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT here.

-- CreateEnum
CREATE TYPE "agency_status" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "agency_origin" AS ENUM ('ADMIN', 'SELF');

-- CreateEnum
CREATE TYPE "agency_close_reason" AS ENUM ('PROBATION_FAILED', 'ADMIN');

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "agency_activated" INTEGER,
ADD COLUMN     "agency_id" UUID,
ADD COLUMN     "agency_required" INTEGER;

-- AlterTable
ALTER TABLE "agencies" ADD COLUMN     "close_note" VARCHAR(500),
ADD COLUMN     "close_reason" "agency_close_reason",
ADD COLUMN     "closed_at" TIMESTAMPTZ(3),
ADD COLUMN     "name" VARCHAR(40),
ADD COLUMN     "origin" "agency_origin" NOT NULL DEFAULT 'ADMIN',
ADD COLUMN     "probation_activated" INTEGER,
ADD COLUMN     "probation_ends_at" TIMESTAMPTZ(3),
ADD COLUMN     "probation_passed_at" TIMESTAMPTZ(3),
ADD COLUMN     "probation_reminded_at" TIMESTAMPTZ(3),
ADD COLUMN     "status" "agency_status" NOT NULL DEFAULT 'OPEN';

-- CreateTable
CREATE TABLE "agency_applications" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "client_key" UUID NOT NULL,
    "request_hash" CHAR(64) NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "country" CHAR(2) NOT NULL,
    "contact_type" VARCHAR(16) NOT NULL,
    "contact_value" VARCHAR(100),
    "expected_hosts" INTEGER NOT NULL,
    "bio" VARCHAR(300),
    "photo_key" VARCHAR(256),
    "selfie_key" VARCHAR(256),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "purged_at" TIMESTAMPTZ(3),

    CONSTRAINT "agency_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "agency_applications_agency_idx" ON "agency_applications"("agency_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "agency_applications_user_idx" ON "agency_applications"("user_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "agency_applications_client_once" ON "agency_applications"("user_id", "client_key");

-- CreateIndex
CREATE INDEX "agencies_probation_running_idx" ON "agencies"("probation_ends_at") WHERE (status = 'OPEN'::agency_status AND probation_ends_at IS NOT NULL AND probation_passed_at IS NULL);

-- CreateIndex
CREATE INDEX "agencies_status_closed_idx" ON "agencies"("status", "closed_at");

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CHECKs (the application rules, and a closed agency always says when and why).
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_expected_hosts_range"
  CHECK ("expected_hosts" BETWEEN 1 AND 10000);
ALTER TABLE "agency_applications" ADD CONSTRAINT "agency_applications_contact_type_known"
  CHECK ("contact_type" IN ('WHATSAPP', 'TELEGRAM', 'PHONE', 'EMAIL', 'OTHER'));
ALTER TABLE "agencies" ADD CONSTRAINT "agencies_closed_consistent"
  CHECK (("status" = 'CLOSED') = ("closed_at" IS NOT NULL AND "close_reason" IS NOT NULL));

-- The notifications of an agency (deleted with it).
CREATE INDEX "notifications_agency_idx" ON "notifications"("agency_id") WHERE "agency_id" IS NOT NULL;
