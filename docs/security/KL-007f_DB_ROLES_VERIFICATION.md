# KL-007f — Verification of KL-013 / PP-01 (SEC-011, least-privilege DB roles)

| | |
| - | - |
| Verifier | A7 (security engineer) |
| Date | 2026-10-16 |
| Subject | KL-013 as merged on the integration branch, commit `466b66b` (feature commit `9f1d6e7`, merge `f924637`), CI run 64 green |
| Environment | Local PostgreSQL 16.15 (Ubuntu), Node 22, Prisma 7.10. Throwaway databases and roles created for this check only and dropped afterwards; no superuser role was created |
| **Verdict for PP-01** | **PASS WITH CONDITIONS** (see §4) |

The repository is public (D40). Findings that are still open are listed with id, severity, a
one-line description and status only. Reproduction details went to the coordinator.

## 1. Scope

Read: `infra/postgres/bootstrap-roles.sql`, `infra/postgres/initdb/10-kabso-roles.sh`,
migration `20261016120000_runtime_role_grants`, `apps/api/src/prisma/runtime-role-check.ts`,
`prisma.service.ts`, `apps/api/prisma.config.ts`, `test/global-setup.ts`, `test/helpers/test-app.ts`,
`test/security/kl013-db-roles.e2e-spec.ts`, `.github/workflows/ci.yml`, `docker-compose.yml`,
`docs/DEPLOYMENT.md` §4–§5.1, `docs/DATABASE_SCHEMA.md`, PP-01, SEC-011.

## 2. What was run, and the results

Everything below was executed by A7. Where a result is "pass", it was observed.

### 2.1 Project test suites (independent re-run)

| Run | Result |
| --- | ------ |
| Bootstrap on a fresh database as admin, then `prisma migrate deploy` as the migration role | pass |
| `kl013-db-roles.e2e-spec.ts` (runtime role = `DATABASE_URL`) | 36 / 36 pass |
| Full e2e suite as the runtime role | 16 files, 391 / 391 pass |
| Unit tests `src/prisma` (boot guard logic) | 16 / 16 pass |

### 2.2 Runtime role — adversarial probes (psql as the runtime login, PostgreSQL 16)

All of the following were **refused** for the runtime role:

- **DDL:** `CREATE` table, temp table, schema, view, materialized view, sequence, type, domain,
  function, procedure, aggregate, operator, trigger, rule, policy, index, statistics, collation,
  text search config, publication, subscription, event trigger, extension (`dblink`,
  `pg_stat_statements`), foreign server; `ALTER TABLE` (add column, rename, enable RLS, owner);
  `COMMENT ON`; `DROP TABLE`; `REINDEX`; `CLUSTER`; `REFRESH MATERIALIZED VIEW`; `VACUUM FULL` /
  `ANALYZE` on app tables (skipped with "permission denied").
