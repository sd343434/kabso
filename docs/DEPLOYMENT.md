# Kabso Live — Deployment, CI and Operations

Owner: DevOps (A8). Status: **Phase 1.** Every section is labelled:

- **[IMPLEMENTED]** — exists in this repository and was validated as stated.
- **[IMPLEMENTED, UNVERIFIED]** — exists in this repository but could not be run in the
  authoring environment (no Docker daemon, Android SDK, Xcode or GitHub runner); it will be
  proven by the first CI run.
- **[DESIGNED]** — the agreed approach; not built yet. Do not assume it exists.

## 1. Local development

### 1.1 Prerequisites

| Tool | Version | Used by |
| ---- | ------- | ------- |
| Node.js | 22.x | `apps/api` |
| pnpm | from `packageManager` in root `package.json` (enable with `corepack enable`) | `apps/api` |
| Flutter | 3.47.7 stable (Dart 3.13.5) | `apps/mobile` |
| Docker + Compose v2 | recent | Postgres, Redis, MinIO |
| openssl | any | generating `JWT_ACCESS_SECRET` |

### 1.2 Bootstrap — [IMPLEMENTED]

```bash
scripts/dev-setup.sh            # checks tools, creates .env, starts Postgres + Redis
scripts/dev-setup.sh --storage  # also MinIO + bucket init (needed from Phase 3)
```

The script is idempotent: it never overwrites an existing `.env`, gives `JWT_ACCESS_SECRET`
and `RATE_LIMIT_KEY_SECRET` separate `openssl rand -base64 48` values only while they are
still placeholders (and appends `RATE_LIMIT_KEY_SECRET` to an older `.env` that lacks it), and
only starts containers when a Docker daemon is reachable (`docker compose up -d --wait` blocks
until health checks pass). Verified locally without a daemon (fresh run, re-run, older `.env`);
shellcheck 0.11.0 reports no findings.

### 1.3 Infrastructure (`docker-compose.yml`) — [IMPLEMENTED, UNVERIFIED]

| Service | Image | Host port (127.0.0.1 only) | Volume | Health check |
| ------- | ----- | -------------------------- | ------ | ------------ |
| `postgres` | `postgres:16.15-alpine@sha256:7218…80ea` | 5432 | `postgres-data` | `pg_isready` |
| `redis` | `redis:7.4-alpine@sha256:858f…3499` (AOF on) | 6379 | `redis-data` | `redis-cli ping` |
| `minio` (profile `storage`) | `pgsty/minio:RELEASE.2026-08-04T00-00-00Z@sha256:b6bf…2372` | 9000 API, 9001 console | `minio-data` | `GET /minio/health/live` |
| `minio-init` (profile `storage`) | same image, one-shot | — | — | creates `$S3_BUCKET` idempotently |

- Credentials are dev defaults overridable from `.env`; database `kabso_dev`, admin user `kabso`.
  On the first start of an empty volume `infra/postgres/initdb/10-kabso-roles.sh` creates the
  migration role `kabso_migrator`, the runtime logins `kabso_app` (`kabso_dev`) and
  `kabso_app_test` (the e2e database `kabso_test`) and their per-database groups (§5.1). The API
  uses `kabso_app`, Prisma's CLI `kabso_migrator`.
- The file validates with `docker compose config` (Compose v5.6.0 CLI, no daemon needed), but
  the containers have **not** been started in the authoring environment (no Docker daemon).
- **MinIO image note:** upstream MinIO no longer publishes community container images
  (`minio/minio` and `minio/mc` on Docker Hub are no longer pullable). The default is the
  community-maintained AGPL build by pgsty, which bundles `mc` and `curl`. Organisations with
  an approved mirror set `MINIO_IMAGE`. MinIO is local-only; cloud environments use S3 or R2.
- Images are pinned by tag **and** registry digest (SEC-021; full digests in the file). The
  digest is the multi-arch index, so the same pin works on amd64 and arm64 machines. To
  refresh, run `scripts/image-digests.sh <image:tag> …` (queries Docker Hub) and update
  `docker-compose.yml` and the CI service containers together. Dependabot bumps the compose
  file only, and ignores new PostgreSQL/Redis **majors** (decision D2).
- Reset everything: `docker compose --profile storage down -v` (deletes all local data).

### 1.4 Configuration

Root `.env.example` documents every variable for local development. The API reads plain
environment variables (validated with Zod at boot); export the root `.env` before starting it
(`set -a; . ./.env; set +a`) or use the API's own loader if `apps/api` documents one. The
mobile app gets only `API_BASE_URL` through `--dart-define`. It never receives secrets.

## 2. Continuous integration (`.github/workflows/ci.yml`) — [IMPLEMENTED]

Evidence: run 13 (`workflow_dispatch` on `fbd1745`) passed all 8 jobs, including the Android
debug APK and the unsigned iOS build. The KL-010 changes below (concurrency, digests, pinned
Redocly, guard removal) are validated locally only until the next run.

Triggers: every `pull_request`, pushes to `main` and `claude/**`, and manual
`workflow_dispatch`, which runs every job. The default token is `contents: read`; only the
change detector also gets `pull-requests: read`. Every third-party action is pinned to a full
commit SHA, and Dependabot proposes updates weekly (with a 7-day cooldown).

**Concurrency rule (KL-010):** a run is only cancelled by a newer run that executes at least
the same jobs. In run 10 the first mobile and Android verification was cancelled by a
docs-only push two minutes later; that can no longer happen.

| Event | Concurrency group | In-progress run cancelled? | Why it is safe |
| ----- | ----------------- | -------------------------- | -------------- |
| `pull_request` | one per PR | yes, by the next push to the PR | paths-filter diffs the whole PR against its base, so the newer run covers a superset of files |
| push to a `claude/**` branch that is **not** the repository default branch | one per branch | **never** | runs queue; GitHub only replaces a run that is still *pending* with the newer one, and paths-filter diffs the branch against its merge-base with the default branch, so the newer run again covers a superset |
| push to the **repository default branch** (detected with `github.event.repository.default_branch`), push to `main`, `workflow_dispatch` | one per run | never, and never replaced | on the default branch paths-filter only diffs against the previous push (`before`); replacing a queued run could leave a commit untested (defect KL-010-D1) |

