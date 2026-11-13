-- v1.139-social (D387, owner 2026-11-12), CONVENTIONS §10.176: the operations staff roles.
--
-- 1. The wallet ledger's sign rule: STAFF_COMPENSATION is a credit.
-- 2. `staff_schedule_slots`: the weekly shift schedule «جدول المناوبات» — one slot of one staff member, a weekday
--    (1 Monday … 7 Sunday) and minutes of the day in the app's time zone (LIVE_RANKINGS_TIME_ZONE, D99); CHECK
--    `staff_schedule_slots_shape`. The API refuses overlaps per person and people without a schedulable role.
-- 3. `staff_compensation_settings` (one row, CHECK `staff_compensation_settings_one`) and `staff_compensations`: the
--    VIP_CARE compensations (coins, VIP days or a store item) with their value in coins, status and decision; CHECKs
--    `staff_compensations_kind_shape`, `staff_compensations_status_values`, `staff_compensations_decision`.
-- 4. `official_social_accounts`: the app's official social media accounts — links only (https, CHECK
--    `official_social_accounts_url_https`); no password, token or key column exists or may be added (D40).
-- 5. `kabso_admin_panel_role(...)` accepts the four new roles (each gets its staff ID like the others).
--
-- New tables get their runtime grants from the default privileges (KL-013, migration 20261016130000).
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- 1. The ledger reason's sign (read from the catalogue, not restated, as 20270513090000_vip_gift_perks did).
DO $$
DECLARE
  def text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO STRICT def
    FROM pg_constraint c
   WHERE c.conrelid = 'wallet_ledger'::regclass AND c.conname = 'wallet_ledger_reason_sign';
  ALTER TABLE "wallet_ledger" DROP CONSTRAINT "wallet_ledger_reason_sign";
  EXECUTE format('ALTER TABLE wallet_ledger ADD CONSTRAINT wallet_ledger_reason_sign CHECK ((%s) OR (reason::text = %L AND delta > 0))',
                 substring(def FROM '^CHECK \((.*)\)$'), 'STAFF_COMPENSATION');
END
$$;

-- 2. The shift schedule.
CREATE TABLE "staff_schedule_slots" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "weekday" SMALLINT NOT NULL,
    "start_minute" SMALLINT NOT NULL,
    "end_minute" SMALLINT NOT NULL,
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_schedule_slots_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "staff_schedule_slots_shape" CHECK (
      weekday BETWEEN 1 AND 7 AND start_minute BETWEEN 0 AND 1439 AND end_minute BETWEEN 1 AND 1440
      AND end_minute > start_minute)
);

CREATE INDEX "staff_schedule_slots_day_idx" ON "staff_schedule_slots"("weekday", "start_minute");
CREATE INDEX "staff_schedule_slots_user_idx" ON "staff_schedule_slots"("user_id", "weekday", "start_minute");

ALTER TABLE "staff_schedule_slots" ADD CONSTRAINT "staff_schedule_slots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_schedule_slots" ADD CONSTRAINT "staff_schedule_slots_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 3. Compensations.
CREATE TABLE "staff_compensation_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "daily_limit_coins" BIGINT NOT NULL DEFAULT 50000,
    "per_grant_max_coins" BIGINT NOT NULL DEFAULT 10000,
    "updated_at" TIMESTAMPTZ(3),
    "updated_by_id" UUID,

    CONSTRAINT "staff_compensation_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "staff_compensation_settings_one" CHECK (id = 1),
    CONSTRAINT "staff_compensation_settings_range" CHECK (
      daily_limit_coins BETWEEN 0 AND 1000000000 AND per_grant_max_coins BETWEEN 0 AND 1000000000)
);

