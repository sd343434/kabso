-- v1.66-social (D198, CONVENTIONS §10.61, CP-040): versioned legal documents, consent records and the personal-data
-- export «تنزيل بياناتي» (GDPR Art. 15/20, CCPA right to know). The runtime role gets DML through the default
-- privileges (20261016130000_per_database_runtime_group): no GRANT here. No backfill: until the owner publishes the
-- first versions with `legal-admin publish`, no consent is required (§10.61.2).

CREATE TYPE "legal_document_kind" AS ENUM ('TERMS', 'PRIVACY');
CREATE TYPE "consent_document" AS ENUM ('TERMS', 'PRIVACY', 'AGE_18', 'TOPUP_TERMS');
CREATE TYPE "data_export_status" AS ENUM ('PENDING', 'RUNNING', 'READY', 'DOWNLOADED', 'EXPIRED', 'FAILED');

-- One published version of the terms or the privacy policy. Written only by `legal-admin publish` (migration role,
-- audited); never updated by the API. The version in force is the latest one whose effective_at has passed.
CREATE TABLE "legal_documents" (
    "id" UUID NOT NULL,
    "kind" "legal_document_kind" NOT NULL,
    "version" VARCHAR(32) NOT NULL,
    "effective_at" TIMESTAMPTZ(3) NOT NULL,
    "published_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "content_hash" CHAR(64) NOT NULL,
    "url" VARCHAR(300) NOT NULL,
    "summary_ar" VARCHAR(2000) NOT NULL,
    "summary_en" VARCHAR(2000) NOT NULL,

    CONSTRAINT "legal_documents_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "legal_documents_kind_version_key" ON "legal_documents"("kind", "version");
CREATE INDEX "legal_documents_kind_effective_idx" ON "legal_documents"("kind", "effective_at" DESC);
ALTER TABLE "legal_documents" ADD CONSTRAINT "legal_documents_shape" CHECK (
  version ~ '^[0-9A-Za-z][0-9A-Za-z._-]{0,31}$'
  AND content_hash ~ '^[0-9a-f]{64}$'
  AND url ~ '^https://'
  AND length(btrim(summary_ar)) > 0 AND length(btrim(summary_en)) > 0);

-- Who accepted what, when and how. ip_truncated keeps an IPv4 /24 or an IPv6 /48 only; both it and user_agent are
-- cleared when the account is purged (D193), and the rows deleted with the tombstone's other records 7 years later.
CREATE TABLE "user_consents" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "document" "consent_document" NOT NULL,
    "version" VARCHAR(32) NOT NULL,
    "legal_document_id" UUID,
    "accepted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip_truncated" VARCHAR(64),
    "user_agent" VARCHAR(512),
    "method" VARCHAR(20) NOT NULL,

    CONSTRAINT "user_consents_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "user_consents_user_idx" ON "user_consents"("user_id", "document", "accepted_at" DESC);
CREATE UNIQUE INDEX "user_consents_once_per_document" ON "user_consents"("user_id", "legal_document_id")
  WHERE legal_document_id IS NOT NULL;
ALTER TABLE "user_consents" ADD CONSTRAINT "user_consents_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "user_consents" ADD CONSTRAINT "user_consents_legal_document_id_fkey"
  FOREIGN KEY ("legal_document_id") REFERENCES "legal_documents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "user_consents" ADD CONSTRAINT "user_consents_shape" CHECK (
  method IN ('REGISTRATION', 'IN_APP', 'TOPUP_WEBSITE', 'LUCKY_GIFT')
  AND ((document IN ('TERMS', 'PRIVACY')) = (legal_document_id IS NOT NULL))
  AND length(version) BETWEEN 1 AND 32);

-- «تنزيل بياناتي»: one export job. The ZIP lives in object storage under the private prefix
-- `private/data-exports/` (never public); only the SHA-256 of the single-use download token is kept.
CREATE TABLE "data_exports" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "data_export_status" NOT NULL DEFAULT 'PENDING',
    "requested_via" VARCHAR(10) NOT NULL,
    "requested_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "started_at" TIMESTAMPTZ(3),
    "ready_at" TIMESTAMPTZ(3),
    "expires_at" TIMESTAMPTZ(3),
    "downloaded_at" TIMESTAMPTZ(3),
    "object_key" VARCHAR(200),
    "size_bytes" INTEGER,
    "sha256" CHAR(64),
    "token_hash" CHAR(64),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "error" VARCHAR(200),

    CONSTRAINT "data_exports_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "data_exports_user_idx" ON "data_exports"("user_id", "requested_at" DESC);
CREATE INDEX "data_exports_status_idx" ON "data_exports"("status", "requested_at");
CREATE UNIQUE INDEX "data_exports_token_key" ON "data_exports"("token_hash") WHERE token_hash IS NOT NULL;
ALTER TABLE "data_exports" ADD CONSTRAINT "data_exports_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "data_exports" ADD CONSTRAINT "data_exports_shape" CHECK (
  requested_via IN ('APP', 'ADMIN')
  AND attempts >= 0
  AND (status <> 'READY' OR (object_key IS NOT NULL AND token_hash IS NOT NULL AND expires_at IS NOT NULL
                             AND ready_at IS NOT NULL))
  AND (status <> 'DOWNLOADED' OR downloaded_at IS NOT NULL)
  AND (object_key IS NULL OR object_key LIKE 'private/data-exports/%'));

-- What the person accepted at `register` (D198): kept with the pending registration until `register/verify` records
-- it in user_consents (the pending row is deleted then, or when it expires).
ALTER TABLE "pending_registrations" ADD COLUMN "legal_consent" JSONB;
