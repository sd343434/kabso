-- SEC-011 / KL-013b: one runtime group per database, and no PUBLIC EXECUTE on functions.
--
-- Runs as the migration role (the owner of schema `public`). The runtime grants move from the
-- cluster-wide group `kabso_runtime` (shared by every database in the cluster) to the group of
-- THIS database, `kabso_runtime_<current_database()>`, which infra/postgres/bootstrap-roles.sql
-- creates. The name is derived here, never written into the migration, and is only used through
-- format('%I'). No login role, password or environment-specific value appears here.

DO $$
DECLARE
  grp text := 'kabso_runtime_' || current_database();
  -- `prisma migrate dev` replays migrations into a temporary shadow database that has no
  -- _prisma_migrations table and no bootstrap; `migrate deploy` always has the table.
  shadow boolean := to_regclass('public._prisma_migrations') IS NULL;
  schema_owner name := (SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname = 'public');
  rel record;
BEGIN
  -- Migration-role guard (docs/DATABASE_SCHEMA.md): exactly the owner of schema public, and
  -- nothing that reaches a superuser / CREATEROLE / BYPASSRLS / REPLICATION role.
  IF EXISTS (
    SELECT 1 FROM pg_roles r
     WHERE pg_has_role(current_user, r.oid, 'MEMBER')
       AND (r.rolsuper OR r.rolcreaterole OR r.rolbypassrls OR r.rolreplication)
  ) THEN
    RAISE EXCEPTION 'migrations must run as the migration role (MIGRATION_DATABASE_URL); "%" is or can become a superuser / CREATEROLE / BYPASSRLS / REPLICATION role', current_user;
  END IF;
  IF shadow THEN
    -- The shadow database (owned by the migration role through pg_database_owner) only serves
    -- schema diffing; runtime grants are irrelevant there.
    RAISE NOTICE 'shadow database: runtime grants skipped';
    RETURN;
  END IF;
  IF current_user <> schema_owner THEN
    RAISE EXCEPTION 'migrations must run as the owner of schema public ("%"), not as "%"', schema_owner, current_user;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = grp) THEN
    RAISE EXCEPTION 'role "%" does not exist. Run infra/postgres/bootstrap-roles.sql for this database as an admin before migrating (docs/DEPLOYMENT.md §5.1).', grp;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_roles
     WHERE rolname = grp
       AND (rolcanlogin OR rolsuper OR rolcreaterole OR rolcreatedb OR rolbypassrls OR rolreplication)
  ) THEN
    RAISE EXCEPTION 'role "%" must be a NOLOGIN group without role attributes; re-run infra/postgres/bootstrap-roles.sql', grp;
  END IF;

  -- Copy what the legacy group holds on every relation of the schema (tables, views,
  -- sequences), so table-specific restrictions (append-only audit_logs, ...) carry over exactly.
  FOR rel IN
    SELECT c.oid::regclass AS name, c.relkind,
           string_agg(DISTINCT a.privilege_type, ', ') AS privs
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) a
      JOIN pg_roles g ON g.oid = a.grantee AND g.rolname = 'kabso_runtime'
     WHERE n.nspname = 'public'
     GROUP BY c.oid, c.relkind
  LOOP
    EXECUTE format('GRANT %s ON %s %s TO %I', rel.privs,
                   CASE WHEN rel.relkind = 'S' THEN 'SEQUENCE' ELSE 'TABLE' END, rel.name, grp);
  END LOOP;
  EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', grp);

  -- The documented invariants, whatever the legacy ACLs said.
  EXECUTE format('REVOKE ALL ON TABLE public."_prisma_migrations" FROM %I', grp);
  IF to_regclass('public.audit_logs') IS NOT NULL THEN
    EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.audit_logs FROM %I', grp);
  END IF;

  -- Future objects created by the migration role: DML for this database's group only.
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', grp);
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO %I', grp);

  -- The cluster-wide legacy group keeps nothing in this database. (Its CONNECT on the database
  -- was granted by the admin and is revoked by the bootstrap script.)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kabso_runtime') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM kabso_runtime;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM kabso_runtime;
    REVOKE ALL ON SCHEMA public FROM kabso_runtime;
    ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public REVOKE ALL ON TABLES FROM kabso_runtime;
    ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public REVOKE ALL ON SEQUENCES FROM kabso_runtime;
  END IF;
END
$$;

-- KL7F-06: functions and procedures are not executable by PUBLIC. Applies to the existing
-- routines of the schema and (global default privileges; a per-schema entry cannot remove a
-- PUBLIC default) to every routine the migration role creates later. A routine the API must
-- call needs an explicit GRANT EXECUTE to the runtime group in the migration that creates it.
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
