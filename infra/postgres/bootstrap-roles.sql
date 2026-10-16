-- Kabso Live — database role bootstrap (SEC-011 / KL-013).
--
-- Creates the least-privilege role layout for ONE database. Run it as an admin role (local
-- superuser, or the managed service's master user) connected to the application database, once
-- per environment and again whenever a password rotates (it is idempotent):
--
--   KABSO_DB_MIGRATOR_USER=kabso_migrator KABSO_DB_MIGRATOR_PASSWORD=... \
--   KABSO_DB_APP_USER=kabso_app           KABSO_DB_APP_PASSWORD=... \
--   psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/postgres/bootstrap-roles.sql
--
-- Role names and passwords are read from the ENVIRONMENT (psql \getenv), never from this file
-- or the command line, so they come from the secret manager / .env and stay out of git and of
-- `ps`. A password value may also be a pre-computed `SCRAM-SHA-256$...` verifier, which keeps the
-- clear text out of the server log if statement logging is enabled.
--
-- Layout (see docs/DEPLOYMENT.md §5.1):
--   kabso_runtime    NOLOGIN group. Holds the runtime DML grants. Fixed name: Prisma migrations
--                    grant to it (20261016120000_runtime_role_grants), so they never reference a
--                    login role, a password or anything environment-specific.
--   $KABSO_DB_MIGRATOR_USER  LOGIN. Owns schema `public` and every object the migrations create;
--                    used only by `prisma migrate deploy`. No SUPERUSER / CREATEROLE / BYPASSRLS.
--   $KABSO_DB_APP_USER       LOGIN. Used by the API (DATABASE_URL). Member of kabso_runtime and
--                    nothing else: DML only, no DDL, no TRUNCATE, owns nothing.
--
-- Optional: KABSO_DB_MIGRATOR_CREATEDB=true gives the migrator CREATEDB. LOCAL DEVELOPMENT ONLY
-- (`prisma migrate dev` creates a shadow database); never set it for staging/production.

\set ON_ERROR_STOP on
\set QUIET on

\getenv migrator_role KABSO_DB_MIGRATOR_USER
\getenv migrator_password KABSO_DB_MIGRATOR_PASSWORD
\getenv app_role KABSO_DB_APP_USER
\getenv app_password KABSO_DB_APP_PASSWORD
\getenv migrator_createdb KABSO_DB_MIGRATOR_CREATEDB

\if :{?migrator_role}
\else
  \warn 'bootstrap-roles: KABSO_DB_MIGRATOR_USER is not set'
  SELECT 'missing KABSO_DB_MIGRATOR_USER'::int;
\endif
\if :{?migrator_password}
\else
  \warn 'bootstrap-roles: KABSO_DB_MIGRATOR_PASSWORD is not set'
  SELECT 'missing KABSO_DB_MIGRATOR_PASSWORD'::int;
\endif
\if :{?app_role}
\else
  \warn 'bootstrap-roles: KABSO_DB_APP_USER is not set'
  SELECT 'missing KABSO_DB_APP_USER'::int;
\endif
\if :{?app_password}
\else
  \warn 'bootstrap-roles: KABSO_DB_APP_PASSWORD is not set'
  SELECT 'missing KABSO_DB_APP_PASSWORD'::int;
\endif
\if :{?migrator_createdb}
\else
  \set migrator_createdb false
\endif

-- Hand the values to server-side checks without interpolating them into dollar-quoted bodies.
SELECT set_config('kabso.migrator_role', :'migrator_role', false) AS _m,
       set_config('kabso.app_role', :'app_role', false) AS _a,
       set_config('kabso.migrator_password', :'migrator_password', false) AS _mp,
       set_config('kabso.app_password', :'app_password', false) AS _ap \gset

DO $$
DECLARE
  migrator text := current_setting('kabso.migrator_role');
  app text := current_setting('kabso.app_role');
BEGIN
  IF migrator = '' OR app = '' THEN
    RAISE EXCEPTION 'bootstrap-roles: role names must not be empty';
  END IF;
  IF migrator = app THEN
    RAISE EXCEPTION 'bootstrap-roles: the migration role and the runtime role must differ (both are "%")', app;
  END IF;
  IF 'kabso_runtime' IN (migrator, app) THEN
    RAISE EXCEPTION 'bootstrap-roles: "kabso_runtime" is the NOLOGIN group role; choose other login names';
  END IF;
  IF app = current_user OR migrator = current_user THEN
    RAISE EXCEPTION 'bootstrap-roles: run this as an admin role, not as "%"', current_user;
  END IF;
  IF length(current_setting('kabso.migrator_password')) < 12
     OR length(current_setting('kabso.app_password')) < 12 THEN
    RAISE EXCEPTION 'bootstrap-roles: passwords must be at least 12 characters';
  END IF;
END
$$;

-- Do not keep the passwords in session settings longer than needed.
SELECT set_config('kabso.migrator_password', '', false) AS _mp,
       set_config('kabso.app_password', '', false) AS _ap \gset

-- 1. Roles ---------------------------------------------------------------------------------------
-- CREATE ROLE defaults are NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS. They are
-- not repeated on ALTER (managed services refuse to touch some attributes); the final check below
-- verifies them instead.
SELECT 'CREATE ROLE kabso_runtime NOLOGIN'
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kabso_runtime') \gexec
SELECT format('CREATE ROLE %I LOGIN', :'migrator_role')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'migrator_role') \gexec
SELECT format('CREATE ROLE %I LOGIN', :'app_role')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_role') \gexec

