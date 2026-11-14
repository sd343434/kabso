-- v1.108-social (D343, CONVENTIONS §10.142). Owner: «في انشاء الحساب هناك صندوق يدخل شخص اما رمز الدعوة او رمز المشرف
-- الذي استقطبه … النظام يعرف ان كان الشخص قام بتحميل التطبيق قبل المرة يلا يعتبره مستخدم جديد ولا حالة استقطاب».
-- One sign-up field takes a friend's invite code (D217) or a supervisor's staff ID (D285); the credit is withheld,
-- with the reason, when the device already had a Kabso account or the mailbox was registered before.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

CREATE TYPE "signup_credit_status" AS ENUM ('GRANTED', 'WITHHELD');

-- An account created with a supervisor's staff ID (one row per account, written once at the account's creation).
CREATE TABLE "staff_signup_recruits" (
    "user_id" UUID NOT NULL,
    "recruiter_user_id" UUID NOT NULL,
    "code" VARCHAR(16) NOT NULL,
    "status" "signup_credit_status" NOT NULL,
    "withhold_reason" VARCHAR(32),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "staff_signup_recruits_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "staff_signup_recruits_reason" CHECK (("status" = 'WITHHELD') = ("withhold_reason" IS NOT NULL))
);
CREATE INDEX "staff_signup_recruits_recruiter_idx" ON "staff_signup_recruits"("recruiter_user_id", "created_at" DESC);
CREATE INDEX "staff_signup_recruits_status_idx" ON "staff_signup_recruits"("status", "created_at" DESC);
ALTER TABLE "staff_signup_recruits" ADD CONSTRAINT "staff_signup_recruits_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_signup_recruits" ADD CONSTRAINT "staff_signup_recruits_recruiter_user_id_fkey"
    FOREIGN KEY ("recruiter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The keyed hash (HMAC-SHA-256 under the server's key) of the canonical mailbox an account was created with. Written by
-- the API at the account's creation; accounts that existed before this migration get theirs from the referral sweeper
-- (the key is not in the database, so SQL cannot compute it). `purged_at` starts the retention after a purge.
CREATE TABLE "signup_email_marks" (
    "user_id" UUID NOT NULL,
    "email_hash" CHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "purged_at" TIMESTAMPTZ(3),
    CONSTRAINT "signup_email_marks_pkey" PRIMARY KEY ("user_id")
);
CREATE INDEX "signup_email_marks_hash_idx" ON "signup_email_marks"("email_hash");
CREATE INDEX "signup_email_marks_purged_idx" ON "signup_email_marks"("purged_at") WHERE purged_at IS NOT NULL;
ALTER TABLE "signup_email_marks" ADD CONSTRAINT "signup_email_marks_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The «not a new person» check reads every session of a device (signed out ones too), not only the open ones.
CREATE INDEX "sessions_device_hash_all_idx" ON "sessions"("device_hash") WHERE device_hash IS NOT NULL;
