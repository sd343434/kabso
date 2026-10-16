-- Kabso Live — database role bootstrap (SEC-011 / KL-013, KL-013b).
--
-- Creates the least-privilege role layout for ONE database. Run it as an admin role (local
-- superuser, or the managed service's master user with CREATEROLE) connected to the application
-- database, once per database and again whenever a password rotates (it is idempotent). The
-- whole run is ONE transaction: on any error nothing is changed.
--
--   KABSO_DB_ENV=production \
--   KABSO_DB_MIGRATOR_USER=kabso_migrator KABSO_DB_MIGRATOR_PASSWORD='SCRAM-SHA-256$...' \
--   KABSO_DB_APP_USER=kabso_app           KABSO_DB_APP_PASSWORD='SCRAM-SHA-256$...' \
--   psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/postgres/bootstrap-roles.sql
--
-- Role names and passwords are read from the ENVIRONMENT (psql \getenv), never from this file or
-- the command line. Outside development (KABSO_DB_ENV unset, `staging` or `production`) the
-- passwords MUST be SCRAM-SHA-256 verifiers (infra/postgres/scram-verifier.mjs), so no clear-text
-- password is ever part of a statement the server could log, and the known development/CI
-- default passwords are refused even in verifier form. KABSO_DB_ENV=development (docker compose,
-- CI, e2e) also accepts clear text (>= 12 characters).
--
-- Layout (docs/DEPLOYMENT.md §5.1):
--   kabso_runtime_<database>  NOLOGIN group of THIS database. Holds the runtime DML grants (given
--                    by migration 20261016130000, which derives the same name from
--                    current_database()). CONNECT on this database only.
--   $KABSO_DB_MIGRATOR_USER  LOGIN. Owns schema `public` and every object the migrations create;
--                    used only by `prisma migrate deploy`. No SUPERUSER / CREATEROLE / BYPASSRLS.
--   $KABSO_DB_APP_USER       LOGIN. Used by the API (DATABASE_URL). Member of
--                    kabso_runtime_<database> and of nothing else: DML only, no DDL, owns nothing,
--                    one login per database.
--   kabso_runtime    Legacy cluster-wide group (KL-013). Still created because migration
--                    20261016120000 grants to it; it ends up with no members and no privileges in
--                    this database.
--
-- Modes (KABSO_DB_MODE):
--   bootstrap (default)    everything above; needs all four KABSO_DB_* role variables.
--   add-runtime-login      adds/updates the runtime login KABSO_DB_APP_USER (+ password) as a
--                          member of this database's group — zero-downtime rotation step 1.
--   retire-runtime-login   removes KABSO_DB_APP_USER from the group and disables its login;
--                          refuses if it is the group's last login — rotation step 3.
--
-- Optional: KABSO_DB_MIGRATOR_CREATEDB=true gives the migrator CREATEDB for the shadow database
-- of `prisma migrate dev`. Only accepted with KABSO_DB_ENV=development.

\set ON_ERROR_STOP on
\set QUIET on

\getenv mode KABSO_DB_MODE
\getenv db_env KABSO_DB_ENV
\getenv migrator_role KABSO_DB_MIGRATOR_USER
\getenv migrator_password KABSO_DB_MIGRATOR_PASSWORD
\getenv app_role KABSO_DB_APP_USER
\getenv app_password KABSO_DB_APP_PASSWORD
\getenv migrator_createdb KABSO_DB_MIGRATOR_CREATEDB

\if :{?mode}
\else
  \set mode bootstrap
\endif
\if :{?db_env}
\else
  \set db_env production
\endif
\if :{?migrator_role}
\else
  \set migrator_role ''
\endif
\if :{?migrator_password}
\else
  \set migrator_password ''
\endif
\if :{?app_role}
\else
  \set app_role ''
\endif
\if :{?app_password}
\else
  \set app_password ''
\endif
\if :{?migrator_createdb}
\else
  \set migrator_createdb false
\endif

BEGIN;

-- 0. Keep statements of this transaction out of the server log where the admin may change the
--    logging settings (superuser). Managed-service masters usually may not; then only verifiers
--    are accepted outside development (below), and the run is refused if every statement is
--    being logged.
DO $$
BEGIN
  PERFORM set_config('log_statement', 'none', true);
  PERFORM set_config('log_min_error_statement', 'panic', true);
  PERFORM set_config('log_min_duration_statement', '-1', true);
EXCEPTION WHEN insufficient_privilege THEN
  IF current_setting('log_statement') = 'all' OR current_setting('log_min_duration_statement') = '0' THEN
    RAISE EXCEPTION 'bootstrap-roles: the server logs every statement (log_statement=all or log_min_duration_statement=0) and this role cannot turn that off for the transaction; refusing to send role passwords';
  END IF;
END
$$;

-- Hand the values to server-side checks as transaction-local settings (gone at COMMIT/ROLLBACK),
-- never interpolated into dollar-quoted bodies.
SELECT set_config('kabso.mode', :'mode', true) AS _m,
       set_config('kabso.env', :'db_env', true) AS _e,
       set_config('kabso.migrator_role', :'migrator_role', true) AS _mr,
       set_config('kabso.app_role', :'app_role', true) AS _ar,
       set_config('kabso.migrator_password', :'migrator_password', true) AS _mp,
       set_config('kabso.app_password', :'app_password', true) AS _ap,
       set_config('kabso.migrator_createdb', :'migrator_createdb', true) AS _mc,
       set_config('kabso.group', 'kabso_runtime_' || current_database(), true) AS _g \gset

-- 1. Validate everything before changing anything ------------------------------------------------
DO $$
DECLARE
  mode text := current_setting('kabso.mode');
  env text := current_setting('kabso.env');
  is_strict boolean;
  createdb boolean;
  migrator text := current_setting('kabso.migrator_role');
  app text := current_setting('kabso.app_role');
  grp text := current_setting('kabso.group');
  names text[];
  checks text[];  -- (role, password) pairs to validate
  dev_defaults text[] := ARRAY[
    'kabso_dev_password', 'kabso_app_dev_password', 'kabso_app_test_dev_password',
    'kabso_migrator_dev_password', 'ci_test_password_not_secret', 'ci_app_password_not_secret',
    'ci_migrator_password_not_secret'];
  scram_re text := '^SCRAM-SHA-256\$[0-9]+:[A-Za-z0-9+/]+={0,2}\$[A-Za-z0-9+/]+={0,2}:[A-Za-z0-9+/]+={0,2}$';
  n text;
  pw text;
  cand text;
  i int;
  j int;
  iters int;
  salt bytea;
  stored text;
  k bytea; ik bytea; ok bytea; u bytea; acc bit(256); salted bytea; ck bytea;
  r record;
  bad text;
  this_db oid := (SELECT oid FROM pg_database WHERE datname = current_database());
BEGIN
  IF mode NOT IN ('bootstrap', 'add-runtime-login', 'retire-runtime-login') THEN
    RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_MODE must be bootstrap, add-runtime-login or retire-runtime-login (got "%")', mode;
  END IF;
  IF env NOT IN ('development', 'staging', 'production') THEN
    RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_ENV must be development, staging or production (got "%")', env;
  END IF;
  is_strict := env <> 'development';
  IF lower(current_setting('kabso.migrator_createdb')) NOT IN ('true', 'false', '') THEN
    RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_MIGRATOR_CREATEDB must be true or false';
  END IF;
  createdb := lower(current_setting('kabso.migrator_createdb')) = 'true';
  IF createdb AND (is_strict OR mode <> 'bootstrap') THEN
    RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_MIGRATOR_CREATEDB=true is only allowed with KABSO_DB_ENV=development';
  END IF;
  IF octet_length(grp) > 63 THEN
    RAISE EXCEPTION 'bootstrap-roles: database name "%" is too long for its runtime group "kabso_runtime_<database>" (at most 49 bytes)', current_database();
  END IF;

  -- Names --------------------------------------------------------------------------------------
  IF app = '' THEN
    RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_APP_USER is not set';
  END IF;
  names := ARRAY[app];
  IF mode = 'bootstrap' THEN
    IF migrator = '' THEN
      RAISE EXCEPTION 'bootstrap-roles: KABSO_DB_MIGRATOR_USER is not set';
    END IF;
    IF migrator = app THEN
      RAISE EXCEPTION 'bootstrap-roles: the migration role and the runtime role must differ (both are "%")', app;
    END IF;
    names := names || migrator;
  END IF;
  FOREACH n IN ARRAY names LOOP
    IF octet_length(n) > 63 OR n LIKE 'pg\_%' OR n = 'public' OR n LIKE 'kabso\_runtime%' THEN
      RAISE EXCEPTION 'bootstrap-roles: "%" cannot be used as a login name (reserved, a group name, or longer than 63 bytes)', n;
    END IF;
    IF n IN (current_user, session_user) THEN
      RAISE EXCEPTION 'bootstrap-roles: run this as an admin role, not as "%"', n;
    END IF;
  END LOOP;

  -- Passwords ----------------------------------------------------------------------------------
  IF mode = 'bootstrap' THEN
    checks := ARRAY[migrator, current_setting('kabso.migrator_password'), app, current_setting('kabso.app_password')];
  ELSIF mode = 'add-runtime-login' THEN
    checks := ARRAY[app, current_setting('kabso.app_password')];
  ELSE
    checks := ARRAY[]::text[];
  END IF;
  FOR i IN 1..coalesce(array_length(checks, 1), 0) / 2 LOOP
    n := checks[2 * i - 1];
    pw := checks[2 * i];
    IF pw = '' THEN
      RAISE EXCEPTION 'bootstrap-roles: no password set for "%" (KABSO_DB_*_PASSWORD)', n;
    END IF;
    IF pw ~ '^md5' THEN
      RAISE EXCEPTION 'bootstrap-roles: MD5 password hashes are not accepted (role "%"); use a SCRAM-SHA-256 verifier', n;
    END IF;
    IF pw LIKE 'SCRAM-SHA-256$%' THEN
      IF pw !~ scram_re THEN
        RAISE EXCEPTION 'bootstrap-roles: malformed SCRAM-SHA-256 verifier for role "%"', n;
      END IF;
      IF is_strict THEN
        -- Refuse a verifier of a known development default: recompute StoredKey (RFC 5802) for
        -- each default with the verifier's salt and iteration count.
        iters := split_part(split_part(pw, '$', 2), ':', 1)::int;
        salt := decode(split_part(split_part(pw, '$', 2), ':', 2), 'base64');
        stored := split_part(split_part(pw, '$', 3), ':', 1);
        IF iters < 4096 OR iters > 100000 THEN
          RAISE EXCEPTION 'bootstrap-roles: SCRAM iteration count for role "%" must be between 4096 and 100000', n;
        END IF;
        FOREACH cand IN ARRAY dev_defaults LOOP
          k := convert_to(cand, 'UTF8');
          k := k || decode(repeat('00', 64 - length(k)), 'hex');
          ik := k; ok := k;
          FOR j IN 0..63 LOOP
            ik := set_byte(ik, j, get_byte(k, j) # 54);
            ok := set_byte(ok, j, get_byte(k, j) # 92);
          END LOOP;
          u := sha256(ok || sha256(ik || salt || '\x00000001'::bytea));
          acc := ('x' || encode(u, 'hex'))::bit(256);
          FOR j IN 2..iters LOOP
            u := sha256(ok || sha256(ik || u));
            acc := acc # ('x' || encode(u, 'hex'))::bit(256);
          END LOOP;
          salted := decode(repeat('00', 64), 'hex');
          FOR j IN 0..31 LOOP
            salted := set_byte(salted, j, substring(acc FROM j * 8 + 1 FOR 8)::int);
          END LOOP;
          ik := salted; ok := salted;
          FOR j IN 0..63 LOOP
            ik := set_byte(ik, j, get_byte(salted, j) # 54);
            ok := set_byte(ok, j, get_byte(salted, j) # 92);
          END LOOP;
          ck := sha256(ok || sha256(ik || convert_to('Client Key', 'UTF8')));
          IF encode(sha256(ck), 'base64') = stored THEN
            RAISE EXCEPTION 'bootstrap-roles: the password of role "%" is a known development default; refusing with KABSO_DB_ENV=%', n, env;
          END IF;
        END LOOP;
      END IF;
    ELSE
      IF is_strict THEN
        RAISE EXCEPTION 'bootstrap-roles: with KABSO_DB_ENV=% the password of role "%" must be a SCRAM-SHA-256 verifier (infra/postgres/scram-verifier.mjs), not clear text', env, n;
      END IF;
      IF length(pw) < 12 THEN
        RAISE EXCEPTION 'bootstrap-roles: passwords must be at least 12 characters (role "%")', n;
      END IF;
    END IF;
  END LOOP;

  -- Pre-existing roles: never turn an unrelated or unsafe role into one of ours --------------------
  FOR r IN SELECT * FROM pg_roles WHERE rolname = ANY (names || ARRAY[grp, 'kabso_runtime']) LOOP
    IF r.rolsuper OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls
       OR (r.rolcreatedb AND r.rolname <> migrator) THEN
      RAISE EXCEPTION 'bootstrap-roles: existing role "%" has unsafe attributes (SUPERUSER / CREATEROLE / REPLICATION / BYPASSRLS / CREATEDB); fix or drop it first', r.rolname;
    END IF;
    IF r.rolname = ANY (names) AND NOT r.rolcanlogin THEN
      RAISE EXCEPTION 'bootstrap-roles: existing role "%" is NOLOGIN; refusing to turn it into a login', r.rolname;
    END IF;
    IF r.rolname IN (grp, 'kabso_runtime') AND r.rolcanlogin THEN
      RAISE EXCEPTION 'bootstrap-roles: existing role "%" must be NOLOGIN', r.rolname;
    END IF;
    -- What the role can reach (also SET-only memberships).
    SELECT string_agg(b.rolname, ', ' ORDER BY b.rolname) INTO bad
      FROM pg_roles b
     WHERE pg_has_role(r.oid, b.oid, 'MEMBER') AND b.oid <> r.oid
       AND NOT (r.rolname = app AND b.rolname IN (grp, 'kabso_runtime'))
       AND NOT (r.rolname = migrator AND b.rolname = 'pg_database_owner');
    IF bad IS NOT NULL THEN
      RAISE EXCEPTION 'bootstrap-roles: existing role "%" is a member of %; % must not reach other roles (one runtime login per database)', r.rolname, bad, r.rolname;
    END IF;
    -- Who can act as the role (other than this admin).
    SELECT string_agg(m.rolname, ', ' ORDER BY m.rolname) INTO bad
      FROM pg_auth_members am JOIN pg_roles m ON m.oid = am.member
     WHERE am.roleid = r.oid AND m.rolname <> current_user
       AND NOT (r.rolname = grp AND m.rolcanlogin)
       AND NOT (r.rolname = 'kabso_runtime');
    IF bad IS NOT NULL THEN
      RAISE EXCEPTION 'bootstrap-roles: other roles are members of "%": %', r.rolname, bad;
    END IF;
    -- Footprint in other databases (ownership, privileges, objects).
    SELECT string_agg(DISTINCT d.datname, ', ') INTO bad
      FROM pg_database d
     WHERE d.oid <> this_db
       AND (d.datdba = r.oid
            OR EXISTS (SELECT 1 FROM aclexplode(d.datacl) a WHERE a.grantee = r.oid)
            OR EXISTS (SELECT 1 FROM pg_shdepend s
                        WHERE s.dbid = d.oid AND s.refclassid = 'pg_authid'::regclass AND s.refobjid = r.oid));
    IF bad IS NOT NULL THEN
      IF r.rolname = 'kabso_runtime' THEN
        RAISE NOTICE 'bootstrap-roles: legacy group kabso_runtime still has access to database(s) %; bootstrap and migrate those too (docs/DEPLOYMENT.md §5.1)', bad;
      ELSIF r.rolname = migrator AND NOT is_strict THEN
        RAISE NOTICE 'bootstrap-roles: migration role "%" is also used in database(s) % (accepted with KABSO_DB_ENV=development)', migrator, bad;
      ELSE
        RAISE EXCEPTION 'bootstrap-roles: role "%" already owns or holds privileges in other database(s): % (use separate roles per database / environment)', r.rolname, bad;
      END IF;
    END IF;
    -- The runtime login owns nothing here.
    IF r.rolname = app AND EXISTS (
      SELECT 1 FROM pg_shdepend s
       WHERE s.dbid IN (0, this_db) AND s.refclassid = 'pg_authid'::regclass AND s.refobjid = r.oid
         AND s.deptype = 'o'
    ) THEN
      RAISE EXCEPTION 'bootstrap-roles: runtime role "%" owns objects or databases; it must own nothing', app;
    END IF;
  END LOOP;

  IF mode <> 'bootstrap' THEN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = grp)
       OR NOT has_schema_privilege(grp, 'public', 'USAGE') THEN
      RAISE EXCEPTION 'bootstrap-roles: "%" is not set up yet; run the bootstrap and `prisma migrate deploy` first', grp;
    END IF;
  END IF;
  IF mode = 'retire-runtime-login' THEN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = app) OR NOT pg_has_role(app, grp, 'MEMBER') THEN
      RAISE EXCEPTION 'bootstrap-roles: "%" is not a runtime login of this database', app;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_auth_members am JOIN pg_roles m ON m.oid = am.member
       WHERE am.roleid = (SELECT oid FROM pg_roles WHERE rolname = grp)
         AND m.rolname <> app AND m.rolcanlogin
    ) THEN
      RAISE EXCEPTION 'bootstrap-roles: "%" is the last runtime login of this database; add the new one first (KABSO_DB_MODE=add-runtime-login)', app;
    END IF;
  END IF;
END
$$;

-- 2. Roles ---------------------------------------------------------------------------------------
-- CREATE ROLE defaults are NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; existing
-- roles were checked above and are checked again at the end.
SELECT 'CREATE ROLE kabso_runtime NOLOGIN'
 WHERE current_setting('kabso.mode') = 'bootstrap'
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kabso_runtime') \gexec
SELECT format('CREATE ROLE %I NOLOGIN', current_setting('kabso.group'))
 WHERE current_setting('kabso.mode') = 'bootstrap'
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_setting('kabso.group')) \gexec
SELECT format('CREATE ROLE %I LOGIN', current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.mode') = 'bootstrap'
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_setting('kabso.migrator_role')) \gexec
SELECT format('CREATE ROLE %I LOGIN', current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') IN ('bootstrap', 'add-runtime-login')
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_setting('kabso.app_role')) \gexec

-- Passwords are (re)set on every run, so the script doubles as the rotation procedure.
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', current_setting('kabso.migrator_role'),
              current_setting('kabso.migrator_password'))
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', current_setting('kabso.app_role'),
              current_setting('kabso.app_password'))
 WHERE current_setting('kabso.mode') IN ('bootstrap', 'add-runtime-login') \gexec

