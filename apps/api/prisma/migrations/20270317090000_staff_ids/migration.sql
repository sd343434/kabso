-- v1.73-live (D283c, CONVENTIONS §10.96.12; owner 2026-11-05: «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ
-- Kabso01»): the official staff ID of every account given a panel role (OWNER, MODERATION, SUPPORT, FINANCE).
--
-- 1. `staff_ids`: one number per person (Kabso01, Kabso02, …; two digits, then 100+). Retired, never reused: the row
--    stays after a revoke (a re-grant shows the same number again) and a purged account leaves its number behind with
--    `user_id` NULL. READ-ONLY for the runtime group, like `user_admin_permissions` (KL-058): only the SECURITY DEFINER
--    functions below write it.
-- 2. `kabso_admin_panel_role(...)` (migration 20270112100000_admin_v2) also gives the person their number in the same
--    transaction as a grant when they have none (`kabso_assign_staff_id`): under a transaction advisory lock, MAX + 1 —
--    two grants at once queue (no duplicate, no gap; a rolled-back grant gives nothing away, unlike a sequence).
-- 3. Backfill: the accounts holding a panel role now get numbers in the order of their first panel grant (ties by id),
--    so the bootstrapped first OWNER is Kabso01.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

CREATE TABLE "staff_ids" (
    "number" INTEGER NOT NULL,
    "user_id" UUID,
    "assigned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_ids_pkey" PRIMARY KEY ("number"),
    CONSTRAINT "staff_ids_number_positive" CHECK ("number" >= 1)
);
CREATE UNIQUE INDEX "staff_ids_user_id_key" ON "staff_ids"("user_id");
ALTER TABLE "staff_ids" ADD CONSTRAINT "staff_ids_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- The person's number, given once (inside the caller's transaction). Not executable by the runtime group directly.
CREATE FUNCTION public.kabso_assign_staff_id(p_user uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  n integer;
BEGIN
  SELECT number INTO n FROM staff_ids WHERE user_id = p_user;
  IF n IS NOT NULL THEN
    RETURN n;
  END IF;
  -- One assignment at a time; the statements after the lock see the numbers the previous holder committed.
  PERFORM pg_advisory_xact_lock(hashtext('kabso:staff-id'));
  SELECT number INTO n FROM staff_ids WHERE user_id = p_user;
  IF n IS NOT NULL THEN
    RETURN n;
  END IF;
  SELECT COALESCE(MAX(number), 0) + 1 INTO n FROM staff_ids;
  INSERT INTO staff_ids (number, user_id) VALUES (n, p_user);
  RETURN n;
END
$fn$;

REVOKE ALL ON FUNCTION public.kabso_assign_staff_id(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.kabso_admin_panel_role(p_user uuid, p_role text, p_grant boolean, p_by uuid)
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
    GET DIAGNOSTICS changed = ROW_COUNT;
    -- v1.73-live (D283c): the staff ID, in this transaction (the one from an earlier grant is kept).
    PERFORM kabso_assign_staff_id(p_user);
  ELSE
    DELETE FROM user_admin_permissions WHERE user_id = p_user AND permission = p_role::admin_permission;
    GET DIAGNOSTICS changed = ROW_COUNT;
  END IF;
  RETURN changed > 0;
END
$fn$;

-- Backfill: today's holders, in the order of their first panel grant.
INSERT INTO staff_ids (number, user_id, assigned_at)
SELECT row_number() OVER (ORDER BY first_grant, user_id), user_id, first_grant
  FROM (SELECT user_id, MIN(granted_at) AS first_grant
          FROM user_admin_permissions
         WHERE permission IN ('OWNER', 'MODERATION', 'SUPPORT', 'FINANCE')
         GROUP BY user_id) AS holders;

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
  -- Read-only for the runtime group (the default privileges gave it DML).
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_ids FROM %I', grp);
END
$$;
