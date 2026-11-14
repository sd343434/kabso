-- D72 follow-up (CP-005 §9.8, owner 2026-10-20): granular admin permissions for the levels
-- admin API. An admin endpoint needs users.role = ADMIN AND the permission it names. Additive.
--
-- The runtime group may only READ this table: permissions are granted and revoked with the
-- migration role (`pnpm levels:admin grant|revoke`, docs/DEPLOYMENT.md §5.2), so a compromised
-- API process cannot grant itself more.
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
END
$$;

-- CreateEnum
CREATE TYPE "admin_permission" AS ENUM ('LEVELS_VIEW', 'LEVELS_EDIT', 'LEVELS_PUBLISH', 'LEVELS_ADJUST', 'LEVELS_RECONCILE');

-- CreateTable
CREATE TABLE "user_admin_permissions" (
    "user_id" UUID NOT NULL,
    "permission" "admin_permission" NOT NULL,
    "granted_by_id" UUID,
    "granted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_admin_permissions_pkey" PRIMARY KEY ("user_id","permission")
);

-- AddForeignKey
ALTER TABLE "user_admin_permissions" ADD CONSTRAINT "user_admin_permissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Read-only for the runtime group of THIS database (the shadow database has none).
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
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.user_admin_permissions FROM %I', grp);
END
$$;