SELECT format('ALTER ROLE %I %s', current_setting('kabso.migrator_role'),
              CASE WHEN lower(current_setting('kabso.migrator_createdb')) = 'true' THEN 'CREATEDB' ELSE 'NOCREATEDB' END)
 FROM pg_roles
 WHERE current_setting('kabso.mode') = 'bootstrap'
   AND rolname = current_setting('kabso.migrator_role')
   AND rolcreatedb IS DISTINCT FROM (lower(current_setting('kabso.migrator_createdb')) = 'true') \gexec

SELECT format('GRANT %I TO %I', current_setting('kabso.group'), current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') IN ('bootstrap', 'add-runtime-login')
   AND NOT pg_has_role(current_setting('kabso.app_role'), current_setting('kabso.group'), 'MEMBER') \gexec

-- Legacy (KL-013) membership: removed once this database's group holds the runtime grants
-- (migration 20261016130000 applied); before that it keeps the API working until the migration.
SELECT format('REVOKE kabso_runtime FROM %I', current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') IN ('bootstrap', 'add-runtime-login', 'retire-runtime-login')
   AND EXISTS (SELECT 1 FROM pg_auth_members am
                WHERE am.roleid = (SELECT oid FROM pg_roles WHERE rolname = 'kabso_runtime')
                  AND am.member = (SELECT oid FROM pg_roles WHERE rolname = current_setting('kabso.app_role')))
   AND (current_setting('kabso.mode') = 'retire-runtime-login'
        OR has_schema_privilege(current_setting('kabso.group'), 'public', 'USAGE')) \gexec

-- Retire: no group, no login, no password. (Drop the role later with DROP ROLE once unused.)
SELECT format('REVOKE %I FROM %I', current_setting('kabso.group'), current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') = 'retire-runtime-login' \gexec
SELECT format('ALTER ROLE %I WITH NOLOGIN PASSWORD NULL', current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') = 'retire-runtime-login' \gexec

-- 3. Database ------------------------------------------------------------------------------------
-- Nobody connects by default; each role gets exactly what it needs on THIS database. The legacy
-- group and the logins themselves hold nothing here directly.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database())
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM kabso_runtime', current_database())
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM %I', current_database(), current_setting('kabso.app_role'))
 WHERE current_setting('kabso.mode') IN ('bootstrap', 'add-runtime-login') \gexec
SELECT format('GRANT CONNECT, TEMPORARY, CREATE ON DATABASE %I TO %I', current_database(), current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec
SELECT format('REVOKE TEMPORARY, CREATE ON DATABASE %I FROM %I', current_database(), current_setting('kabso.group'))
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), current_setting('kabso.group'))
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec

-- 4. Schema --------------------------------------------------------------------------------------
-- The migration role owns `public`, so everything the migrations create is owned by it and the
-- default privileges in the grant migrations apply. Changing the owner needs the right to SET
-- ROLE to the migration role; a managed-service master (CREATEROLE, not superuser) gets that
-- temporarily here and loses it again before COMMIT.
SELECT set_config('kabso.set_grant',
         CASE
           WHEN current_setting('kabso.mode') <> 'bootstrap' THEN ''
           WHEN (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN ''
           WHEN pg_has_role(current_user, current_setting('kabso.migrator_role'), 'SET') THEN ''
           -- PostgreSQL 16 keeps one membership row per grantor; only the row this admin grants
           -- is touched (a CREATEROLE creator's automatic ADMIN row is left as it is).
           WHEN EXISTS (SELECT 1 FROM pg_auth_members am
                         WHERE am.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
                           AND am.grantor = (SELECT oid FROM pg_roles WHERE rolname = current_user)
                           AND am.roleid = (SELECT oid FROM pg_roles WHERE rolname = current_setting('kabso.migrator_role')))
             THEN 'option'
           ELSE 'membership'
         END, true) AS _sg \gset
SELECT format('GRANT %I TO CURRENT_USER WITH INHERIT FALSE, SET TRUE', current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.set_grant') <> '' \gexec

-- PUBLIC must not create objects in `public` (done by the owner, whoever that is right now).
SELECT format('SET LOCAL ROLE %I', pg_get_userbyid(nspowner))
  FROM pg_namespace
 WHERE nspname = 'public' AND current_setting('kabso.mode') = 'bootstrap'
   AND pg_get_userbyid(nspowner) = current_setting('kabso.migrator_role') \gexec
SELECT 'REVOKE CREATE ON SCHEMA public FROM PUBLIC'
 WHERE current_setting('kabso.mode') = 'bootstrap' AND has_schema_privilege('public', 'public', 'CREATE') \gexec
RESET ROLE;
SELECT format('ALTER SCHEMA public OWNER TO %I', current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.mode') = 'bootstrap' \gexec

SELECT format('REVOKE SET OPTION FOR %I FROM CURRENT_USER', current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.set_grant') = 'option' \gexec
SELECT format('REVOKE %I FROM CURRENT_USER', current_setting('kabso.migrator_role'))
 WHERE current_setting('kabso.set_grant') = 'membership' \gexec

-- 5. Verify (still inside the transaction: any failure rolls everything back) ---------------------
DO $$
DECLARE
  mode text := current_setting('kabso.mode');
  is_strict boolean := current_setting('kabso.env') <> 'development';
  migrator text := current_setting('kabso.migrator_role');
  app text := current_setting('kabso.app_role');
  grp text := current_setting('kabso.group');
  migrated boolean := has_schema_privilege(grp, 'public', 'USAGE');
  this_db oid := (SELECT oid FROM pg_database WHERE datname = current_database());
  bad text;
BEGIN
  SELECT string_agg(rolname, ', ') INTO bad
    FROM pg_roles
   WHERE rolname IN (app, migrator, grp, 'kabso_runtime')
     AND (rolsuper OR rolcreaterole OR rolreplication OR rolbypassrls
          OR (rolname <> migrator AND rolcreatedb) OR (rolname = migrator AND rolcreatedb AND is_strict)
          OR (rolname IN (grp, 'kabso_runtime') AND rolcanlogin));
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'bootstrap-roles: unsafe role attributes on: %', bad;
  END IF;

  IF mode = 'retire-runtime-login' THEN
    IF pg_has_role(app, grp, 'MEMBER') OR (SELECT rolcanlogin FROM pg_roles WHERE rolname = app) THEN
      RAISE EXCEPTION 'bootstrap-roles: "%" was not retired', app;
    END IF;
    RETURN;
  END IF;

  -- The runtime login reaches its group only (plus the legacy group until the migration ran).
  SELECT string_agg(r.rolname, ', ') INTO bad
    FROM pg_roles r
   WHERE pg_has_role(app, r.oid, 'MEMBER')
     AND r.rolname <> app AND r.rolname <> grp
     AND NOT (r.rolname = 'kabso_runtime' AND NOT migrated);
  IF bad IS NOT NULL OR NOT pg_has_role(app, grp, 'MEMBER') THEN
    RAISE EXCEPTION 'bootstrap-roles: runtime role "%" must be a member of "%" only (also reaches: %)', app, grp, coalesce(bad, '-');
  END IF;
  -- The group itself is a member of nothing.
  IF EXISTS (SELECT 1 FROM pg_roles r WHERE pg_has_role(grp, r.oid, 'MEMBER') AND r.rolname <> grp) THEN
    RAISE EXCEPTION 'bootstrap-roles: "%" must not be a member of other roles', grp;
  END IF;

  -- Neither the login nor its group has a footprint in another database.
  SELECT string_agg(DISTINCT d.datname, ', ') INTO bad
    FROM pg_database d, pg_roles r
   WHERE r.rolname IN (app, grp) AND d.oid <> this_db
     AND (d.datdba = r.oid
          OR EXISTS (SELECT 1 FROM aclexplode(d.datacl) a WHERE a.grantee = r.oid)
          OR EXISTS (SELECT 1 FROM pg_shdepend s
                      WHERE s.dbid = d.oid AND s.refclassid = 'pg_authid'::regclass AND s.refobjid = r.oid));
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'bootstrap-roles: "%" / "%" have access to other database(s): %', app, grp, bad;
  END IF;

  -- Database ACL: PUBLIC and the legacy group nothing, the group CONNECT only, the login nothing
  -- directly.
  IF has_database_privilege('public', current_database(), 'CONNECT')
     OR has_database_privilege('public', current_database(), 'TEMPORARY')
     OR has_database_privilege('public', current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'bootstrap-roles: PUBLIC still has privileges on database %', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_database d, aclexplode(d.datacl) a, pg_roles r
              WHERE d.oid = this_db AND a.grantee = r.oid
                AND (r.rolname IN (app, 'kabso_runtime') OR (r.rolname = grp AND a.privilege_type <> 'CONNECT'))) THEN
    RAISE EXCEPTION 'bootstrap-roles: unexpected database privileges for %, % or kabso_runtime', app, grp;
  END IF;
  IF NOT has_database_privilege(grp, current_database(), 'CONNECT')
     OR has_database_privilege(app, current_database(), 'TEMPORARY')
     OR has_database_privilege(app, current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'bootstrap-roles: runtime role "%" must have CONNECT (through %) and nothing else on the database', app, grp;
  END IF;

  IF mode = 'bootstrap' THEN
    IF (SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname = 'public') <> migrator THEN
      RAISE EXCEPTION 'bootstrap-roles: schema public is not owned by "%"', migrator;
    END IF;
    IF has_schema_privilege('public', 'public', 'CREATE') THEN
      RAISE EXCEPTION 'bootstrap-roles: PUBLIC can still CREATE in schema public';
    END IF;
  END IF;

  IF NOT migrated THEN
    RAISE NOTICE 'bootstrap-roles: "%" has no grants yet: run `prisma migrate deploy`%', grp,
      CASE WHEN pg_has_role(app, 'kabso_runtime', 'MEMBER')
           THEN ', then run this script again to remove the legacy kabso_runtime membership' ELSE '' END;
  END IF;

  -- Other databases the runtime login can still reach through PUBLIC (not app databases
  -- bootstrapped by this script, which revokes PUBLIC). Informational.
  SELECT string_agg(datname, ', ') INTO bad
    FROM pg_database
   WHERE datname <> current_database() AND datallowconn AND NOT datistemplate
     AND has_database_privilege(app, datname, 'CONNECT');
  IF bad IS NOT NULL THEN
    RAISE NOTICE 'bootstrap-roles: "%" can still CONNECT (through PUBLIC, no table privileges) to: %; consider REVOKE CONNECT ON DATABASE ... FROM PUBLIC there', app, bad;
  END IF;
END
$$;

COMMIT;

\echo bootstrap-roles: done for database :DBNAME (mode :mode, runtime role :app_role)
