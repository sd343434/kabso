-- SEC-011 / KL-013: least-privilege runtime access.
--
-- Runs as the migration role (the owner of schema `public`; see infra/postgres/bootstrap-roles.sql
-- and docs/DEPLOYMENT.md §5.1). Grants go to the NOLOGIN group role `kabso_runtime`; the API's
-- login role is a member of it. No login role name, password or environment-specific value
-- appears here.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kabso_runtime') THEN
    RAISE EXCEPTION 'role "kabso_runtime" does not exist. Run infra/postgres/bootstrap-roles.sql as a database admin before migrating (docs/DEPLOYMENT.md §5.1).';
  END IF;
  -- Default privileges below apply to objects created by the role running the migrations, so
  -- that must always be the (non-superuser) owner of the schema.
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL), not as superuser "%"', current_user;
  END IF;
  IF NOT pg_has_role(current_user, (SELECT nspowner FROM pg_namespace WHERE nspname = 'public'), 'USAGE') THEN
    RAISE EXCEPTION 'migrations must run as the owner of schema public (the migration role); "%" is not', current_user;
  END IF;
END
$$;

-- Existing objects ------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO kabso_runtime;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kabso_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO kabso_runtime;

-- Prisma's migration history is not application data. (It does not exist in the shadow database
-- `prisma migrate dev` replays migrations into, hence the guard.)
DO $$
BEGIN
  IF to_regclass('public._prisma_migrations') IS NOT NULL THEN
    REVOKE ALL ON TABLE public."_prisma_migrations" FROM kabso_runtime;
  END IF;
END
$$;

-- Append-only audit trail: the API may write and read entries, never change or remove them.
-- (ON DELETE SET NULL on actor_user_id still works: referential actions run as the table owner.)
REVOKE UPDATE, DELETE ON TABLE "audit_logs" FROM kabso_runtime;

-- Future objects ----------------------------------------------------------------------------------
-- Every table / sequence the migration role creates later (live_rooms, follows, ...) is
-- DML-accessible by the runtime group without further grants. DDL, TRUNCATE, REFERENCES and
-- TRIGGER are never granted. A table that must be append-only or read-only needs an explicit
-- REVOKE in the migration that creates it.
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kabso_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO kabso_runtime;
