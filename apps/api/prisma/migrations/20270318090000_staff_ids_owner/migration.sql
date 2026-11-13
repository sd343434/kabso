-- v1.74-live (D283d, CONVENTIONS §10.96.12; owner correction 2026-11-05: «المالك… لا، kabso»): the primary OWNER's staff
-- ID is plain «Kabso» (number 0, no digits); the staff numbering Kabso01, Kabso02, … starts with the first other staff
-- member. Builds on 20270317090000_staff_ids (D283c).
--
-- 1. CHECK `staff_ids_number_positive` (>= 1) becomes `staff_ids_number_nonnegative` (>= 0): 0 is «Kabso».
-- 2. `kabso_assign_staff_id(uuid, boolean)`: an OWNER grant takes number 0 while nobody ever held it (the primary OWNER
--    = the earliest OWNER grant); a person who already had a number then gives it up (retired, never reused). Every
--    other grant (and any later OWNER) gets MAX + 1 as before. Number 0 is retired like the others: if the primary
--    OWNER's role ends it stays theirs and no other OWNER gets it. The one-argument version is dropped.
-- 3. `kabso_admin_panel_role(...)` passes `p_role = 'OWNER'`.
-- 4. Renumber (safe: not deployed): the account holding OWNER now with the earliest OWNER grant gets 0; every other row
--    keeps its order (by its first panel grant, else its `assigned_at`) as 1, 2, 3, ….
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

ALTER TABLE "staff_ids" DROP CONSTRAINT "staff_ids_number_positive";
ALTER TABLE "staff_ids" ADD CONSTRAINT "staff_ids_number_nonnegative" CHECK ("number" >= 0);

DROP FUNCTION public.kabso_assign_staff_id(uuid);

CREATE FUNCTION public.kabso_assign_staff_id(p_user uuid, p_owner boolean)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  n integer;
BEGIN
  SELECT number INTO n FROM staff_ids WHERE user_id = p_user;
  IF n IS NOT NULL AND NOT (p_owner AND n <> 0) THEN
    RETURN n;
  END IF;
  -- One assignment at a time; the statements after the lock see the numbers the previous holder committed.
  PERFORM pg_advisory_xact_lock(hashtext('kabso:staff-id'));
  SELECT number INTO n FROM staff_ids WHERE user_id = p_user;
  IF p_owner AND NOT EXISTS (SELECT 1 FROM staff_ids WHERE number = 0) THEN
    -- The primary OWNER: «Kabso». A number held before is retired (kept, owned by nobody).
    IF n IS NOT NULL THEN
      UPDATE staff_ids SET user_id = NULL WHERE user_id = p_user;
    END IF;
    INSERT INTO staff_ids (number, user_id) VALUES (0, p_user);
    RETURN 0;
  END IF;
  IF n IS NOT NULL THEN
    RETURN n;
  END IF;
  SELECT COALESCE(MAX(number), 0) + 1 INTO n FROM staff_ids;
  INSERT INTO staff_ids (number, user_id) VALUES (n, p_user);
  RETURN n;
END
$fn$;

REVOKE ALL ON FUNCTION public.kabso_assign_staff_id(uuid, boolean) FROM PUBLIC;

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
    -- v1.73-live (D283c) / v1.74-live (D283d): the staff ID in this transaction («Kabso» for the primary OWNER).
    PERFORM kabso_assign_staff_id(p_user, p_role = 'OWNER');
  ELSE
    DELETE FROM user_admin_permissions WHERE user_id = p_user AND permission = p_role::admin_permission;
    GET DIAGNOSTICS changed = ROW_COUNT;
  END IF;
  RETURN changed > 0;
END
$fn$;

-- Renumber: the primary OWNER 0, the rest 1, 2, … in their order.
CREATE TEMP TABLE staff_ids_renumber AS
WITH primary_owner AS (
  SELECT p.user_id FROM user_admin_permissions p
   WHERE p.permission = 'OWNER'
   ORDER BY p.granted_at, p.user_id
   LIMIT 1
), ordered AS (
  SELECT s.number AS old_number, s.user_id, s.assigned_at,
         (s.user_id IS NOT NULL AND s.user_id = (SELECT user_id FROM primary_owner)) AS is_primary,
         COALESCE((SELECT MIN(g.granted_at) FROM user_admin_permissions g
                    WHERE g.user_id = s.user_id
                      AND g.permission IN ('OWNER', 'MODERATION', 'SUPPORT', 'FINANCE')), s.assigned_at) AS first_grant
    FROM staff_ids s
)
SELECT user_id, assigned_at,
       CASE WHEN is_primary THEN 0
            ELSE row_number() OVER (PARTITION BY is_primary ORDER BY first_grant, old_number) END AS number
  FROM ordered;
DELETE FROM staff_ids;
INSERT INTO staff_ids (number, user_id, assigned_at) SELECT number, user_id, assigned_at FROM staff_ids_renumber;
DROP TABLE staff_ids_renumber;
