-- v1.72-social (D208, CONVENTIONS §10.67): the admin panel's account controls «تحكم كامل» — temporary locks and
-- restrictions, a forced password change, balance adjustments by the team. The runtime role gets DML through the
-- default privileges (20261016130000_per_database_runtime_group): no GRANT here. No backfill.

CREATE TYPE "account_restriction_kind" AS ENUM ('LOCK', 'CHAT_MUTE', 'NO_LIVE', 'NO_GIFTS', 'NO_POSTING');

ALTER TYPE "wallet_ledger_reason" ADD VALUE 'ADMIN_ADJUSTMENT';
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'ADMIN_ADJUSTMENT';
ALTER TYPE "notification_type" ADD VALUE 'ACCOUNT_RESTRICTED';
ALTER TYPE "notification_type" ADD VALUE 'ACCOUNT_RESTRICTION_LIFTED';
ALTER TYPE "notification_type" ADD VALUE 'BALANCE_ADJUSTED';
ALTER TYPE "notification_type" ADD VALUE 'PROFILE_EDITED_BY_TEAM';

-- The ledgers' sign rules (`*_ledger_reason_sign`) list every reason with its sign; ADMIN_ADJUSTMENT is either sign
-- (credit or debit, never 0). The current rule is extended in place — read from the catalogue, not restated — so a
-- branch that changed the list before this migration (e.g. a new reason) keeps its change. `reason::text` because a
-- value added above cannot be used as an enum literal in the same transaction.
DO $$
DECLARE
  t text;
  def text;
BEGIN
  FOREACH t IN ARRAY ARRAY['wallet_ledger', 'cherry_ledger'] LOOP
    SELECT pg_get_constraintdef(c.oid) INTO STRICT def
      FROM pg_constraint c
     WHERE c.conrelid = t::regclass AND c.conname = t || '_reason_sign';
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', t, t || '_reason_sign');
    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I CHECK ((%s) OR (reason::text = %L AND delta <> 0))',
                   t, t || '_reason_sign', substring(def FROM '^CHECK \((.*)\)$'), 'ADMIN_ADJUSTMENT');
  END LOOP;
END
$$;

-- Set by a temporary password or «فرض تغيير كلمة المرور»; cleared by the sign-in that chooses a new password.
ALTER TABLE "users" ADD COLUMN "password_change_required_at" TIMESTAMPTZ(3);

-- A temporary lock (no sign-in) or restriction set by the team. Active while lifted_at IS NULL and
-- starts_at <= now() < ends_at. The reason is shown to the person.
CREATE TABLE "account_restrictions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" "account_restriction_kind" NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by_id" UUID,
    "via" VARCHAR(10) NOT NULL,
    "lifted_at" TIMESTAMPTZ(3),
    "lifted_by_id" UUID,
    "lift_reason" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_restrictions_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "account_restrictions_open_idx" ON "account_restrictions"("user_id", "kind", "ends_at" DESC)
  WHERE lifted_at IS NULL;
CREATE INDEX "account_restrictions_user_idx" ON "account_restrictions"("user_id", "created_at" DESC);
ALTER TABLE "account_restrictions" ADD CONSTRAINT "account_restrictions_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "account_restrictions" ADD CONSTRAINT "account_restrictions_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "account_restrictions" ADD CONSTRAINT "account_restrictions_lifted_by_id_fkey"
  FOREIGN KEY ("lifted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "account_restrictions" ADD CONSTRAINT "account_restrictions_shape" CHECK (
  ends_at > starts_at
  AND via IN ('panel', 'cli')
  AND length(btrim(reason)) > 0
  AND (lifted_at IS NOT NULL OR lift_reason IS NULL));

-- A credit (> 0) or debit (< 0) of coins or cherries by the team, with the ledger row it wrote (ADMIN_ADJUSTMENT,
-- reference = this id). The per-admin daily cap sums |delta| of the admin's rows of the day.
CREATE TABLE "admin_balance_adjustments" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "actor_user_id" UUID,
    "currency" VARCHAR(10) NOT NULL,
    "delta" BIGINT NOT NULL,
    "balance_before" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "allow_negative" BOOLEAN NOT NULL DEFAULT false,
    "reason" VARCHAR(500) NOT NULL,
    "via" VARCHAR(10) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_balance_adjustments_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "admin_balance_adjustments_actor_idx" ON "admin_balance_adjustments"("actor_user_id", "created_at");
CREATE INDEX "admin_balance_adjustments_user_idx" ON "admin_balance_adjustments"("user_id", "created_at" DESC);
ALTER TABLE "admin_balance_adjustments" ADD CONSTRAINT "admin_balance_adjustments_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "admin_balance_adjustments" ADD CONSTRAINT "admin_balance_adjustments_actor_user_id_fkey"
  FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "admin_balance_adjustments" ADD CONSTRAINT "admin_balance_adjustments_shape" CHECK (
  currency IN ('COINS', 'CHERRIES')
  AND delta <> 0
  AND balance_after = balance_before + delta
  AND (allow_negative OR balance_after >= 0)
  AND via IN ('panel', 'cli'));

ALTER TABLE "notifications" ADD COLUMN "account_restriction_id" UUID;
ALTER TABLE "notifications" ADD COLUMN "balance_adjustment_id" UUID;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_account_restriction_id_fkey"
  FOREIGN KEY ("account_restriction_id") REFERENCES "account_restrictions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_balance_adjustment_id_fkey"
  FOREIGN KEY ("balance_adjustment_id") REFERENCES "admin_balance_adjustments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
