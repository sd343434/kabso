# KL-007g — Re-verification of KL-007f (KL7F-01..09) after KL-013b

| | |
| - | - |
| Verifier | A7 (security engineer) |
| Date | 2026-10-16 |
| Subject | KL-013b as integrated on `claude/amazing-tesla-5aj3um`: merge `2a161f0`, reviewed at HEAD `42bc4ad` |
| Method | Adversarial code review, CI evidence (run 76, API job `117007805948`, log read through the GitHub API), offline probes. **No local database access.** Admin credentials were not available, and connecting with the migration or runtime login was also blocked in this environment, so no local SQL probe was run |
| **Verdict for PP-01** | **PASS WITH CONDITIONS** (§4) |

The repository is public (D40). Open findings below give only an id, a severity, one line and a
status. Reproduction details went to the coordinator.

## 1. Scope

Read: `infra/postgres/bootstrap-roles.sql`, `infra/postgres/scram-verifier.mjs`,
`infra/postgres/initdb/10-kabso-roles.sh`, migration `20261016130000_per_database_runtime_group`,
`apps/api/src/prisma/runtime-role-check.ts` and its spec, `prisma.service.ts`,
`test/security/kl013-db-roles.e2e-spec.ts`, `test/helpers/db-admin.ts`, `test/global-setup.ts`,
`.github/workflows/ci.yml`, `docker-compose.yml`, `docs/DEPLOYMENT.md` §5.1,
`docs/DATABASE_SCHEMA.md` (roles section), the board (KL-013b row) and PP-01. Also read: the diff of `1f4c723`
(the fix after run 73).

## 2. Evidence

Each item says where it comes from. "CI" means A7 read it in the log of run 76 (`2a161f0`,
PostgreSQL 16.15, a superuser admin, throwaway credentials). For runs 73, 75 and 77–79, A7 checked
only the status through the API (73 failed; 75 and 77–79 passed). A7 did not read their logs.

| # | Evidence | Source |
| - | -------- | ------ |
| E1 | `kl013-db-roles.e2e-spec.ts`: 88 / 88 pass; e2e total 500 / 500 (18 files); unit 27 files pass | CI |
| E2 | CI bootstrap step completes (`done for database kabso_test`); NOTICE that `kabso_app` can still CONNECT to `postgres` through PUBLIC | CI |
| E3 | Server log: each expected bootstrap refusal is present (login of another database, group with privileges elsewhere, migration role used elsewhere, NOLOGIN role, clear text in production, dev default as a verifier, last runtime login). None of them has a `STATEMENT:` line, while ordinary errors in the same log do. The log has no password or verifier text | CI |
| E4 | Server log: the runtime login of one database gets `permission denied for database` (no CONNECT) on the other database, in both directions | CI |
| E5 | Retire: `password authentication failed … has no password assigned` for the retired login | CI |
| E6 | Guard unit tests `src/prisma`: 31 / 31 pass | run locally by A7 |
| E7 | The bootstrap's development-default check, re-implemented line by line in Python, matches RFC 5802 verifiers that `scram-verifier.mjs` produced for all 7 listed defaults, and not a random password. The list matches every default database password in the repository | run locally by A7 (offline) |
| E8 | `psql` documentation (16.15): with `\getenv`, if the environment variable is not set, the psql variable is not changed | local man page |

## 3. Per-finding verdicts

