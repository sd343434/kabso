-- v1.78-social (D223, CONVENTIONS §10.75; owner 2026-11-01): «الجهاز الواحد لا يمكنه عمل غير حسابين» — one device can
-- create at most SIGNUP_MAX_ACCOUNTS_PER_DEVICE (2) accounts; signing in is never limited. The app sends
-- `DeviceInfo.deviceKey` (a salted SHA-256 of ANDROID_ID / the iOS Keychain id); the server keeps only an HMAC of it
-- under its own key. The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group):
-- no GRANT. No backfill: accounts made before this have no device and never count.

-- The pending sign-up keeps the device from `register` until `registerVerify`.
ALTER TABLE "pending_registrations" ADD COLUMN "device_hash" CHAR(64);

-- One row per account created with a device id; kept when the account is deleted (the tombstone row stays), so
-- delete-and-recreate does not free a place.
CREATE TABLE "device_signups" (
    "user_id" UUID NOT NULL,
    "device_hash" CHAR(64) NOT NULL,
    "platform" VARCHAR(16),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_signups_pkey" PRIMARY KEY ("user_id")
);
CREATE INDEX "device_signups_device_idx" ON "device_signups"("device_hash", "created_at");
ALTER TABLE "device_signups" ADD CONSTRAINT "device_signups_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "device_signups" ADD CONSTRAINT "device_signups_hash_shape" CHECK (device_hash ~ '^[0-9a-f]{64}$');

-- An OWNER's exception for one device (panel, the authenticator code again, a reason, audited).
CREATE TABLE "device_signup_exceptions" (
    "device_hash" CHAR(64) NOT NULL,
    "max_accounts" INTEGER NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "granted_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "device_signup_exceptions_pkey" PRIMARY KEY ("device_hash")
);
ALTER TABLE "device_signup_exceptions" ADD CONSTRAINT "device_signup_exceptions_granted_by_id_fkey"
  FOREIGN KEY ("granted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "device_signup_exceptions" ADD CONSTRAINT "device_signup_exceptions_shape"
  CHECK (device_hash ~ '^[0-9a-f]{64}$' AND max_accounts BETWEEN 1 AND 100);
