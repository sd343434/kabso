-- v1.65-social (D197, CONVENTIONS §10.60, CP-039): the admin panel v2 «لوحة الإدارة».
--
-- 1. Indexes for the panel's read-only statistics (`/admin/stats/*`) and its new tables: every aggregate filters
--    one table by a time column (the Asia/Riyadh day is computed on top of the range). Additive; no row changes.
-- 2. `kabso_admin_panel_role(...)`: the ONLY way the API's runtime role can add or remove a panel role (OWNER,
--    MODERATION, SUPPORT, FINANCE) — for the OWNER's team page (TOTP + reason, audited by the API). The table stays
--    read-only for the runtime group (20261021090000_admin_permissions): the function is SECURITY DEFINER (owned by
--    the migration role), refuses every other permission (the LEVELS_* ones stay CLI-only) and is executable only
--    by this database's runtime group (KL7F-06: no PUBLIC execute). `admin-admin grant|revoke` uses it too.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE INDEX "users_created_at_idx" ON "users"("created_at");
CREATE INDEX "recharge_sales_created_at_idx" ON "recharge_sales"("created_at");
CREATE INDEX "recharge_topups_created_at_idx" ON "recharge_topups"("created_at");
CREATE INDEX "live_gifts_created_at_idx" ON "live_gifts"("created_at");
CREATE INDEX "live_rooms_started_at_idx" ON "live_rooms"("started_at");
CREATE INDEX "topup_orders_credited_at_idx" ON "topup_orders"("credited_at") WHERE "credited_at" IS NOT NULL;
CREATE INDEX "topup_orders_created_at_idx" ON "topup_orders"("created_at");
CREATE INDEX "cherry_withdrawals_decided_at_idx" ON "cherry_withdrawals"("decided_at") WHERE "status" = 'PAID'::cherry_withdrawal_status;
CREATE INDEX "agency_earnings_created_at_idx" ON "agency_earnings"("created_at");
CREATE INDEX "cherry_ledger_created_at_idx" ON "cherry_ledger"("created_at");
CREATE INDEX "audit_logs_created_at_idx" ON "audit_logs"("created_at" DESC);

CREATE FUNCTION public.kabso_admin_panel_role(p_user uuid, p_role text, p_grant boolean, p_by uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  changed integer;
BEGIN
  IF p_role NOT IN ('OWNER', 'MODERATION', 'SUPPORT', 'FINANCE') THEN
    RAISE EXCEPTION 'kabso_admin_panel_role: % is not a panel role', p_role USING ERRCODE = '22023';
  END IF;
  IF p_grant THEN
    INSERT INTO user_admin_permissions (user_id, permission, granted_by_id)
    VALUES (p_user, p_role::admin_permission, p_by)
    ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM user_admin_permissions WHERE user_id = p_user AND permission = p_role::admin_permission;
  END IF;
  GET DIAGNOSTICS changed = ROW_COUNT;
  RETURN changed > 0;
END
$fn$;

REVOKE ALL ON FUNCTION public.kabso_admin_panel_role(uuid, text, boolean, uuid) FROM PUBLIC;

DO $$
DECLARE
  grp text := 'kabso_runtime_' || current_database();
BEGIN
  IF to_regclass('public._prisma_migrations') IS NULL THEN
    RAISE NOTICE 'shadow database: runtime grants skipped';
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = grp) THEN
    RAISE EXCEPTION 'role "%" does not exist. Run infra/postgres/bootstrap-roles.sql for this database first (docs/DEPLOYMENT.md §5.1).', grp;
  END IF;
  EXECUTE format('GRANT EXECUTE ON FUNCTION public.kabso_admin_panel_role(uuid, text, boolean, uuid) TO %I', grp);
END
$$;