| ID | Verdict | Basis |
| -- | ------- | ----- |
| KL7F-01 (Medium) cluster-wide group | **FIXED** | Each database has its own group, `kabso_runtime_<database>`, with CONNECT only on that database. PUBLIC and the legacy group get nothing. The bootstrap refuses logins, groups or migration roles (strict mode) that are already used in another database, and it checks this through `pg_shdepend`, so grants on objects are covered too. CI: E4, E3, and the isolation/refusal tests. The legacy-layout migration path works, but its first step does not behave as documented: see **KL7G-01** (availability, not isolation). Until every database in a cluster is migrated, the legacy group still links the databases not yet migrated (documented as "repeat for every database"; the bootstrap prints a NOTICE) |
| KL7F-02 (Medium) guard ignores memberships | **FIXED** | The guard collects every role reachable with `pg_has_role(…, 'MEMBER')`, which also covers SET-only and INHERIT-FALSE/SET-FALSE memberships. It reports every role other than the login and its group, and ORs the role attributes over all of them. CI: six predefined/legacy roles with SET-only membership are rejected, a CREATEROLE role without SET or INHERIT is rejected, and a production boot refuses a login with SET-only `pg_read_all_data`. Residual: **KL7G-02** (the guard checks `current_user`, not `session_user`) and **KL7G-03** (ADMIN OPTION) |
| KL7F-03 (Low) object-level grants | **FIXED** (for the reported scope) | Now checked: TEMP, CREATE, TRUNCATE/REFERENCES/TRIGGER, UPDATE/DELETE on `audit_logs` (also per column), any privilege on `_prisma_migrations`, and grant options on relations, schemas, functions and the database. CI: 8 grant cases are reported, and the clean baseline passes. Residual: **KL7G-04** |
| KL7F-04 (Low) bootstrap not atomic | **FIXED** | The run is a single `BEGIN … COMMIT` with `ON_ERROR_STOP`; every statement in it is transactional. Every input and every pre-existing role is validated before any change: attributes, NOLOGIN, membership in both directions, footprint in other databases, ownership. The final verification runs inside the transaction. CI: a failure injected after the first changes leaves no roles and no ACL behind; a NOLOGIN role is refused and stays unchanged; a refusal leaves the existing passwords unchanged |
| KL7F-05 (Low) clear-text passwords in the log | **FIXED** | Outside development, only SCRAM verifiers are accepted (MD5 and malformed values are refused). A superuser admin turns statement and error-statement logging off for the transaction; the CI log shows no `STATEMENT:` for bootstrap errors (E3). A non-superuser admin is refused when `log_statement=all` or `log_min_duration_statement=0`; the managed path was code-reviewed only. Residual: **KL7G-06** |
| KL7F-06 (Low, latent) PUBLIC EXECUTE | **FIXED** | The migration revokes EXECUTE on existing routines in `public` and adds a global default revoke for future routines of the migration role. CI: no routine in `public` is executable by PUBLIC, and a function created later can be executed by neither PUBLIC nor the runtime login |
| KL7F-07 (Info) PostgreSQL limits | **PARTIALLY** | Self-password changes, role-level settings, large objects and advisory timeouts are documented as accepted in DEPLOYMENT §5.1. PUBLIC CONNECT/TEMP on the maintenance database `postgres` appears only as a bootstrap NOTICE (E2) and is not in the docs |
| KL7F-08 (Info) migration guard | **FIXED** | The guard in `20261016130000` refuses any role that is, or can reach, a SUPERUSER / CREATEROLE / BYPASSRLS / REPLICATION role, and requires the current role to **be** the owner of `public`; a member of the owner role is not enough. DATABASE_SCHEMA.md makes the guard a rule for future migrations, with a reusable snippet. CI: the runtime login is refused, and a re-run as the migration role is idempotent. Enforcement in future migrations depends on review |
| KL7F-09 (Info) managed-service docs | **FIXED** (docs/code); execution **NOT VERIFIABLE HERE** | On a non-superuser master, the script grants itself SET on the migration role for the transaction and revokes it before COMMIT. Rotation (add/retire) and strict-mode rules are documented, and stale documents were updated. The self-grant path never runs in CI, because the CI admin is a superuser. It was code-reviewed only |

### 3.1 Specific questions

- **`KABSO_DB_ENV` unset → production:** true in the script. An unset variable becomes
  `production`, an empty or unknown value is refused, compose and CI set `development` explicitly,
  and every e2e call sets it. One exception: a psql variable `db_env` that is already set
  (`-v db_env=…`, or `~/.psqlrc`, because the documented command has no `-X`) survives an unset
  environment variable (E8) → **KL7G-05**.
- **Dev-default refusal:** applies to clear text (refused outright in strict mode) and to verifiers
  (StoredKey is recomputed for each default); `scram-verifier.mjs` refuses them too. CI and E7.
- **Rotation:** add creates the second login with CONNECT only through the group, and the guard
  passes for it in CI. Retire removes the group membership, sets NOLOGIN and clears the password
  (CI checks the catalog, `pg_authid` and the refused login). It refuses to retire the last login
  (CI). The test change after run 73 accepts either refusal message, but it still asserts NOLOGIN,
  no membership and a NULL password. A regression in any of the three would fail CI, because the
  CI admin is a superuser and the `pg_authid` check therefore runs there.