-- Always (re)set the passwords so the script doubles as the rotation procedure.
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'migrator_role', :'migrator_password') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'app_role', :'app_password') \gexec

\if :migrator_createdb
  \warn 'bootstrap-roles: granting CREATEDB to the migration role (local development only)'
  SELECT format('ALTER ROLE %I CREATEDB', :'migrator_role') \gexec
\else
  SELECT format('ALTER ROLE %I NOCREATEDB', :'migrator_role')
   WHERE (SELECT rolcreatedb FROM pg_roles WHERE rolname = :'migrator_role') \gexec
\endif

SELECT format('GRANT kabso_runtime TO %I', :'app_role')
 WHERE NOT pg_has_role(:'app_role', 'kabso_runtime', 'MEMBER') \gexec

-- 2. Database ------------------------------------------------------------------------------------
-- Nobody connects by default; each role gets exactly what it needs on this database.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT, TEMPORARY, CREATE ON DATABASE %I TO %I', current_database(), :'migrator_role') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO kabso_runtime', current_database()) \gexec

-- 3. Schema --------------------------------------------------------------------------------------
-- The migration role owns `public`, so everything the migrations create is owned by it and the
-- default privileges in the grant migration apply. The runtime group may only use the schema.
SELECT format('ALTER SCHEMA public OWNER TO %I', :'migrator_role') \gexec
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO kabso_runtime;

-- 4. Verify --------------------------------------------------------------------------------------
DO $$
DECLARE
  migrator text := current_setting('kabso.migrator_role');
  app text := current_setting('kabso.app_role');
  bad text;
BEGIN
  SELECT string_agg(rolname, ', ') INTO bad
    FROM pg_roles
   WHERE rolname IN (app, migrator, 'kabso_runtime')
     AND (rolsuper OR rolcreaterole OR rolreplication OR rolbypassrls
          OR (rolname <> migrator AND rolcreatedb));
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'bootstrap-roles: unsafe role attributes on: % (expected NOSUPERUSER NOCREATEROLE NOREPLICATION NOBYPASSRLS; CREATEDB only on the migrator in dev)', bad;
  END IF;

  -- The runtime login must reach nothing but kabso_runtime (and PUBLIC).
  SELECT string_agg(r.rolname, ', ') INTO bad
    FROM pg_roles r
   WHERE pg_has_role(app, r.oid, 'MEMBER')
     AND r.rolname NOT IN (app, 'kabso_runtime');
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'bootstrap-roles: runtime role "%" is a member of other roles: %', app, bad;
  END IF;
END
$$;

\echo bootstrap-roles: done for database :DBNAME (migration role :migrator_role, runtime role :app_role)
