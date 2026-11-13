-- v1.74-social (D217, CONVENTIONS §10.71; owner 2026-11-01): «دعوة الأصدقاء» — invite codes, referrals and their
-- rewards in withdrawable cherries (ledger reason REFERRAL_REWARD), held REFERRAL hold hours before they are
-- credited, with the fraud checks (device, email alias, IP, daily cap) and the settings the panel edits. The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT. No backfill.

-- CreateEnum
CREATE TYPE "referral_status" AS ENUM ('PENDING', 'QUALIFIED', 'REJECTED', 'VOID');
CREATE TYPE "referral_reward_kind" AS ENUM ('SIGNUP_INVITER', 'SIGNUP_INVITEE', 'FIRST_RECHARGE', 'MILESTONE');
CREATE TYPE "referral_reward_status" AS ENUM ('PENDING', 'CREDITED', 'VOID', 'REVERSED');

-- The ledgers' sign rule: REFERRAL_REWARD is a credit, REFERRAL_REVERSAL (the claw-back) a debit. Extended in place (read from the catalogue, not restated), as
-- 20270130090000_admin_control did, so a branch that changed the list before keeps its change.
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'cherry_ledger'::regclass AND c.conname = 'cherry_ledger_reason_sign';
  ALTER TABLE "cherry_ledger" DROP CONSTRAINT "cherry_ledger_reason_sign";
  EXECUTE format('ALTER TABLE cherry_ledger ADD CONSTRAINT cherry_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0) OR (reason::text = %L AND delta < 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'REFERRAL_REWARD', 'REFERRAL_REVERSAL');
END
$$;

-- The app's install id (`DeviceInfo.installId`: a random id kept by the app until it is uninstalled), on the session
-- and on the pending sign-up; the code typed at sign-up. Nullable: older apps send neither.
ALTER TABLE "sessions" ADD COLUMN "install_id" VARCHAR(64);
CREATE INDEX "sessions_install_id_idx" ON "sessions"("install_id") WHERE install_id IS NOT NULL;
ALTER TABLE "pending_registrations" ADD COLUMN "install_id" VARCHAR(64);
ALTER TABLE "pending_registrations" ADD COLUMN "referral_code" VARCHAR(16);

-- One row (id 1): every amount and rule of the programme, edited in the panel (FINANCE / OWNER, code again, audited).
CREATE TABLE "referral_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "inviter_signup_cherries" BIGINT NOT NULL DEFAULT 20000,
    "invitee_signup_cherries" BIGINT NOT NULL DEFAULT 0,
    "first_recharge_bps" INTEGER NOT NULL DEFAULT 500,
    "milestones" JSONB NOT NULL DEFAULT '[{"friends":1,"cherries":50000},{"friends":5,"cherries":300000},{"friends":15,"cherries":1000000}]',
    "daily_signup_cap" INTEGER NOT NULL DEFAULT 20,
    "hold_hours" INTEGER NOT NULL DEFAULT 24,
    "apply_window_days" INTEGER NOT NULL DEFAULT 7,
    "self_ip_window_hours" INTEGER NOT NULL DEFAULT 24,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "referral_settings_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "referral_settings" ADD CONSTRAINT "referral_settings_shape" CHECK (
  id = 1
  AND inviter_signup_cherries BETWEEN 0 AND 100000000
  AND invitee_signup_cherries BETWEEN 0 AND 100000000
  AND first_recharge_bps BETWEEN 0 AND 5000
  AND jsonb_typeof(milestones) = 'array' AND jsonb_array_length(milestones) <= 5
  AND daily_signup_cap BETWEEN 0 AND 1000
  AND hold_hours BETWEEN 0 AND 720
  AND apply_window_days BETWEEN 0 AND 90
  AND self_ip_window_hours BETWEEN 0 AND 720);
INSERT INTO "referral_settings" ("id") VALUES (1);

-- A person's invite code: stable once made, unique, 8 characters without look-alikes.
CREATE TABLE "referral_codes" (
    "user_id" UUID NOT NULL,
    "code" VARCHAR(16) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "referral_codes_pkey" PRIMARY KEY ("user_id")
);
CREATE UNIQUE INDEX "referral_codes_code_key" ON "referral_codes"("code");
ALTER TABLE "referral_codes" ADD CONSTRAINT "referral_codes_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "referral_codes" ADD CONSTRAINT "referral_codes_shape" CHECK (code ~ '^[A-Z0-9]{6,16}$');

