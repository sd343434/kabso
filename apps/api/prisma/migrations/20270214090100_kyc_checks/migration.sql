-- v1.80-kyc (D227, CONVENTIONS §10.77; owner 2026-11-01): identity verification with Didit «تأكيد الهوية» for the
-- applicants «كن مضيفاً مع الإدارة» (D209), «افتح وكالة» (D206) and recharge agents (D185). The OWNER enters the Didit
-- API key, the webhook secret and the workflow ids in the admin panel (one `kyc_settings` row, the two secrets sealed
-- like D196 / D222). A check keeps only the minimum: Didit's session id and number, the status and decision, the
-- warning codes, the dates, the name, the date of birth (18+), the document's issuing country and the document
-- number as an HMAC. Never an image. The runtime role gets DML through the default privileges
-- (20261016130000_per_database_runtime_group): no GRANT.

-- CreateEnum
CREATE TYPE "kyc_purpose" AS ENUM ('HOST_APPLICATION', 'AGENCY_OPEN', 'RECHARGE_AGENT');

-- CreateEnum
CREATE TYPE "kyc_status" AS ENUM ('NOT_STARTED', 'IN_PROGRESS', 'IN_REVIEW', 'APPROVED', 'DECLINED', 'EXPIRED', 'ABANDONED');

-- CreateTable
CREATE TABLE "kyc_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "api_key_enc" TEXT,
    "api_key_last4" VARCHAR(4),
    "api_key_set_by_id" UUID,
    "api_key_set_at" TIMESTAMPTZ(3),
    "webhook_secret_enc" TEXT,
    "webhook_secret_last4" VARCHAR(4),
    "webhook_secret_set_by_id" UUID,
    "webhook_secret_set_at" TIMESTAMPTZ(3),
    "workflow_id" UUID,
    "workflow_id_host" UUID,
    "workflow_id_agency" UUID,
    "workflow_id_recharge" UUID,
    "max_sessions_per_day" SMALLINT NOT NULL DEFAULT 3,
    "last_test_at" TIMESTAMPTZ(3),
    "last_test_ok" BOOLEAN,
    "last_test_by_id" UUID,
    "last_test" JSONB,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "kyc_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kyc_checks" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "purpose" "kyc_purpose" NOT NULL,
    "status" "kyc_status" NOT NULL DEFAULT 'NOT_STARTED',
    "session_id" UUID NOT NULL,
    "session_number" INTEGER,
    "workflow_id" UUID NOT NULL,
    "provider_status" VARCHAR(32) NOT NULL,
    "reasons" VARCHAR(64)[] DEFAULT ARRAY[]::VARCHAR(64)[],
    "full_name" VARCHAR(200),
    "date_of_birth" DATE,
    "document_country" CHAR(3),
    "document_hash" CHAR(64),
    "duplicate_document" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decided_at" TIMESTAMPTZ(3),
    "last_event_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kyc_checks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kyc_webhook_events" (
    "event_id" VARCHAR(64) NOT NULL,
    "session_id" UUID,
    "type" VARCHAR(48) NOT NULL,
    "status" VARCHAR(32),
    "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kyc_webhook_events_pkey" PRIMARY KEY ("event_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "kyc_checks_session_key" ON "kyc_checks"("session_id");

-- CreateIndex
CREATE INDEX "kyc_checks_user_idx" ON "kyc_checks"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "kyc_checks_document_idx" ON "kyc_checks"("document_hash");

-- CreateIndex
CREATE INDEX "kyc_checks_status_idx" ON "kyc_checks"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "kyc_webhook_events_received_idx" ON "kyc_webhook_events"("received_at");

-- AddForeignKey
ALTER TABLE "kyc_checks" ADD CONSTRAINT "kyc_checks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CHECKs: one settings row; keys stored with their hint; the daily limit 1–10; switched on only when complete.
ALTER TABLE "kyc_settings" ADD CONSTRAINT "kyc_settings_shape" CHECK (
  id = 1
  AND ((api_key_enc IS NULL) = (api_key_last4 IS NULL))
  AND ((webhook_secret_enc IS NULL) = (webhook_secret_last4 IS NULL))
  AND max_sessions_per_day BETWEEN 1 AND 10
  AND (NOT enabled OR (api_key_enc IS NOT NULL AND webhook_secret_enc IS NOT NULL AND workflow_id IS NOT NULL)));

-- CHECKs: a decided check says when; a document hash is 64 hex; the country is 3 upper-case letters; at most 20
-- reasons.
ALTER TABLE "kyc_checks" ADD CONSTRAINT "kyc_checks_shape" CHECK (
  ((status IN ('APPROVED', 'DECLINED', 'IN_REVIEW')) <= (decided_at IS NOT NULL))
  AND (document_hash IS NULL OR document_hash ~ '^[0-9a-f]{64}$')
  AND (document_country IS NULL OR document_country ~ '^[A-Z]{3}$')
  AND coalesce(array_length(reasons, 1), 0) <= 20);

-- D185's recharge applications: with Didit on, the ID card and the selfie are no longer uploaded (the identity check
-- replaces them), so the two picture keys may be missing — both or neither.
ALTER TABLE "recharge_agent_applications" DROP CONSTRAINT "recharge_agent_applications_shape";
ALTER TABLE "recharge_agent_applications" ADD CONSTRAINT "recharge_agent_applications_shape" CHECK (
  ((status = 'PENDING') = (decided_at IS NULL))
  AND (status = 'REJECTED' OR reject_reason IS NULL)
  AND ((photo_key IS NULL) = (selfie_key IS NULL))
  AND (purged_at IS NOT NULL OR (full_name IS NOT NULL AND phone IS NOT NULL
       AND locations IS NOT NULL AND payment_methods IS NOT NULL)));