Cost: at most one running and one queued run per branch. A docs-only push still runs
`changes`, `secrets` and `ci-ok` (about one runner-minute each); the expensive mobile, Android
and API jobs run only when their paths are in the diff. A push to a branch that also has an
open PR produces both a push run and a PR run; only the PR run is cancellable.

| Job | Runs when | Steps |
| --- | --------- | ----- |
| `changes` | always | `dorny/paths-filter` → `api` / `mobile` / `contracts` outputs |
| `api` | `apps/api/**`, `infra/postgres/**`, root `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, or the workflow file changed | Node 22, pnpm (version from `packageManager`, store cached) → `install --frozen-lockfile` → `prisma:generate` → bootstrap DB roles (`infra/postgres/bootstrap-roles.sql` in the service container) → `prisma:migrate:deploy` (migration role) → `lint` → `format:check` → `typecheck` → `test` → `test:e2e` (runtime role) → `build`. Postgres 16.15 and Redis 7.4 service containers, pinned by digest, with health checks. |
| `mobile` | `apps/mobile/**`, design tokens, or the workflow file changed | Flutter 3.47.7 (SDK and pub cache cached) → `pub get --enforce-lockfile` → `build_runner build` → fail on drift (`git diff --exit-code` plus untracked files) → `dart format --set-exit-if-changed lib test` → `flutter analyze` → `flutter test` |
| `android` | same as `mobile` | Temurin 17 with Gradle cache, the Android SDK from the runner image, then `flutter build apk --debug`. The APK is uploaded as an artifact kept for 7 days. **Never run in the authoring environment (no Android SDK, blocker B6).** |
| `ios` | `workflow_dispatch`, or a push to `main` that changes mobile | `macos-latest`, `flutter build ios --no-codesign`. Gated because macOS minutes cost about 10 times Linux minutes. **Never run in the authoring environment.** |
| `contracts` | `docs/contracts/**`, `redocly.yaml`, `tools/redocly/**`, or the workflow file changed | `npm ci --ignore-scripts` in `tools/redocly` (Redocly CLI 2.57.0 pinned by `package-lock.json` with sha512 integrity), then `redocly lint` with the rules in `redocly.yaml`; results shown as PR annotations |
| `secrets` | always | gitleaks 8.30.1 CLI (download checked against its SHA-256) scans the full git history with redacted output |
| `ci-ok` | always | **Allowlist:** passes only if every job's result is `success` or `skipped` (path-filtered or gated); any other result (`failure`, `cancelled`, `abandoned`, `timed_out`, missing, or a future value) fails and names the job. Since KL-010c: run 29 passed while `ios` was `abandoned` (no macOS runner) under the old failure/cancelled denylist. **Make this the only required status check** in branch protection. |

CI test configuration lives in the workflow `env`. It contains clearly fake values
(`ci_test_password_not_secret`, `ci_migrator_password_not_secret`, `ci_app_password_not_secret`,
`ci-test-only-jwt-secret-…`, `ci-test-only-rate-limit-…`)
that only exist inside the ephemeral job. No repository secrets are used by CI today.

The Phase 1 bootstrap guard (skip app jobs while `apps/api` / `apps/mobile` were absent) was
removed in KL-010: both apps exist, so a missing app now fails CI instead of being skipped.

**Supply chain (SEC-021):** actions by commit SHA; service and compose images by digest;
Redocly CLI by lockfile; gitleaks by SHA-256-checked release tarball; API dependencies by
`pnpm install --frozen-lockfile`; Flutter packages by `pubspec.lock` with
`--enforce-lockfile`. Dependabot cooldown: 7 days (14 for majors) for npm, pub, actions and
compose; security updates are not delayed.

**Command contract** the apps must provide: `apps/api/package.json` scripts `prisma:generate`,
`prisma:migrate:deploy`, `lint`, `typecheck`, `format:check`, `test`, `test:e2e`, `build`, and
a root `packageManager` field. `apps/mobile` must keep `build_runner` as a dev dependency and
commit its generated code (decision D5).

**Default branch (human decision pending):** the repository's default branch is currently
`claude/amazing-tesla-5aj3um`; there is no `main` branch. CI handles this: the default branch
is detected at run time for concurrency, and paths-filter compares against it. Places that
still say `main` and only take effect once a `main` branch exists:

- the `push: branches: [main, "claude/**"]` trigger (the current default branch is covered
  by `claude/**`);
- the `ios` job runs on pushes to `main` only, so **today iOS builds run only on
  `workflow_dispatch`**;
- branch protection (below) and the staging deploy trigger in §3 are written for `main`.

Dependabot sets no `target-branch`, so its PRs go to whatever the default branch is (today
`claude/amazing-tesla-5aj3um`). Renaming the default branch to `main` is left to the repository
owner; after that, none of the items above needs changing.

Branch protection on `main` — [DESIGNED]: require a PR, the `CI OK` check, one review and
linear history, and block force pushes. A repository admin has to configure this in GitHub
settings.

## 3. Environments — [DESIGNED]

| | dev (local) | staging | production |
| - | ----------- | ------- | ---------- |
| Purpose | each developer | integration, QA, store test tracks | users |
| Deployed from | working tree | every merge to `main` (automatic) | a tagged release `vX.Y.Z` after staging sign-off (manual approval) |
| Config source | `.env` from `.env.example` | GitHub Environment `staging` plus cloud secret manager | GitHub Environment `production` (required reviewers) plus cloud secret manager |
| Database | compose Postgres | managed Postgres 16 (PITR on) | managed Postgres 16 (PITR on, multi-AZ) |
| Redis | compose Redis | managed Redis 7 | managed Redis 7 (HA) |
| Storage | MinIO | S3/R2 bucket `kabso-media-staging` | S3/R2 bucket `kabso-media-prod` |
| Mail | `MAIL_TRANSPORT=log` | SMTP provider in sandbox mode (B2) | SMTP provider (B2) |

Rules: the same container image is promoted from staging to production; only configuration
differs. Configuration is validated at boot and the process exits on invalid configuration.
Production values are never copied into staging, and production data is never copied into
dev.

### 3.1 Client IP and `TRUST_PROXY` (SEC-003)

Per-IP rate limits (CONVENTIONS §7) are only as good as the client IP. Express derives it from
`X-Forwarded-For` according to `TRUST_PROXY`, and any client can send that header. A wrong
value lets an attacker rotate `X-Forwarded-For` and bypass every per-IP limit (PoC in
`docs/security/KL-007_PHASE1_REVIEW.md`).

- **`TRUST_PROXY=true` is refused when `NODE_ENV=production`** (contract v1.1; the boot check
  is being implemented by A3 in KL-011 — until it is merged, treat it as a deploy-checklist
  item). `true` trusts the left-most, client-controlled entry.
- Use a **hop count** = the number of proxies in front of the API that *append* to
  `X-Forwarded-For` and that every request must pass through; or a **CIDR list** of your own
  proxies' addresses (robust when the hop count varies). Never list a range that clients can
  connect from.
- The API port must only be reachable through those proxies (security group, private
  subnet, ingress-only service). With no proxy in front, a hop count of 1 trusts the client's
  own header — use `false`.

| Platform (request path) | `TRUST_PROXY` | Notes |
| ----------------------- | ------------- | ----- |
| Local dev, docker compose, CI | `false` | no proxy; spoofed headers are ignored |
| AWS ALB → ECS/EC2 | `1`, or the VPC subnets of the ALB, e.g. `10.0.0.0/16` | ALB appends the connecting IP; security group admits only the ALB |
| AWS CloudFront → ALB → app | `2` | CloudFront appends the viewer IP, ALB appends the edge IP; restrict the ALB to the CloudFront origin-facing prefix list |
| GCP external Application LB → GKE/GCE | `2` | the LB appends `<client-ip>,<lb-ip>` |
| Google Cloud Run (no LB in front) | `1` | |
| Kubernetes ingress-nginx behind an L4 (TCP) load balancer | `1` | ingress-nginx is the only appending hop; add 1 per additional L7 proxy |
| Cloudflare → origin LB → app | `2` | allow only Cloudflare IP ranges at the origin |

These values are [DESIGNED] until the platform is chosen. **Verify after every
infrastructure change:** send `curl -H 'X-Forwarded-For: 203.0.113.7' https://<host>/health/ready`
and check that the logged client IP is your real address, not `203.0.113.7`; the API is
planned to log the effective `TRUST_PROXY` setting at boot (KL-011).

### 3.2 API container / runtime spec: libuv threadpool and Argon2

The API caps concurrent Argon2 hashes with `ARGON2_MAX_CONCURRENCY` (default
`os.availableParallelism()`; over the cap, login and register answer 503, contract v1.1). Argon2
runs on the libuv threadpool, which is shared with DNS lookups, file system and crypto work and
defaults to **4** threads. If the pool is smaller than the cap, hashes queue behind each other
and starve DNS and fs work.

- **Rule:** `UV_THREADPOOL_SIZE ≥ ARGON2_MAX_CONCURRENCY + 4`.
- **Set it in the process environment before Node starts**: in the container/task definition
  `env`, the Kubernetes `env:` block, or the systemd unit. libuv reads it once at startup, so
  setting it from application code or a dotenv loader is too late. Locally,
  `set -a; . ./.env; set +a` before `pnpm … start` works.
- **Set both values explicitly per environment.** The default cap follows the CPU count the
  runtime sees, which differs between laptops, CI runners and containers with CPU limits. Size
  them from the container's CPU limit, e.g. 2 vCPU: `ARGON2_MAX_CONCURRENCY=2`,
  `UV_THREADPOOL_SIZE=6`; 8 vCPU: `8` and `12`.
- Memory: each Argon2 hash uses about 19 MiB (`m=19456`), so the cap also bounds hashing memory
  (8 concurrent hashes ≈ 152 MiB). Include this in the container memory limit.
- A startup check or warning in the API when the rule is violated is the backend's call (A3).
  Until then this is a deploy-checklist item. [DESIGNED for deployments; documented in root
  `.env.example`.]

## 4. Secrets management — [DESIGNED]

- **No secret ever lives in the repository or in the mobile app binary.** `.gitignore`
  excludes `.env*` (except `.env.example`), keystores, `key.properties`, `*.p12` and
  Firebase configuration files. The `secrets` CI job scans the history with gitleaks on
  every run **[IMPLEMENTED]**.
- Runtime secrets (`DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`,
  `RATE_LIMIT_KEY_SECRET`, SMTP, S3 and LiveKit keys) live in the cloud secret manager (AWS Secrets Manager or GCP Secret Manager). Each
  environment's workload identity reads only its own secrets. They are injected as environment
  variables at container start.
- Deploy-time credentials live in **GitHub Environments** (`staging`, `production`). Deploy
  jobs use OIDC federation to the cloud provider (no long-lived cloud keys in GitHub).
  `production` requires reviewer approval.
- Mobile signing material (Android upload keystore and its passwords, App Store Connect API
  key, iOS distribution certificate and profiles) is stored as base64 GitHub Environment
  secrets on a `mobile-release` environment, decoded only inside the release job and deleted
  at job end.
- Rotation: `JWT_ACCESS_SECRET` rotation needs dual-key verification (`kid`) so access tokens
  stay valid for up to 15 minutes. Planned for the Security model; until then a rotation
  signs every user out. `RATE_LIMIT_KEY_SECRET` (HMAC key for rate-limit buckets, required in
  production, distinct from the JWT key) can rotate at any time; rotation only resets
  counters. Generate both with `openssl rand -base64 48`. Database passwords rotate through
  the secret manager and the bootstrap script; the runtime login rotates without downtime via
  a second login (§5.1).
- **Database roles (SEC-011 / KL-013):** the API uses a least-privilege runtime role (DML
  only, `DATABASE_URL`); migrations run as a separate migration role (`MIGRATION_DATABASE_URL`,
  given only to the migration job). Both passwords live in the secret manager and are set by
  `infra/postgres/bootstrap-roles.sql` (from SCRAM verifiers outside development), which reads
  them from the environment. Zero-downtime rotation of the runtime login: §5.1.

## 5. Database migrations — [DESIGNED]

- Tooling: Prisma Migrate. Developers create migrations locally with `prisma migrate dev`.
  CI and deployed environments only ever run **`prisma migrate deploy`** (CI already does this
  against the service container **[IMPLEMENTED]**). **Never run `migrate dev`, `db push` or
  `migrate reset` against staging or production.**
- **Pre-deploy job:** each deploy runs one migration job (`pnpm --filter ./apps/api
  prisma:migrate:deploy`) with the migration role, before new application pods start. If it
  fails, the deploy stops and the old version keeps serving.
- **Backup first:** before the migration job in production, take an on-demand snapshot and
  record its id in the deploy log. PITR covers the rest.
- **Expand / contract** so that each release stays compatible with the previous app version
  (needed for rolling deploys and rollback):
  1. *Expand*: add new nullable columns, tables and indexes (`CREATE INDEX CONCURRENTLY` via
     raw SQL for large tables). Ship code that writes both the old and new shapes.
  2. Backfill in batches with an idempotent job, not inside the migration.
  3. Switch reads to the new shape.
  4. *Contract*: drop old columns in a **later** release, once no running version reads them.
- Destructive or locking migrations need a review note in the PR: the expected lock, the
  table size, and the rollback.

### 5.1 Database roles (SEC-011) — [IMPLEMENTED (KL-013, KL-013b); compose init UNVERIFIED]

The API never connects as the schema owner. Roles, **per database** (one database per
environment; several databases may share one PostgreSQL cluster):

| Role | Login | Used by | Rights |
| ---- | ----- | ------- | ------ |
| migration role (`KABSO_DB_MIGRATOR_USER`, default `kabso_migrator`) | yes | the pre-deploy migration job only (`prisma migrate deploy`, `MIGRATION_DATABASE_URL`) | owns schema `public` and every table, sequence, type and function in it; DDL; `CONNECT, TEMPORARY, CREATE` on its database. No `SUPERUSER`, `CREATEROLE`, `REPLICATION`, `BYPASSRLS`; `CREATEDB` only in local dev (shadow database of `prisma migrate dev`). Outside development it must not be used by any other database |
| `kabso_runtime_<database>` (e.g. `kabso_runtime_kabso_prod`) | **no** (group) | holds the runtime grants of THIS database | `CONNECT` on this database only; `USAGE` on `public`; `SELECT, INSERT, UPDATE, DELETE` on app tables; `INSERT, SELECT` only on `audit_logs`; `USAGE, SELECT` on sequences; nothing on `_prisma_migrations`; no `TEMPORARY`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, `CREATE`, `EXECUTE` on functions, ownership or grant options |
| runtime login (`KABSO_DB_APP_USER`, default `kabso_app`) | yes | API pods (`DATABASE_URL`) | member of `kabso_runtime_<database>` and nothing else; all role attributes off; one login per database (never shared between environments) |
| `kabso_runtime` | no | legacy (KL-013) | cluster-wide group of the first implementation. Still created because migration `20261016120000` grants to it; migration `20261016130000` and the bootstrap leave it with no members and no privileges in a migrated database |
| bootstrap / admin (local `POSTGRES_USER`, managed-service master user) | break-glass only | environment bootstrap, password rotation | creates the roles; never used by the API or by migrations |

**Why a NOLOGIN group per database:** migrations are committed SQL, so they may only reference
names that carry no secret and no environment-specific value. Migration `20261016130000` derives
the group name from `current_database()` (dynamic SQL with `format('%I')`), so the same migration
grants to `kabso_runtime_kabso_staging` in staging and to `kabso_runtime_kabso_prod` in
production. A runtime login of one database therefore has no privilege — not even `CONNECT` — in
any other database of the cluster (KL-007f KL7F-01). The database name may be at most 49 bytes
(role names are limited to 63). `PUBLIC` keeps PostgreSQL's default `USAGE` on schema `public`
(name lookup only, no `CREATE`, no privilege on any object in it); access is gated by `CONNECT`
on the database, which `PUBLIC` does not have.

**Where each piece lives (and why):**

1. **Role creation and passwords — bootstrap script, not a migration:**
   `infra/postgres/bootstrap-roles.sql`, run by an admin with `psql` 15 or later. Creating roles
   needs `CREATEROLE`, which the migration role must not have, and passwords must never be in git.
   The script reads everything from the environment (`\getenv`), so nothing appears on the command
   line:

   | Variable | Meaning |
   | -------- | ------- |
   | `KABSO_DB_ENV` | `development` (compose, CI, e2e) or `staging` / `production`. **Unset means production.** Outside development: passwords must be SCRAM verifiers, the known dev/CI default passwords are refused even as verifiers, `CREATEDB` is refused, and a migration role used by another database is refused |
   | `KABSO_DB_MODE` | `bootstrap` (default), `add-runtime-login`, `retire-runtime-login` (rotation, below) |
   | `KABSO_DB_MIGRATOR_USER`, `KABSO_DB_MIGRATOR_PASSWORD` | migration role (bootstrap mode) |
   | `KABSO_DB_APP_USER`, `KABSO_DB_APP_PASSWORD` | runtime login |
   | `KABSO_DB_MIGRATOR_CREATEDB` | `true` only for local dev |

   The whole run is **one transaction**: it validates every input and every pre-existing role
   first (no unsafe attributes, no `NOLOGIN` role turned into a login, no membership in other
   roles, no ownership or privileges in other databases, the runtime login owns nothing), then
   creates/updates the roles, the database ACL (`PUBLIC` gets nothing, the group `CONNECT` only)
   and the owner of `public`, and finally verifies the result. Any error rolls everything back.
   It is idempotent and re-sets the passwords on every run.
2. **Grants on schema objects — Prisma migrations** (run as the migration role, so they live
   with the schema they protect): `20261016120000_runtime_role_grants` (KL-013) and
   `20261016130000_per_database_runtime_group` (KL-013b), which moves every runtime grant from
   the legacy group to `kabso_runtime_<database>` (same privileges per table, so `audit_logs`
   stays append-only), sets `ALTER DEFAULT PRIVILEGES` for tables and sequences created later,
   revokes `EXECUTE` on functions from `PUBLIC` (existing ones and, through global default
   privileges, future ones), and removes everything the legacy group held. It refuses to run
   unless the current role **is** the owner of schema `public` (not merely a member of it) and
   reaches no superuser / `CREATEROLE` / `BYPASSRLS` / `REPLICATION` role, and it refuses if the
   group does not exist (bootstrap first).

**Passwords outside development (KL7F-05):** pass SCRAM-SHA-256 verifiers, never clear text, so
no clear-text password is ever part of an SQL statement the server could log. Generate a
verifier from the password (read from stdin, not argv):

```bash
read -rs PW && printf '%s' "$PW" | node infra/postgres/scram-verifier.mjs; unset PW
# -> SCRAM-SHA-256$4096:<salt>$<StoredKey>:<ServerKey>   (goes into KABSO_DB_*_PASSWORD)
# The clear-text password goes only into the DATABASE_URL / MIGRATION_DATABASE_URL secrets.
```

When the admin is a superuser, the script also turns statement logging off for its own
transaction (`log_statement`, `log_min_error_statement`, `log_min_duration_statement`). A
managed-service master usually may not; if the server logs every statement and the script cannot
change that, it refuses to run.

```bash
# Once per database, as the admin; values from the secret manager:
export KABSO_DB_ENV=production
export KABSO_DB_MIGRATOR_USER=kabso_migrator_prod KABSO_DB_MIGRATOR_PASSWORD='SCRAM-SHA-256$...'
export KABSO_DB_APP_USER=kabso_app_prod           KABSO_DB_APP_PASSWORD='SCRAM-SHA-256$...'
psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/postgres/bootstrap-roles.sql

# Every deploy, pre-deploy job:
MIGRATION_DATABASE_URL=postgresql://kabso_migrator_prod:...@host/kabso_prod pnpm --filter ./apps/api prisma:migrate:deploy
# API pods get only DATABASE_URL=postgresql://kabso_app_prod:...@host/kabso_prod
```

**Managed services (KL7F-09):** the master user is not a superuser but has `CREATEROLE` and owns
the database. On PostgreSQL 16 changing the owner of `public` requires the right to `SET ROLE`
to the migration role; the script grants that to the master itself (`WITH INHERIT FALSE, SET
TRUE`) for the duration of the transaction and revokes it again before `COMMIT`, so no manual
`GRANT` and no re-run is needed. The database must be owned by the master or the migration role,
never by the runtime login (the script refuses that).

**Migrating a database bootstrapped with the KL-013 layout** (`kabso_runtime`), e.g. staging if
it was set up before KL-013b. All three steps belong to one maintenance window; the API keeps
working throughout:

1. Re-run the bootstrap (new script) for the database. It creates `kabso_runtime_<database>`,
   adds the runtime login to it, revokes `CONNECT` of `kabso_runtime` (and of `PUBLIC`) on this
   database and keeps the login's legacy membership for now (the new group has no table grants
   yet; the script says so in a NOTICE).
2. `prisma migrate deploy` — applies `20261016130000`, which copies the grants to the new group
   and removes them from `kabso_runtime`.
3. Re-run the bootstrap. It now removes the legacy `kabso_runtime` membership and verifies the
   final layout. The boot guard rejects a login that is still in `kabso_runtime`, so do not
   restart API pods between steps 1 and 3 in production.

If `migrate deploy` runs before step 1, the migration stops with `role "kabso_runtime_<database>"
does not exist` and changes nothing, but Prisma records it as failed: run `prisma migrate resolve
--rolled-back 20261016130000_per_database_runtime_group` (migration role), then step 1, then
deploy again.

Repeat for every database of the cluster. A runtime login that served several databases must be
split first (one login per database): the bootstrap refuses a login that is already a member of
another database's group or has privileges in another database.

**Zero-downtime password rotation (runtime login):** use a second login and switch:

1. Add the new login (no other change):
   `KABSO_DB_MODE=add-runtime-login KABSO_DB_APP_USER=kabso_app_prod_b KABSO_DB_APP_PASSWORD='SCRAM-SHA-256$...' psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/postgres/bootstrap-roles.sql`
2. Put the new `DATABASE_URL` into the secret manager and do a rolling restart; wait until no
   session of the old login remains (`pg_stat_activity`).
3. Retire the old login: `KABSO_DB_MODE=retire-runtime-login KABSO_DB_APP_USER=kabso_app_prod psql ...`
   (removes it from the group, sets `NOLOGIN` and clears its password; refuses if it is the
   group's last login). Drop it later with `DROP ROLE` once it is no longer needed.

The next rotation goes back from `_b` to the first name. The migration role is only used by the
short pre-deploy job: rotate it by re-running the bootstrap (mode `bootstrap`) with a new
verifier between deploys.

**Rules for future migrations** (also in `docs/DATABASE_SCHEMA.md`, with the reusable guard):

- Migrations **must run as the migration role**: default privileges only apply to objects that
  role creates. New tables then need no `GRANT`. A table that must be append-only or read-only
  gets an explicit `REVOKE` in the migration that creates it (dynamic SQL on
  `'kabso_runtime_' || current_database()`). Never grant `TRUNCATE`, `REFERENCES`, `TRIGGER`,
  grant options or ownership to the runtime group, and never name a login role or password in a
  migration. A function the API must call needs an explicit `GRANT EXECUTE` to the group.

**Boot-time guard [IMPLEMENTED]:** after connecting, the API inspects its own role and **every
role it can reach through membership** — including `SET`-only memberships with `INHERIT FALSE`
(`src/prisma/runtime-role-check.ts`). It is refused when: it (or a reachable role) is a superuser
or has `CREATEROLE`, `CREATEDB`, `REPLICATION` or `BYPASSRLS`; it can reach any role other than
itself and `kabso_runtime_<current database>` (e.g. `pg_read_all_data`, `pg_write_server_files`,
`pg_execute_server_program`, `pg_database_owner`, the migration role, the legacy `kabso_runtime`);
it is not a member of that group; it owns any non-system schema or relation; it may `CREATE` in a
schema or the database, or create `TEMPORARY` tables; it holds `TRUNCATE`/`REFERENCES`/`TRIGGER`
on a table, `UPDATE`/`DELETE` (also column-level) on `audit_logs`, any privilege on
`_prisma_migrations`, or a grant option on any table, schema, function or the database; or it
owns, or holds privileges in, another database. With `NODE_ENV=production` any finding — or
failing to inspect the role — logs `db.runtime_role_check failed — refusing to start. …` at fatal
level and aborts the boot (fail closed, no override). Outside production the same finding is a
warning so older single-role dev setups still start.

**Accepted PostgreSQL limits (KL7F-07):** every login may change its own password and its own
role-level settings (`ALTER ROLE CURRENT_USER SET ...`), and may create large objects; PostgreSQL
has no privilege to prevent this. Consequences: per-role timeouts set with `ALTER ROLE` (below)
are advisory, not a security control; the runtime login's password lives only in the secret
manager, so a changed password shows up as failed connections, not as silent access. Large
objects are not used by the API.

**Where it runs:**

- **Local compose:** `infra/postgres/initdb/10-kabso-roles.sh` runs the bootstrap
  (`KABSO_DB_ENV=development`) on the first start of an empty volume: `kabso_dev` with runtime
  login `kabso_app`, `kabso_test` with its own runtime login `kabso_app_test` (one login per
  database); both share `kabso_migrator` (`CREATEDB` for the shadow database). An existing volume
  needs the migration steps above (or `docker compose down -v`, which deletes local data).
  **UNVERIFIED** in a container (no Docker daemon in the authoring environment).
- **CI:** step "Bootstrap database roles" runs the same SQL inside the service container as the
  admin user (`KABSO_DB_ENV=development`), then `migrate deploy` uses `MIGRATION_DATABASE_URL`
  and the unit/e2e suites use the runtime login (`DATABASE_URL`). The e2e step also gets the
  admin URL (`KABSO_TEST_ADMIN_DATABASE_URL`) and runs the bootstrap with the runner's `psql` for
  the KL-013b tests.
- **E2E suite:** needs both URLs for the same `*_test` database and refuses to run if they use
  the same role. It migrates and truncates as the migration role; the API under test is the
  runtime login. `test/security/kl013-db-roles.e2e-spec.ts` proves that DDL, `TRUNCATE`,
  `CREATE ROLE`, `GRANT` and the like fail, DML works, `audit_logs` is append-only, a table
  created later is DML- but not DDL-accessible, functions are not executable by `PUBLIC`, and the
  boot guard rejects the owner role, reachable predefined/`CREATEROLE` roles and object-level
  grants. With an admin URL it also creates a second database and proves cross-database
  isolation, the bootstrap's refusals, its atomicity and the rotation modes.
- **Staging / production:** bootstrap once per database as above before the first migration.

Optional hardening not applied by the script (tune per environment; see KL7F-07): `ALTER ROLE
kabso_app_prod SET statement_timeout = '15s'`, `idle_in_transaction_session_timeout = '30s'` and
a `CONNECTION LIMIT`.

### 5.2 Level systems (migration `20261020090000_levels`, D72) — [IMPLEMENTED, draft contract]

- Additive. Seeds the four categories **disabled with no version**; no multiplier or threshold
  is seeded (CP-005 §9: the owner decides them). `points_ledger` and `level_history` are
  append-only for the runtime group (REVOKE UPDATE/DELETE/TRUNCATE, like `audit_logs`).
- Nothing earns points in production: the `SourceTransactionVerifier` port defaults to
  `UnavailableSourceVerifier`, which refuses every event. A gifts/wallet/games module must
  provide a verifier against its own committed ledger before any category is enabled.
- Activation order per category: create a draft, fill it, `validate`, `preview`, `publish`, then
  `PATCH … {enabled: true}` — each by an `ADMIN` and audited. Disabling stops crediting but keeps
  stored points; reversals still apply.
- Admin rights (migration `20261021090000_admin_permissions`): an admin endpoint needs
  `role = ADMIN` and its permission. Grant with the migration role, e.g.
  `MIGRATION_DATABASE_URL=… pnpm levels:admin grant owner@example.com ALL`
  (`revoke`, `list` likewise); the runtime role can only read the table. Every grant is audited.
- The owner's ladder (CP-005 §9.1): `pnpm levels:admin draft-preset <admin email>` writes one DRAFT
  per category (100 levels, ×0.1). Review, then publish with `PRESERVE_POINTS` and enable.
- Room level (CP-016 D, D101, CONVENTIONS §10.18): live taps credit the host's `ATTRACTIVENESS`
  points (10 counted taps = 1 point, `LIVE_TAPS`) inside the taps transaction, from the server's
  own count, so they need no source verifier. They credit nothing, and `LiveRoom.roomLevel` stays
  null, until `ATTRACTIVENESS` is published and enabled as above. Gifts still need the verifier.
- `pnpm levels:admin publish-charm <admin email>` (owner D101) does that in one audited step: the
  owner's ladder for `ATTRACTIVENESS` (the newest draft, or a new one from the preset) published
  and enabled. It refuses once anyone holds charm points (then publish through the API, which
  recalculates). The tool is built into the API image as `dist/cli/levels-admin.js`; on the
  server (§11), from `/opt/kabso/infra/deploy`:

  ```bash
  # once: the owner's account becomes an admin
  docker exec kabso-postgres-1 psql -U kabso_admin -d kabso \
    -c "UPDATE users SET role = 'ADMIN' WHERE email = lower('owner@example.com')"
  # the migration role runs the tool
  docker compose --profile jobs run --rm migrate node dist/cli/levels-admin.js publish-charm owner@example.com
  ```
- After an incident: `POST /admin/levels/reconciliation {mode: "DRY_RUN"}` reports states that
  differ from their ledger and failed or stuck events; `REPAIR` rebuilds the states from the
  ledger and retries the events. The ledger itself is never edited.

### 5.3 Media storage (migration `20261022090000_social_m1`, CP-006 M1) — [IMPLEMENTED, draft contract; storage BLOCKED B12]

- **Provider:** S3-compatible. Locally MinIO (`docker compose --profile storage up -d`), in the
  cloud Cloudflare R2 (D45). Settings: `S3_ENDPOINT`, `S3_REGION` (`auto` for R2), `S3_BUCKET`,
  `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (secret manager only), `S3_FORCE_PATH_STYLE`
  (`true` for MinIO), `MEDIA_PUBLIC_BASE_URL`, `MEDIA_UPLOADS_ENABLED` (default `false`; the API
  refuses to start with it on and any of bucket, keys or public URL missing; production refuses
  plain-http endpoints).
- **Bucket layout:** `uploads/{userId}/{uploadId}` holds raw client uploads for minutes (private,
  deleted after verification or by the sweeper); `media/{mediaId}/1080.webp` and `/320.webp`
  are the processed, metadata-free images. **Only `media/` may be publicly readable** — through
  the CDN / R2 custom domain set as `MEDIA_PUBLIC_BASE_URL`, or a public-read policy limited to
  that prefix. `uploads/` must never be public.
- **Token scope:** the API key needs `PutObject`, `GetObject`, `HeadObject`, `DeleteObject` on the
  bucket only. No CORS rule is needed for the mobile app (it is not a browser); a future web
  client needs `PUT` allowed from its origin on `uploads/` only.
- **Lifecycle:** the in-process media sweeper (`MEDIA_SWEEP_INTERVAL_SECONDS`, 300 s, refused at
  0 in production) closes expired slots and deletes assets never attached to a post within 24 h.
  A bucket lifecycle rule that deletes `uploads/` objects older than 2 days is a recommended
  backstop.
- **Live video (CP-010, D93):** LiveKit (D3). Set `LIVEKIT_URL` (`wss://` in production),
  `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` from the secret manager (B1); all three are required
  when `LIVE_HOSTING_ENABLED=true`. Configure the LiveKit project's webhook to
  `POST https://<api-host>/internal/livekit/webhook` (signed with the same key; outside `/api/v1`,
  not public API): it records who is watching. The in-process reconciliation (every
  `LIVE_SWEEP_INTERVAL_SECONDS`) closes media sessions of rooms that are no longer live. Going live
  also needs the hosting permission (`PUT /api/v1/admin/live/hosts/{username}`, admin permission
  `LIVE_HOSTS`); keep `LIVE_HOSTING_ENABLED=false` in production until L1b (agencies and identity
  checks) is done. Locally: `livekit-server --dev --bind 127.0.0.1` with the `.env.example` values.
- **Notifications retention (CP-009):** the in-process sweeper
  (`NOTIFICATIONS_SWEEP_INTERVAL_SECONDS`, 3600 s, refused at 0 in production) deletes
  notifications whose latest activity is older than 30 days. `POST /notifications/read` is
  limited by `RATE_LIMIT_NOTIFICATIONS_READ_USER` (120 / hour); the inbox and the unread count
  share `RATE_LIMIT_FEED_USER`.
- **Verification:** `apps/api/test/kl060-s3-storage.e2e-spec.ts` runs the production adapter
  against any S3-compatible server when `S3_TEST_ENDPOINT` (plus `S3_TEST_ACCESS_KEY_ID` /
  `S3_TEST_SECRET_ACCESS_KEY`) is set; verified against moto 5.1 in development (MinIO could not
  run in the authoring environment: no Docker daemon).
- **Missing before uploads can be turned on anywhere but locally:** the R2 account, bucket,
  custom domain and API token (B12), and an image-moderation provider (B13; until then photo
  posts are visible only to their author, CONVENTIONS §11.2).

## 6. Observability baseline

| Item | Status |
| ---- | ------ |
| Structured JSON logs (pino) with secret redaction | [DESIGNED in architecture; implemented by KL-002 — verify in apps/api] |
| `X-Request-Id` on every response, propagated to logs | Contract in `CONVENTIONS.md` §1; implemented by KL-002 |
| `GET /health/live` (process up), `GET /health/ready` (DB and Redis reachable) | Contract in `openapi.yaml`; implemented by KL-002 |
| Liveness/readiness probes wired to those endpoints in the orchestrator | [DESIGNED] |
| Error reporting (e.g. Sentry for API and Flutter, with PII scrubbing) | [DESIGNED — not added; needs a provider decision] |
| Metrics (RED per route, DB pool, Redis latency) and alerting on readiness failures and 5xx rate | [DESIGNED] |
| Log shipping and retention (30 days hot) | [DESIGNED] |

Logs never contain tokens, passwords, refresh secrets or full email bodies.

## 7. Backup and restore — [DESIGNED]

- **PostgreSQL:** managed service with point-in-time recovery (WAL archiving), with 7 days of
  retention in staging and 30 in production, plus daily snapshots copied to a second region.
  Targets: RPO ≤ 5 min, RTO ≤ 1 h.
- **Restore drill** each quarter: restore PITR into a fresh instance, run `prisma migrate
  status`, run smoke tests against it, and record the timings.
- **Redis** holds only rebuildable data (rate limits, caches). No backup; losing it signs
  nobody out because sessions are in Postgres.
- **Object storage:** versioning on, with a lifecycle rule for non-current versions and
  cross-region replication for production media.
- **Local:** `docker compose exec postgres pg_dump -U kabso kabso_dev > backup.sql`.

## 8. Rollback procedure — [DESIGNED]

1. **App rollback** (the default): redeploy the previous image tag. This is safe because of
   expand/contract: the previous version still understands the current schema.
2. **Do not roll back migrations** by running down-migrations in production. If a migration is
   wrong, ship a forward fix migration.
3. **Data corruption:** restore to a new instance through PITR at a time before the incident,
   reconcile, then switch `DATABASE_URL` (a secret manager update and a rolling restart).
4. **Mobile:** a released binary cannot be recalled. Halt the staged rollout (Play) or pause
   the phased release (App Store), then ship a fix. Server-side feature flags and a minimum
   supported client version check (`X-Client` header) are [DESIGNED] to disable broken clients.
5. Write a post-incident note in `docs/` within 48 hours.

## 9. Mobile release preparation — [DESIGNED]

- **Versioning:** `pubspec.yaml` `version: MAJOR.MINOR.PATCH+BUILD`. Semantic version for
  users; `BUILD` is a monotonically increasing integer (the CI run number) used as the Android
  `versionCode` and iOS `CFBundleVersion`. Releases are tagged `mobile-vX.Y.Z`.
- **Bundle id:** `com.kabso.live` is a placeholder (blocker B7).
- **Android:** release builds (`flutter build appbundle --release`) are signed in CI from
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
  `ANDROID_KEY_PASSWORD` (GitHub Environment `mobile-release`). Play App Signing holds the app
  signing key, and CI holds only the upload key. Tracks: internal → closed testing → production
  with a staged rollout (10% → 50% → 100%).
- **iOS:** `flutter build ipa` on macOS with an App Store Connect API key
  (`APP_STORE_CONNECT_API_KEY_*`) and match or manual certificates stored as secrets. Tracks:
  TestFlight internal → TestFlight external → App Store phased release. Needs an Apple
  developer account (blockers B4 and B6).
- **Build flavours:** `API_BASE_URL` per environment through `--dart-define` (staging builds
  go to the internal and TestFlight tracks only).
- **Today:** CI produces an unsigned Android **debug** APK and an unsigned iOS build on
  dispatch or main; both compiled in run 13 but are not device-tested (see §2 and §10).

## 10. What is not verified

- CI ran green on GitHub in run 13 (`fbd1745`). The KL-010 workflow changes (concurrency
  groups, digest-pinned service images, pinned Redocly install, guard removal,
  `--enforce-lockfile`) pass `actionlint` 1.7.12 with shellcheck 0.11.0 but have not run on
  GitHub yet.
- The Docker Compose services have never been started (no daemon in the authoring
  environment).
- KL-013 / KL-013b: the compose init script (`infra/postgres/initdb/10-kabso-roles.sh`) has
  not run in a container yet. KL-013b's bootstrap script, its admin-only e2e tests (which need
  `psql` >= 15 on the CI runner) and the CI "Bootstrap database roles" step are first proven by
  CI (decision D19); see the KL-013b report for what was run locally.
- The Android debug APK and unsigned iOS build compile in CI (run 13); neither has been
  installed on a device or emulator.
- The Dependabot `cooldown` / `ignore` settings were validated against the published schema;
  their effect is only visible in the next weekly Dependabot run.
- The per-platform `TRUST_PROXY` values in §3.1 are based on each platform's documented
  `X-Forwarded-For` behaviour and must be verified on the real deployment.

## 11. Single-server deployment with automatic updates (KL-069) — [IMPLEMENTED]

The first real server (Hostinger VPS, Ubuntu 26.04 LTS, domain `kabsolive.com`) runs the whole
stack with Docker Compose. It is the staging/beta server of §3, not the managed production
platform. Files: `apps/api/Dockerfile`, `.dockerignore`, `infra/deploy/`,
the `deploy-image` job of `.github/workflows/ci.yml`.

| Host | Service |
| ---- | ------- |
| `kabsolive.com` | Caddy, a static "coming soon" page (`infra/deploy/site`) |
| `api.kabsolive.com` | Caddy → API (`/internal/*` answers 404 from outside) |
| `live.kabsolive.com` | Caddy → LiveKit signalling (`wss://`); media on 7881/tcp, 7882/udp |

PostgreSQL, Redis and the API are not published; only 80, 443 (TCP+UDP), 7881/tcp and
7882/udp are. Caddy gets and renews the Let's Encrypt certificates once the three DNS A
records point at the server.

**Release flow (no manual server step):**

1. A commit reaches the `staging` branch (pushed only with the owner's approval).
2. CI runs on it (`ci.yml`). Only when `ci-ok` is green does its `deploy-image` job build
   `apps/api/Dockerfile` from that exact commit, smoke-test it, and push
   `ghcr.io/sd343434/kabso-api:staging` and `:sha-<commit>` with the job's own `GITHUB_TOKEN`.
   No secret is stored in GitHub.
3. On the server, `kabso-update.timer` runs `infra/deploy/update.sh` every 5 minutes: it
   fast-forwards `/opt/kabso` to `origin/staging`, pulls the image, and when either changed runs
   `prisma migrate deploy` as the migration role (`migrate` service, the only one with
   `MIGRATION_DATABASE_URL`), restarts what changed and waits for `/health/ready`. A failed
   migration stops the update and the running API keeps serving.

**One-time setup** (as root, from the provider's browser terminal; read the script first):

```bash
curl -fsSL https://raw.githubusercontent.com/sd343434/kabso/staging/infra/deploy/install.sh -o install.sh
bash install.sh
```

It installs Docker, opens the firewall, clones the repository, and generates every secret on
the server into `/etc/kabso/*.env` (mode 600): JWT, rate-limit, registration-code and cursor
keys (`openssl rand`, accepted by `secret-strength.ts`), the three database passwords (the
bootstrap gets SCRAM verifiers only, §5.1), and the LiveKit key pair. It asks for the domain,
the certificate e-mail and the SMTP settings (password without echo). Re-running keeps existing
secrets. Before the first run the `kabso-api` package must exist (first green CI on
`staging`) and be **public** (GitHub → Packages → kabso-api → Package settings → Change
visibility), because the server pulls without a token.

Settings the script writes: `NODE_ENV=production`, `TRUST_PROXY=1` (Caddy is the one appending
proxy, §3.1), `MAIL_TRANSPORT=smtp`, `LIVE_HOSTING_ENABLED=true` with the server's own LiveKit
(webhook over the internal network), `MEDIA_UPLOADS_ENABLED=false` (B12, uploads answer 503),
`ARGON2_MAX_CONCURRENCY` = vCPUs and `UV_THREADPOOL_SIZE` = vCPUs + 4 (§3.2).

**Rollback:** set `KABSO_API_IMAGE='ghcr.io/sd343434/kabso-api:sha-<good commit>'` in
`/etc/kabso/kabso.env` and run `bash /opt/kabso/infra/deploy/update.sh --force` (migrations are
expand/contract, §5, so the previous image keeps working); set it back to `:staging` afterwards.

**Verified on the server (2026-10-25, Hostinger KVM 1, Ubuntu 26.04.1):** CI published the
image from `staging`; `install.sh` installed the stack, applied all migrations as the migration
role and started the API; Caddy obtained the certificates and
`https://api.kabsolive.com/health/ready` answers `ok` (database and Redis). One fix came from
it: text typed on an Arabic keyboard carried an invisible direction mark into the certificate
e-mail, which Let's Encrypt refused; `install.sh` now keeps printable ASCII only and checks
every env file. `update.sh` links `/etc/kabso/kabso.env` as the compose `.env`, so
`docker compose -f /opt/kabso/infra/deploy/docker-compose.yml ps|logs <service>` works by hand.

**Verified earlier in the authoring environment (no Docker daemon, no server):** the frozen
`pnpm install` and `pnpm --filter @kabso/api build` the Dockerfile runs; the env files the
script generates pass the API's own `loadConfig` with `NODE_ENV=production` (and fail without
the SMTP password); on an empty PostgreSQL 16 database the initdb step created the role layout
with production verifiers, `prisma migrate deploy` as the migration role applied every migration,
and the API started as the runtime role with `/health/ready` 200; LiveKit 1.9.1 started with the
generated `livekit.yaml`; `caddy validate` (2.10.2) accepted the Caddyfile; `docker compose
config` accepted the compose file; `ci.yml` parses as YAML (no actionlint available). **Not verified yet:** the timer's first automatic update, real mail delivery, and WebRTC media through the server's firewall (a TURN server may be needed for
some mobile networks).