- **TRUNCATE** on application tables and on `audit_logs`.
- **Ownership / role / database administration:** `REASSIGN OWNED`, `DROP OWNED` of the
  migration role's objects, `CREATE ROLE/USER`, `CREATE DATABASE`, `ALTER ROLE ... SUPERUSER /
  CREATEROLE / BYPASSRLS`, `ALTER ROLE <migration role> PASSWORD`, `ALTER DATABASE ... OWNER/SET`.
- **GRANT escalation:** granting the migration role, `pg_read_server_files` or
  `pg_write_all_data` to itself (error); granting table/schema/database privileges it holds
  without grant option (warning, ACLs unchanged).
- **Role switching:** `SET ROLE` to the migration role or to `postgres`, `SET SESSION
  AUTHORIZATION` (only `SET ROLE kabso_runtime`, its own group, works — expected).
- **`_prisma_migrations`:** `SELECT` and `UPDATE` refused.
- **`audit_logs`:** `INSERT` works; `UPDATE`, `DELETE`, `MERGE ... DELETE` and
  `INSERT ... ON CONFLICT DO UPDATE` refused; `has_table_privilege` / `has_column_privilege`
  report no `UPDATE`/`DELETE`.
- **Server files and programs:** `COPY ... TO/FROM PROGRAM`, `COPY` to/from a server file,
  `pg_read_file`, `pg_read_binary_file`, `pg_ls_dir`, `pg_stat_file`, server-side `lo_import` /
  `lo_export`, `pg_ls_logdir`, `pg_ls_waldir`, `pg_current_logfile`.
- **Admin functions / settings:** `pg_reload_conf`, `pg_rotate_logfile`, `pg_switch_wal`,
  `pg_create_restore_point`; setting `log_statement`, `session_replication_role`,
  `allow_system_table_mods`; reading `pg_shadow` / `pg_authid`; other users' queries in
  `pg_stat_activity` are hidden.

Catalog state observed for the runtime login:

- Role attributes all off (no SUPERUSER, CREATEROLE, CREATEDB, REPLICATION, BYPASSRLS).
- `pg_auth_members`: member of `kabso_runtime` only (no admin option); recursive membership
  check returns only itself and `kabso_runtime`.
- Database ACL: `PUBLIC` has nothing (CONNECT and TEMP revoked); runtime group has CONNECT only;
  migration role CONNECT, TEMP, CREATE.
- Schema `public`: owned by the migration role; `PUBLIC` has `USAGE` only (CREATE revoked);
  runtime group `USAGE`.
- No non-system functions exist; no `SECURITY DEFINER` functions are reachable.

### 2.3 Default privileges for future objects

`pg_default_acl` holds, for the migration role in schema `public`, `kabso_runtime=arwd` on
tables and `kabso_runtime=rU` on sequences. A table with an identity column and a view created
later by the migration role were DML-accessible to the runtime role without extra grants, with
no `TRUNCATE`; a table in a new schema was not accessible at all (fail closed). The e2e test for
a table created after the grant migration also passed. See KL7F-06 for functions.

### 2.4 Bootstrap script

| Check | Result |
| ----- | ------ |
| Injection through role names (double quote, single quote, `;`, `--`) and passwords (quotes, `$$`, backslash, psql `:var` syntax) | pass — identifiers via `format('%I')`, literals via psql `:'var'` and `%L`; roles created with the literal names, no extra statements executed, passwords stored verbatim (login with the exact strings succeeded) |
| Re-run on an already bootstrapped database | pass — idempotent, ACLs unchanged, tests still green |
| Missing env var / password shorter than 12 / identical names | pass — stops with a clear error before any change |
| Pre-existing role with unsafe attributes, or runtime login with extra memberships | detected by the final verification (error) — but see KL7F-04 |
| Password rotation (re-run with a new runtime password) | pass — old password rejected, new one accepted |
| Session settings holding passwords | cleared after use (`current_setting` empty) |
| Server log at default settings (`log_statement=none`) after successful runs | no password present — but see KL7F-05 |
| Simulated managed service (non-superuser master with CREATEROLE on PG16) | works after the documented membership grant; see KL7F-09 |
| `initdb/10-kabso-roles.sh` logic (dev + `_test` database, CREATEDB for the shadow DB) | pass when run with psql against PostgreSQL 16. **Not run inside the postgres container** (no Docker daemon here) |

### 2.5 Grant migration

| Check | Result |
| ----- | ------ |
| Guard block run as a superuser | refused ("not as superuser") |
| Guard block run as a non-owner login | refused ("must run as the owner of schema public") |
| Run as the migration role | pass |
| `prisma.config.ts` without `MIGRATION_DATABASE_URL` | falls back to `DATABASE_URL`; the runtime role cannot run DDL, so it fails closed |
| Secrets in the migration | none (grants only to the fixed group name) |

### 2.6 Boot guard (`runtime-role-check.ts` via `PrismaService`, `isProduction: true`)

A full `NODE_ENV=production` API boot is currently impossible: configuration validation refuses
`MAIL_TRANSPORT=log` first (B2 / PP-20). The guard was therefore exercised through
`PrismaService.onModuleInit()` with `isProduction: true` (the code path production uses), and
the built API (`node dist/main.js`) was booted in development mode.

| Connection role | Result |
| --------------- | ------ |
| Runtime login | accepted |
| Migration/owner role | refused (`UnsafeDatabaseRoleError`, fatal log line) |
| Login with `SET`-able membership in the migration role (`INHERIT FALSE`) | refused (ownership through membership detected) |
| Development boot as owner role | starts with the `db.runtime_role_check` warning |
| Development boot as runtime role | starts, no warning |

Gaps: KL7F-02, KL7F-03.

### 2.7 CI and secrets

CI (`ci.yml`, job `api`) uses an ephemeral service container and values named
`*_not_secret`, passes them to `docker exec` through the environment (not argv), runs the same
bootstrap SQL as production and the e2e suite as the runtime role. Repository examples
(`.env.example`, `apps/api/.env.example`, README) contain local dev placeholders only.

## 3. Findings

| ID | Severity | Description | Status |
| -- | -------- | ----------- | ------ |
| KL7F-01 | Medium | The fixed cluster-wide group `kabso_runtime` lets the runtime login of one environment use DML on every other database bootstrapped in the same PostgreSQL cluster | Open |
| KL7F-02 | Medium | The boot guard does not consider privileges reachable through role membership (predefined `pg_*` roles, `SET ROLE` to roles with dangerous attributes) | Open |
| KL7F-03 | Low | The boot guard does not check object-level grants that break documented invariants (`audit_logs` append-only, `_prisma_migrations`, grant option, TEMP) | Open |
| KL7F-04 | Low | The bootstrap script is not atomic; a failed final verification leaves earlier changes applied | Open |
| KL7F-05 | Low | Clear-text role passwords can reach the server log when a password statement fails | Open |
| KL7F-06 | Low (latent) | Functions created by the migration role are executable by `PUBLIC` (no default-privilege revoke) | Open |
| KL7F-07 | Info | PostgreSQL lets the runtime role change its own password and role-level settings, and create large objects; the optional timeout hardening in §5.1 can be overridden | Open (accept or mitigate) |
| KL7F-08 | Info | The migration-role guard runs only in migration `20261016120000` and accepts a non-owner member of the owner role | Open |
| KL7F-09 | Info (docs) | Managed-service bootstrap and rotation steps are incomplete; several documents still say the role is not implemented | Open |

## 4. Verdict

**PP-01: PASS WITH CONDITIONS.**

The core requirement is met and was observed: the API's runtime role is DML-only. It cannot run
DDL, `TRUNCATE`, change ownership, create roles or databases, escalate grants, switch to the
migration role, read or change `_prisma_migrations`, alter or delete `audit_logs`, or reach
server files or programs. Migrations run as a separate non-superuser owner role. Default
privileges cover future tables and sequences. The negative tests exist and pass in CI and in
this independent run.

Conditions before the first staging or production deployment:

1. **KL7F-01:** either fix it, or require (in `DEPLOYMENT.md` and the PP-01 entry) that each
   environment uses its own PostgreSQL cluster and that the bootstrap refuses to run otherwise.
2. **KL7F-02:** fix the boot guard so membership-derived privileges are detected.
   Alternatively, make re-running the bootstrap verification part of every deploy and record the
   accepted residual risk.
3. **KL7F-09:** correct the managed-service and rotation steps, and the stale documents, before
   A8 runs the first managed bootstrap.

KL7F-03 to KL7F-08 are not blocking; they should be scheduled (KL7F-04 and KL7F-05 before the
first production bootstrap is preferred).

## 5. Not tested

- `infra/postgres/initdb/10-kabso-roles.sh` inside the actual `postgres:16.15-alpine`
  container (no Docker daemon; script logic run with psql against PostgreSQL 16 instead).
- A full `NODE_ENV=production` API boot (blocked by the mail transport, B2); the guard was tested
  through `PrismaService` with `isProduction: true`.
- A real managed service (RDS / Cloud SQL / others); simulated with a non-superuser CREATEROLE
  master on PostgreSQL 16.
- Membership in a superuser role reachable through `SET ROLE` (no superuser roles were created,
  by instruction). Covered by code reading, together with the CREATEROLE variant of KL7F-02,
  which was tested.
- `prisma migrate dev` with the shadow database.
- CI run 64 logs were not re-inspected; CI configuration was read and the same steps were run locally.
