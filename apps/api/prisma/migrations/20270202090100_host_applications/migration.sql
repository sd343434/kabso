-- v1.73-social (D209, CONVENTIONS §10.68; owner 2026-10-31): «كن مضيفاً مع الإدارة» — a person in no agency applies
-- to host directly with the Kabso team (ID card + selfie as the D185 private uploads, date of birth ≥ 18, the host
-- rules accepted). The team approves (a `live_hosts` row with source IDENTITY, `granted_by_id` the admin) or rejects
-- with a reason (the person may apply again after HOST_APPLICATION_REAPPLY_DAYS). One PENDING application per user.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT.

-- CreateEnum
CREATE TYPE "host_application_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

-- CreateTable
CREATE TABLE "host_applications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "host_application_status" NOT NULL DEFAULT 'PENDING',
    "client_key" UUID NOT NULL,
    "request_hash" CHAR(64) NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "country" CHAR(2) NOT NULL,
    "date_of_birth" DATE,
    "contact_type" VARCHAR(16) NOT NULL,
    "contact_value" VARCHAR(100),
    "bio" VARCHAR(300),
    "links" VARCHAR(200)[] DEFAULT ARRAY[]::VARCHAR(200)[],
    "photo_key" VARCHAR(256),
    "selfie_key" VARCHAR(256),
    "rules_accepted_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "decided_by_id" UUID,
    "reject_reason" VARCHAR(500),
    "cancel_reason" VARCHAR(16),
    "purged_at" TIMESTAMPTZ(3),

    CONSTRAINT "host_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "host_applications_user_idx" ON "host_applications"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "host_applications_status_idx" ON "host_applications"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "host_applications_decided_by_idx" ON "host_applications"("decided_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "host_applications_client_once" ON "host_applications"("user_id", "client_key");

-- AddForeignKey
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- One open application per user (the race of two submits ends in a unique violation, answered 409).
CREATE UNIQUE INDEX "host_applications_one_pending" ON "host_applications"("user_id") WHERE "status" = 'PENDING';

-- CHECKs: the contact methods of §10.68, at most 3 links, a decided application says when (and a rejection why),
-- a cancelled one why.
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_contact_type_known"
  CHECK ("contact_type" IN ('WHATSAPP', 'TELEGRAM', 'PHONE', 'EMAIL', 'OTHER'));
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_links_max"
  CHECK (cardinality("links") <= 3);
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_decided_consistent"
  CHECK (("status" = 'PENDING') = ("decided_at" IS NULL));
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_rejected_reason"
  CHECK ("status" <> 'REJECTED' OR "reject_reason" IS NOT NULL);
ALTER TABLE "host_applications" ADD CONSTRAINT "host_applications_cancel_reason"
  CHECK (("status" = 'CANCELLED') = ("cancel_reason" IS NOT NULL));
