-- v1.62-social (D193, CONVENTIONS §10.56, CP-036): account deletion «حذف الحساب». A request puts the account in
-- PENDING_DELETION (hidden, signed out) for the grace period; signing in again may cancel it; after it the sweeper
-- turns the account into a tombstone (personal data and content removed, the financial and audit rows kept under the
-- same random id). The runtime role gets DML through the default privileges: no GRANT here.

CREATE TYPE "account_deletion_status" AS ENUM ('PENDING', 'CANCELLED', 'PURGED');

CREATE TABLE "account_deletion_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "account_deletion_status" NOT NULL DEFAULT 'PENDING',
    "requested_via" VARCHAR(10) NOT NULL,
    "requested_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "purge_after" TIMESTAMPTZ(3) NOT NULL,
    "cancelled_at" TIMESTAMPTZ(3),
    "cancelled_via" VARCHAR(10),
    "purged_at" TIMESTAMPTZ(3),
    "purged_via" VARCHAR(10),

    CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "account_deletion_requests_one_pending" ON "account_deletion_requests"("user_id")
  WHERE status = 'PENDING'::account_deletion_status;
CREATE INDEX "account_deletion_requests_due_idx" ON "account_deletion_requests"("purge_after")
  WHERE status = 'PENDING'::account_deletion_status;
CREATE INDEX "account_deletion_requests_user_idx" ON "account_deletion_requests"("user_id", "requested_at" DESC);

ALTER TABLE "account_deletion_requests" ADD CONSTRAINT "account_deletion_requests_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "account_deletion_requests" ADD CONSTRAINT "account_deletion_requests_shape" CHECK (
  requested_via IN ('APP', 'ADMIN')
  AND purge_after >= requested_at
  AND (status = 'CANCELLED') = (cancelled_at IS NOT NULL)
  AND (cancelled_at IS NULL) = (cancelled_via IS NULL)
  AND (cancelled_via IS NULL OR cancelled_via IN ('APP', 'ADMIN'))
  AND (status = 'PURGED') = (purged_at IS NOT NULL)
  AND (purged_at IS NULL) = (purged_via IS NULL)
  AND (purged_via IS NULL OR purged_via IN ('SWEEPER', 'ADMIN')));

-- The regular username of a purged account, quarantined (only its SHA-256; no link to the tombstone).
CREATE TABLE "deleted_usernames" (
    "name_hash" CHAR(64) NOT NULL,
    "until" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "deleted_usernames_pkey" PRIMARY KEY ("name_hash")
);
CREATE INDEX "deleted_usernames_until_idx" ON "deleted_usernames"("until");
ALTER TABLE "deleted_usernames" ADD CONSTRAINT "deleted_usernames_hash_shape" CHECK (name_hash ~ '^[0-9a-f]{64}$');