ALTER TABLE "staff_compensation_settings" ADD CONSTRAINT "staff_compensation_settings_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "staff_compensations" (
    "id" UUID NOT NULL,
    "staff_id" UUID,
    "user_id" UUID NOT NULL,
    "kind" VARCHAR(10) NOT NULL,
    "coins" BIGINT,
    "days" INTEGER,
    "vip_tier_id" UUID,
    "item_code" VARCHAR(40),
    "value_coins" BIGINT NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "status" VARCHAR(10) NOT NULL,
    "over_limit" VARCHAR(10),
    "decided_by_id" UUID,
    "decided_at" TIMESTAMPTZ(3),
    "decision_note" VARCHAR(500),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_compensations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "staff_compensations_kind_shape" CHECK (
      (kind = 'COINS' AND coins BETWEEN 1 AND 1000000000 AND days IS NULL AND vip_tier_id IS NULL AND item_code IS NULL)
      OR (kind = 'VIP_DAYS' AND coins IS NULL AND days BETWEEN 1 AND 365 AND vip_tier_id IS NOT NULL AND item_code IS NULL)
      OR (kind = 'ITEM' AND coins IS NULL AND days IN (7, 14, 30) AND vip_tier_id IS NULL AND item_code IS NOT NULL)),
    CONSTRAINT "staff_compensations_value_positive" CHECK (value_coins > 0),
    CONSTRAINT "staff_compensations_status_values" CHECK (
      status IN ('GRANTED', 'PENDING', 'APPROVED', 'REJECTED')
      AND (over_limit IS NULL OR over_limit IN ('per_grant', 'daily'))),
    CONSTRAINT "staff_compensations_decision" CHECK (
      (status IN ('GRANTED', 'PENDING') AND decided_at IS NULL)
      OR (status IN ('APPROVED', 'REJECTED') AND decided_at IS NOT NULL))
);

CREATE INDEX "staff_compensations_staff_idx" ON "staff_compensations"("staff_id", "created_at" DESC);
CREATE INDEX "staff_compensations_status_idx" ON "staff_compensations"("status", "created_at" DESC);
CREATE INDEX "staff_compensations_user_idx" ON "staff_compensations"("user_id");

ALTER TABLE "staff_compensations" ADD CONSTRAINT "staff_compensations_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "staff_compensations" ADD CONSTRAINT "staff_compensations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_compensations" ADD CONSTRAINT "staff_compensations_vip_tier_id_fkey" FOREIGN KEY ("vip_tier_id") REFERENCES "vip_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "staff_compensations" ADD CONSTRAINT "staff_compensations_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 4. The official social accounts (links only).
CREATE TABLE "official_social_accounts" (
    "id" UUID NOT NULL,
    "platform" VARCHAR(16) NOT NULL,
    "handle" VARCHAR(64) NOT NULL,
    "url" VARCHAR(512) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by_id" UUID,

    CONSTRAINT "official_social_accounts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "official_social_accounts_platform_values" CHECK (platform IN ('INSTAGRAM', 'TIKTOK', 'X', 'FACEBOOK',
      'YOUTUBE', 'SNAPCHAT', 'TELEGRAM', 'WHATSAPP', 'THREADS', 'LINKEDIN', 'DISCORD', 'OTHER')),
    CONSTRAINT "official_social_accounts_handle_length" CHECK (char_length(handle) BETWEEN 1 AND 64),
    CONSTRAINT "official_social_accounts_url_https" CHECK (url LIKE 'https://%')
);

CREATE INDEX "official_social_accounts_order_idx" ON "official_social_accounts"("sort_order", "id");

ALTER TABLE "official_social_accounts" ADD CONSTRAINT "official_social_accounts_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- 5. The roles function accepts the four new roles.
CREATE OR REPLACE FUNCTION public.kabso_admin_panel_role(p_user uuid, p_role text, p_grant boolean, p_by uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  changed integer;
BEGIN
  -- v1.75-live (D285): BD «تطوير الأعمال». v1.139-social (D387): LIVE_OPS, TALENT, VIP_CARE, COMMUNITY.
  IF p_role NOT IN ('OWNER', 'MODERATION', 'SUPPORT', 'FINANCE', 'BD', 'LIVE_OPS', 'TALENT', 'VIP_CARE', 'COMMUNITY') THEN
    RAISE EXCEPTION 'kabso_admin_panel_role: % is not a panel role', p_role USING ERRCODE = '22023';
  END IF;
  IF p_grant THEN
    INSERT INTO user_admin_permissions (user_id, permission, granted_by_id)
    VALUES (p_user, p_role::admin_permission, p_by)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS changed = ROW_COUNT;
    -- v1.73-live (D283c) / v1.74-live (D283d): the staff ID in this transaction («Kabso» for the primary OWNER).
    PERFORM kabso_assign_staff_id(p_user, p_role = 'OWNER');
  ELSE
    DELETE FROM user_admin_permissions WHERE user_id = p_user AND permission = p_role::admin_permission;
    GET DIAGNOSTICS changed = ROW_COUNT;
  END IF;
  RETURN changed > 0;
END
$fn$;

INSERT INTO "staff_compensation_settings" ("id") VALUES (1);