-- Who invited whom (one inviter per person, ever). REJECTED: refused by a fraud rule at the start (`reject_reason`);
-- VOID: voided later (the hold's re-check or the team); a referral the team approves or voids keeps its reject
-- reason. The invitee's install id, IP and the SHA-256 of their canonical mailbox are kept for the duplicate checks and
-- the team; the IP is cleared when the account is purged (D193).
CREATE TABLE "referrals" (
    "id" UUID NOT NULL,
    "inviter_user_id" UUID NOT NULL,
    "invitee_user_id" UUID NOT NULL,
    "code" VARCHAR(16) NOT NULL,
    "source" VARCHAR(8) NOT NULL,
    "status" "referral_status" NOT NULL DEFAULT 'PENDING',
    "reject_reason" VARCHAR(32),
    "invitee_install_id" VARCHAR(64),
    "invitee_ip" VARCHAR(64),
    "invitee_email_hash" CHAR(64) NOT NULL,
    "hold_until" TIMESTAMPTZ(3) NOT NULL,
    "first_recharge_at" TIMESTAMPTZ(3),
    "qualified_at" TIMESTAMPTZ(3),
    "voided_at" TIMESTAMPTZ(3),
    "void_reason" VARCHAR(500),
    "decided_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "referrals_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "referrals_invitee_key" ON "referrals"("invitee_user_id");
CREATE INDEX "referrals_inviter_idx" ON "referrals"("inviter_user_id", "created_at" DESC);
CREATE INDEX "referrals_status_idx" ON "referrals"("status", "created_at" DESC);
CREATE INDEX "referrals_due_idx" ON "referrals"("hold_until") WHERE status = 'PENDING';
CREATE INDEX "referrals_install_idx" ON "referrals"("invitee_install_id") WHERE invitee_install_id IS NOT NULL;
CREATE INDEX "referrals_email_idx" ON "referrals"("invitee_email_hash");
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_inviter_user_id_fkey"
  FOREIGN KEY ("inviter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_invitee_user_id_fkey"
  FOREIGN KEY ("invitee_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_decided_by_id_fkey"
  FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_shape" CHECK (
  inviter_user_id <> invitee_user_id
  AND source IN ('SIGNUP', 'LATER')
  AND (status <> 'REJECTED' OR reject_reason IS NOT NULL)
  AND ((status = 'QUALIFIED') = (qualified_at IS NOT NULL) OR status = 'VOID')
  AND ((status = 'VOID') = (voided_at IS NOT NULL)));

-- A reward: to the inviter for the sign-up, to the invitee (0 by default: none), to the inviter for the invitee's
-- first recharge (a percentage of its coin value in cherries), or a milestone bonus (no referral). PENDING until
-- `hold_until`, then CREDITED (one ledger row REFERRAL_REWARD, reference = the reward id) or VOID. REVERSED: credited,
-- then taken back when the team voided the referral (one ledger row REFERRAL_REVERSAL, reference = the reward id; the
-- balance may go below 0 — `reversal_shortfall` is the part the balance did not cover, a debt that blocks withdrawals
-- until it is earned back). A REVERSED row frees its kind (or milestone) for a new reward if the team approves again.
CREATE TABLE "referral_rewards" (
    "id" UUID NOT NULL,
    "referral_id" UUID,
    "user_id" UUID NOT NULL,
    "kind" "referral_reward_kind" NOT NULL,
    "status" "referral_reward_status" NOT NULL DEFAULT 'PENDING',
    "cherries" BIGINT NOT NULL,
    "hold_until" TIMESTAMPTZ(3) NOT NULL,
    "base_coins" BIGINT,
    "rate_bps" INTEGER,
    "recharge_reason" VARCHAR(20),
    "recharge_reference" VARCHAR(64),
    "milestone_friends" INTEGER,
    "credited_at" TIMESTAMPTZ(3),
    "voided_at" TIMESTAMPTZ(3),
    "reversed_at" TIMESTAMPTZ(3),
    "reversal_shortfall" BIGINT,
    "void_reason" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "referral_rewards_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "referral_rewards_referral_kind_key" ON "referral_rewards"("referral_id", "kind")
  WHERE referral_id IS NOT NULL AND status <> 'REVERSED';
CREATE UNIQUE INDEX "referral_rewards_milestone_key" ON "referral_rewards"("user_id", "milestone_friends")
  WHERE kind = 'MILESTONE' AND status <> 'REVERSED';
CREATE INDEX "referral_rewards_user_idx" ON "referral_rewards"("user_id", "created_at" DESC);
CREATE INDEX "referral_rewards_due_idx" ON "referral_rewards"("hold_until") WHERE status = 'PENDING';
CREATE INDEX "referral_rewards_credited_idx" ON "referral_rewards"("credited_at" DESC) WHERE status = 'CREDITED';
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_referral_id_fkey"
  FOREIGN KEY ("referral_id") REFERENCES "referrals"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_shape" CHECK (
  cherries > 0
  AND ((kind = 'MILESTONE') = (referral_id IS NULL))
  AND ((kind = 'MILESTONE') = (milestone_friends IS NOT NULL))
  AND ((kind = 'FIRST_RECHARGE') = (base_coins IS NOT NULL AND rate_bps IS NOT NULL AND recharge_reference IS NOT NULL))
  AND ((status IN ('CREDITED', 'REVERSED')) = (credited_at IS NOT NULL))
  AND ((status = 'VOID') = (voided_at IS NOT NULL))
  AND ((status = 'REVERSED') = (reversed_at IS NOT NULL AND reversal_shortfall IS NOT NULL))
  AND (reversal_shortfall IS NULL OR reversal_shortfall BETWEEN 0 AND cherries));