- **Schema-ACL test after run 73:** it asserts that PUBLIC's own ACL entry on `public` is exactly
  `USAGE` and that PUBLIC has no ACL entry on any relation in `public`, and the KL7F-06 tests cover
  functions. A regression to PUBLIC CREATE, or a relation granted to PUBLIC, would fail it.
- **PUBLIC USAGE on `public` (security):** accepted. USAGE only allows name lookup. PUBLIC has no
  CONNECT on the database and no privilege on any relation or routine in the schema, and the catalogs
  can be read without USAGE anyway. Side effect: `has_schema_privilege(<group>, 'public', 'USAGE')`
  is always true, and the bootstrap uses exactly that expression as its "migration applied"
  signal → **KL7G-01**.

## 4. Verdict

**PP-01: PASS WITH CONDITIONS.**

All three blocking conditions from KL-007f are met:
- KL7F-01: the runtime groups are per database, and CI shows isolation in both directions.
- KL7F-02: the guard evaluates every reachable role, and CI shows refusals for SET-only and
  predefined roles.
- KL7F-09: the managed-service and rotation documentation is complete.

KL7F-03 to KL7F-06 and KL7F-08 are fixed with CI evidence, and KL7F-07 is mostly documented.

Conditions:
1. **KL7G-01:** fix the "migration applied" test in the bootstrap, or correct DEPLOYMENT §5.1,
   before any database with the KL-013 layout (staging, if it exists) is migrated. Otherwise
   step 1 removes the API's table access until `migrate deploy` has run.
2. Run the first managed-service bootstrap (non-superuser master) in staging and record the
   result, before production. That path has never run; see §5.
3. KL7G-02 to KL7G-06 are not blocking. Schedule them; KL7G-02 and KL7G-05 are cheap to fix.

## 5. Open findings

| ID | Severity | Description | Status |
| -- | -------- | ----------- | ------ |
| KL7G-01 | Low | The bootstrap's "migration applied" check also counts PUBLIC's USAGE on `public`, so step 1 of the legacy-layout path removes the legacy membership before the migration has run; the add/retire precondition does not detect a missing migration either | Open |
| KL7G-02 | Low | The boot guard checks `current_user` only; a connection that switches role at login (session user ≠ current user) is judged by the role it switched to | Open |
| KL7G-03 | Info | Neither the guard nor the bootstrap checks ADMIN OPTION on the runtime group or other LOGIN members of it; foreign or expired logins count toward "not the last login" | Open |
| KL7G-04 | Info | The guard does not check parameter ACLs (`GRANT SET ON PARAMETER`) or EXECUTE grants on administrative or `SECURITY DEFINER` functions | Open |
| KL7G-05 | Info | Strict mode can be relaxed by a psql variable set before the script runs (`-v` or `~/.psqlrc`) when `KABSO_DB_ENV` is unset; the documented command lacks `-X` | Open |
| KL7G-06 | Info | The statement-logging refusal covers only `log_statement=all` and `log_min_duration_statement=0`; audit extensions, DDL logging or sampled logging can still record SCRAM verifiers (never clear text in strict mode) | Open (accept or document) |
| KL7F-07 (part) | Info | PUBLIC CONNECT/TEMP on the `postgres` maintenance database is not documented (bootstrap NOTICE only) | Open |

## 6. Not verified here

- **Any local SQL probe.** There was no admin connection (by instruction), and connecting as the
  migration or runtime login was also blocked in this environment. As a result, the guard query
  and the guard's behaviour against the old shared-`kabso_runtime` layout in the scratch databases
  were **not run** by A7. The guard is covered by CI (E1) and by local unit tests (E6). Legacy-layout
  behaviour (KL7G-01) is derived from code, PostgreSQL semantics and the CI-confirmed PUBLIC USAGE
  on `public`.
- A real admin-run bootstrap outside CI: the full happy path, a re-run on a populated database,
  and the legacy-layout migration in its documented order (CI only re-adds a legacy membership
  after the migration).
- A managed-service master (non-superuser CREATEROLE): the temporary SET self-grant and its
  removal, the logging-refusal branch, and provider-specific settings such as
  `createrole_self_grant` or audit extensions.
- `initdb/10-kabso-roles.sh` inside the `postgres:16.15-alpine` container (no Docker daemon).
- A full `NODE_ENV=production` API boot (the guard was exercised through `PrismaService` with
  `isProduction: true` in CI).
- Logs of CI runs 73, 75 and 77–79 (status only).
