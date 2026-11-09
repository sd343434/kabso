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
mobile app gets `API_BASE_URL` through `--dart-define`. It never receives server secrets; the
one other define is D144's DeepAR client licence key (`DEEPAR_LICENSE_ANDROID`, see §9.1),
which is optional.

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
| `mobile` | `apps/mobile/**`, design tokens, or the workflow file changed | Flutter 3.47.7 (SDK and pub cache cached) → `pub get --enforce-lockfile` → `build_runner build` → fail on drift (`git diff --exit-code` plus untracked files) → `dart format --set-exit-if-changed lib test` → `flutter analyze` → `flutter test` → (D144) the same format/analyze/test in the local plugin `packages/kabso_camera_fx` (excluded from the app's analysis) |
| `android` | same as `mobile` | Temurin 17 with Gradle cache, the Android SDK from the runner image, then `flutter build apk --debug --dart-define=DEEPAR_LICENSE_ANDROID=…` (D144: from the `DEEPAR_LICENSE_ANDROID` repository secret through `env`, never echoed; empty without the secret, and the build still passes). The APK is uploaded as an artifact kept for 7 days. **Never run in the authoring environment (no Android SDK, blocker B6).** |
| `ios` | `workflow_dispatch`, or a push to `main` that changes mobile | `macos-latest`, `flutter build ios --no-codesign`. Gated because macOS minutes cost about 10 times Linux minutes. **Never run in the authoring environment.** |
| `contracts` | `docs/contracts/**`, `redocly.yaml`, `tools/redocly/**`, or the workflow file changed | `npm ci --ignore-scripts` in `tools/redocly` (Redocly CLI 2.57.0 pinned by `package-lock.json` with sha512 integrity), then `redocly lint` with the rules in `redocly.yaml`; results shown as PR annotations |
| `secrets` | always | gitleaks 8.30.1 CLI (download checked against its SHA-256) scans the full git history with redacted output |
| `ci-ok` | always | **Allowlist:** passes only if every job's result is `success` or `skipped` (path-filtered or gated); any other result (`failure`, `cancelled`, `abandoned`, `timed_out`, missing, or a future value) fails and names the job. Since KL-010c: run 29 passed while `ios` was `abandoned` (no macOS runner) under the old failure/cancelled denylist. **Make this the only required status check** in branch protection. |
| `staging-apk` | push to `staging`, after a green `ci-ok` | The staging test APK: `flutter build apk --profile --split-per-abi --target-platform android-arm64` (arm64-v8a only since KL-069; no universal APK for staging) with `API_BASE_URL=https://api.kabsolive.com`, `APP_VERSION=0.1.0-staging+<sha7>` and the DeepAR key (D144); `google-services.json` from the secret (D152). Artifact `kabso-live-staging-arm64-apk` (file `kabso-live-staging-arm64.apk`), kept 14 days. |
| `staging-apk-release` | after `staging-apk` succeeded | *(D330, §11.8)* Publishes that APK as `kabso-staging.apk` + `kabso-staging.txt` (commit, version, sha256, size) of the rolling public prerelease `staging-latest` (tag moved to the commit, assets replaced). The only job with `contents: write` (+ `actions: read` for `gh run download`); no checkout, no third-party action, no secret. |

CI test configuration lives in the workflow `env`. It contains clearly fake values
(`ci_test_password_not_secret`, `ci_migrator_password_not_secret`, `ci_app_password_not_secret`,
`ci-test-only-jwt-secret-…`, `ci-test-only-rate-limit-…`)
that only exist inside the ephemeral job. The only repository secret CI reads is D144's optional
`DEEPAR_LICENSE_ANDROID` (the `android` job, §9.1).

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
  *(D123)* A live keeps running in the background through an Android foreground service (types
  `microphone` and `mediaPlayback`): the Play Console's foreground-service declaration must list
  both, with a short video of going live, leaving the app and the ongoing notification. Keep
  `LIVE_HEARTBEAT_STALE_SECONDS` (45) at least 2 × `LIVE_HEARTBEAT_INTERVAL_SECONDS` (15) as
  enforced: the backgrounded app keeps beating at the interval.
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
- **D222 (v1.75-social):** the OWNER can now enter and turn on R2 (or any S3) in the admin panel «التخزين (R2 / S3)»
  instead of these env settings — two buckets (public `media/`, private `uploads/` + `private/`), panel over env, no
  restart. Steps (Arabic and English): §5.40.

### 5.4 Coins (migration `20261108090000_wallet_and_bullets`, CP-017, D104) — [IMPLEMENTED, draft contract]

- Additive: `wallets` (one balance per user, 0 without a row), `wallet_ledger` (every change;
  append-only for the runtime group, like `points_ledger`) and `live_bullets`. Bullet messages
  cost 15 coins (CONVENTIONS §10.19). There is no purchase yet (B5): coins are granted only by an
  admin with the migration role.
- `pnpm wallet:admin grant <email> <coins>` adds coins (a positive whole number, at most 10^9 per
  command); `revoke <email> <coins>` takes them back (refused if the balance is smaller);
  `balance <email>` prints it. Every grant and revoke writes a ledger row and an audit log row
  (`wallet.grant` / `wallet.revoke`) in one transaction. The tool is built into the API image as
  `dist/cli/wallet-admin.js`; on the server, from `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/wallet-admin.js grant someone@example.com 100
  docker compose --profile jobs run --rm migrate node dist/cli/wallet-admin.js balance someone@example.com
  ```
- Voice clips and images of the live chat (migration `20261108100000_live_chat_media`) are
  deleted by the live sweeper 60 s after they were sent (`LIVE_SWEEP_INTERVAL_SECONDS` cadence);
  they need `MEDIA_UPLOADS_ENABLED` like every upload. While it is off, every live-chat picture and
  voice clip is refused with 503 `MEDIA_UPLOADS_UNAVAILABLE` (the app says photo uploads / voice
  messages are unavailable, D118); turning them on needs `MEDIA_UPLOADS_ENABLED=true` plus
  `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `MEDIA_PUBLIC_BASE_URL` (required, or
  the API refuses to start), `S3_ENDPOINT` and `S3_REGION` (`auto`) for R2, as in §5.3.

### 5.5 Families, CP couples and medals (migrations `20261110090000_families_cp_medals_enums`, `20261110100000_families_cp_medals`, `20261110110000_medal_showcase`; CP-018, D106) — [IMPLEMENTED, draft contract]

- Additive. The first migration only adds enum values (`wallet_ledger_reason`: `FAMILY_CREATE`,
  `CP_REQUEST`, `CP_REFUND`, `CP_GIFT`; `notification_type`: five CP-018 types), because PostgreSQL
  cannot use a value added in the same transaction; the second creates the family, CP and medal
  tables, replaces the `wallet_ledger_reason_sign` and `media_assets_kind_known` CHECKs, seeds the
  medal catalogue (9 medals) and makes `family_points_ledger` append-only for the runtime group;
  the third adds `user_medals.showcase_position`. Apply them in order with the usual
  `migrate` job (§5); no data is rewritten.
- New server config `BONDS_SWEEP_INTERVAL_SECONDS` (default 300; `0` disables it and is refused in
  production): the sweeper that expires family join requests and CP requests after 7 days and gives
  the CP request's 99 coins back. New rate-limit settings `RATE_LIMIT_FAMILY_WRITE_USER` (60/3600),
  `RATE_LIMIT_CP_WRITE_USER` (30/3600), `RATE_LIMIT_CP_GIFT_USER` (30/60), all optional.
- **Medals backfill, once after the deploy** (medals are awarded automatically from then on):
  `pnpm medals:admin backfill [--notify]` awards every medal earned by past events (hosted lives
  and hours, charm levels, family members, couples, bullet senders). Idempotent (a second run
  awards nothing); writes one `medals.backfill` audit row; without `--notify` it sends no
  notifications (recommended for the first run, so old events do not flood inboxes). Built into
  the API image as `dist/cli/medals-admin.js`; on the server, from `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/medals-admin.js backfill
  ```

### 5.6 The bag (migration `20261111090000_bag`; CP-019, D107) — [IMPLEMENTED, draft contract]

- Additive: creates `bag_items` (the catalogue, seeded with `bunny_royal` (free), `kabi_royal`,
  `golden_stags`, `emerald_wings`) and `user_bag_items` (owned items, at most one worn per user and
  category), with the enums `bag_category` and `bag_item_source`. Apply it with the usual
  `migrate` job (§5); no new server config, no new rate-limit setting (`PUT /me/bag/equipped`
  uses `RATE_LIMIT_FAMILY_WRITE_USER`).
- **Backfill inside the migration (no separate step):** every account that exists when it runs
  and is not deleted receives `bunny_royal` (source `BACKFILL`) and wears it (owner D107: those
  users never chose to take it off). It is one `INSERT … SELECT` over `users` in the migration's
  transaction; it skips accounts that already own the item, so it never puts back an item someone
  took off. Accounts created afterwards receive and wear it at signup, in the account's
  transaction.
- **Granting the other items** (no store yet): `pnpm bag:admin grant <email> <code>`,
  `revoke <email> <code>`, `list <email>`. Runs as the migration role; granting does not change
  what the user wears; each change writes a `bag.grant` / `bag.revoke` audit row. Built into the
  API image as `dist/cli/bag-admin.js`; on the server, from `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/bag-admin.js grant someone@example.com emerald_wings
  docker compose --profile jobs run --rm migrate node dist/cli/bag-admin.js list someone@example.com
  ```

### 5.7 Live gifts (migrations `20261112090000_live_gifts_enums`, `20261112100000_live_gifts`; CP-020, D108) — [IMPLEMENTED, draft contract]

- Apply both with the usual `migrate` job (§5), in order (the first only adds the wallet ledger
  reason `LIVE_GIFT`; PostgreSQL needs it committed before use). The second creates `gifts`,
  `user_gift_stock`, `live_gifts`, `live_gift_recipients` and the enums `gift_category`,
  `gift_badge`, `live_gift_source`; lets `wallet_ledger` take `LIVE_GIFT` debits; and extends
  `live_room_tappers` with `support_coins`, `points`, `points_at` (backfilled from the counted taps
  in the same transaction; `last_batch_at` becomes nullable) and rebuilds
  `live_room_tappers_room_rank_idx` on the new order. The backfill is one `UPDATE` over the
  tappers table: fine at today's size; schedule it off-peak once that table is large.
- **The catalogue starts empty** (owner: the art comes later). Until gifts are added the panel
  shows empty tabs and every send answers 409 `GIFT_UNAVAILABLE`. Add gifts with the CLI; the
  `assetKey` / `animationKey` must match files bundled in the app release:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js add rose \
    --category POPULAR --name-ar "وردة" --name-en "Rose" --price 1 --asset gift_rose --sort 10
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js update rose --animation fx_rose --badge NEW
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js disable rose
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js list
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js grant someone@example.com rose 99
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js bag someone@example.com
  ```

  Locally: `pnpm gift:admin …`. Runs as the migration role; every change writes an audit row
  (`gift.add`, `gift.update`, `gift.disable`, `gift.enable`, `gift.grant`). Gifts are never deleted
  (sends and bag stock keep them): disable instead.
- **Hosted gift art (migration `20261119090000_gift_art`; D126, contract v1.26.2-live draft):**
  apply it with the usual `migrate` job (nullable columns and CHECKs on `gifts`; no backfill, no
  GRANT). Gift images and SVGA effects are no longer bundled in the app: `gift-admin add|update …
  --image <file.png|webp> --animation-file <file.svga>` checks each file (image ≤ 1 MB, 64–2048 px,
  about square; SVGA 2.x ≤ 25 MB) and uploads it to the media bucket at
  `media/gifts/<code>/<sha256 prefix>.<ext>` (public through `MEDIA_PUBLIC_BASE_URL` like the rest of
  `media/`, §5.3; `Cache-Control: public, max-age=31536000, immutable`); the app downloads and caches
  it. `--image none` / `--animation-file none` remove them (the old objects stay in the bucket).
  The job therefore needs the API's `S3_*` settings and `MEDIA_PUBLIC_BASE_URL` besides
  `MIGRATION_DATABASE_URL`, and **the files must be inside the job container**: copy them to the
  host, mount the folder read-only with `-v`, and pass the storage settings with `-e` (the server's
  compose file is not in this repository: if its `migrate` service already receives the `S3_*`
  variables, drop the `-e` flags; never put the keys in git). From the operator's Mac, then on the
  server in `/opt/kabso/infra/deploy`:

  ```bash
  # on the Mac (the files the owner supplied)
  ssh root@<server> mkdir -p /root/gifts
  scp ~/Downloads/angel_warrior.png ~/Downloads/angel_warrior.svga root@<server>:/root/gifts/
  # on the server, after the API image with D126 is deployed and the migrate job has run
  cd /opt/kabso/infra/deploy
  set -a; . ./<the env file the api service uses>; set +a   # S3_* and MEDIA_PUBLIC_BASE_URL
  GIFT="docker compose --profile jobs run --rm -v /root/gifts:/gifts:ro \
    -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID -e S3_SECRET_ACCESS_KEY \
    -e S3_FORCE_PATH_STYLE -e MEDIA_PUBLIC_BASE_URL migrate node dist/cli/gift-admin.js"
  $GIFT add angel_warrior --category FUN --name-ar "الملاك المحارب" --name-en "Angel Warrior" \
    --price 50 --asset gift_angel_warrior --tag luxury --tag-ar "فخامة" --tag-en "Luxury" \
    --badge NEW --sort 10 --image /gifts/angel_warrior.png --animation-file /gifts/angel_warrior.svga
  $GIFT list            # … image=media/gifts/angel_warrior/1eaf….png animation-file=…svga (16830815 bytes)
  curl -sI "$MEDIA_PUBLIC_BASE_URL/media/gifts/angel_warrior/<key from list>.svga" | head -5   # 200, immutable
  # later: replace a file, or take the art away
  $GIFT update angel_warrior --animation-file /gifts/angel_warrior_v2.svga
  $GIFT update angel_warrior --image none --animation-file none
  ```

  The CLI prints each uploaded URL. Apps from before D126 ignore the URLs and show the bundled
  `--asset` image if the release has it, else Kabso's gift box.
- **New optional server config:** `LIVE_GIFT_QUANTITIES` (default `1,10,66,99,188,520,1314`; 1–12
  strictly ascending whole numbers 1–9999; the API refuses to start otherwise) and
  `RATE_LIMIT_LIVE_GIFT_USER` (default `120/60`). Changing the quantities changes the catalogue
  `version`, so apps reload it.
- **D145c (lucky streaks):** optional `RATE_LIMIT_LIVE_LUCKY_GIFT_USER` (default `600/60`: every gift
  send of a user per minute) and `RATE_LIMIT_LIVE_LUCKY_GIFT_BURST_USER` (default `10/1`: lucky
  sends per second, instead of `RATE_LIMIT_LIVE_GIFT_USER`). The app's MAX X queue paces taps at
  ≥ 100 ms and retries a 429 silently after `Retry-After` with the same `clientId`.
- **D145d (100 lucky sends a second):** the defaults are now `RATE_LIMIT_LIVE_LUCKY_GIFT_USER=6000/60`
  and `RATE_LIMIT_LIVE_LUCKY_GIFT_BURST_USER=100/1` (were `600/60` and `10/1`); normal gifts keep
  `RATE_LIMIT_LIVE_GIFT_USER` (`120/60`). A server that set the old values explicitly keeps them until
  the variables are removed or changed. The app's MAX X queue paces at ≥ 10 ms (one send in flight
  at a time). Measured (dev box, 4 vCPU, API + PostgreSQL 16 + Redis on one host, e2e `kl093`): one
  user commits about 20 lucky sends a second one at a time and about 28–35 a second when 100 are
  offered in one second (every one accepted, no 429): each send is one interactive transaction of
  about 37 statements under the sender's advisory lock (p50 26 ms; the database itself spends about
  2.5 ms executing them), so a single sender's sends are serialized. The limit no longer refuses
  100 a second, but the database path does not commit 100 a second for one sender.
- **D145d (MAX X sounds):** the app ships the owner's sounds in `apps/mobile/assets/sounds/`
  (`PROVENANCE.md`); nothing to deploy on the server.
- Levels: gifts credit charm (`GIFT_RECEIVED`) and support (`GIFT_SENT`) only while those
  categories are enabled with a published version (`levels:admin`); nothing is credited later for
  gifts sent while a category was unavailable.

### 5.8 The CP space (migrations `20261113090000_cp_space_enums`, `20261113100000_cp_space`; CP-021, D112) — [IMPLEMENTED, draft contract]

- Apply both with the usual `migrate` job (§5), in order (the first only adds the report target
  `CP_CONFESSION`; PostgreSQL needs it committed before use). The second creates
  `cp_points_ledger` (append-only for the runtime group), `cp_check_ins`, `cp_task_claims`,
  `cp_confessions` and the enum `cp_points_source`; adds `live_chat_messages.cp_bubble` (boolean,
  default false: a constant default, no table rewrite) and `reports.target_cp_confession_id`;
  replaces the `reports_one_target` CHECK.
- **Backfill inside the migration (no separate step):** one `cp_points_ledger` row per existing
  CP gift (source `GIFT`, at the gift's time), so every couple's ledger adds up to its
  `cp_couples.points` and gifts sent this week count for the weekly couples ranking. One
  `INSERT … SELECT` over `cp_gifts`; idempotent (`ON CONFLICT DO NOTHING`).
- The CP day (tasks reset at 00:00) and the CP week (Monday 00:00, the weekly ranking) follow the
  existing `LIVE_RANKINGS_TIME_ZONE` (default UTC); changing it moves both for everyone.
- **New optional server config:** `RATE_LIMIT_CP_SPACE_WRITE_USER` (default `60/60`: check-in, task
  claims, confession deletes) and `RATE_LIMIT_CP_CONFESSION_USER` (default `10/3600`: new
  confessions). No sweeper and no CLI.
- Reported confessions appear in the existing admin reports queue (`targetType: CP_CONFESSION`);
  `REMOVE_TARGET` hides the confession.

### 5.9 Families v2 (migrations `20261115090000_families_v2_enums`, `20261115100000_families_v2`; CP-022, D116) — [IMPLEMENTED, draft contract]

- Apply in order with `prisma migrate deploy` (the enum value `FAMILY_CHAT_MESSAGE` must be committed
  before the second migration uses it). No GRANT: the runtime group gets DML on the new tables
  (`family_chat_messages`, `family_chat_mutes`) through the default privileges.
- New columns: `users.last_active_at` (presence, empty until users make requests after the deploy),
  `privacy_settings.show_activity_status` (default true), `families.cover_media_id` / `cover_url` /
  `tagline`; a new index `family_points_ledger_created_idx` (built in the migration; on a large
  ledger consider building it `CONCURRENTLY` by hand first, the migration's `CREATE INDEX` then
  needs `IF NOT EXISTS`); the `media_assets_kind_known` check gains `FAMILY_COVER`; the
  `reports_one_target` check gains `FAMILY_CHAT_MESSAGE`. No backfill.
- Each authenticated request now schedules at most one `UPDATE users SET last_active_at` per user
  per minute and API process (after the response).
- The family boards follow the existing `LIVE_RANKINGS_TIME_ZONE` (month for prestige, Monday week
  for the most active board).
- **New optional server config:** `RATE_LIMIT_FAMILY_CHAT_USER` (default `30/60`). No sweeper and
  no CLI; family chat messages have no retention limit yet.
- Reported family chat messages appear in the existing admin reports queue
  (`targetType: FAMILY_CHAT_MESSAGE`); `REMOVE_TARGET` hides the message.

### 5.10 Promo banners on the live hub (migration `20261118090000_home_banners`; D124) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5). It creates `home_banners` and lets `media_assets.kind`
  take `HOME_BANNER`; no GRANT (default privileges), no backfill. No new server config.
- **No banner exists after the deploy**, so the hub shows none. Banners are managed only with the
  `banner-admin` CLI, built into the API image as `dist/cli/banner-admin.js` (locally:
  `pnpm banner:admin …`). It runs as the migration role; every change writes an audit row
  (`banner.add`, `banner.enable`, `banner.disable`, `banner.remove`).
- `add --image <file>` reads a JPEG, PNG or WebP **inside the container**, cover-crops it to 3:1
  (1 500 × 500 and 320 × 107 WebP; send 3:1 pictures, e.g. 1 500 × 500 or 2 000 × 667, and nothing
  is cut) and stores it in the media bucket, so the job needs the API's `S3_*` settings and
  `MEDIA_PUBLIC_BASE_URL` besides `MIGRATION_DATABASE_URL`, and media storage must be configured
  (§5.3, B12). `--owner` is an existing account (the picture's owner, e.g. the owner's admin
  account). Instead of `--image`, `--media <id>` takes a `HOME_BANNER` upload made through the API
  in the last 24 hours.
- `--link` is `/cp/space`, `/families`, `/live?tab=trending|new|following`, `/home/room/<roomId>`,
  `/users/<username>` or an `https://` URL. Optional: `--title-ar`, `--title-en` (overlay text,
  1–40 characters; leave them out when the text is in the picture), `--text-side left|right`,
  `--starts` / `--ends` (ISO times; default now / open), `--sort <n>` (lowest first), `--disabled`.
- On the server: copy the pictures to the host first (they are not in the image), mount that folder
  into the job, and pass the storage settings from the environment the API uses. From the
  operator's machine and then from `/opt/kabso/infra/deploy`:

  ```bash
  scp banner_families.webp banner_cp.webp banner_talents.webp server:/opt/kabso/banners/
  # on the server, in /opt/kabso/infra/deploy, with the API's S3_* / MEDIA_PUBLIC_BASE_URL exported
  # (skip the -e flags if the migrate service already receives them)
  BANNER="docker compose --profile jobs run --rm -v /opt/kabso/banners:/banners:ro \
    -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID -e S3_SECRET_ACCESS_KEY \
    -e S3_FORCE_PATH_STYLE -e MEDIA_PUBLIC_BASE_URL migrate node dist/cli/banner-admin.js"
  $BANNER add --image /banners/banner_families.webp --owner owner@example.com --link /families --sort 10
  $BANNER add --image /banners/banner_cp.webp --owner owner@example.com --link /cp/space --sort 20
  $BANNER add --image /banners/banner_talents.webp --owner owner@example.com --link '/live?tab=trending' --sort 30
  $BANNER list                 # + shown now, ~ outside its window, - disabled
  $BANNER disable <bannerId>   # hide; enable <bannerId> shows it again
  $BANNER remove <bannerId>    # deletes the banner, its asset row and its two objects
  ```

- Apps cache `GET /home/banners` for up to a minute (`Cache-Control: private, max-age=60`) and
  reload it on pull to refresh, so a change shows within about a minute.

### 5.10a Wish list and in-room promo banners (migration `20261129090000_live_wish_gifts_room_banners`; D136, D137) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5): `live_rooms.wish_gifts` (`VARCHAR(40)[]`, default empty,
  CHECK ≤ 4) and `home_banners.placement` (`HOME` default, CHECK `HOME|ROOM`, index). No GRANT, no
  backfill; existing banners stay on the hub. No new server config.
- The wish list needs nothing from operations: hosts set it in the app (live settings, ≡ Room Tools).
- **In-room promo box (D137):** no ROOM banner exists after the deploy, so rooms show no box. Add one
  with the same job as §5.10 and `--placement room`. Design the picture at **600 × 800 px (3:4)**,
  JPEG/PNG/WebP; it is cover-cropped to 600 × 800 and 240 × 320 WebP and shown about 82 × 109 pt at
  the top end of every live. `--media` is refused for ROOM (API uploads are 3:1). Links as in §5.10;
  an `https://` link is stored but not tappable in the app yet. With `$BANNER` as above:

  ```bash
  scp room_promo_event.webp server:/opt/kabso/banners/
  $BANNER add --image /banners/room_promo_event.webp --owner owner@example.com \
    --placement room --link /families --sort 10 --ends 2026-12-01T00:00:00+03:00
  $BANNER list                 # each line shows "home" or "room"
  ```

- Apps read `GET /home/banners?placement=room` when a live opens (cached up to a minute).
- *(D173, contract v1.39-live)* The same ROOM banners show to **everyone** in the room — signed-in
  viewers, guests without an account (the endpoint now serves `placement=room` without a token, per-IP
  guest limit `RATE_LIMIT_LIVE_GUEST_READ_IP`), seated guests and the host — in video lives at the
  start under the «ترتيب الغرف» chip, in audio rooms low at the end over the gift button. Nothing to
  configure: deploy the API and add a ROOM banner as above. `$BANNER disable <id>` hides it everywhere
  within a minute.

### 5.11 Lucky gifts (migrations `20261127090000_lucky_gifts_enums`, `20261127100000_lucky_gifts`; D132) — [IMPLEMENTED, draft contract; owner / legal review before switching on]

- Apply with the usual `migrate` job (§5): the enum values (`gift_category` `LUCKY`,
  `wallet_ledger_reason` `LUCKY_GIFT`, `LUCKY_GIFT_WIN`) in their own migration first, then the tables
  `lucky_gift_days` (the daily protection), `lucky_gift_draws` (the audit row of every lucky send) and
  `lucky_gift_age_confirmations` (the 18+ statement), and the wallet ledger's sign CHECK extended. No
  GRANT (default privileges), no backfill; no existing row changes.
- **Config** (API environment; restart to change; the server refuses to start on an invalid value,
  even while lucky gifts are off — CONVENTIONS §10.27 has the rules and the odds formula):

  | Variable | Default | Meaning |
  | -------- | ------- | ------- |
  | `LUCKY_GIFTS_ENABLED` | `false` | `true` lists the LUCKY tab and lets lucky gifts be sent |
  | `LUCKY_GIFT_RTP_PERCENT` | `85` | target return and the daily protection's ceiling: coins won per 100 spent (1–99, two decimals) |
  | `LUCKY_GIFT_HOST_SHARE_PERCENT` | `10` | share of the value counted for charm, scores, boards, Contribution and family points |
  | `LUCKY_GIFT_MULTIPLIERS` | `5,10,25,50,100,250,500,1000` (D148; was `5,10,50,100,500`) | winning multipliers, ascending |
  | `LUCKY_GIFT_CHANCES_PER_MILLION` | `48918,15451,3903,1464,569,130,40,12` (D148) | each multiplier's chance in draws per million, same order; with the guarantee the return must not pass `LUCKY_GIFT_RTP_PERCENT` |
  | `LUCKY_PITY_AFTER` | `15` (D148) | losing draws in a row before a sender's guaranteed draw; `0` turns the guarantee off |
  | `LUCKY_PITY_MULTIPLIER` | `5` (D148) | what the guaranteed draw pays at least (one of the multipliers) |
  | ~~`LUCKY_GIFT_RTP_SHARES`~~ | — | **removed in D148**: set → the API refuses to start |
  | `LUCKY_GIFT_BIG_WIN_MULTIPLIER` | `100` | wins from this multiplier are told to every other live («لحظة الحظ»); D178: every win is announced to its own room |
  | `GIFT_GLOBAL_TICKER_MIN_COINS` | `500000` (D305, owner «٥٠٠ ألف كوينز وأكثر»; was `1000` in D178) | a gift whose **unit price** (one gift — owner, D305; D178 counted the send) is at least this many coins shows as the gifts strip in every live, its own too (one every 3 s, the newest first). See D178, D305 and §5.84. **The OWNER sets it in the panel** («إعدادات الموقع» → «شريطا الهدايا والألعاب», no restart, ≤ 30 s); this variable is only the fallback (`.env`, restart the API) |
  | `GAME_WIN_TICKER_MIN_TICKETS` | `1000000` (D305, owner «١ مليون وأकثر») | a game prize worth at least this many tickets shows as the games strip in every live (§5.84); the panel's value wins (as above). No game pays ticket prizes yet |
  | `LUCKY_GIFT_DAY_TIME_ZONE` | `UTC` | the daily protection's day |
  | `LUCKY_GIFTS_DISABLED_COUNTRIES` | empty | ISO alpha-2 codes where lucky gifts are off |
  | `LUCKY_GIFTS_COUNTRY_HEADER` | unset | the header the edge sets to the client country (required with a country list) |

  `GET /api/v1/live/gifts/lucky/odds` shows the table the server draws from; check it after every
  change. With a country list, the edge (Cloudflare `CF-IPCountry`, or the reverse proxy's GeoIP)
  must **set or strip** that header on every request so clients cannot choose it; requests without
  it are refused lucky gifts (fail closed).
- **Before switching on in production:** owner / legal sign-off on the odds, the 18+
  self-declaration and the country list (store loot-box rules), and lucky gifts added with
  `gift-admin add <code> --category LUCKY …` (§5.7). Lucky gifts are sent with coins only
  (`gift-admin grant` refuses them).
- **Monitoring:** every lucky send writes a `lucky_gift_draws` row (winning draws, table, budget
  before and after). On the server:

  ```bash
  GIFT="docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js"
  $GIFT lucky-wins --limit 50 --min-multiplier 100   # the latest big wins
  $GIFT lucky-day 2026-11-01                         # spend, paid, budget left, realised return
  ```

  Pass `-e LUCKY_GIFT_RTP_PERCENT` to the job when the API does not use the default 85, so
  `lucky-day` prints the right budget.
- **Rollback:** set `LUCKY_GIFTS_ENABLED=false` (lucky gifts disappear from the catalogue and cannot
  be sent; the rows stay). The migration is additive; do not drop the tables (audit).

### 5.11a Lucky gifts D148: eight tiers, the guarantee, «لحظة الحظ» (migration `20261203090000_lucky_pity`) — [IMPLEMENTED, draft contract v1.30-live; not deployed]

- **Before upgrading:** if the API environment sets `LUCKY_GIFT_RTP_SHARES` (D132's way of setting
  the odds), **remove it** — the new API refuses to start while it is set (so an old table is never
  read with a new meaning). If it sets `LUCKY_GIFT_MULTIPLIERS` to the old `5,10,50,100,500`, remove
  that too (or set `LUCKY_GIFT_CHANCES_PER_MILLION` with one chance per multiplier); the defaults
  are the owner's D148 table (§5.11 table; CONVENTIONS §10.27).
- **Migrate** with the usual `migrate` job (§5): one new table `lucky_gift_pity` (a sender's losing
  draws in a row) and three nullable audit columns on `lucky_gift_draws` (`losses_before`,
  `losses_after`, `guaranteed`). Additive, no backfill, no GRANT (default privileges). Every
  sender starts with a count of 0.
- **New optional config:** `LUCKY_GIFT_CHANCES_PER_MILLION`, `LUCKY_PITY_AFTER` (`15`),
  `LUCKY_PITY_MULTIPLIER` (`5`) — §5.11 table. The odds endpoint then shows the eight tiers,
  `pity: {after: 15, multiplier: 5}` and `returnPercent: 84.9999`; check it after deploying:

  ```bash
  curl -s https://<api>/api/v1/live/gifts/lucky/odds | jq '{returnPercent, pity, outcomes}'
  ```

- **Global ticker:** no config. It uses two Redis keys (`lucky:ticker:gate`, 10 s;
  `lucky:ticker:pending`, ≤ 30 s) and the media server's data messages (one per LIVE room, at most
  5 000, at most once every 10 s). Redis or LiveKit down → no ticker; sends are unaffected.
- **Throughput (owner: 100 lucky sends a second per user):** measured on the dev box with e2e
  `kl093` (API and the test client in one Node process, PostgreSQL 16 and Redis on the same 4 vCPU
  host): before (D145e) one user committed ≈ 23 sends/s one at a time and 32–39/s when 100 were
  offered in one second; after D148 ≈ 33/s one at a time and 50–70/s offered 100 in a second (61–67/s in
  the final run), all accepted, 0 × 429; the transaction itself is ≈ 11–12 ms (was 23 ms; ≈ 16 statements instead of
  ≈ 37). The remaining limit is CPU in the Node process (≈ 85–98 % of one core during the burst):
  100/s for **one** sender is not reached on this box. Sends of one sender now wait in an in-process
  queue instead of holding database connections, so a burst no longer starves the pool for other
  requests.
- **Monitoring:** `gift-admin lucky-wins` / `lucky-day` as in §5.11. A guaranteed draw shows in
  `lucky_gift_draws.wins` as `[index, 0, 5]` (paid above drawn) and in `guaranteed`.
- **Rollback:** `LUCKY_PITY_AFTER=0` turns the guarantee off (the table alone then returns 69.13 %;
  set `LUCKY_GIFT_CHANCES_PER_MILLION` for another table); `LUCKY_GIFTS_ENABLED=false` turns lucky
  gifts off. Rolling back to an API before D148 uses that API's own defaults (×5 … ×500, no
  guarantee); unset `LUCKY_GIFT_MULTIPLIERS` first if it was set to eight tiers (the old API would
  pair them with its five shares and refuse to start). The new table and columns can stay (unused).

### 5.12 Nearby and Featured on the live hub (migration `20261128090000_live_nearby_featured`; D133) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5): a nullable `user_profiles.country_code` (every account
  starts with none; users set it with `PATCH /me`) and the table `live_featured_hosts`. No GRANT, no
  backfill, no new server config.
- Featured hosts are managed only with the `feature-admin` CLI (migration role, audited
  `live.feature.add` / `live.feature.remove`):

  ```bash
  FEATURE="docker compose --profile jobs run --rm migrate node dist/cli/feature-admin.js"
  $FEATURE add --user host@example.com --rank 10                       # or --user <username>
  $FEATURE add --user layla.k --rank 5 --until 2026-11-30T00:00:00Z     # ends on its own
  $FEATURE add --user layla.k --until none                              # remove the end
  $FEATURE remove --user layla.k
  $FEATURE list                                                         # expired rows marked -
  ```

  Locally: `pnpm feature:admin …`. Lower ranks come first; equal ranks follow the popular order.

### 5.13 The host's live statistics (migration `20261130090000_live_audience`; D140) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5): the table `live_room_audience` (one row per live and
  viewer identity: first join, watch time, open visit) and the nullable column
  `live_rooms.peak_viewer_count` (CHECK ≥ 0; new rooms start at 0). No GRANT (default privileges),
  no backfill, no new server config.
- Lives started before the deploy keep `peak_viewer_count` NULL: their statistics answer
  `viewers: null` and no countries (the app hides those parts). A live that is on during the deploy
  is one of them.
- Rows are written by the media webhook and the sweeper's presence reconciliation (§10.8 of the
  conventions); they are removed with their live or their user (cascade). No endpoint lists them —
  `GET /live/rooms/{roomId}/stats` (host only) returns aggregates.
- Rollback: the API before D140 ignores the table and the column; drop them only after rolling
  back the API (`DROP TABLE live_room_audience; ALTER TABLE live_rooms DROP COLUMN
  peak_viewer_count;`).

### 5.14 Premium usernames (migrations `20261201090000_premium_usernames_enums`, `20261201100000_premium_usernames`; D146) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5), in order: the enum values (`wallet_ledger_reason`
  `PREMIUM_USERNAME_RENT` / `PREMIUM_USERNAME_RENEW`, `notification_type`
  `PREMIUM_USERNAME_EXPIRING` / `PREMIUM_USERNAME_EXPIRED`) in their own migration (PostgreSQL cannot
  use a value in the transaction that adds it), then the tables `premium_username_leases`,
  `premium_username_payments`, `premium_username_tier_prices`, `premium_username_name_prices`,
  `premium_username_reserved` (seeded with a short brand / authority list), the nullable columns
  `user_profiles.premium_tier` and `notifications.premium_lease_id`, and the widened
  `user_profiles_username_format` CHECK (1–30 characters; every existing name still passes). No
  GRANT (default privileges), no backfill.
- **The new username rule applies at once** to registrations and `PUT /me/username`; existing
  usernames are untouched (grandfathered). Apps built before D146 show a generic error for the new
  validation issues (`letters_and_digits`, `premium`) until they update.
- **Nothing is on sale until the owner sets prices.** With no row in
  `premium_username_tier_prices` the store says "not on sale yet" and every rent is refused. Prices
  are whole coins per 30-day period, set only with the `premium-admin` CLI (migration role, every
  change audited `premium_username.price`):

  ```bash
  PREMIUM="docker compose --profile jobs run --rm migrate node dist/cli/premium-admin.js"
  $PREMIUM price list                                   # tiers and names with their own price
  $PREMIUM price set --tier LEGEND --coins 50000        # 1–3 characters
  $PREMIUM price set --tier RUBY --coins 20000          # one repeated character (7777, aaaaaa)
  $PREMIUM price set --tier GOLD --coins 12000          # 4–5 characters, or a pattern (1221, 1212, 123456, ali777)
  $PREMIUM price set --tier SILVER --coins 3000         # 6+ letters only or digits only
  $PREMIUM price set --username 777 --coins 250000      # one name's own price (wins over its tier)
  $PREMIUM price clear --tier SILVER                    # SILVER names off sale again
  $PREMIUM price clear --username 777                   # back to its tier's price
  ```

- **Reserved names** (never rented; an admin may still grant one): the code reserves the v1.0
  names (`admin`, `support`, `official`, `staff`, `moderator`, …) and anything containing `kabso`;
  the owner's list adds brand words and **offensive words**, which are entered on the server only
  (this repository is public):

  ```bash
  $PREMIUM reserve add <word> --reason offensive
  $PREMIUM reserve remove <word>
  $PREMIUM reserve list
  ```

- **Grants and revokes** (no charge; audited `premium_username.grant` / `.revoke`):

  ```bash
  $PREMIUM grant --user host@example.com --username 7 --forever         # no end, not renewable
  $PREMIUM grant --user layla.k --username 8888 --days 30 [--replace]   # --replace ends another one first
  $PREMIUM revoke --user layla.k                                        # now, no grace, no refund
  $PREMIUM list                                                         # ACTIVE and GRACE leases
  $PREMIUM status 7777                                                  # tier, state, price
  ```

  Locally: `pnpm premium:admin …`.
- Server config (defaults are the owner-approved values; change them per environment, no app
  update): `PREMIUM_USERNAME_PERIOD_DAYS=30`, `PREMIUM_USERNAME_GRACE_DAYS=7`,
  `PREMIUM_USERNAME_REMINDER_DAYS=3,1`, `PREMIUM_USERNAME_MAX_PREPAID_DAYS=365`,
  `PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS=60` (0 disables the sweeper — then nothing expires, so
  production refuses 0; it is safe on several instances), `RATE_LIMIT_PREMIUM_RENT_USER=20/3600`,
  `RATE_LIMIT_USERNAME_CHANGE_USER=5/86400`.
- Rollback: the API before D146 ignores the new tables and columns, but users renting a name keep
  it as their username and never revert; revoke every lease first (`premium-admin list`, then
  `revoke`), roll back the API, then drop the tables, the two columns and restore the CHECK
  (`… CHECK ("username" ~ '^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$')`, which fails while a 2-character
  username exists). The enum values cannot be dropped (harmless).

### 5.15 Search trends (migration `20261202090000_search_trends`; D147) — [IMPLEMENTED, draft contract]

- Apply with the usual `migrate` job (§5): tables `search_terms`, `search_term_counts`,
  `search_blocked_words`. No GRANT (default privileges), no backfill: the lists start empty and fill
  as updated apps record submitted searches (older apps never do).
- **Privacy**: only normalized terms and hourly counts of searchers are stored, never who searched;
  the per-person dedupe key is an HMAC in Redis that expires after 7 days. Counts older than 14 days
  are deleted by the sweeper (`SEARCH_TRENDS_SWEEP_INTERVAL_SECONDS=3600`; 0 disables it — then old
  counts stay, so keep it on in production; safe on several instances).
- A term is listed only after `SEARCH_TRENDING_MIN_SEARCHERS=5` different people searched it in 7
  days (raise it for a large audience; never below 2). `RATE_LIMIT_SEARCH_RECORD_USER=120/3600`.
- **Moderation** with the `search-admin` CLI (migration role; offensive words are entered on the
  server only, this repository is public):

  ```bash
  SEARCH="docker compose --profile jobs run --rm migrate node dist/cli/search-admin.js"
  $SEARCH top                         # the 50 most searched terms (7 days, 24 h; hidden marked -)
  $SEARCH hide "some term"            # never listed (still counted); audited search.term.hide
  $SEARCH unhide "some term"
  $SEARCH block-word add <word>       # no trending term or hashtag containing it
  $SEARCH block-word remove <word>
  $SEARCH block-word list
  ```

  The public list is cached 60 s. Locally: `pnpm search:admin …`.
- Rollback: the API before D147 ignores the tables (the app's sections then hide on 404); drop the
  three tables to remove the data.

### 5.16 Push notifications (migration `20261203090000_push_notifications`; D152) — [IMPLEMENTED, draft contract; not device-tested]

Android pushes through Firebase Cloud Messaging (project `kabso-27b19`, free Spark plan; Android
app `com.kabso.kabso_live`), CONVENTIONS §11.12. **iOS is deferred** (no Apple Developer account /
APNs key yet): the iOS app never starts Firebase and needs no `GoogleService-Info.plist`.

- **Migration** with the usual `migrate` job (§5): enum `push_platform`, table `device_tokens`
  (one token per session, deleted with it), `notifications.pushed_at` (the push outbox; existing
  rows are marked handled, so nothing old is pushed) and `notification_settings.messages`
  (default on). No GRANT (default privileges).
- **Server key** (never in git, never in an env file): the Admin SDK service-account key is a file
  on the server, `/etc/kabso/firebase-admin.json`, mounted **read-only** into the `api` container
  at `/run/secrets/firebase-admin.json`, and `FIREBASE_CREDENTIALS_FILE` points there (the `api`
  service of `infra/deploy/docker-compose.yml` on the deploy branch). The API runs as `node`
  (uid/gid 1000), so the file is owned `root:1000`, mode `640`; `/etc/kabso` stays `700` (root
  only), so no other host account can reach it. One-time, on the server:

  ```bash
  ls -ln /etc/kabso/firebase-admin.json          # the key the owner placed (root, 600)
  chgrp 1000 /etc/kabso/firebase-admin.json      # the container's `node` group may read it
  chmod 640 /etc/kabso/firebase-admin.json
  stat -c '%a %U' /etc/kabso                     # 700 root — keep it so
  # After the deploy branch carries D152 (the timer deploys it within 5 minutes), or at once:
  bash /opt/kabso/infra/deploy/update.sh --force
  cd /opt/kabso && docker compose -f infra/deploy/docker-compose.yml logs api | grep -i "push notifications"
  #   → "Push notifications are on (Firebase Cloud Messaging)" with projectId kabso-27b19
  ```

  Never print the key (`cat`, logs, chat). The API logs only the project id and, on failure, the
  reason (`missing`, `not_a_file`, `unreadable`, `invalid`, `firebase_start_failed`).
- **Without the key** the stack still starts: Docker creates an empty **directory** where a
  bind-mounted host file is missing, the API sees "not a file", logs `Push notifications are off`
  and runs normally (tokens are still accepted; nothing is sent). To add the key later:
  `rmdir /etc/kabso/firebase-admin.json`, put the file there, run the two commands above, then
  `docker compose -f infra/deploy/docker-compose.yml up -d api`. To switch push off on purpose
  without deleting the key, set `KABSO_FIREBASE_ADMIN_FILE=/dev/null` in `/etc/kabso/kabso.env`
  (the mount source) and recreate `api`.
- **Settings:** `PUSH_DISPATCH_INTERVAL_MS=2000` (how often new notifications are pushed; 0
  disables the outbox — then nothing general is pushed), `PUSH_GENERAL_GAP_SECONDS=5` and
  `PUSH_MESSAGES_GAP_SECONDS=10` (burst collapse, per recipient / per recipient and chat; uses
  Redis). The outbox is safe on several API instances (`FOR UPDATE SKIP LOCKED`). Tokens of ended
  sessions and tokens unseen for 60 days are deleted by the notifications sweeper.
- **APK builds:** CI writes `apps/mobile/android/app/google-services.json` from the repository
  secret `GOOGLE_SERVICES_JSON` before the debug APK (job `android`) and the staging APK (job
  `staging-apk`) are built; the file is git-ignored (as is `GoogleService-Info.plist`) and checked
  for this app's package. Without the secret (forks, pull requests from forks, a fresh clone)
  Gradle does not apply the `com.google.gms.google-services` plugin and the APK builds and runs
  with push off. Locally: put the file there yourself (never commit it).
- **Logs and privacy:** counts and Firebase error codes only — never a token, title, body or
  message text. Tokens Firebase reports as not registered / invalid are deleted.
- **Rotating the key:** create a new key in the Firebase console (Project settings → Service
  accounts), replace the file (same owner and mode), then
  `docker compose -f infra/deploy/docker-compose.yml up -d --force-recreate api` (a bind-mounted
  file keeps pointing at the old file until the container is recreated), then delete the old key
  in Google Cloud IAM. The owner overrode the org policy
  `iam.disableServiceAccountKeyCreation` on the project to create the key: set it back to
  *inherit* once the key exists.
- **Rollback:** the API before D152 ignores the new table and columns; the app before D152 never
  registers a token. Drop `device_tokens`, `push_platform`, `notifications.pushed_at` and
  `notification_settings.messages` to remove the data.
- **Not verified here** (no device, no Firebase project access from this environment): delivery,
  the channels' sounds, the Android 13+ prompt, taps from a closed app, the compose start with the
  real key. See the D152 row of the board.

### 5.17 «إفيهات» quips and the host share per category (migrations `20261204090000_quips_enums`, `20261204100000_quips`; D154) — [IMPLEMENTED, draft contract v1.32-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): enum value `gift_category.QUIPS`; columns `gifts.sound_key`,
  `sound_ms`, `quip_text`, `live_rooms.quip_busy_until`; `live_gifts.host_share_bps` (NOT NULL, **backfilled**
  in the migration: lucky sends from their draws' audit row, every other send 6 500 = 65 %); table
  `live_free_quips`; the CHECKs `gifts_price_range`, `live_gifts_amounts` and
  `live_gift_recipients_coins_positive` are replaced to allow a free quip (0 coins, QUIPS only). No GRANT
  (default privileges). The backfill touches every `live_gifts` row once (fast for today's volume).
- **Then add the owner's pack** (35 gifts: 8 free sounds, 27 Kabi lines at 99 / 199 / 299 coins; idempotent,
  audited `gift.add`; the sounds themselves ship inside the app — an app built from D154 or later):

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js quips-seed
  docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js list | grep QUIPS
  ```

  Until it runs, the «إفيهات» tab and the host's soundboard stay empty (the app hides the tab). Older apps
  ignore the QUIPS category.
- **New optional config:**

  | Variable | Default | Meaning |
  | -------- | ------- | ------- |
  | `GIFT_HOST_SHARE_PERCENTS` | `POPULAR:65,EVENT:65,FUN:65,QUIPS:50` | the recipients' earnings share per category (owner: quips 50 %, other gifts 65 % — D149); each non-lucky category once, 0–100; fixed on each send (`live_gifts.host_share_bps`). LUCKY keeps `LUCKY_GIFT_HOST_SHARE_PERCENT`. An invalid value → the API refuses to start |
  | `QUIP_QUEUE_MAX_WAIT_SECONDS` | `60` | a quip (or soundboard sound) that would start later than this is refused (409 `QUIP_QUEUE_FULL`); 5–600 |

- The soundboard (`POST /live/rooms/{roomId}/sounds`) uses the taps bucket (`RATE_LIMIT_LIVE_TAPS_USER`)
  plus a fixed one-sound-every-2-s rule in Redis.
- **Rollback:** the API before D154 ignores the new columns and table, but its inserts into `live_gifts`
  do not name `host_share_bps` and would fail on its NOT NULL — so roll the API back only together with
  `ALTER TABLE live_gifts ALTER COLUMN host_share_bps SET DEFAULT 6500;` (keeps old inserts working).
  Disable the quips without a rollback with `gift-admin disable <code>` (each).

### 5.18 Traffic cards «بطاقة الزيارات» (migrations `20261205090000_live_boosts_enums`, `20261205100000_live_boosts`; D154b) — [IMPLEMENTED, draft contract v1.33-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): enum `live_boost_source`, ledger reasons `LIVE_BOOST` and
  `LIVE_BOOST_REFUND` (the `wallet_ledger_reason_sign` CHECK is replaced to include them), tables
  `live_boosts` and `live_boost_cards`. No GRANT, no backfill.
- **New optional config:**

  | Variable | Default | Meaning |
  | -------- | ------- | ------- |
  | `LIVE_BOOST_PRICES` | `10:200000,20:550000,30:1500000,60:3500000` | `minutes:coins` per length on sale; **exactly 4** lengths = the rocket stages 1–4 (D233, v1.51-live; was 1–8 lengths at 10 000 / 18 000 / 25 000 / 45 000). The admin panel «صواريخ الزيارات» can override each stage's price (`live_boost_prices`) |
  | `LIVE_BOOST_SLOTS` | `3` | paid «مميز» slots at the top of the live list (owner) |
  | `LIVE_BOOST_MAX_WAIT_MINUTES` | `180` | a card that would wait longer is refused (409 `BOOST_QUEUE_FULL`) |

  The settlement (refunds of cards whose live ended before they ran) runs on the live sweeper's interval
  (`LIVE_SWEEP_INTERVAL_SECONDS`) and before every purchase; safe on several instances (one advisory lock).
- **D233 (v1.51-live, migration `20270218090000_live_boost_stages`):** adds `live_boosts.stage` (backfilled by length,
  NOT NULL, CHECK 1–4) and table `live_boost_prices`; no GRANT. Deploy the API with the migration (an older API does not
  write `stage` and its purchases would fail on NOT NULL: roll back only with
  `ALTER TABLE live_boosts ALTER COLUMN stage SET DEFAULT 1;`). A `LIVE_BOOST_PRICES` set on the server with other than 4
  lengths stops the API from starting — remove it (the default is the owner's rocket prices) or give 4 lengths. The
  OWNER edits the prices in the panel «صواريخ الزيارات» (`catalog.manage`, the code again, audited).
- **Rewards:** grant cards with the CLI (audited):

  ```bash
  BOOST="docker compose --profile jobs run --rm migrate node dist/cli/boost-admin.js"
  $BOOST grant someone@example.com 30 1   # one 30-minute card
  $BOOST cards someone@example.com
  $BOOST queue                            # cards running and waiting now
  ```

- **Rollback:** the API before D154b ignores the tables; a card running at that moment simply stops
  showing (nothing is refunded automatically — list them with `boost-admin queue` first).

### 5.19 Newcomers «الجدد» (no migration; D154c) — [IMPLEMENTED, draft contract v1.34-live; not deployed, not device-tested]

- **New optional config:** `NEWCOMER_DAYS` (default `30`, owner; 1–365): an account younger than this is a
  newcomer (the «جديد 🌱» chat badge and the host's and moderators' Newcomers list). No table, no backfill.

### 5.20 The data center «مركز البيانات» (migration `20261206090000_live_summaries`; D154d) — [IMPLEMENTED, draft contract v1.35-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): table `live_summaries`. No GRANT, no backfill in the migration:
  the API's summariser fills it after the deploy (200 ended lives every `LIVE_SWEEP_INTERVAL_SECONDS`, and
  a host's own lives at once when they open the data center), so the first minutes after the deploy cost a
  few batch inserts. No new config (the periods use `LIVE_RANKINGS_TIME_ZONE`).

### 5.21 A live's program «قائمة البرامج» (migration `20261207090000_live_program`; D154e) — [IMPLEMENTED, draft contract v1.36-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): table `live_program_items`. No GRANT, no backfill, no new
  config (the announcements run on `LIVE_SWEEP_INTERVAL_SECONDS`; 0 turns them off).

### 5.22 Stickers on a live «ملصقات» (migration `20261208090000_live_stickers`; D154h) — [IMPLEMENTED, draft contract v1.37-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): tables `live_stickers` and `live_sticker_art` (empty: the
  Kabi pack is built into the API). No GRANT, no backfill, no new config. Adding a pack later is an
  `INSERT INTO live_sticker_art (key, pack, sort_order)` once the app ships its art.

### 5.23 YouTube watch-together «يوتيوب» (migration `20261209090000_live_watch`; D154i) — [IMPLEMENTED, draft contract v1.38-live; not deployed, not device-tested]

- Apply with the usual `migrate` job (§5): tables `live_watch`, `live_watch_suggestions`. No GRANT,
  no backfill.
- **Outbound HTTPS** from the API to `www.youtube.com` (oEmbed: every video a host plays or a viewer
  suggests) and, with a key, `www.googleapis.com` (search). Allow both in the server's egress.
- **`YOUTUBE_API_KEY`** (optional, a secret; never in git): a YouTube Data API v3 key from the Google
  Cloud project `kabso` (APIs & Services → enable "YouTube Data API v3" → Credentials → API key,
  restricted to that API and, if possible, to the server's IP). Unset: search answers 503
  `YOUTUBE_SEARCH_UNAVAILABLE` and the app says «البحث غير مفعّل بعد» and takes links. The free quota
  is 10,000 units a day; a search costs 100 (≈ 100 searches a day; the API caches each query 10 min).
### 5.24 Direct messages (migrations `20261210090000_direct_messages_enums`, `20261210100000_direct_messages`; D155) — [IMPLEMENTED, draft contract v1.40-social; not device-tested]

Real 1:1 messages behind the Messages tab (CONVENTIONS §11.13): conversations, message requests,
`whoCanMessage`, receipts, unread counts, pictures, voice notes, pack emojis, gifts in a
conversation, block / report / mute / delete, pushes on `kabso_messages`. **Every message is
hard-deleted 24 hours after it was sent** (owner).

- **Migrations** with the usual `migrate` job (§5), after D154's (§5.17–§5.23: they are older and
  apply first), in this order (the first adds enum values the second uses): `20261210090000_direct_messages_enums` (`wallet_ledger_reason` `DM_GIFT`,
  `report_target_type` `DM_MESSAGE`) and `20261210100000_direct_messages` (enums
  `who_can_message`, `dm_participant_status`, `dm_message_kind`; tables `dm_conversations`,
  `dm_participants`, `dm_messages`, `dm_message_hides`; columns
  `privacy_settings.who_can_message` (default `EVERYONE`), `live_gifts.dm_conversation_id`,
  `reports.target_dm_message_id`, `reports.dm_snapshot`; the `reports_one_target`,
  `media_assets_kind_known`, `media_assets_duration_shape` and `wallet_ledger_reason_sign` CHECKs
  extended — the ledger CHECK keeps D154b's `LIVE_BOOST` / `LIVE_BOOST_REFUND`, §5.18). No GRANT
  (default privileges), no backfill.
- **Settings** (all optional; defaults shown):

  | Variable | Default | Meaning |
  | --- | --- | --- |
  | `DM_RETENTION_HOURS` | `24` | A message is deleted this many hours after it was sent (owner: 24). 1–720 |
  | `DM_SWEEP_INTERVAL_SECONDS` | `60` | The retention sweeper (expired messages, their picture / voice objects, report snapshots resolved > 30 days ago). **0 is refused in production** |
  | `DM_REQUEST_MAX_MESSAGES` | `3` | Messages a stranger may send before the recipient accepts or replies |
  | `DM_DELETE_FOR_EVERYONE_SECONDS` | `3600` | "Delete for everyone" window of one's own message |
  | `GIFT_DM_RECIPIENT_SHARE_PERCENT` | `50` | Share of a (non-lucky) gift's value counted for the recipient's charm in a conversation (owner: 50 %). **Lucky gifts keep `LUCKY_GIFT_HOST_SHARE_PERCENT` (10 %)** — RTP 85 % + 50 % would exceed 100 % |
  | `RATE_LIMIT_DM_SEND_USER` | `30/60` | `POST /dm/messages` per user |
  | `RATE_LIMIT_DM_REQUEST_USER` | `20/3600` | Message-request messages (to strangers) per user |
  | `RATE_LIMIT_DM_WRITE_USER` | `300/3600` | read / accept / delete / mute per user |

  `POST /dm/gifts` uses the live gift limits (`RATE_LIMIT_LIVE_LUCKY_GIFT_USER`,
  `RATE_LIMIT_LIVE_GIFT_USER`, `RATE_LIMIT_LIVE_LUCKY_GIFT_BURST_USER`). Pushes reuse
  `PUSH_MESSAGES_GAP_SECONDS` (per recipient and conversation) and need the D152 key (§5.16).
- **Media:** pictures (`DM_IMAGE`) and voice notes (`DM_VOICE`) go through the existing upload
  pipeline, so they need `MEDIA_UPLOADS_ENABLED=true` and storage (§5.3); without it the app says
  uploads are unavailable and text, emojis and gifts still work. Files of expired messages are
  deleted with them. A reported message's file is copied to `reports/dm/<reportId>.<ext>` in the
  same bucket (served like other media by an unguessable key) and deleted 30 days after the
  report is resolved.
- **Blocked words:** the server list of the `search-admin` CLI (`block-word add|remove|list`,
  §5.15) is also masked in direct messages (and the recipient's own live blocked words).
- **Gifts:** sends are rows of `live_gifts` with `room_id` NULL and `dm_conversation_id` set; ledger
  `DM_GIFT` (lucky: `LUCKY_GIFT` / `LUCKY_GIFT_WIN`). They are permanent; the gift *message*
  expires like any message. Lucky gifts follow `LUCKY_GIFTS_ENABLED` and its gates (§5.11). In a
  conversation `GIFT_DM_RECIPIENT_SHARE_PERCENT` replaces the category's live share of
  `GIFT_HOST_SHARE_PERCENTS` (§5.17) for every non-lucky gift, quips included, and is stored as the
  send's `live_gifts.host_share_bps` (lucky: the lucky share). Paid quips can be sent in a
  conversation (no room queue there); **free quips cannot** (`GIFT_UNAVAILABLE`: the one free quip
  belongs to a live).
- **Several instances:** the sweeper deletes by id with bounded batches and is safe to run on
  more than one instance (a row deleted twice is a no-op).
- **Rollback:** the API before D155 ignores the new tables and columns (the app's Messages tab then
  shows errors — roll the app back too). Drop the four `dm_*` tables, the three enums and the new
  columns to remove the data; `live_gifts` rows with `dm_conversation_id` keep their ledger rows.
- **Not verified here:** on a device (sending pictures/voice from the phone, pushes, the badge in
  the background), against real R2 storage, and with the production key. See the D155 row.

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
- **DeepAR (D144):** see §9.1; a release build needs the production DeepAR plan.
- **Today:** CI produces an unsigned Android **debug** APK and an unsigned iOS build on
  dispatch or main; both compiled in run 13 but are not device-tested (see §2 and §10).

### 9.1 DeepAR effects and native colour filters (D144) — [IMPLEMENTED, Android, not device-tested]

The local plugin `apps/mobile/packages/kabso_camera_fx` runs on the host's published camera
track (flutter_webrtc's pre-encoder frame processor), so viewers see what the host sees:
D143's colour filters (a GPU colour matrix; no licence needed) and DeepAR effects (phase 1:
the SDK's built-in background blur). Android only; iOS is phase 3 (Magic stays greyed there).

- **SDK:** `ai.deepar.ar:DeepAR:5.6.22` from DeepAR's public Maven repository
  (`https://sdk.developer.deepar.ai/maven-android-repository/releases/`, no credentials),
  declared by the plugin itself and content-filtered to the `ai.deepar.ar` group. The plugin
  ships consumer ProGuard rules (`-keep class ai.deepar.ar.**`) for minified builds.
- **Licence key:** `--dart-define=DEEPAR_LICENSE_ANDROID=<key>`. CI: the repository secret
  `DEEPAR_LICENSE_ANDROID` (Settings → Secrets and variables → Actions), passed through `env`.
  Locally: put `{"DEEPAR_LICENSE_ANDROID": "<key>"}` in `apps/mobile/deepar.local.json`
  (git-ignored) and build with `--dart-define-from-file=deepar.local.json`. The key is created
  in the DeepAR developer portal for the Android package name (today the placeholder
  `com.kabso.live`, blocker B7 — a new key is needed when it changes). It is a client key and
  ends up inside the APK; it stays out of git because usage is billed. No key → the APK still
  builds; colour filters work and Magic shows Effects as unavailable.
- **Billing:** DeepAR counts monthly active users (one user/device that initializes DeepAR in a
  month). The app initializes DeepAR only when a host first picks an effect, so viewers and
  hosts who never pick one are not counted. The free plan (up to 10 MAU) is for testing and
  development and shows a watermark; production needs a paid plan (from $25/month for 1,000
  MAU at the time of writing). Owner decision before release.
- **APK size:** DeepAR adds native libraries and model assets — estimated, not measured, at
  roughly 23 MB of assets plus 11–23 MB of native code per ABI (uncompressed). Not measured
  in a build yet; a release should split per ABI (app bundle).
- **Not verified:** the full APK was not built in the authoring environment (jitpack.io is
  blocked there for flutter_webrtc's `audioswitch`, and disk was short); the plugin's Kotlin
  compiled against the real DeepAR 5.6.22 and WebRTC 150.7871.01 classes. Licence
  initialization, watermark, orientation/mirroring on both cameras, latency, fps, battery
  and background pause/resume need the owner's device.
- **Third-party notices:** `apps/mobile/packages/kabso_camera_fx/THIRD_PARTY_NOTICES.md`.
- **D144a — no frozen picture, status and diagnostics:** the DeepAR stage publishes a render
  only when DeepAR took a newer camera frame since the last one published (else the raw
  frame), keeps one frame in flight, latches DeepAR's input size per instance and switches
  the effect off by itself (raw camera, Magic says why) after 30 frames in a row without a
  fresh render, 10 s without a first one, a stalled DeepAR thread, a licence error or a
  failed start. **Diagnostics overlay** — debug and profile builds only (CI's APK is a debug
  build), video lives on Android: a small black box under the host's top bar; tap folds it.
  What to read on the device:
  - `DeepAR ready licence yes` with `out` rising about as fast as `in`, few `raw`: working.
  - `licence no`: the build has no key (`DEEPAR_LICENSE_ANDROID`).
  - `fed` rising but `out` flat and `stale` rising: DeepAR re-draws without taking frames
    (the D144 freeze case) — the effect turns off (`disabled (no_output)`) instead of freezing.
  - `inflight` growing into seconds: DeepAR's thread is stuck (`disabled (stalled)`).
  - `init no` for 10 s: `error (init_timeout)`; `licence_failed`: DeepAR refused the key.
  - `render` = DeepAR's own render count, `got` = renders that reached the processor; `wait` /
    `pack` = average ms per frame waiting for DeepAR / reading the camera back; `input` =
    DeepAR's latched input (`1280x720@270` front camera); `#` = DeepAR instances (a new one
    per camera flip).
  The Kotlin rules are unit-tested (`./gradlew :kabso_camera_fx:testDebugUnitTest` in
  `apps/mobile/android`, CI's Android job); none of this has run on a device yet.
- **D144b — the effect always gets the camera, or says it did not start:** a camera opened
  while another is still open is a *shared* flutter_webrtc track that the processor never
  sees; the app now opens one camera at a time (`LiveCameraGate`), the plugin moves a shared
  track onto the camera's frame path at attach, and the start is judged 10 s after the
  pick, frames or not. Overlay line `camera N  path …`: `camera` = frames the track handed
  to the processor (effect or not), `path` = `source` (normal) / `rebound` (a shared track
  was moved) / `unknown`. `camera 0` while `on track` → after 10 s `error (no_frames)`;
  `init no` with frames → `error (init_timeout)`; Magic then says the effect did not start
  and the raw camera goes on.
- **D144c — one DeepAR engine, never paused, nothing black on the air:** DeepAR's native
  engine is one per app process; a new one never starts while the last is not released
  (it waits; `error (engine_busy)` after 10 s). None and every failure release DeepAR
  instead of pausing it (a paused DeepAR ignores `switchEffect`). DeepAR's picture goes out
  only once it was seen lit; black renders are replaced by the camera and only 8 s of black
  gives up (`disabled (black_output)`). Overlay: `engine` = DeepAR's own state (1 starting,
  2 running), `lit N ms` = from the pick to the first lit picture, `held` = black renders
  replaced by the camera; DeepAR's warnings on their own `warn` line.
- **Camera/microphone permissions (D144a):** Android asks through the plugin's
  `com.kabso/permissions` channel after the app's own explanation sheet, once; refused for
  good → «فتح الإعدادات». Audio rooms and audio seats ask for the microphone only.

### 9.2 The free camera effects engine beside DeepAR (D228) — [IMPLEMENTED, Android, not device-tested]

A second engine for Magic's effects, **next to DeepAR (not replacing it)**, so the owner can compare both on a phone:
Google ML Kit selfie segmentation (background blur) + MediaPipe Face Landmarker (beauty: smooth skin, brighten,
slim face, bigger eyes; sliders 0–100, default 40), all GLSL on the GPU inside the same `kabso_camera_fx` processor
(`FreeFxStage` instead of `DeepArStage`; the colour stage follows either). No key, no account.

- **Switch (server):** admin panel «إعدادات الموقع» → «محرك مؤثرات الكاميرا» (OWNER; `PUT /admin/camera-fx`, audited).
  Default DeepAR. Hosts get it the next time they open the go-live screen (`LiveConfig.cameraFxEngine`). Needs the
  migration `20270215090000_camera_fx_engine` (adds the key to `site_settings`' CHECK; no data).
- **Switch (test builds only):** the FX diagnostics overlay (debug/profile APKs, video live on Android) has three chips
  under it — `srv` (follow the server), `DeepAR`, `Free`; kept on the phone. Not in release builds.
- **Face model:** downloaded once (3.6 MB) from Google's model storage on first beauty use, SHA-256 pinned; not in the
  APK. No network → blur still works, beauty says why.
- **APK size (measured from the AARs, not from a built APK; owner approved the increase 2026-11-01):** native code
  per ABI, uncompressed —
  arm64-v8a 36.0 MB (MediaPipe 14.4 + ML Kit 21.6), armeabi-v7a 26.1 MB, x86_64 37.7 MB, x86 40.6 MB; about 12 MB
  per ABI after compression (arm64 gzip: 6.6 + 5.7 MB), plus ~0.25 MB model asset and ~2.5 MB of classes before R8.
  A universal (all-ABI) debug APK grows by roughly 140 MB; a per-ABI release/app bundle by ~36 MB on the phone and
  ~12 MB to download for arm64.
- **Privacy:** the picture stays on the phone; both SDKs send Google usage/performance metrics (see the plugin's
  `THIRD_PARTY_NOTICES.md`). **Owner approved the disclosure (2026-11-01):** the privacy policy text now says so
  (`infra/deploy/site/privacy.html` §2 «مؤثرات الكاميرا في البث» / “Camera effects in lives” and §5 Google, Arabic
  and English) — the version was **not** bumped: the owner publishes it (`legal-admin publish privacy`). The Play
  Data safety answers for these SDKs are PRE_PRODUCTION_CHECKLIST **PP-39**.
- **Removal:** docs/KNOWN_LIMITATIONS.md («The free camera effects engine», D228).
- **Not verified:** see docs/KNOWN_LIMITATIONS.md (D228) — fps, quality, memory, heat and the release (R8) build have
  not run anywhere; CI's Android job is the first full build.

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
| `kabsolive.com` | Caddy, the public website (`infra/deploy/site`, D192 §11.7); `/api/v1/waitlist`, `/api/v1/site/settings` → API; `/topup*` → 302 to `api.` (D190) |
| `www.kabsolive.com` | Caddy, permanent redirect to `kabsolive.com` (D192) |
| `api.kabsolive.com` | Caddy → API (`/internal/*` answers 404 from outside) |
| `live.kabsolive.com` | Caddy → LiveKit signalling (`wss://`); media on 7881/tcp, 7882/udp; *(D330)* `/app/` the staging test APK mirror (§11.8) |
| `admin.kabsolive.com` | *(D191)* Caddy, the admin panel's static build (`infra/deploy/admin/current`) and `/api/*` → API (§11.6) |
| `studio.kabsolive.com` | *(D247)* Caddy, «استوديو البث»'s static build (`infra/deploy/studio/current`) and `/api/*` → API (§5.48) |

PostgreSQL, Redis and the API are not published; only 80, 443 (TCP+UDP), 7881/tcp and
7882/udp are. Caddy gets and renews the Let's Encrypt certificates once the DNS A records (the
domain, `api.`, `live.` and, since D191, `admin.`; since D247, `studio.`) point at the server.

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

### 11.6 The admin panel «لوحة الإدارة» (D191) — [IMPLEMENTED, draft contract v1.60-social; not deployed]

CONVENTIONS §10.54. `apps/admin` (React + TypeScript + Vite) is built into static files and served by Caddy at
`https://admin.<domain>`, which also proxies `/api/*` to the API (same origin: the HttpOnly session cookie stays
first-party). The panel signs in an existing admin account with its password and a **mandatory authenticator code**.

**Owner steps, once:**

1. **DNS:** an A record `admin.kabsolive.com` → the server's IPv4 (the same address as `api.`). Caddy gets the
   certificate by itself on the next update.
2. **Key:** `ADMIN_TOTP_KEY` in `/etc/kabso/api.env` (encrypts the authenticators' secrets; without it the panel
   answers 503). `install.sh` writes it on a new server and adds it once on an existing one; by hand:

   ```bash
   sudo sh -c 'grep -q "^ADMIN_TOTP_KEY=" /etc/kabso/api.env || echo "ADMIN_TOTP_KEY='"'"'$(openssl rand -base64 48 | tr "+/" "-_" | tr -d "=\n")'"'"'" >> /etc/kabso/api.env'
   sudo docker compose -f /opt/kabso/infra/deploy/docker-compose.yml up -d api   # re-reads api.env
   ```

   Never change it afterwards without `admin-admin reset-2fa` for every admin (their authenticators become
   unreadable). Optional settings (defaults): `ADMIN_SESSION_IDLE_SECONDS` 1800, `ADMIN_SESSION_MAX_SECONDS` 28800,
   `ADMIN_PENDING_SECONDS` 300, `ADMIN_LOCKOUT_ATTEMPTS` 5, `ADMIN_LOCKOUT_SECONDS` 900, `ADMIN_DASHBOARD_TIME_ZONE`
   `Asia/Riyadh` (the dashboard's «today»), `RATE_LIMIT_ADMIN_LOGIN_IP`
   `30/900`, `RATE_LIMIT_ADMIN_IP` `1200/900`, `RATE_LIMIT_ADMIN_TEAM_IP` `20/900` (D271: the staff page's grant /
   revoke / reset-2fa per IP); D273: `STAFF_APP_GRANT_SECONDS` 43200 (the app's staff step-up), `RATE_LIMIT_STAFF_APP_USER`
   `300/900`, `RATE_LIMIT_STAFF_STEP_UP_USER` `10/900`.
3. **Optional IP allowlist:** `KABSO_ADMIN_ALLOW_IPS='203.0.113.7/32 198.51.100.0/24'` in `/etc/kabso/kabso.env`
   (space-separated CIDRs) answers 403 at admin.<domain> to every other address. **Leave it unset for everyone** — an
   empty value (`KABSO_ADMIN_ALLOW_IPS=`) blocks everyone. Then `docker compose … up -d caddy`.
4. **Bootstrap the first OWNER** (an existing app account; a grant also makes it an admin):

   ```bash
   cd /opt/kabso/infra/deploy
   sudo docker compose --profile jobs run --rm migrate node dist/cli/admin-admin.js grant owner@example.com OWNER
   sudo docker compose --profile jobs run --rm migrate node dist/cli/admin-admin.js list
   ```

   Other roles the same way: `MODERATOR`, `SUPPORT`, `FINANCE`; `revoke <email> <role>` takes one back (the last one
   ends the person's panel sessions); `reset-2fa <email>` after a lost phone. `<email>` may also be `@username`.
   **After the first OWNER (D197, D271):** the OWNER manages everyone else from the panel's **«الموظفون والصلاحيات»**
   (Staff & permissions; settings group): grant a role to an existing app account by email or username, revoke one,
   reset a lost authenticator — each with a written reason and a fresh code from the OWNER's own authenticator, audited
   `via: panel` with the OWNER as the actor. The panel never takes OWNER from oneself. **Neither the panel nor the CLI
   revokes the last active OWNER**: `revoke <email> OWNER` on the last one exits 1 («grant OWNER to another active
   account first») — to hand ownership over, `grant <new> OWNER` first, then `revoke <old> OWNER`. The CLI stays the
   bootstrap of the first OWNER.
5. **Enrol the authenticator:** open `https://admin.kabsolive.com`, sign in with the account's email and password,
   scan the QR code with Google Authenticator / Microsoft Authenticator / 1Password, enter the code, and **store the
   ten recovery codes** offline (shown once; each works once).

**How the build reaches the server:** `update.sh` runs `infra/deploy/build-admin.sh`, which rebuilds only when
`apps/admin`, the lockfile or the fonts changed: it runs `pnpm install --frozen-lockfile --filter @kabso/admin` and
`vite build` in the API's pinned Node image on a copy of those files, then swaps `infra/deploy/admin/current` (two
renames; not in git). A failed build keeps the previous one and does not stop the API deploy. By hand:
`sudo /opt/kabso/infra/deploy/build-admin.sh --force`. CI checks the panel in the `admin` job (typecheck, lint, unit
tests, build).

**Security headers** (Caddy): CSP `default-src 'self'` (no inline script or style, `frame-ancestors 'none'`,
`img-src 'self' data: https:` for the media host's avatars), HSTS, `X-Frame-Options: DENY`, `nosniff`,
`Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex`; `index.html` is `no-store`, hashed assets immutable.

**Local development:** API on :3000 with `ADMIN_TOTP_KEY` set, then `pnpm --filter @kabso/admin dev` (Vite on :5180
proxies `/api`). Smoke: `SMOKE_FILE=/tmp/admin-smoke.json pnpm --filter @kabso/api smoke:admin-server` (resets the
`*_test` database of `DATABASE_URL`, seeds a not-yet-enrolled OWNER and data, listens on :3000), then
`pnpm --filter @kabso/admin build && KABSO_SMOKE_FILE=/tmp/admin-smoke.json pnpm --filter @kabso/admin e2e`.

**Verified in the authoring environment (no server):** API unit and e2e tests (D191 + D185, D179, D175, D189,
KL-060 safety, KL-062 notifications), the Playwright smoke against the local API, `caddy validate` 2.10.2 and a
local Caddy run of the admin block (SPA fallback, headers, `/internal/*` 404, the allowlist). **Not verified:** the
DNS record, the certificate, `build-admin.sh` inside Docker on the server (no Docker daemon here).

**Account controls «تحكم كامل» (D208, contract v1.72-social, CONVENTIONS §10.67):** the migration
`20270130090000_admin_control` runs with the next `update.sh` (new tables `account_restrictions` and
`admin_balance_adjustments`, `users.password_change_required_at`, two notification columns, the ledgers' sign rules
extended in place for `ADMIN_ADJUSTMENT`). Optional settings in `/etc/kabso/api.env`: `ADMIN_ADJUST_DAILY_CAP_COINS`
and `ADMIN_ADJUST_DAILY_CAP_CHERRIES` (10 000 000 each; the most ONE admin may move per day; 0 = no adjustments). The
`ADMIN_USERNAME_RENAME_HOLD_DAYS` (30): how long the old username stays held after a team rename (0 = none). The
panel's ban now asks for the authenticator code. The CLI on the server (migration role; `via: cli` in the audit log,
no actor):

```bash
cd /opt/kabso/infra/deploy
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js state user@example.com
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js lock user@example.com --days 3 --reason "…"
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js unlock user@example.com --reason "…"
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js restrict user@example.com CHAT_MUTE --days 7 --reason "…"
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js require-password-change user@example.com --reason "…"
sudo docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js adjust user@example.com coins +5000 --reason "…"
```

A CLI lock ends every session; a live the person hosts then ends by the room sweeper (no heartbeat), not at once
as from the panel. **Merge note:** a branch that redefines `wallet_ledger_reason_sign` / `cherry_ledger_reason_sign`
(e.g. D204's `RECHARGE_ORDER`) must run before this migration (an earlier timestamp) or keep `ADMIN_ADJUSTMENT` in its
list; this migration extends whatever rule is in place.

### 11.7 The public website kabsolive.com (D192) — [IMPLEMENTED; checked locally through the committed Caddy block, not on the server yet]

**DNS** (A records to the server's IP; Caddy gets every certificate itself): `kabsolive.com` (apex), **`www`**
(new: redirects to the apex; until it exists Caddy only logs failed certificate attempts for it), `api`, `live`,
`admin` for D191's panel, and `studio` for D247's «استوديو البث» (§5.48).

**How the server picks it up:** Caddy serves `infra/deploy/site/` straight from the checkout (`./site:/srv/site:ro`),
so a merged change to the website is live as soon as `update.sh` fast-forwards `/opt/kabso` — no restart. A change to
the Caddyfile (this one: security headers, the two API paths, the `/topup` redirect, `www`) needs Caddy to pick it up,
which `update.sh` does when the Caddyfile changed between the two commits. *D205:* it recreates the Caddy container
(`docker compose -f /opt/kabso/infra/deploy/docker-compose.yml up -d --force-recreate caddy`) instead of `caddy reload` —
on the server a reload did not start serving the new `admin.` site block, while recreating the container did and the
certificate was then obtained (certificates stay in the `caddy-data` volume). Run that command by hand if an update ran
before this script change was on the server.

**`infra/deploy/site/config.json` — the legal fields the owner owns** (shown on `/privacy`, `/terms`, `/contact`):
`companyLegalName` (Kigofi LLC), `address` (30 N Gould St #7354, Sheridan, WY 82801, USA), `country` (United States),
`governingLaw` (Wyoming, USA), `supportEmail` (info@kabsolive.com), `minAge` (18, confirmed), `lastUpdated`, and
`legalReviewed` — **false until a lawyer has reviewed the texts**; while false every legal page shows «مسودة — تحتاج
مراجعة قانونية». An empty field renders «سيُضاف قريباً»; `update.sh` prints a warning listing empty fields and the
unreviewed state on each deployment. Change them by a commit (they are public text).

**Social links and the top-up switch are not in config.json:** the OWNER sets them in D191's admin panel
(«إعدادات الموقع» → `PUT /api/v1/admin/site-settings`, panel session, §11.6; one module and table for the panel and
the website, CONVENTIONS §10.54.6). Links are stored and served in one form: `https://www.instagram.com/<handle>`,
`https://www.tiktok.com/@<handle>`, `https://wa.me/<digits>`. `topupEnabled` stays false until D190's top-up keys are
set (§5.29); the website's «شحن العملات» link opens `https://<domain>/topup`, which Caddy redirects (302) to
`https://api.<domain>/topup` (D190's pages, `TOPUP_PUBLIC_BASE_URL`).

**Waitlist:** `docker compose --profile jobs run --rm migrate node dist/cli/waitlist-admin.js list` (count + newest)
or `… export [--locale ar|en] > waitlist.csv` (delete the file after the launch mailing). Every run is audited.

**Headers** on the static site: CSP `default-src 'self'` (no inline script; fonts self-hosted), `frame-ancestors
'none'`, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, HSTS one year with
subdomains, `Permissions-Policy` off for camera/microphone/geolocation/payment. Art and fonts are cached 30 days (a
changed image gets a new file name); pages, CSS, JS and config.json 5 minutes.

### 11.8 The staging test APK at https://live.kabsolive.com/app/ (D330) — [IMPLEMENTED; validated locally (Caddy 2.10.2, a fake release), not on the server or in CI yet]

**Why:** the staging APK was only a GitHub Actions artifact: a ≈106 MB zip (105.93–105.96 MB for the last three
runs, 2026-11-08), behind a GitHub login, slow on the owner's phone, and a zip to unpack before installing.

**Size.** The staging build has been **arm64-v8a only since KL-069** (`--split-per-abi --target-platform
android-arm64`); the ≈106 MB is already the one-ABI profile APK, zipped. So D330 does **not** make the APK itself
smaller; what changes is how it is delivered. Estimated (not measured — no Android SDK here, the artifact could not be
downloaded): native code is stored uncompressed in the APK (minSdk 24, AGP's default), about 36 MB MediaPipe + ML Kit
(measured from the AARs, §9), 11–23 MB DeepAR, roughly 10 MB each WebRTC and the Flutter engine, plus the app's own
AOT code and ~38 MB of assets — so the APK file is about **140–170 MB**, and gzip brings it back to about the
artifact's ≈106 MB on the wire. The other ABIs (armeabi-v7a, x86, x86_64) would add roughly 60–80 MB each, which is
why no universal APK is built for staging. Smaller still needs app-side changes, not CI: a release build with a real
keystore (R8 and the release engine; estimated 10–20 % less, blocked on the upload key, §9), or moving large art to
download-on-demand. CI's `android` job still builds its **universal debug** APK (`kabso-live-debug-apk`) as the
compile check on every branch; nothing downloads it for testing.

**Flow (no secret, no token on the server):**

1. A green push to `staging` → CI's `staging-apk` builds the APK (unchanged: profile, the same dart-defines, signed
   with the runner's debug key like every Flutter profile build), uploaded as `kabso-live-staging-arm64-apk`.
2. `staging-apk-release` (only this job has `contents: write`) publishes it to the rolling **prerelease
   `staging-latest`** (tag moved to the commit; never marked "latest"): `kabso-staging.apk`, then `kabso-staging.txt`
   (`commit`, `version`, `sha256`, `size`, `built`, `run`). Public repository (D40) → downloadable without a login from
   GitHub's CDN: `https://github.com/sd343434/kabso/releases/download/staging-latest/kabso-staging.apk`.
3. On the server, every `kabso-update.timer` run (5 minutes) ends with `infra/deploy/mirror-apk.sh` (an EXIT trap in
   `update.sh`, so also after "nothing changed" and after a failed deploy; `timeout 600`; a failure only logs
   `staging APK mirror failed …` and never changes the API update or its result). It fetches the ~200-byte manifest
   (release downloads, not the rate-limited API), and only when its sha256 differs from the one served downloads the
   APK, checks the size bounds (10–400 MB), the size and sha256 against the manifest and the ZIP signature, writes a
   gzip copy and the page, and moves them into `/opt/kabso/infra/deploy/app/` with renames (git-ignored; an open
   download keeps the old file). Only the latest build is kept; a half-replaced release pair (sha mismatch) is skipped
   until the next run. By hand: `sudo /opt/kabso/infra/deploy/mirror-apk.sh [--force]`.
4. Caddy (`live.` block, before the LiveKit proxy; LiveKit never uses `/app`; `./app:/srv/app:ro`) serves:

| URL | What |
| --- | ---- |
| `https://live.kabsolive.com/app/` | page: version, commit, build time, size, sha256, «تحميل التطبيق / Download APK» (Arabic + English), `noindex` |
| `https://live.kabsolive.com/app/kabso-staging.apk` | the APK, `Content-Type: application/vnd.android.package-archive`, `Content-Disposition: attachment`; `Content-Encoding: gzip` when the browser accepts it (then no Content-Length: the phone shows MB received without a percentage) |
| `https://live.kabsolive.com/app/raw/kabso-staging.apk` | the same APK never compressed (for a download manager that saves gzip undecoded → "problem parsing the package") |
| `https://live.kabsolive.com/app/kabso-staging.txt` | the manifest |

Every response: `Cache-Control: no-cache` (the name never changes; revalidated by ETag), HSTS, `nosniff`, CSP
`default-src 'none'; style-src 'unsafe-inline'` (no script), `X-Frame-Options: DENY`, `X-Robots-Tag: noindex`; any
other `/app/*` name (the `.gz` copy, temp files) answers 404. `file_server { precompressed gzip }` was **not** used:
Caddy 2.10.2 answered it with 206 Partial Content to a request without `Range` (reproduced locally).

**What becomes public:** the APK is downloadable by anyone with the link, and the `staging-latest` prerelease is
listed on the public repository's Releases page. It contains what any copy of the staging APK contains, and **no
server secret**: the staging API address `https://api.kabsolive.com` (already public), the version/commit, the app's
compiled code (a profile build: the FX diagnostics overlay is visible; demo data off, D86), the **DeepAR client
licence key** (a client key that ships in every APK by design, §9; DeepAR bills by monthly active users and the key is
tied to the package name — a copied key only works in an app with this package id) and, when the secret is set, the
**Firebase client config** from `google-services.json` (project id, app id, the Android API key — public client
identifiers by Firebase's design; restricting that key to the Android app in Google Cloud is good practice). Anyone
who installs it can use the staging server like the app itself (it was already reachable on the internet).

**One-time server steps (owner):** none are required — once this commit is on `staging`, the next timer run
fast-forwards the checkout, recreates Caddy (the Caddyfile and the compose volume changed) and the run after that,
once CI's `staging-apk-release` has published, mirrors the APK. To check (as root):

```bash
systemctl start kabso-update.service && journalctl -u kabso-update.service -n 30 --no-pager   # "staging APK: serving …"
ls -l /opt/kabso/infra/deploy/app/                       # index.html, kabso-staging.apk(.gz), kabso-staging.txt
curl -sI https://live.kabsolive.com/app/kabso-staging.apk | grep -iE '^(HTTP|content-type|content-disposition)'
```

If the update ran before the new `update.sh` was on the server, run
`docker compose -f /opt/kabso/infra/deploy/docker-compose.yml up -d --force-recreate caddy` and
`sudo /opt/kabso/infra/deploy/mirror-apk.sh` once by hand. Before the first `staging-apk-release` run the manifest
answers 404 and the mirror does nothing (silently); `/app/` answers 404 until then. On the phone: open
`https://live.kabsolive.com/app/` in Chrome → «تحميل التطبيق» → open the file → allow installs from Chrome if asked
(installing over the previous staging build needs the same signing key; CI signs the profile build with the runner's
debug key, which can differ between runs — if Android answers "App not installed" / a package conflict, uninstall the
old staging app first, as with the artifact before).

### 5.25 Video posts and reels (migration `20261211090000_video_posts_reels`; D162) — [IMPLEMENTED, draft contract v1.41-social; not deployed, not device-tested]

Video in «منشور جديد» (the «فيديو» tab), reels («ريلز») in «لحظات» and the ➕ menu (CONVENTIONS
§11.14, CP-023). **No server-side transcoding:** the API checks the uploaded MP4 / QuickTime file
(container, length, H.264/HEVC track, size) without decoding it and serves it as uploaded.

- **Migration** with the usual `migrate` job (§5), after D155's (§5.24): enum `post_format`,
  `posts.format` (default `POST`: every existing post stays a post), `media_assets.poster_key`, the
  partial index `posts_reels_author_published_idx`, and wider CHECKs — `media_uploads_byte_size_range`
  (≤ 209 715 200), `media_assets_kind_known` (+ `POST_VIDEO`, `REEL_VIDEO`, `VIDEO_POSTER`),
  `media_assets_duration_shape` (reels ≤ 60 000 ms, post videos ≤ 180 000 ms) and the new
  `media_assets_poster_shape`. No GRANT (default privileges), no backfill.
- **Settings:** none new; no secret. Videos ride the existing upload switch and storage (§5.3):
  `MEDIA_UPLOADS_ENABLED=true` plus `S3_*` and `MEDIA_PUBLIC_BASE_URL`. With uploads off, the app
  says video uploads are unavailable and posts nothing. The upload rate limit
  (`RATE_LIMIT_MEDIA_UPLOAD_USER`, 60 / hour) now counts two uploads per video (the file and its
  poster); `GET /feed/reels` shares `RATE_LIMIT_FEED_USER`.
- **Limits (code constants, contract):** reel ≤ 100 MiB and 1–60 s; post video ≤ 200 MiB and
  1–180 s (**1–90 s since D168**, §5.26); 16–4 096 px per side; `moov` ≤ 16 MiB.
- **Storage:** the storage key additionally needs **`CopyObject`** (the API copies
  `uploads/{userId}/{uploadId}` to `media/{mediaId}/video.mp4|.mov` inside the bucket — the bytes
  never pass through the API) and **ranged `GetObject`** (the container is read by its box headers
  and the `moov` box only). Cloudflare R2's "Object Read & Write" token covers both. The video's
  poster and thumbnail are the phone-made first frame (`media/{posterId}/1080.webp` and
  `320.webp`). `media/` stays the only public prefix; it must serve HTTP **range requests**
  (R2 and its custom domains do) so players can seek and play files whose `moov` is at the end.
- **Cost / capacity:** files are streamed as uploaded (a 60 s phone reel is typically 20–120 MB),
  so egress grows with views; consider a CDN cache rule on `media/*/video.*` (immutable). The
  never-attached sweep (`MEDIA_SWEEP_INTERVAL_SECONDS`) also deletes abandoned videos and posters.
- **Moderation (D162a, owner):** posts with photos, a video and reels are visible to everyone at
  once (no hold); safety relies on reports and moderators' `REMOVE_TARGET`. Data migration
  `20261212090000_media_posts_visible` (after `20261211090000_video_posts_reels`, usual `migrate`
  job) turns posts held `PENDING` by the old CP-006 Q2 rule into `VISIBLE` (nothing else ever set
  `PENDING`; `REMOVED` posts are untouched). No GRANT, no new setting.
- **Later (not in this step):** server-side transcoding / HLS / server thumbnails (CP-006 Q1:
  Cloudflare Stream, Mux or FFmpeg workers), video stories, personalised reels ranking (M5).

### 5.26 Profile editing and 90-second post videos (migration `20261213090000_profile_avatar_video_90s`; D168) — [IMPLEMENTED, draft contract v1.45-social; not deployed, not device-tested]

«تعديل الملف الشخصي» can change the name, the bio and the profile photo; post videos are at most
90 s (owner; reels stay 60 s) (CONVENTIONS §10.42, §11.14).

- **Migration** with the usual `migrate` job (§5), after D162a's: `user_profiles.avatar_media_id`
  (unique, FK to `media_assets`, NO ACTION) and CHECK `user_profiles_avatar_media_has_url`;
  `media_assets_kind_known` gains `AVATAR`; new CHECK `media_assets_post_video_90s` created
  **`NOT VALID`** — PostgreSQL enforces it on new and updated rows only, so post videos stored before
  (up to 180 s) stay valid and playable. **Do not run `ALTER TABLE … VALIDATE CONSTRAINT
  media_assets_post_video_90s`** while such videos exist (it would fail). The API refuses to attach an
  unattached longer one, so it never updates those rows. No GRANT, no backfill.
- **Settings:** new `RATE_LIMIT_AVATAR_USER` (default `30/3600`, `PUT` / `DELETE /me/avatar`). No
  secret. Setting a photo needs `MEDIA_UPLOADS_ENABLED=true` (503 `MEDIA_UPLOADS_UNAVAILABLE`
  otherwise; the app says so); removing it and editing the name / bio work with uploads off.
- **Storage:** an `AVATAR` is two WebP objects like a live cover (`media/{id}/640.webp`, `320.webp`);
  a replaced or removed photo's objects are deleted.
- **Audit:** `user.profile.update` (which fields changed, never values) and `user.avatar.update`.

### 5.27 Profile fields, private accounts and follow requests (migrations `20261215090000_profile_fields_enums`, `20261215100000_profile_fields_private_accounts`; D175) — [IMPLEMENTED, draft contract v1.47-social; not deployed, not device-tested]

Gender (required at sign-up, private by default), the account category, up to 3 https profile links,
the private-account switch with follow requests, and an admin tool to remove a profile photo
(CONVENTIONS §10.47).

- **Migrations** with the usual `migrate` job (§5), in order (the enum values first, in their own
  transaction): `notification_type` gains `FOLLOW_REQUEST`, `FOLLOW_REQUEST_ACCEPTED`, `AVATAR_REMOVED`;
  `report_target_type` gains `PROFILE_LINK`; then types `user_gender`, `account_category`; columns
  `user_profiles.gender`, `show_gender` (default false), `account_category`, `pending_registrations.gender`,
  `reports.target_profile_link_id`, `reports.link_snapshot`; tables `user_profile_links` (CHECKs: position
  0–2, `https://` without whitespace or controls, label 1–30) and `follow_requests` (CHECK not self);
  `reports_one_target` replaced to include `PROFILE_LINK`. No GRANT (default privileges), no backfill:
  existing accounts have no gender until they choose one, and every account stays public.
- **Release together with the app build that has the gender step:** from this API on, `register` without
  `gender` → 400. An older app cannot sign up new accounts (sign-in is unaffected).
- **Settings:** new `RATE_LIMIT_FOLLOW_REQUEST_ANSWER_USER` (default `300/3600`, accept / decline one
  bucket). No secret.
- **Admin CLI** `dist/cli/profile-admin.js` (locally `pnpm profile:admin …`), migration role like the
  others: `remove-avatar <username> --reason <text>` resets the photo, deletes the `AVATAR` asset row,
  notifies the user (`AVATAR_REMOVED`) and audits `admin.avatar.remove` with the reason; it deletes the
  files when given the API's `S3_*` settings, else prints the object keys to delete by hand:
  `docker compose --profile jobs run --rm -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID
  -e S3_SECRET_ACCESS_KEY -e S3_FORCE_PATH_STYLE migrate node dist/cli/profile-admin.js remove-avatar
  <username> --reason "<why>"`.
- **Audit:** `user.profile.update` now also names `gender`, `showGender`, `category`, `links` (never
  values); `user.privacy.private` (`{isPrivate, requestsAccepted}`); `admin.avatar.remove`.

### 5.28 The bag v2: expiry, gifts and sending (migrations `20261216090000_bag_expiry_send_enums`, `20261216100000_bag_expiry_send`; D171) — [IMPLEMENTED, draft contract v1.48-social; not deployed, not device-tested]

(Numbered 5.28: 5.26 and 5.27 are used by other branches in flight.) CONVENTIONS §10.45.

- **Migrations** with the usual `migrate` job (§5), in order (the first only adds the enum values
  `bag_item_source.GIFT` and `notification_type.BAG_ITEM_RECEIVED`): columns
  `user_bag_items.expires_at` (NULL = permanent: **every existing item stays permanent**) and
  `user_bag_items.gifted_by_user_id`, `notifications.bag_item_code`, table `bag_transfers` (the send
  ledger), the CHECK `user_bag_items_gifted_by_source_check`. No GRANT (default privileges), no
  backfill.
- **Settings** (optional; defaults shown):

  | Variable | Default | Meaning |
  | --- | --- | --- |
  | `BAG_SWEEP_INTERVAL_SECONDS` | `300` | The sweeper that deletes expired bag items (reads never return them anyway). 0 disables it |
  | `RATE_LIMIT_BAG_SEND_USER` | `30/3600` | `POST /me/bag/transfers` per user |

- **Granting with a duration:** `bag-admin grant <email> <code> [<days>|forever]` (default
  `forever`, as before; days 1–3650). An item the user owns gets the days added; `forever` makes
  it permanent. On the server:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/bag-admin.js grant someone@example.com emerald_wings 7
  ```

### 5.29 Card top-ups on the website through Stripe (migrations `20270104090000_card_topups_enums`, `20270104100000_card_topups`, `20270104110000_topup_team_refunds`; D190) — [IMPLEMENTED, draft contract v1.59-social; not deployed; no real Stripe call made]

CONVENTIONS §10.53, CP-033. **Off until the owner enters the Stripe keys** — since D196 (v1.64-social, §10.53.1) in
the admin panel «الدفع (Stripe)», with only `TOPUP_PUBLIC_BASE_URL` on the server (the env keys below still work and
are the fallback); until then every top-up operation answers 503 `TOPUP_UNAVAILABLE` and `https://api.<domain>/topup`
says «الشحن بالبطاقة غير مفعّل». Card payments happen **only on the website**, never inside the app. Seller: Kigofi LLC, 30 N Gould St #7354,
Sheridan, WY 82801, USA.

- **Migrations** with the usual `migrate` job (§5), in order: the first adds the coin ledger reasons `CARD_TOPUP`,
  `CARD_TOPUP_REVERSAL`, `CARD_TOPUP_RESTORE`; the second the tables `topup_terms_acceptances`, `topup_orders`,
  `topup_freezes`, `topup_cases`, `stripe_events`, `stripe_customers` and **widens `wallets.coins` and
  `wallet_ledger.balance_after` to allow values below 0** (only a reversed purchase does that); the third adds
  `topup_orders.team_refunded_minor` / `team_refund_reason` (team refunds). No GRANT, no backfill. D196 adds
  `20270111100000_payment_settings` (the table `payment_settings`, one row: the keys the OWNER saves in the panel,
  sealed; no row = the env keys as before). No GRANT, no backfill.
- **Where it lives:** the API serves the pages (`/topup`, `/topup/success`, `/topup/cancel`) and the webhook
  (`/api/v1/payments/stripe/webhook`) on `api.<domain>`; the Caddyfile redirects `https://<domain>/topup…` there.

#### Stripe dashboard (the owner, once; live mode)

1. **Account and business:** activate the account for Kigofi LLC (the address above), USD payouts.
2. **Statement descriptor** (Settings → Business → Public details / Customer emails): `KABSO LIVE` (shortened
   descriptor `KABSO`). Optional dynamic suffix from the server: `STRIPE_STATEMENT_DESCRIPTOR_SUFFIX`.
3. **Customer emails** (Settings → Customer emails): turn on *Successful payments* and *Refunds* receipts (the
   checkout passes the account's email as `receipt_email`).
4. **Payment methods** (Settings → Payment methods): **Cards** on and **Bank transfers** (customer balance, US) on —
   the server offers them by default (owner answer CP-033 Q3: `STRIPE_BANK_TRANSFER_ENABLED=true`,
   `STRIPE_BANK_TRANSFER_TYPE=us_bank_transfer`, Kigofi LLC being a US LLC). If the account cannot take bank
   transfers yet, set `STRIPE_BANK_TRANSFER_ENABLED=false` until it can. Leave other methods off: the checkout only
   allows `card` + `customer_balance`. A transfer is credited only by the webhook
   (`checkout.session.async_payment_succeeded`); until then the order shows «بانتظار وصول التحويل البنكي».
5. **3-D Secure:** nothing to switch — every session asks for it (`request_three_d_secure=any`). Optionally add the
   Radar rule *Request 3D Secure if 3D Secure is supported for card*.
6. **Radar:** keep the default rules (on by default). Optional: *Block if :risk_level: = 'highest'*.
7. **Chargeback Protection** (Payments → Chargeback protection / Radar settings, where Stripe offers it): the owner
   may enroll; Stripe then covers eligible fraud disputes on Checkout payments. **Nothing in the code depends on
   it** — reversals, freezes, cases and evidence run the same either way.
8. **Webhook** (Developers → Webhooks → *Add destination*, account events, the account's API version):
   endpoint `https://api.<domain>/api/v1/payments/stripe/webhook`, events
   `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`,
   `checkout.session.expired`, `charge.refunded`, `radar.early_fraud_warning.created`, `charge.dispute.created`,
   `charge.dispute.closed`. Copy its **signing secret** (`whsec_…`).
9. **API key:** create a **restricted key** (`rk_live_…`) with *write* on Checkout Sessions, Refunds, Disputes,
   Files, Customers (read on the rest is not needed), or use the secret key.

#### Enter the keys in the admin panel (the owner; D196 — no server access, no restart)

Needs the admin panel on (D191: `ADMIN_TOTP_KEY` set, your OWNER account enrolled) and, once, on the server
`TOPUP_PUBLIC_BASE_URL=https://api.<domain>` in `/etc/kabso/api.env` (infrastructure; shown read-only in the panel).

1. Sign in at `https://admin.<domain>` and open **«الدفع (Stripe)»** (OWNER only).
2. **Webhook:** copy «عنوان الـ Webhook» (`https://api.<domain>/api/v1/payments/stripe/webhook`) into Stripe →
   Developers → Webhooks → *Add destination* (step 8 above) and tick the events the panel lists; copy the
   destination's **signing secret** (`whsec_…`).
3. Paste the **secret key** (or the restricted key of step 9) into «مفتاح سري جديد» and press **«اختبار الاتصال»**:
   Stripe must accept it (a harmless `balance.retrieve`; a restricted key without the balance permission shows
   «مفتاح مقيّد يعمل»). Paste the signing secret into «سرّ توقيع جديد».
4. **«حفظ المفاتيح»**, give a reason and your authenticator code. The server tests the key again, stores both
   encrypted (AES-256-GCM, key derived from `ADMIN_TOTP_KEY`) and uses them from the next request — no restart.
   From then on the panel shows only their type (live / test), the last 4 characters, who saved them and when.
5. Optional, same page: the publishable key, bank transfers, the statement descriptor suffix, the dispute
   auto-submit and the app link (each «حسب الخادم» = the env value below). Every save asks for the code and a reason
   and is audited (`payment.settings.update`, keys masked).
6. Then turn on «إظهار رابط «شحن العملات» في الموقع» in «إعدادات الموقع» (refused while there are no keys).

**Rotating:** paste only the new key or only the new signing secret and save; after a new signing secret the old one
is still accepted for 10 minutes (deliveries Stripe already signed). **Removing:** «حذف مفاتيح اللوحة» (code +
reason): the env keys apply again if the server has them, otherwise top-ups stop. **A new `ADMIN_TOTP_KEY`** makes the
saved keys unreadable (the panel says so; the env keys apply): enter them again. `STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION`
stays an env switch: without it production refuses a test key in the panel too.

#### Server environment (fallback; the owner, on the server only — never in git, chat or a ticket)

Before D196 this was the only way, and it still works unchanged: keys saved in the panel take precedence; with none
saved, these apply. Put them in `/etc/kabso/api.env` (and `STRIPE_SECRET_KEY` also in `/etc/kabso/migrate.env` for
`payments-admin refund`, unless the panel holds the key and `ADMIN_TOTP_KEY` is passed to the job), file mode 600, then
recreate the API (`docker compose -f infra/deploy/docker-compose.yml up -d --force-recreate api`):

| Variable | Value | Meaning |
| --- | --- | --- |
| `STRIPE_SECRET_KEY` | `rk_live_…` / `sk_live_…` | Without panel keys: required (with the webhook secret). A test key is refused in production unless `STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION=true` (a staging server only) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_…` | Without panel keys: the webhook's signing secret (step 8) |
| `TOPUP_PUBLIC_BASE_URL` | `https://api.<domain>` | Required (also for the panel's keys; may be set alone): the origin that serves `/topup` (https in production) |
| `TOPUP_PACKAGES` | `100000,500000,1000000,5000000,10000000,50000000` | Coin packages; prices from `COIN_RETAIL_USD_PER_MILLION` (12.5 → $12.50 per million) |
| `STRIPE_BANK_TRANSFER_ENABLED` / `STRIPE_BANK_TRANSFER_TYPE` | `true` / `us_bank_transfer` | US bank transfers next to the card (step 4; owner: on at launch) |
| `STRIPE_STATEMENT_DESCRIPTOR_SUFFIX` | unset | Optional dynamic suffix (letters, digits, spaces; prefix + suffix ≤ 22) |
| `STRIPE_DISPUTE_AUTO_SUBMIT` | `true` | Submit the dispute evidence at once; `false` stages it in the dashboard for review |
| `TOPUP_APP_LINK_ENABLED` | `true` | The app's «الشحن من الموقع» link (owner: shown). Set `false` per environment to hide it (e.g. a store-review build's server); review Google Play / App Store payment rules before the store release (PP-35) |
| `TOPUP_TERMS_VERSION` | `2026-10-31` | Recorded with each acceptance; change it when the statement changes |
| `RATE_LIMIT_TOPUP_CHECKOUT_USER` | `20/3600` | Checkouts started per user |

A partial set (a key without the webhook secret or the base URL) refuses to boot; the base URL alone is fine (the panel's keys). **Test first** on a staging server
with `sk_test_…`/`whsec_…` from test mode and `STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION=true`, the Stripe CLI
(`stripe listen --forward-to https://api.<staging>/api/v1/payments/stripe/webhook`) and the test cards (3-D Secure
`4000 0027 6000 3184`, dispute `4000 0000 0000 0259`, early-fraud warning `4000 0000 0000 5423`).

#### Operations

`payments-admin` runs as the migration role like the other admin tools:

```bash
docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js orders --email someone@example.com
docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js cases            # open cases
docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js case <case id>    # FIFO gifts, recipients, cherries
docker compose --profile jobs run --rm migrate node dist/cli/economy-admin.js reverse-gift <send id> --note "<case id>"
docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js close-case <case id> --note "<decision>"
docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js unfreeze someone@example.com --note "<why>"
docker compose --profile jobs run --rm -e STRIPE_SECRET_KEY migrate node dist/cli/payments-admin.js refund <order id> --note "<why>"
# D196: with the key saved in the panel, pass ADMIN_TOTP_KEY instead of STRIPE_SECRET_KEY
docker compose --profile jobs run --rm -e ADMIN_TOTP_KEY migrate node dist/cli/payments-admin.js refund <order id> --note "<why>"
```

Host cherries are **never** taken back automatically: a case lists the sends the purchase paid for and the team
decides. A team refund (`refund`, e.g. goodwill) is recorded on the order and marked `kabso_initiated=true` in
Stripe; its coins come back through `charge.refunded` **without freezing the buyer** (owner answer CP-033 Q2). Only
Stripe-started events freeze: disputes, early-fraud warnings, refunds made outside Kabso (e.g. in the dashboard). Audit
actions `topup.*` (no actor for webhook steps).

### 5.30 Account deletion «حذف الحساب» (migrations `20270110090000_account_deletion_enums`, `20270110100000_account_deletion`, `20270110110000_account_deletion_retention`; D193) — [IMPLEMENTED, draft contract v1.62-social; not deployed, not device-tested]

- **What it is** (CONVENTIONS §10.56): Settings › Account › «حذف الحساب» → explanation, password, confirmation word →
  the account is hidden and signed out at once; 30 days to cancel by signing in; then the sweeper purges it into a
  tombstone (personal data and content deleted; ledgers and audit kept without personal data).
- **Settings:** `ACCOUNT_DELETION_GRACE_DAYS` (30), `ACCOUNT_DELETION_USERNAME_QUARANTINE_DAYS` (90),
  `ACCOUNT_DELETION_SWEEP_INTERVAL_SECONDS` (3600; refused as 0 in production), `SUPPORT_EMAIL`
  (info@kabsolive.com), `RATE_LIMIT_ACCOUNT_DELETION_USER` (5/900), `REPORT_LEGAL_HOLD_DAYS` (90, 1–3650: reported
  content of a purged account kept hidden, then deleted with its reports and files), `DELETED_LEDGER_RETENTION_DAYS`
  (2557 = 7 years, 1–36500: the tombstone's ledgers and audit rows; then the trail is deleted and the rest
  anonymised). The owner set 90 days and 7 years (2026-10-31); change them only with the owner/legal. The notices
  need real mail (PP-20); without it they go to the log adapter (development only).
- **Retention jobs** (CONVENTIONS §10.56, in the same hourly sweeper — no separate cron): legal holds whose 90 days
  ended are deleted with their reports and files (audit `account.deletion.hold_expired`); tombstones purged more than
  `DELETED_LEDGER_RETENTION_DAYS` ago lose their audit rows, deletion record and 18+ statement, their withdrawals keep
  amounts only (`…`) (one audit row per sweep, `account.deletion.retention_ended`, a count). The migration creates
  two `SECURITY DEFINER` functions (`account_deletion_scrub_audit`, `account_deletion_end_retention`; EXECUTE for the
  runtime group only) because `audit_logs` and `points_ledger` are append-only for the runtime role; they refuse any
  account that is not DELETED.
- **Legal hold (moderation):** there is no app or API view of held content. The team reads it with
  `account-admin holds --reason <text>` and `account-admin hold-show <hold|report id> --reason <text> [--save <dir>]`
  (every view audited, `account.deletion.hold_viewed`); `--save` downloads its files (needs `S3_*`) — keep them off
  shared drives and delete them when the case is closed. The moderation queue (`GET /admin/reports`) still lists the
  held reports (target id only) and can close them.
- **Object storage:** the sweeper deletes the purged account's files through the API's `S3_*` settings; a failure
  is logged (`Media objects not deleted`) and the keys are not kept — check the log after the first purges.
- **Admin CLI** `dist/cli/account-admin.js` (locally `pnpm account:admin …`), migration role:
  `docker compose --profile jobs run --rm -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID
  -e S3_SECRET_ACCESS_KEY -e S3_FORCE_PATH_STYLE migrate node dist/cli/account-admin.js pending`
  (`request|cancel|purge-now <username|email|id> --reason <text>`, `holds`, `hold-show`; audited). Without the
  `S3_*` settings `purge-now` prints the object keys to delete by hand (files under a legal hold are not in that list;
  the sweeper deletes them when the hold ends, so run the API with `S3_*`). Pass `-e REPORT_LEGAL_HOLD_DAYS` when the
  server does not use the default.
- **Deletion without the app (Google Play "web resource"):** until the page exists, the store listing and the
  privacy policy name the address **info@kabsolive.com**: the person writes from the account's email; the team
  replies to confirm, then runs `account-admin request <email> --reason "emailed request <date>"` (same 30-day
  grace and notices). Page `https://kabsolive.com/delete-account` (D198, static, `infra/deploy/site/delete-account.html`): the in-app
  steps, the email route, what is deleted and kept, the 30 days. Enter that URL in Google Play Console › App content ›
  Data safety (and as the "delete account" URL of the listing) before submission.

### 5.31 Privacy: data export, consents, legal documents (migrations `20270115090000_privacy_enums`, `20270115100000_privacy`; D198) — [IMPLEMENTED, draft contract v1.66-social; not deployed, not device-tested]

CONVENTIONS §10.61, CP-040.

- **Migrations** with the usual `migrate` job: `notification_type` gains `DATA_EXPORT_READY`; tables `legal_documents`,
  `user_consents`, `data_exports`; column `pending_registrations.legal_consent`. No GRANT, no backfill.
- **Settings:** `DATA_EXPORT_MIN_INTERVAL_HOURS` (24), `DATA_EXPORT_LINK_DAYS` (7), `DATA_EXPORT_SWEEP_INTERVAL_SECONDS`
  (300; refused as 0 in production), `RATE_LIMIT_DATA_EXPORT_USER` (5/900), `RATE_LIMIT_DATA_EXPORT_DOWNLOAD_USER`
  (10/3600). The export needs object storage (`S3_*`, the export ZIP goes to `private/data-exports/` — like
  `private/recharge-agents/`, **never** public: keep the public-read rule limited to `media/`) and, for the ready
  notice by mail, real mail (PP-20). A bucket lifecycle rule deleting `private/data-exports/` objects older than 10
  days is a recommended backstop (the sweeper deletes them after the download or 7 days).
- **Order at launch (important):** ship the app version with the consent screen first. Then publish the first
  versions — until then no consent is required; from their effective time every signed-in call of an app that has
  not accepted answers 428 (an older app without the screen would be stuck):

  ```bash
  docker compose --profile jobs run --rm -v "$PWD/infra/deploy/site:/site:ro" migrate node dist/cli/legal-admin.js \
    publish terms --version 2026-11-01 --effective <YYYY-MM-DD> --file /site/terms.html \
    --summary-ar "<ملخص>" --summary-en "<summary>"
  docker compose --profile jobs run --rm -v "$PWD/infra/deploy/site:/site:ro" migrate node dist/cli/legal-admin.js \
    publish privacy --version 2026-11-01 --effective <YYYY-MM-DD> --file /site/privacy.html \
    --summary-ar "<ملخص>" --summary-en "<summary>"
  docker compose --profile jobs run --rm migrate node dist/cli/legal-admin.js list
  ```

  and set `infra/deploy/site/config.json` `documents.terms|privacy` = the same version and effective date. Each later
  change of the text: edit the page, publish a **new** version (never reuse one), update `config.json`. The page's
  SHA-256 is recorded, so publish exactly the file the site serves.
- **Emailed requests** (GDPR/CCPA "access" or "portability" by email): verify the sender owns the account (writes from
  its address and confirms), then `privacy-admin export <email> --reason "verified email request <date>"` (the person
  downloads in the app) or, if they cannot use the app, `… --save /tmp/exports` with `-v` a host folder (send by a
  secure channel, then delete). `privacy-admin exports [<user>]` lists jobs. Deletion requests: §5.30.
- **Website:** `privacy.html` and `terms.html` show the version/date from `config.json`; fill `euRepresentative` (an
  EU/UK Art. 27 representative), `hostingProvider` and `emailProvider` (empty → «سيُضاف قريباً»; `update.sh` warns).
  The draft banner stays until `legalReviewed` is true. Adding analytics or any cookie fails CI (`site` job) until a
  consent banner and a new policy version exist.

### 5.32 Family levels and price repriced (migration `20270113100000_family_levels_d200`; D200) — [IMPLEMENTED, draft contract v1.67-social; not deployed]

CONVENTIONS §10.21 (D200 amendment). Creating a family costs **1 000 000 coins** ($12.50; was 500) and the family
level ladder is level 2 at 4 000 000 points … level 10 at 24 000 000 000 — both code constants
(`families.constants.ts`), no setting. The migration only **raises** a family's stored level to what its points reach
on the new ladder (none in practice: every new threshold is above the old one) and never lowers one; from then on a
family's stored level is a floor (`max(stored, ladder)`), so families that levelled up under the old ladder keep
their level. No schema change, no GRANT, no backfill of points; idempotent (a second run changes nothing). Ship the
app with or after the API: the app reads the price and the ladder from `GET /families/config` and formats big values
compactly; an older app shows the new values from the server too (its level line may be cut at billions).

### 5.33 Recharge orders with escrow «طلبات الشحن» (migrations `20270118090000_recharge_orders_enums`, `20270118100000_recharge_orders`; D204) — [IMPLEMENTED, draft contract v1.69-social; not deployed, not device-tested]

CONVENTIONS §10.64. The buyer asks a recharge agent for coins inside the app; **the money is paid outside the app**
(Kabso never receives, holds or moves money — only coins, which are frozen from the agent's stock until the agent
confirms or the team decides a dispute).

- **Migrations** with the usual `migrate` job (§5), in order: the first adds the stock reasons `ORDER_HOLD` /
  `ORDER_RELEASE`, the coin reason `RECHARGE_ORDER` and the notification type `RECHARGE_ORDER_UPDATE`; the second
  the tables `recharge_orders`, `recharge_order_messages`, `recharge_exchange_rates`, the columns
  `notifications.recharge_order_id` / `recharge_order_event`, and widens the stock and coin ledger sign CHECKs. No
  GRANT (default privileges), no backfill; additive.
- **Config** (all optional; defaults = the owner's proposals): `RECHARGE_ORDERS_ENABLED=true` (false: 503, the app
  hides the entry; direct selling stays), `RECHARGE_ORDER_MIN_COINS=10000`, `RECHARGE_ORDER_MAX_COINS=1000000000`,
  `RECHARGE_ORDER_REQUEST_TTL_MINUTES=30`, `RECHARGE_ORDER_PAYMENT_TTL_MINUTES=60`,
  `RECHARGE_ORDER_DISPUTE_AFTER_MINUTES=15`, `RECHARGE_ORDER_SWEEP_INTERVAL_SECONDS=60` (0 is refused in production:
  the sweeper gives expired orders' frozen coins back), `RATE_LIMIT_RECHARGE_ORDER_USER=20/3600`,
  `RATE_LIMIT_RECHARGE_ORDER_ACTION_USER=600/3600`. The buyer's price uses `COIN_RETAIL_USD_PER_MILLION` (12.5).
- **Exchange rates** (OWNER / FINANCE): the panel «أسعار الصرف» (every change needs a reason, audited), or on the
  server `docker compose --profile jobs run --rm migrate node dist/cli/recharge-admin.js set-rate EG EGP 50.5
  --digits 2 --reason "…"` / `clear-rate EG --reason "…"` / `rates`. No rate = the country is priced in USD only.
- **Disputes:** the panel «نزاعات الشحن» (OWNER / SUPPORT / FINANCE read and write as «الإدارة»; OWNER / FINANCE decide
  with the authenticator code). CLI fallback: `recharge-admin disputes`, `recharge-admin resolve <order>
  credit-buyer|refund-agent --reason "…"`, `recharge-admin expire-orders`.
- **Storage:** the chat's pictures and transfer screenshots are private objects under `private/recharge-orders/`
  (same bucket, never public; `private, no-store`). They are kept with the order (evidence); there is no retention
  sweep yet (KNOWN_LIMITATIONS).
- **Store builds:** build the Play / App Store app with `--dart-define=KABSO_STORE_BUILD=true` — it hides «شحن عبر
  وكيل» (D150: off in store builds until legal confirms). Direct APKs (staging) show it when the server allows.
- **Check after deploy:** `GET /api/v1/me/recharge-agent` has `rules.orders.enabled: true`; the API log shows no
  «Recharge order sweep failed».

### 5.34 «افتح وكالة»: self-opened agencies and their probation (migrations `20270125090000_agency_open_enums`, `20270125090100_agency_open`; D206) — [IMPLEMENTED, draft contract v1.70-social; not deployed, not device-tested]

CONVENTIONS §10.65. The first migration only adds the five `AGENCY_*` notification types (a value added by `ALTER TYPE`
cannot be used in its own transaction); the second adds the agency's `name`, `origin` (existing rows: ADMIN), `status`
(existing rows: OPEN), the probation and closing columns, `agency_applications` and `notifications.agency_*` — no
backfill, no GRANT (default privileges). Settings (all with the owner's defaults, no secret):

| Setting | Default | Meaning |
| --- | --- | --- |
| `AGENCY_PROBATION_DAYS` | 7 | a self-opened agency's probation |
| `AGENCY_PROBATION_MIN_HOSTS` | 3 | activated hosts needed (joined + went live + received a gift, before the end) |
| `AGENCY_PROBATION_REMINDER_HOURS` | 24 | the owner's reminder before the end |
| `AGENCY_REOPEN_COOLDOWN_DAYS` | 30 | after a closing, before the person may open again (proposal) |
| `RATE_LIMIT_AGENCY_OPEN_USER` | 5/86400 | «افتح وكالة» attempts per user |

The probations are settled by the existing agency sweeper (`AGENCY_SWEEP_INTERVAL_SECONDS`, 3600 — refused at 0 in
production): it passes, reminds or closes; a closing at the next sweep after the end is decided by the state at the
end (a late sweep decides the same). By hand: `node dist/cli/economy-admin.js agency-probation-sweep`, and
`agency-probation-extend <invite code> <days> --note …`, `agency-close <invite code> --note …`, `agency-reopen <invite
code> --note …` (migration role, audited). The ID card and the selfie are stored under `private/agency-applications/`
in the media bucket (`private, no-store`; never public) — the bucket policy must keep `private/` unreadable, as for
the recharge agents (D185). Media uploads must be enabled (`MEDIA_UPLOADS_ENABLED`), or `openAgency` answers 503.
Ship the API before (or with) the app: an older app shows no «افتح وكالة» (no `openRule`) and ignores the new
notification types; an older API makes the new app hide the button.

### 5.35 Gift categories and the gift's files from the admin panel (migration `20270127090000_gift_categories`; D207) — [IMPLEMENTED, draft contract v1.46-live / v1.71-social; not deployed, not device-tested]

CONVENTIONS §10.66. The migration creates `gift_categories` (enum `gift_category_kind`), **seeds the five tabs** that
were the `gift_category` enum with the names the app showed (POPULAR شائعة / Popular 10, EVENT مناسبات / Events 20,
FUN مرح / Fun 30, LUCKY الحظ / Lucky 40, QUIPS إفيهات / Quips 50), turns `gifts.category` into a `VARCHAR(40)` foreign
key to it (`ON DELETE / UPDATE RESTRICT`; the three CHECKs that compared it with enum literals are dropped and
re-added with the same meaning) and drops the enum. Every existing gift keeps its category; it is one transaction,
re-run safe through Prisma's ledger, and was applied over a kl-int6 database holding POPULAR / LUCKY / FUN / QUIPS
gifts, a hosted SVGA and a PK booster (all kept; the hosted SVGA got `animation_format = SVGA`). It also adds
`gifts.animation_format` / `animation_alpha` (enums `gift_animation_format`, `gift_video_alpha`) and
`audio_object_key` / `audio_bytes` / `audio_ms`, and widens `gifts_animation_object_key_format` to `.svga|.mp4`
(CHECKs `gifts_animation_format_set`, `gifts_audio_set`). No new GRANT: the runtime role's default privileges cover the
new table (checked by the e2e suites running as `kabso_app_*`).

- **Order:** API (with the migration) first, then the admin build, then the app. An app before D207 keeps working: it
  reads `categories`, names the five seeded codes itself and drops gifts of categories it does not know (a new
  category is invisible to it); it would hand an MP4 to its SVGA player, which fails and shows nothing (the strip
  still shows the gift's picture), and ignores `audioUrl`.
- **Storage:** the panel's uploads use the API's media bucket like every other upload (`S3_*`, DEPLOYMENT §5.3), keys
  `media/gifts/<code>/<sha256 prefix>.png|webp|svga|mp4|mp3` and `media/gift-categories/<CODE>/…png|webp`, immutable,
  one year of cache. **Without `S3_BUCKET` / keys the upload answers 503** and the form says so («تخزين الملفات غير
  مُعدّ على الخادم»); without `MEDIA_PUBLIC_BASE_URL` the files are stored but the app gets null URLs. The server has
  no other storage (the app's own media use the same bucket, still gated by PP-28 / B12), so on a server without S3
  gifts cannot be created in the panel (the picture is required) — `gift-admin add` without `--image` still works.
- **Body size:** `POST /api/v1/admin/gift-uploads` takes the raw file (`application/octet-stream`, ≤ 26 MB, the SVGA
  limit); Caddy sets no body limit, so nothing to change there. The panel previews uploaded files from
  `GET /api/v1/admin/gift-files` (same origin), so the admin site's CSP is unchanged.
- **Permissions:** new capability `gifts.categories` (OWNER) for every category change; uploading gift files is
  `catalog.manage` (OWNER) as before; reading the categories is `catalog.view`.
- **CLI:** `gift-admin categories | category-add | category-update | category-enable | category-disable |
  category-delete [--move-to]`, `--animation-file <file.mp4> [--alpha none|side-by-side]`, `--sound-file <file.mp3>`
  (same S3 settings as `--image`, §5.7).
- **Rollback:** the migration is not reversible by Prisma; to go back, restore the database backup taken before the
  update (§7). Hosted MP4 / MP3 files and category icons stay in the bucket (only a storage cost).

### 5.37 «كن مضيفاً مع الإدارة»: applications to host directly with the team (migrations `20270202090000_host_applications_enums`, `20270202090100_host_applications`; D209) — [IMPLEMENTED, draft contract v1.73-social; not deployed, not device-tested]

CONVENTIONS §10.68. The first migration only adds the two `HOST_APPLICATION_*` notification types (a value added by
`ALTER TYPE` cannot be used in its own transaction); the second adds `host_application_status` and `host_applications`
(one PENDING per user: partial unique index `host_applications_one_pending`; CHECKs) — no backfill, no GRANT (default
privileges). Numbering: §5.35 / §5.36 are left to D207 / D208 (in progress on other branches). Settings (no secret):

| Setting | Default | Meaning |
| --- | --- | --- |
| `HOST_APPLICATION_MIN_AGE` | 18 | the applicant's minimum age on the day they apply (UTC); the server refuses a value below 18 |
| `HOST_APPLICATION_REAPPLY_DAYS` | 30 | after a rejection, before the person may apply again (0 = at once) |
| `RATE_LIMIT_HOST_APPLY_USER` | 5/86400 | «كن مضيفاً مع الإدارة» submissions per user (refused ones count) |

The team decides in the panel («طلبات المضيفين», capabilities `hosts.applications` / `.photos` / `.decide`) or with
`node dist/cli/host-admin.js applications [--status pending] | view <id> [--save <dir>] | approve <id> | reject <id>
--reason …` (migration role, audited `via: cli`; `--save` needs the `S3_*` settings). Approving writes the
`live_hosts` row with source `IDENTITY`. The ID card and the selfie are stored under `private/host-applications/` in the
media bucket (`private, no-store`; never public) — the bucket policy must keep `private/` unreadable (as D185 / D206).
Media uploads must be enabled (`MEDIA_UPLOADS_ENABLED`), or `applyForHosting` answers 503. Ship the API before (or
with) the app: the new app hides the card on an older API (404), an older app ignores the new notification types.
- Not verified on a device.

### 5.38 Live categories and the podcast live (migrations `20270205090000_podcast_mode_enum`, `20270205090100_podcast`; D212) — [IMPLEMENTED, draft contract v1.47-live; not deployed, not device-tested]

CONVENTIONS §10.69. Two migrations, in order: the first only adds `PODCAST` to `live_room_mode` (an enum value
cannot be used in the transaction that adds it); the second adds nullable / defaulted columns only — `live_rooms`
(`episode_number`, `podcast_topic`, `questions_open` default true, `question_seconds`; CHECK
`live_rooms_podcast_fields`; unique `live_rooms_host_episode_key`; `live_rooms_seat_count_mode` re-created with
`PODCAST` = 4), `live_room_seats.demote_at` (+ partial index), `live_seat_requests.question` / `deferred_at`,
`live_schedule_slots.mode` / `podcast_topic` (CHECK `live_schedule_slots_podcast_fields`, partial index). No new
table, so no GRANT; no backfill (existing rows satisfy every CHECK: their new columns are NULL / true). Checked on a
database migrated to `claude/kl-int6b` (`prisma migrate deploy`, then `prisma migrate diff` shows no drift on the
touched tables).

- **No new setting.** Timed questions are demoted by the live media reconciliation that already runs every
  `LIVE_SWEEP_INTERVAL_SECONDS` (15 s) when LiveKit is configured; a speaker's own app also leaves at the end.
- **Chat:** `join` lines are now limited to one per 200 ms per room (was 1 s): more lines on the data channel of a
  busy room (≤ 5 / s / room).
- **Rate limits:** the existing seat buckets (`RATE_LIMIT_LIVE_SEAT_*`): a raised hand is a seat request, «لاحقاً» a seat
  action. `GET /live/podcasts/scheduled` takes the guest-read bucket.
- **Themes:** `LiveConfig.themes` gains `podcast-studio`, `podcast-majlis`, `podcast-library` (art in the app). Older
  apps show an unknown theme as classic.
- **Order:** API first (an older app shows a PODCAST as a camera-less SOLO room and never sends the new fields); then
  the app. The admin panel's mode chips need the API's `mode` filter.

### 5.39 «دعوة الأصدقاء»: referral rewards in cherries (migrations `20270206090000_referrals_enums`, `20270206090100_referrals`; D217) — [IMPLEMENTED, draft contract v1.74-social; not deployed, not device-tested]

CONVENTIONS §10.71. The first migration only adds enum values — `REFERRAL_REWARD` and `REFERRAL_REVERSAL` to
`cherry_ledger_reason`, `REFERRAL_REWARD_REVERSED` to `notification_type` (an enum value cannot be used in the
transaction that adds it); the second extends the cherry ledger's sign rule in place (read from the catalogue;
`REFERRAL_REWARD` > 0, `REFERRAL_REVERSAL` < 0), adds nullable `sessions.install_id` (+ partial index), `pending_registrations.install_id` /
`referral_code`, and the tables `referral_settings` (one row, inserted with the defaults), `referral_codes`,
`referrals`, `referral_rewards` (CHECKs, partial unique indexes). No backfill, no GRANT (default privileges). Checked
on a database migrated to `claude/kl-int7` (`prisma migrate deploy`, then `prisma migrate diff` shows no drift on the
touched tables).

| Setting | Default | Meaning |
| --- | --- | --- |
| `REFERRAL_SWEEP_INTERVAL_SECONDS` | 300 | how often held referrals / rewards are settled (0 refused in production) |
| `RATE_LIMIT_REFERRAL_APPLY_USER` | 10/86400 | a code entered later, per user (refused attempts count) |
| `RATE_LIMIT_REFERRAL_TICKER_IP` | 60/600 | the public ticker, per client IP |

Every amount lives in `referral_settings` and is changed in the panel («إعدادات الدعوات», `referrals.settings`: OWNER,
FINANCE, the authenticator code again) or `node dist/cli/referral-admin.js settings --set key=value --reason …`
(migration role, audited `via: cli`); the defaults are listed in KNOWN_LIMITATIONS for the owner to confirm. **The
programme is on after the migration.** The website's Caddyfile gains `rewrite /i/* /invite.html` (the invite link
page, `infra/deploy/site/invite.html` + `assets/invite.js`). Order: API (migrations) and Caddy/site first, then the
app; an older app sends no install id, shows `REFERRAL_REWARD` / `REFERRAL_REVERSAL` in the history as «أخرى» and
ignores the `REFERRAL_REWARD_REVERSED` notification (the push text still reaches it). Voiding a referral after its
cherries were credited takes them back at once (owner 2026-11-01); a cherry balance may then be below 0 (a debt that
blocks withdrawals), as after a gift reversal.
- Not verified on a device or a server.

### 5.40 Media storage from the admin panel «التخزين (R2 / S3)» (migration `20270208090000_storage_settings`; D222) — [IMPLEMENTED, draft contract v1.75-social; not deployed; no real R2 call made]

CONVENTIONS §10.72. Additive: one new table (`storage_settings`, one row at most); DML for the runtime role comes from
the default privileges (no GRANT); no backfill. Without a row, or with the switch off, the server's `S3_*` /
`MEDIA_PUBLIC_BASE_URL` / `MEDIA_UPLOADS_ENABLED` apply exactly as in §5.3, so existing deployments and CI are
unchanged. Needs the admin panel on (D191: `ADMIN_TOTP_KEY` set, the OWNER enrolled): the keys are sealed with a key
derived from it — **a new `ADMIN_TOTP_KEY` makes them unreadable** (the panel says so and the env applies): enter them
again. Nothing to set on the server for R2 itself.

**Layout with the panel's storage:** two buckets. The PUBLIC one holds only `media/` (processed images, videos and
posters, voice clips, gift art, banners) and is served from the public base URL; the PRIVATE one holds `uploads/`
(raw client uploads, minutes) and `private/` (ID photos and selfies, recharge-order pictures, data exports) and is
**never** public — the API reads it with the key and serves those files only to who may see them. **CORS:** none
needed (the app uploads with the presigned URL directly and is not a browser; the panel's uploads go through the
API). If a browser client ever uploads with presigned PUTs, add to the PRIVATE bucket (R2 → bucket → Settings → CORS
policy) a rule allowing `PUT` from that origin with header `Content-Type`, e.g.
`[{"AllowedOrigins":["https://app.kabsolive.com"],"AllowedMethods":["PUT"],"AllowedHeaders":["Content-Type"],"MaxAgeSeconds":3600}]`.
**Lifecycle (recommended, private bucket):** delete `uploads/` older than 2 days and `private/data-exports/` older than
10 days (R2 → bucket → Settings → Object lifecycle rules), as §5.3 / §5.31.

#### The owner's steps — بالعربية

1. **الحساب:** ادخل إلى dash.cloudflare.com وأنشئ حساباً (أو استخدم حساب نطاق kabsolive.com إن كان على Cloudflare).
2. **تفعيل R2:** من القائمة الجانبية «R2 Object Storage» ← «Purchase R2 Plan» / «Enable». يطلب وسيلة دفع؛ أول 10 GB
   تخزين شهرياً مجانية ولا رسوم على التنزيل (egress).
3. **الحاويتان:** «Create bucket» مرتين: `kabso-media` (العامة) و`kabso-private` (الخاصة). Location: «Automatic» واترك
   «Jurisdiction» على الافتراضي (إن اخترت EU فنقطة الاتصال تصبح `https://<account>.eu.r2.cloudflarestorage.com`:
   اختر حينها في اللوحة «S3 متوافق» وأدخلها مع المنطقة `auto`).
4. **الوصول العام للحاوية العامة فقط:** افتح `kabso-media` ← Settings ← «Public access»:
   - للإنتاج: «Custom Domains» ← «Connect Domain» ← `media.kabsolive.com` (النطاق يجب أن يكون على Cloudflare) ← انتظر
     حتى تصبح الحالة «Active». الرابط العام = `https://media.kabsolive.com`.
   - للتجربة فقط: «R2.dev subdomain» ← «Allow» ← انسخ الرابط `https://pub-….r2.dev` (محدود السرعة؛ لا يُعتمد للإنتاج).
   - **لا تفعّل أي وصول عام لـ `kabso-private`** (لا r2.dev ولا نطاق).
5. **مفتاح API:** صفحة R2 ← «Manage API tokens» (أو «API Tokens») ← «Create API token» (Account API token):
   - Permissions: **Object Read & Write**.
   - Specify bucket(s): **Apply to specific buckets only** ← اختر `kabso-media` و`kabso-private` فقط.
   - TTL: Forever (أو مدة تجددها لاحقاً) ← «Create API Token».
   - انسخ فوراً **Access Key ID** و**Secret Access Key** (السر يظهر مرة واحدة فقط). لا ترسلهما في محادثة أو بريد.
6. **معرّف الحساب:** في صفحة R2 الرئيسية، يمين الشاشة «Account Details» ← **Account ID** (32 حرفاً). انسخه.
7. **CORS:** لا حاجة لأي قاعدة (التطبيق ليس متصفحاً ولوحة الإدارة ترفع عبر الخادم).
8. **في لوحة الإدارة:** ادخل `https://admin.kabsolive.com` ← «التخزين (R2 / S3)»:
   - المزوّد: Cloudflare R2؛ معرّف الحساب؛ معرّف المفتاح والمفتاح السري؛ الحاوية العامة `kabso-media` ورابطها العام
     (`https://media.kabsolive.com` أو رابط r2.dev)؛ الحاوية الخاصة `kabso-private`.
   - اضغط **«اختبار الاتصال»**: يجب أن تظهر كل الخطوات العشر «تم» (رفع ملف صغير في `_healthcheck/`، التحقق منه، قراءته،
     قراءته من الرابط العام للحاوية العامة، التأكد أن ملف الحاوية الخاصة غير مكشوف، حذفه). إن فشلت خطوة يظهر السبب
     بالعربية (مفتاح خاطئ، صلاحية ناقصة، حاوية غير موجودة، الرابط العام لا يعرض الحاوية…).
   - «حفظ الإعدادات» ← السبب + رمز تطبيق المصادقة. ثم مفتاح **«تفعيل»** ← السبب + رمز جديد: يُعاد الاختبار ثم يبدأ الرفع
     فوراً دون إعادة تشغيل الخادم. الحالة تصبح «مفعّل».
9. **التأكد:** من التطبيق ارفع صورة منشور: يجب أن تظهر، ورابطها يبدأ بالرابط العام.

#### The owner's steps — English

1. Create a Cloudflare account (or use the one holding kabsolive.com). 2. Enable **R2 Object Storage** (a payment
method is asked; 10 GB-month free, no egress fees). 3. Create two buckets, `kabso-media` (public) and `kabso-private`
(private); location Automatic, default jurisdiction (an EU jurisdiction has the endpoint
`https://<account>.eu.r2.cloudflarestorage.com`: then choose «S3-compatible» in the panel with that endpoint and region
`auto`). 4. **Public bucket only:** Settings → Public access → Custom Domains → Connect `media.kabsolive.com`
(production), or R2.dev subdomain → Allow (testing only; rate-limited). Never public access on `kabso-private`.
5. R2 → Manage API tokens → Create API token: **Object Read & Write**, **specific buckets only** (the two), copy the
Access Key ID and the Secret Access Key (shown once). 6. Copy the **Account ID** (R2 overview → Account Details).
7. No CORS rule is needed. 8. Admin panel → «التخزين (R2 / S3)»: provider Cloudflare R2, account id, the two keys, the
public bucket and its public URL, the private bucket → **«اختبار الاتصال»** (all ten steps «تم») → «حفظ الإعدادات»
(reason + code) → **«تفعيل»** (reason + a fresh code; tested again; uploads work at once, no restart). 9. Upload a post
picture from the app and open its URL.

**Rotating the token:** create the new token, paste only the new key id and secret, test, save (while on, the save
tests first). **Turning off:** «تفعيل» off (code + reason): the env storage applies if the server has one, otherwise
every upload is 503 «التخزين غير مفعّل»; stored files are not touched. **Removing:** «إزالة إعدادات اللوحة».
**Changing a bucket** does not move the objects already stored: existing URLs point at the old public base (see
KNOWN_LIMITATIONS); choose the buckets and the domain once.

**Not covered by the panel (env only):** the CLIs that touch files — `gift-admin` (`--image` …), `banner-admin`,
`profile-admin`, `host-admin`, `recharge-admin`, `account-admin`, `privacy-admin` — still build their storage from the
env `S3_*` (one bucket) and `MEDIA_PUBLIC_BASE_URL`. With the storage only in the panel, run them with the same values
as env (and the private bucket's objects are not reachable through them), or use the panel's own sections (gifts and
their files D207, users, applications).

### 5.41 The social redesign: home feed `tab=mixed`, the profile cover (migrations `20270209090000_profile_cover_enums`, `20270209090100_profile_cover`; D218) — [IMPLEMENTED, draft contract v1.76-social; not deployed, not device-tested]

CONVENTIONS §10.73. (§5.39 and §5.40 are D217's and D222's, on their own branches.) Two migrations, in order: the
first only adds `COVER_REMOVED` to `notification_type` (an enum value cannot be used in the transaction that adds
it); the second adds nullable `user_profiles.cover_media_id` (unique, FK to `media_assets` NO ACTION) and
`cover_url`, the CHECK `user_profiles_cover_media_has_url` (both null or both set) and re-creates
`media_assets_kind_known` with `PROFILE_COVER`. No new table, so no GRANT; no backfill (every existing row has both
null). Checked on a database migrated to `claude/kl-int7` + this branch (`prisma migrate deploy` from the e2e global
setup; `prisma migrate diff` shows no drift on the touched tables).

- **No new setting.** `PUT` / `DELETE /me/cover` reuse `RATE_LIMIT_AVATAR_USER` in their own bucket (`me:cover`).
  The mixed feed reuses Trending's snapshot (Redis, 10 minutes, ≤ 1 000 entries per caller) and the `social:feed`
  rate limit.
- **Uploads:** covers are object-storage uploads like the photo: with uploads off `PUT /me/cover` answers 503 and the
  app says so; removing still works.
- **Moderation:** the panel's «حذف صورة الغلاف» (user page, capability `users.avatar`) or
  `docker compose --profile jobs run --rm -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID
  -e S3_SECRET_ACCESS_KEY -e S3_FORCE_PATH_STYLE migrate node dist/cli/profile-admin.js remove-cover <username>
  --reason <text>`.
- **Order:** API first (an older app ignores `tab=mixed`, `viewerFollowsAuthor`, `coverUrl`, `country`,
  `joinedMonth`, `blockedByMe` and the `COVER_REMOVED` notification); then the app — the new app needs the API's
  `tab=mixed` (an older API answers 400 and the posts page shows its error state); the admin panel's cover button
  needs `removeAdminUserCover`.
- Not verified on a device or a server (the cover upload against R2, the mixed feed on production data).


### 5.42 The person card's lifetime totals and their privacy switches (migration `20270212090000_profile_stats_privacy`; D220) — [IMPLEMENTED, draft contract v1.77-social; not deployed, not device-tested]

CONVENTIONS §10.74. (§5.39–§5.41 are D217's, D222's and D218's, on their own branches.) One migration: two
`privacy_settings` columns, `hide_cherries_received` and `hide_coins_sent`, `BOOLEAN NOT NULL DEFAULT false`. No new
table, so no GRANT; constant defaults, so no table rewrite and no backfill (a user without a row reads both as
false).

- **No new setting, no new job.** The totals are summed per `GET /users/{username}` through existing indexes
  (`cherry_ledger_user_reason_idx`, `live_gifts_sender_room_idx`); the request already has its own rate limit
  (`users:profile`). Two indexed aggregate reads per profile view; watch `GET /users/{username}` latency for very
  heavy senders after deploy.
- **Order:** API first. An older app ignores the new fields and the new privacy keys; the new app treats a missing
  total as hidden (an older API shows the card with two numbers) and shows the two switches only when the server
  sends them. The admin panel's two numbers need this API.
- Not verified on a device or a server.

### 5.43 At most 2 accounts created per device (migration `20270211090000_device_signups`; D223) — [IMPLEMENTED, draft contract v1.78-social; not deployed, not device-tested]

CONVENTIONS §10.75. The migration adds nullable `pending_registrations.device_hash` and the tables `device_signups`
(one row per account created with a device key: the server's HMAC of the app's key, the platform, the time; FK to
`users` ON DELETE CASCADE — a purged account keeps its tombstone row, so its device row stays) and
`device_signup_exceptions` (an OWNER's per-device limit, with the reason and who granted it). CHECKs on the hash shape
and `max_accounts` 1–100. No backfill (accounts made before have no device and never count), no GRANT (default
privileges). Checked on a database migrated from `claude/kl-217-invite-friends` (`prisma migrate deploy`, then
`prisma migrate diff` shows no drift on the touched tables).

| Setting | Default | Meaning |
| --- | --- | --- |
| `SIGNUP_MAX_ACCOUNTS_PER_DEVICE` | 2 | accounts one device may create, deleted ones included (1–100); an OWNER may raise it per device in the panel |
| `SIGNUP_DEVICE_KEY` | unset | optional source of the HMAC key the device keys are stored under (≥ 32 bytes; in production a strong value different from the other secrets); unset → derived from `RATE_LIMIT_KEY_SECRET` (label `signup-device/v1`) |

**Changing `SIGNUP_DEVICE_KEY`, or `RATE_LIMIT_KEY_SECRET` while it is unset, makes every device start again from 0
accounts** — set it once before the release if a dedicated key is wanted, and keep it. Signing in is never limited. The
app needs the new build (the `com.kabso/device_id` channel in `MainActivity.kt` / `AppDelegate.swift`, no new
package): an older app, the website and any client that sends no `device.deviceKey` are not counted. Order: API first
(an older server rejects the unknown `deviceKey` field as `unknown_field` — **ship the API before the app**), then the
app. The panel's user page gains the tab «الجهاز» (`users.device_view`: OWNER, SUPPORT; the exception:
`users.device_exception`, OWNER, the authenticator code again).
- Not verified on a device or a server (ANDROID_ID across reinstalls, the iOS Keychain across reinstalls, the panel
  on a server).

### 5.44 Identity verification with Didit «التحقق من الهوية (Didit)» (migrations `20270214090000_kyc_enums`, `20270214090100_kyc_checks`; D227) — [IMPLEMENTED, draft contract v1.80-kyc; not deployed; no real Didit call made, not device-tested]

CONVENTIONS §10.77. Additive: three new notification values (their own migration), the tables `kyc_settings` (one row
at most), `kyc_checks`, `kyc_webhook_events`; DML for the runtime role from the default privileges (no GRANT); no
backfill. The second migration also **relaxes** `recharge_agent_applications_shape` (the two picture keys may now be
missing — both or neither) so a recharge application can be made with Didit on. Without a row, or with the switch
off, nothing changes: the applications keep the manual ID card + selfie (§5.33, §5.34, §5.37). Needs the admin panel on
(D191: `ADMIN_TOTP_KEY` set, the OWNER enrolled): the Didit API key and webhook secret are sealed with a key derived
from it, and the document numbers are hashed with another key derived from it — **a new `ADMIN_TOTP_KEY` makes the
saved secrets unreadable (enter them again) and makes old document hashes no longer match new ones (the duplicate
flag only sees checks made after the change).** The Didit keys are never server settings.

| Setting | Default | Meaning |
| --- | --- | --- |
| `API_PUBLIC_URL` | `https://api.kabsolive.com` | only shown in the panel: the webhook address is `<API_PUBLIC_URL>/api/v1/kyc/didit/webhook` (set it on staging) |
| `RATE_LIMIT_KYC_START_USER` | `20/86400` | session starts per user (the OWNER's daily limit in the panel is separate, default 3) |
| `RATE_LIMIT_KYC_SYNC_USER` | `60/3600` | «sync» reads of a decision per user |

Caddy: nothing to add — `api.kabsolive.com` already proxies `/api/v1/*`; the webhook path is public (no auth) and
verified by its signature. Order: API (with the migrations) first, then the panel, then the app (an older app sends
the ID pictures and keeps working while Didit is off; with Didit on, an older app's form still sends pictures, which
are ignored, and it cannot run «تأكيد الهوية» — release the app before turning Didit on).

#### The owner's steps — بالعربية

1. **إنشاء الحساب:** ادخل إلى `https://business.didit.me` وأنشئ حساباً (بريد العمل)، ثم أنشئ المؤسسة (Organization)
   والتطبيق (Application) باسم «Kabso Live». أول 500 تحقق شهرياً مجانية، وبعدها نحو 0.33 دولار للتحقق الكامل.
2. **إنشاء سير العمل (Workflow):** من القائمة «Workflows» ← «Create workflow» ← اختر نوع KYC وفعّل:
   - **ID Verification** (وثيقة الهوية: بطاقة/جواز/رخصة)،
   - **Liveness** واختر **Passive** (التحقق من أن الشخص حقيقي دون حركات)،
   - **Face Match** (مطابقة الوجه مع صورة الوثيقة 1:1).
   - لا تضف AML أو غيره إلا إذا أردت (كل ميزة تضيف تكلفة). اضبط الحد الأدنى للعمر إن وُجد على 18.
   - احفظ ثم **انشر (Publish)** سير العمل، وانسخ **Workflow ID** (معرّف بصيغة UUID مثل `xxxxxxxx-xxxx-…`).
   - (اختياري) يمكنك إنشاء سير عمل مختلف لكل طلب (مضيف / وكالة / وكيل شحن)؛ إن استخدمت سيراً واحداً للجميع فتحقق
     واحد مقبول يكفي الشخص للطلبات الثلاثة.
3. **المفتاح وسر الـ Webhook:** «Settings» ← «API & Webhooks»:
   - انسخ **API Key** (يُرسل في كل طلب من الخادم؛ لا تضعه في التطبيق ولا ترسله في محادثة).
   - في خانة **Webhook URL** ضع: `https://api.kabsolive.com/api/v1/kyc/didit/webhook`
     (للتجربة على خادم الاختبار استخدم العنوان الذي تعرضه لوحة الإدارة في قسم Didit).
   - اترك إصدار الـ Webhook على الافتراضي (v3) واحفظ، ثم انسخ **Webhook Secret Key**.
4. **مدة الاحتفاظ بالبيانات لدى Didit:** «App Settings» ← «Data» ← اختر مدة (ننصح بـ **سنة واحدة**: نحتاج الصور مدة
   مراجعة الطلبات والنزاعات فقط) ← Save. لا تفعّل «Retain biometric template» إلا إذا قررت ذلك صراحة.
5. **في لوحة الإدارة:** ادخل `https://admin.kabsolive.com` ← «التحقق من الهوية (Didit)»:
   - الصق **مفتاح API** و**سر الـ Webhook** و**معرّف سير العمل الافتراضي** (والمعرّفات الخاصة بكل طلب إن وُجدت)، واختر
     «عدد الجلسات في اليوم لكل شخص» (الافتراضي 3).
   - اضغط **«اختبار الاتصال»**: يجب أن يظهر «المفتاح يعمل» وكل سير عمل «منشور». إن ظهر «مفتاح خاطئ» أو «سير العمل غير
     موجود/غير منشور» فصحّح ثم أعد الاختبار.
   - «حفظ» ← السبب + رمز تطبيق المصادقة. ثم مفتاح **«تفعيل»** ← السبب + رمز جديد: يُعاد الاختبار ويبدأ العمل فوراً.
   - المفاتيح لا تظهر بعد الحفظ إطلاقاً (آخر 4 أحرف فقط)، وكل تغيير مسجّل في سجل التدقيق.
6. **التجربة:** من التطبيق: «الوكالة» ← «كن مضيفاً مع الإدارة» ← خطوة «تأكيد الهوية» ← «ابدأ التحقق»: صوّر الوثيقة
   ثم وجهك. بعد الانتهاء تظهر الحالة (مقبول / قيد المراجعة / مرفوض مع السبب) ويصلك إشعار. في لوحة الإدارة افتح الطلب:
   يظهر قسم «التحقق من الهوية» بالحالة والاسم وتاريخ الميلاد ودولة الوثيقة، وزر «عرض الصور» (روابط مؤقتة من Didit) أو
   رقم الجلسة للبحث عنه في لوحة Didit. لا يمكن قبول طلب المضيف أو تفعيل وكيل الشحن أو فتح وكالة قبل تحقق مقبول.
7. **إيقاف مؤقت:** مفتاح «تفعيل» إلى إيقاف: تعود الطلبات إلى رفع صورة الهوية والسيلفي يدوياً كما كانت.

#### The owner's steps — English

1. Create an account at `https://business.didit.me`, then the organization and an application «Kabso Live» (500 free
   checks a month, then about $0.33 a full check). 2. **Workflows → Create workflow** (KYC): **ID Verification**,
   **Liveness — Passive**, **Face Match**; nothing else unless wanted (each feature costs); minimum age 18 if offered;
   save, **Publish**, copy the **Workflow ID** (a UUID). Optionally one workflow per application; with one workflow for
   all, one approved check serves the three applications. 3. **Settings → API & Webhooks:** copy the **API Key**; set
   **Webhook URL** to `https://api.kabsolive.com/api/v1/kyc/didit/webhook` (staging: the address the panel shows);
   keep the webhook version (v3); save; copy the **Webhook Secret Key**. Never put the key in the app or in a chat.
   4. **App Settings → Data:** a retention window (we suggest **1 year**); leave «Retain biometric template» off unless
   decided. 5. **Admin panel → «التحقق من الهوية (Didit)»:** paste the API key, the webhook secret, the default
   workflow id (and per-application ones if any), the sessions per person per day (default 3); **«اختبار الاتصال»**
   (the key works, each workflow published); **Save** (reason + authenticator code); then **«تفعيل»** (reason + a new
   code; the test runs again). Saved secrets are never shown again (last 4 only); every change is audited. 6. **Test:**
   in the app, «الوكالة» → «كن مضيفاً مع الإدارة» → «تأكيد الهوية» → document, then face; the result shows in the app
   with a notification and in the application's page in the panel (state, name, birth date, document country,
   «عرض الصور» = Didit's short-lived links, the session number for Didit's console). A host application cannot be
   approved, a recharge agent cannot be activated (first top-up) and an agency cannot be opened without an approved
   check. 7. Switching «تفعيل» off brings back the manual ID card + selfie.

- **Privacy:** add Didit to the published privacy policy with `legal-admin publish privacy` when the text in
  `infra/deploy/site/privacy.html` (Didit added as a processor, AR + EN, this change) is reviewed — the version was
  NOT bumped (PP-40).
- Not verified: a real Didit account, key, workflow or webhook delivery (Didit was faked in every test); the hosted
  flow inside the Android / iOS WebView with a real camera; the exact wording of Didit's console menus (taken from
  docs.didit.me on 2026-11-01).

### 5.45 «PK أحكام»: dares after a PK, the dare library and PK points (migration `20270216090000_pk_dares`; D229) — [IMPLEMENTED, draft contract v1.50-live; not deployed, not device-tested]

CONVENTIONS §10.80. The migration adds the type `pk_type` (and the columns `type` on `pk_matches`, `pk_invites`,
`pk_queue`, default NORMAL — existing rows are normal PKs), `points` / `dares_done` / `dares_refused` on
`pk_host_records` (0), the tables `pk_dares` (the library), `pk_match_dares`, `pk_dare_reports`, `pk_dare_seen`,
`pk_point_events` and the one-row `pk_dare_settings` (inserted with the owner's defaults: win +3, draw +1, loss 0,
refused −3, 30 s to decide, 5 reports). CHECKs on the shapes. No GRANT (default privileges). Checked on a fresh
database (`prisma migrate deploy`, then `prisma migrate diff` shows no drift on the touched tables). **The library is
not in the migration** (20 000 rows): after the migration run once

```
docker compose --profile jobs run --rm migrate node dist/cli/pk-dares-admin.js import
docker compose --profile jobs run --rm migrate node dist/cli/pk-dares-admin.js stats
```

(the migration role; the default file `prisma/seed/pk-dares/pk-dares.v1.jsonl` is in the image under
`apps/api/prisma`). It is idempotent by `code`: a second run inserts nothing, a later seed version adds only its new
codes and never overwrites the team's edits. Expect `received 20000, inserted 20000, rejected 0` the first time (it took
15 s on the test machine). Without the import there is no active dare: a DARES match then ends with no dare (logged).

| Setting | Default | Meaning |
| --- | --- | --- |
| `PK_DARES_ENABLED` | true | «PK أحكام» invitations and random waits (off: 409 `PK_UNAVAILABLE`; running dares finish) |
| `PK_DARE_DRAW_SECONDS` | 4 | the cards' shuffle before the drawn dare is revealed (1–30) |
| `PK_DARE_SECONDS` | 180 | the dare's timer after the loser accepts (owner: 3 minutes; 10–600) |
| `PK_DARE_OUTCOME_SECONDS` | 8 | how long «نُفّذ الحكم» / «رفض الحكم» stays before the PK closes (0–120) |
| `RATE_LIMIT_LIVE_PK_DARE_REPORT_USER` | 10/600 | dare reports per user |
| `PK_REMATCH_ACCEPT_SECONDS` | 15 | D242 «جولة أخرى»: how long the other host has to accept a rematch offer (5–120) |
| `PK_REMATCH_MAX` | 5 | D242: rematches in a row with the same opponent; 0 = unlimited (0–100) |

The points, the loser's decision time and the auto-disable threshold are in the panel «أحكام PK» (`pk_dares.edit`:
OWNER, MODERATION; audited). Order: API (migration + import) first, then the admin panel, then the app; an older app
sends no `type` (NORMAL), shows a DARES invitation as a normal one and ignores `PkMatch.dare` (its host is never
offered a dare's buttons, so a dare drawn against it times out as refused after 30 s — ship the app before announcing
«PK أحكام»).
- Not verified on a device or a server (the draw animation on a phone, the second-room dare banner on real LiveKit).

### 5.46 Automatic exchange rates for every country (migration `20270225090000_fx_rates`; D245) — [IMPLEMENTED, draft contract v1.81-social; not deployed; no real provider call made from the tests (local stub)]

CONVENTIONS §10.87. Additive: two new tables (`fx_rates`, `fx_settings` — one row at most); DML for the runtime role
from the default privileges (no GRANT); no backfill. Once deployed, the API fetches the free feed within a minute of
starting and then hourly; every country's recharge price shows the local amount automatically. The manual rates
already set in «أسعار الصرف» (D204) keep winning («يدوي»). The paid key is sealed with a key derived from
`ADMIN_TOTP_KEY` (the panel must be on, D191) — **a new `ADMIN_TOTP_KEY` makes a saved paid key unreadable: the
server falls back to the free feed and the panel says so; enter the key again.** No key is ever a server setting.

**Network (VPS):** the API container needs **outbound HTTPS (TCP 443)** to `open.er-api.com`, and with a paid provider
to `api.currencyapi.com` or `v6.exchangerate-api.com`. Docker's default bridge allows it; a firewall with an egress
allow-list must list these hosts. Without it: «آخر خطأ: unreachable» in the panel, manual rates still work, the other
countries show USD only. Check from the VPS: `docker compose exec api node -e "fetch('https://open.er-api.com/v6/latest/USD').then(r=>console.log(r.status))"` → `200`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `FX_FREE_INTERVAL_SECONDS` | `3600` (min 600) | how often the free feed is read (its data changes once a day; do not lower much — its terms) |
| `FX_PAID_INTERVAL_SECONDS` | `60` (min 60) | how often the paid provider is read while it is on (match your plan's quota: 60 s ≈ 44 000 requests a month) |
| `FX_POLL_TICK_SECONDS` | `30` (0 = off) | how often each API instance checks whether a fetch is due (0: no automatic rates, manual only) |
| `FX_STALE_AFTER_HOURS` | `48` | an automatic rate older than this is not used (USD only) |
| `FX_MAX_JUMP_PERCENT` | `50` | a value moving more than this from the last good one is held for review in the panel |
| `FX_FETCH_TIMEOUT_MS` | `10000` | per request |
| `FX_FREE_URL`, `FX_CURRENCYAPI_BASE_URL`, `FX_EXCHANGERATE_API_BASE_URL` | the providers' | change only for a proxy; https in production |

Order: API (with the migration) first, then the panel. The app needs no change (it shows `price.local` as before).

#### The owner's steps — بالعربية

**الآن (مجاناً، لا شيء مطلوب):** بعد النشر تُجلب الأسعار تلقائياً كل ساعة من مصدر مجاني (ExchangeRate-API، يتحدّث
مرة في اليوم) لكل الدول. افتح لوحة الإدارة ← «أسعار الصرف»: بطاقة «الحالة» تعرض المصدر و«آخر تحديث» و«التحديث القادم»
وأي خطأ. أي بلد تضع له سعراً يدوياً يبقى على سعرك («يدوي») حتى تضغط «إعادة إلى التلقائي». إذا ظهر «سعر معلّق للمراجعة»
(قفزة أكبر من 50%) فراجعه واضغط «قبول السعر الجديد» إن كان صحيحاً. تأكد أن الخادم يسمح بالاتصال الخارجي HTTPS (انظر أعلاه).

**لاحقاً (تحديث كل دقيقة، مدفوع):**
1. اختر مزوّداً: **currencyapi.com** (المقترح: تحديث كل 60 ثانية في الخطط المدفوعة) أو **ExchangeRate-API**. اختر خطة
   فيها «تحديث كل دقيقة» وعدد طلبات شهرية لا يقل عن نحو **45 000** (طلب كل دقيقة). إن كانت خطتك تحدّث كل 5 دقائق مثلاً
   فاطلب من الفريق ضبط `FX_PAID_INTERVAL_SECONDS=300` حتى لا تُستهلك الطلبات بلا فائدة.
2. أنشئ الحساب: currencyapi ← `https://app.currencyapi.com/register` ثم من لوحة التحكم انسخ **API Key**.
   (ExchangeRate-API ← `https://app.exchangerate-api.com/sign-up` ثم انسخ المفتاح من «Dashboard».)
3. في لوحة الإدارة ← «مزوّد أسعار الصرف» (للمالك فقط): اختر المزوّد، الصق المفتاح، اضغط **«اختبار الاتصال»** — يجب أن
   يظهر «نجح» وعدد العملات. ثم فعّل «تفعيل» ← السبب + رمز تطبيق المصادقة ← حفظ. يبدأ الجلب كل دقيقة فوراً.
4. المفتاح لا يظهر بعد الحفظ إطلاقاً (آخر 4 أحرف فقط)، ويُحفظ مشفّراً، وكل تغيير مسجّل في سجل التدقيق. لا ترسل المفتاح
   في محادثة ولا تضعه في ملفات الخادم.
5. للإيقاف: «تفعيل» إلى إيقاف أو «إزالة المفتاح» (رمز + سبب): يعود النظام إلى المصدر المجاني كل ساعة.

#### The owner's steps — English

**Now (free, nothing to do):** after deployment the rates of every country are fetched hourly from a free source
(ExchangeRate-API open access, data updated once a day). Panel → «أسعار الصرف»: the status card shows the source, the
last update, the next fetch and any error. A country you set by hand stays on your rate («يدوي») until «إعادة إلى
التلقائي». A «held for review» value (a jump over 50 %) waits for «قبول السعر الجديد». Make sure the server allows
outbound HTTPS (above).

**Later (every minute, paid):** 1. Choose **currencyapi.com** (suggested: 60-second updates on its paid plans) or
**ExchangeRate-API**; pick a plan with minute updates and at least ~45 000 requests a month (one a minute). If the
plan updates every 5 minutes, have `FX_PAID_INTERVAL_SECONDS=300` set so requests are not wasted. 2. Sign up
(`https://app.currencyapi.com/register`, or `https://app.exchangerate-api.com/sign-up`) and copy the API key from the
dashboard. 3. Panel → «مزوّد أسعار الصرف» (OWNER only): choose the provider, paste the key, **«اختبار الاتصال»** (must
show success and the number of currencies), then switch «تفعيل» on → reason + authenticator code → save; the minute
polling starts at once. 4. The key is never shown again (last 4 only), stored encrypted, every change audited; never
send it in chat or put it in server files. 5. To stop: switch off or «إزالة المفتاح» (code + reason) → the free feed
hourly again.

### 5.47 «بث ستريمر»: the streamer live (migrations `20270301090000_streamer_mode_enum`, `20270301090100_streamer`; D213) — [IMPLEMENTED, draft contract v1.56-live; not deployed; the Android build NOT run, screen capture NOT tested on a device]

CONVENTIONS §10.86. Two migrations, in order: the first only adds `STREAMER` to `live_room_mode`; the second adds
nullable / defaulted columns only — `live_rooms.streamer_orientation`, `streamer_camera_visible`,
`streamer_camera_corner` (CHECK `live_rooms_streamer_fields`: all three set for a STREAMER, all NULL otherwise) and
`streamer_version` (default 0) — and re-creates `live_rooms_seat_count_mode` with `STREAMER` (no seats). No new
table, so no GRANT; no backfill (existing rows are not STREAMER: their new columns are NULL / 0). Checked on a fresh
test database (`prisma migrate deploy` from zero; `prisma migrate diff` shows no drift on `live_rooms`).

- **LiveKit:** the STREAMER host's token grants `camera`, `microphone`, `screen_share` and `screen_share_audio`
  (no server setting). A 720p30 screen at ~2.5 Mbps uplink plus the camera bubble: more egress per streamer than a
  solo live (budget it in LiveKit Cloud's plan).
- **Rate limit:** `PUT /live/rooms/{id}/streamer` uses its own bucket `live:streamer` with the existing
  `RATE_LIMIT_LIVE_TAPS_USER` rule (default 120 / 60 s per user). No new variable.
- **Android app:** the manifest adds `FOREGROUND_SERVICE_MEDIA_PROJECTION` and `FOREGROUND_SERVICE_CAMERA` and the
  live service's types `mediaProjection|camera` (used only for a streamer live). **Google Play:** the Play Console's
  foreground-service declaration must list `mediaProjection` and `camera` with a short video of the feature
  (PRE_PRODUCTION PP-43) — an app update that declares them without it can be rejected.
- **Order:** API first (an older app reads STREAMER as SOLO and shows the host's camera track; it ignores the
  `streamer` field and topic), then the app; the admin panel's «ستريمر» chip needs the API's `mode` filter.

### 5.48 «استوديو البث»: the browser studio at studio.<domain> (migration `20270302090000_streamer_main`; D247) — [IMPLEMENTED, draft contract v1.57-live; not deployed; real OBS NOT tested]

CONVENTIONS §10.88. **Migration:** one nullable column, `live_rooms.streamer_main` (`SCREEN` / `CAMERA`); existing
STREAMER rows are set to `SCREEN` in the same migration, then the CHECK `live_rooms_streamer_fields` is re-created
with `IS NOT NULL` on every STREAMER field (D213's version let a NULL orientation or corner through: `NULL IN (…)` is
not false). No new table, no GRANT. Checked on a fresh test database (`prisma migrate deploy` from zero; `prisma
migrate diff` shows no drift on `live_rooms`).

**The studio (no new server service):** `apps/studio` is built into static files by `infra/deploy/build-studio.sh` (run
by `update.sh` like `build-admin.sh`: only when `apps/studio`, the lockfile or the fonts changed; the API's pinned Node
image; `infra/deploy/studio/current` swapped with two renames, not in git; a failed build keeps the previous one and
never stops the API deploy). Caddy serves it at `studio.<domain>` (`./studio:/srv/studio:ro` in the compose file) with
`/api/*` → API on the same origin.

**Owner steps, once:**

1. **DNS:** an A record `studio.kabsolive.com` → the server's IPv4 (the same address as `api.` and `admin.`). Caddy gets
   the certificate on the next update (update.sh recreates Caddy when the Caddyfile changed).
2. **Media origin (only if LiveKit is not `live.<domain>`):** the studio's CSP allows `wss://live.<domain>` and
   `https://live.<domain>`. When `LIVEKIT_URL` points elsewhere (e.g. LiveKit Cloud), add both forms to
   `/etc/kabso/kabso.env`: `KABSO_STUDIO_MEDIA_ORIGINS='wss://<project>.livekit.cloud https://<project>.livekit.cloud'`,
   then `sudo docker compose -f /opt/kabso/infra/deploy/docker-compose.yml up -d --force-recreate caddy`.
3. Nothing else: no new API variable. The hosts sign in with their app accounts; only accounts with the hosting
   permission can go live (as in the app).

**Order:** the API (the `main` column and field) and the app's viewer together; the studio after them (an app without
D247 shows a «الكاميرا فقط» live as waiting for the screen). By hand: `sudo /opt/kabso/infra/deploy/build-studio.sh
--force`. CI checks it in the `studio` job (typecheck, lint, unit tests, build).

**Security headers** (Caddy): CSP `default-src 'self'` (`script-src 'self'`, `worker-src 'self'` for the heartbeat
clock, `connect-src 'self'` + the media server, `img-src 'self' data: blob: https:` for avatars and gift pictures,
`media-src 'self' blob:`, `frame-ancestors 'none'`), `Permissions-Policy: camera=(self), microphone=(self),
display-capture=(self)` (the public website keeps `camera=()`), HSTS, `X-Frame-Options: DENY`, `nosniff`,
`Referrer-Policy: no-referrer`, COOP same-origin, `X-Robots-Tag: noindex` (the website's `/studio` page is the indexed
one); `index.html` is `no-store`, hashed assets immutable.

**Bandwidth:** a studio live sends the screen (≈ 2.5 Mbps at 720p30, ≈ 4 Mbps at 1080p30), the camera (simulcast) and
the sound — more LiveKit egress per viewer than a phone streamer at 1080p; budget it.

**Local run:** API (or `SMOKE_STUDIO=1 … vitest run --config vitest.smoke.config.ts test/smoke/studio.smoke.ts`, which
seeds a host, a viewer and a gift; with `LIVEKIT_TEST_URL` it uses a real LiveKit), then
`KABSO_API_URL=http://127.0.0.1:3000 pnpm --filter @kabso/studio dev` (Vite on :5190 proxies `/api`). The Playwright
run (`apps/studio/e2e`) needs `KABSO_STUDIO_SMOKE`, `KABSO_STUDIO_URL`, `KABSO_API_DIR` (and `KABSO_SITE_DIR`,
`KABSO_LIVEKIT_RESTART`, `KABSO_STUDIO_CAPTURES` optionally).

### 5.49 The live hub's banners as in the owner's reference: the card-size banner and adding banners from the panel (migration `20270303090000_banner_hub_card`; D248) — [IMPLEMENTED, draft contract v1.59-live; not deployed, not device-tested]

CONVENTIONS §10.90. Additive: the banner placement CHECK gains `HUB_CARD` (no new table, no backfill). (§5.47 and
§5.48 are D213 / D247's; §5.50 is reserved for D250, §5.51 is D246b's.)

| Setting | Default | Meaning |
| --- | --- | --- |
| `HOME_HUB_CARD_CELL` | `4` (0–40) | the live hub grid cell (0-based, reading order; 4 = the first cell of the third row) of the card-size banner |

Order: API (with the migration) first, then the panel, then the app. An older app ignores `hub_card` banners (it never
asks for them) and keeps its carousel after the 4th card. The panel's upload needs object storage (the same as the
CLI's `--image`, §5.10 / §5.40); without it 503.

**What to upload (the owner):**

- **Carousel** «البنر الأساسي — الرئيسية بعد أول بثين»: **1 500 × 300 px** (5:1, D248b: the reference's shape),
  text inside the picture, keep it away from the edges; one or more, they rotate every 4 s. Banners already uploaded at
  1 500 × 500 still show, centre-cropped to 5:1 (their top and bottom are cut: re-upload them at 1 500 × 300). The
  same banners show 5:1 in the Voice rooms list and the Creator Center. «ارفع صور بنر 1500×300».
- **Card-size banner** «بنر بين اللايفات — بحجم بطاقة البث»: **720 × 805 px** (the live card's shape), text inside the
  picture. Several take turns in the same cell every 5 s.
- Both: JPEG, PNG or WebP, at most 15 MB; anything else is cropped around the centre to that shape (the panel shows the
  crop before adding).

**Animated banners (D248c, contract v1.61-live):** every category may move — an animated **WebP or GIF**, at most
15 MB in, **≤ 150 frames, ≤ 10 s a loop, ≤ 3 MB after cropping**; stored as an animated WebP. Sizes: main home banner
**1 500 × 300**, between the lives **720 × 805**, inside a live **600 × 800**. No video, Lottie or SVGA.
«يمكن رفع صور متحركة WebP/GIF بالمقاسات: 1500×300، 720×805، 600×800» (حتى 150 إطاراً و10 ثوانٍ و3 ميغابايت بعد القص).

#### The owner's steps — بالعربية

1. لوحة الإدارة ← «البانرات والفعاليات» ← «إضافة بانر».
2. اختر «مكان العرض»: «البنر الأساسي — الرئيسية بعد أول بثين» (ارفع صور بنر 1500×300) أو «بنر بين اللايفات — بحجم بطاقة البث»
   (صورة 720 × 805) أو «داخل البث — بانر صغير» (صورة 600 × 800).
3. اختر الصورة (ثابتة JPEG/PNG/WebP/GIF أو متحركة WebP/GIF) وتأكد من «معاينة القص»، ثم اكتب الرابط (مثل ‎/families‎) والسبب واضغط «إضافة بانر».
4. لتغيير الخانة التي يظهر فيها بانر البطاقة: `HOME_HUB_CARD_CELL` في إعدادات الخادم (4 = أول خانة في الصف الثالث).

### 5.50 Live moderation from the panel «مراقبة البث» (migration `20270304090000_live_moderation`; D250) — [IMPLEMENTED, draft contract v1.60-live; not deployed, not device-tested]

CONVENTIONS §10.91. Additive: the enum `live_moderation_kind`, the tables `live_moderation_actions` (what the team did on
a live: the host's notification target) and `device_bans` (HMACs of D223's device keys; the panel never shows them),
the nullable `sessions.device_hash` (+ a partial index) and `notifications.live_moderation_id`, the notification type
`LIVE_MODERATED`. DML for the runtime role from the default privileges (no GRANT); no backfill (sessions created before
this have no device and are never matched by a device ban). Checked on a fresh database (`prisma migrate deploy`, then
`prisma migrate diff` shows no drift on the touched tables).

- **Admin CSP (Caddy, `admin.<domain>`).** Watching a live loads `livekit-client` (its own lazy chunk) and talks to the
  media server: `connect-src` now allows `wss://live.<domain>` and `https://live.<domain>`, and `media-src 'self'
  blob:` the video elements. When `LIVEKIT_URL` is elsewhere (LiveKit Cloud), add its origins to `/etc/kabso/kabso.env`:
  `KABSO_ADMIN_MEDIA_ORIGINS='wss://<project>.livekit.cloud https://<project>.livekit.cloud'` (unset = nothing extra;
  as `KABSO_STUDIO_MEDIA_ORIGINS` for D247). Then `docker compose up -d caddy` (Caddy reads the env at start).
- **LiveKit.** No server setting: the staff observer is an ordinary token with `hidden: true`, subscribe only. The
  API's webhook and reconciliation never count a `staff:` identity. Watching costs one subscriber's bandwidth per
  staff member per live (the cards' previews ask for the lowest layer, at most 6 at once).
- **The app.** Sign-in now sends `device.deviceKey` (D223's key) — **ship the API before the app** (an older API reads
  it only at sign-up, so it is harmless, but the device ban only works with this API). Without the new app, sessions
  have no device: a device ban then blocks sign-up only (D223's sign-up path already sends the key) and ends the
  sessions it can see.
- **Who can.** `lives.watch`, `lives.reports`: OWNER, MODERATION and SUPPORT (owner answer D250b: SUPPORT watches and reads, no action); `lives.moderate`, `devices.ban`: OWNER and MODERATION. A device ban asks
  for the authenticator code again; bans and suspensions end by themselves (nothing to schedule).
- Not verified on a server or a phone (the CSP in a real browser against the production LiveKit, the push with the
  reason on a device, a device ban against a real ANDROID_ID).

### 5.51 The party page's room cards: «رائج» per kind (no migration; D246) — [IMPLEMENTED, draft contract v1.58-live; not deployed, not device-tested]

CONVENTIONS §10.89. (Numbered §5.48 on its branch; renumbered §5.51 at integration `claude/kl-int12` because D247's studio is §5.48, D248 §5.49 and D250 §5.50.) No migration and no new table: `LiveRoomSummary.roomLevel`,
`popular` and `hostCountry` are read in the room statements.

| Setting | Default | Meaning |
| --- | --- | --- |
| `LIVE_POPULAR_TOP_N` | 10 | D246 «رائج»: a live is popular while among this many first lives of its kind (audio, podcast, multi, video) in the `popular` order (1–100) |

Order: API first, then the app (an older server sends none of the fields: the cards show no level, no «رائج», no flag).

### 5.52 The level-up banner in every live «شريط ترقية المستويات» (migration `20270305090000_level_ticker`; D254) — [IMPLEMENTED, draft contract v1.62-live; not deployed, not device-tested]

CONVENTIONS §10.92. The migration only widens the `site_settings` key CHECK with `levelTickerMinLevel` (no new table, no
row inserted: absent = 30). No env setting: the OWNER sets the threshold in the panel («إعدادات الموقع» → «شريط ترقية
المستويات», `PUT /admin/level-ticker`, 1–100, audited `site.settings.update`); it takes effect at the next level-up, with
no restart and no app update. Redis keys `level:ticker:gate` (8 s), `level:ticker:pending` (the line, ≤ 20, expires after
120 s) and `level:ticker:seen:<user>:<category>:<level>` (7 days) under the API's key prefix; Redis or the media server
down → no banner, never a failed gift or tap.

Order: API (with its migration) first, then the panel and the app. An older app ignores the `level-ticker` message; an
older panel does not show the setting (the default 30 applies).

### 5.53 The VIP perks (migrations `20270306090000_vip_perks`, `20270306090100_vip_daily_enums`, `20270306090200_vip_daily`; D258) — [IN PROGRESS, draft contract v1.83-social; not deployed, not device-tested]

CONVENTIONS §10.94. The migration adds `vip_tier_perks.amount` and VIP 1's other six perks (the owner's list:
`CHAT_NAME_COLOR`, `MIC_WAVE`, `DAILY_BULLET` 3 a day, `PROFILE_VISITORS`, `DAILY_COINS` unset, `LEVEL_SPEEDUP` 1 %;
`ON CONFLICT DO NOTHING`). No env setting. After deploying, the OWNER uploads VIP 1's art in the panel («VIP» → the tier →
each perk's «رفع صورة» / «رفع SVGA»: `POST /admin/vip/uploads`, stored under `media/vip/<tier>/` in the media bucket, so
object storage must be configured) and sets the daily coins amount; the art takes effect at once, with no app update.

**Art size.** The owner's VIP 1 entry car (`peacock_000.svga`) is **13 MB**: it is accepted (≤ 25 MB) but every viewer of a
live downloads it when the member joins. Ask the designer for a 2–3 MB export (fewer frames / smaller images inside) before
uploading it; the app shows the banner alone until the car has downloaded, plays it once, and keeps the file on the
device (the gift art cache), so each viewer downloads it once.

**The owner's VIP 1 art sizes.** badge 3.7 MB, chat bubble 2.7 MB, frame 2.6 MB, card 2.5 MB, banner 0.8 MB, mic wave
0.2 MB, car 13 MB — every one is 36 full-frame bitmaps (the car 75). The app downloads each once per device and keeps
only small frames in memory, but the first load on a slow network is long: ask the designer for lighter exports
(fewer frames or smaller images; the badge is shown ~20 px tall, 128 px frames are plenty).

**Special colour and medals.** Migration `20270306090400_vip_name_color` adds `vip_tiers.name_color` and sets VIP 1's
to `#FFD12E`. The medal showcase now holds at most 3: people who chose more keep their first 3 (trimmed on read, no
data change); an app older than this build may still offer 6 and get 400 `too_big` past 3.

**Renewal discount.** Migration `20270306090500_vip_renewal_discount` gives every tier a 15 % renewal discount (the
owner changes it per tier in the panel; 0 = none) and records list price and discount on each purchase. An app older
than this build sends the list price for a renewal and gets 409 `VIP_PRICE_CHANGED`; it reloads and shows the list
price again — ship the app with it.

**Profile visitors.** Migration `20270306090300_profile_visits` adds the visits table (one row per pair; it grows with
profile views — about one row per distinct visitor of each profile; rows older than 30 days are never listed and can be
pruned by a later job).

**Daily perks.** The second and third migrations add the wallet reason `VIP_DAILY_COINS`, the daily-claims table, and
let a bullet message cost 0 (the CHECK becomes `cost >= 0`): a VIP's first 3 public messages a day are free. The level
speed-up (+1 %) applies to the points a live gift earns on the sender's own level. The daily coins claim answers
`no_perk` until the OWNER sets VIP 1's daily coins amount in the panel.

Order: API (with its migration) first, then the panel and the app. An older app ignores `UserSummary.vip`; an older panel
does not show the amount or the upload buttons (the URL fields still work).

### 5.54 The live's real host cherries «كرز المضيف الحقيقي» (migration `20270306090600_live_host_cherries`; D259) — [IMPLEMENTED, draft contract v1.63-live; not deployed, not device-tested]

CONVENTIONS §10.95. The migration adds `live_room_scores.host_cherries` (≥ 0) and backfills it from the stored sends:
the host's own recipient rows of every live's gifts, each floored as the cherry ledger credits it, **at 10 cherries a
coin** (the default `CHERRIES_PER_COIN`). If production ever ran with another `CHERRIES_PER_COIN`, past lives read
slightly off (display only; no balance changes). It is one `UPDATE` over `live_gifts` × `live_gift_recipients`: run it
in a quiet hour on a large database. No env setting.

Order: API (with its migration) first, then the app. An older app ignores `hostCherries` and keeps showing the score in
the pill; the new app on an older server shows 0 cherries.
### 5.55 Staff presence in lives «فريق كابسو» (migration `20270307090000_live_staff_presence`; D260) — [IMPLEMENTED, draft contract v1.64-live; not deployed, not device-tested]

CONVENTIONS §10.96. The migration adds `admin_shifts`, `live_room_assignments` and `live_room_staff_watchers` (no backfill;
the runtime role gets DML through the default privileges). No env setting: the assignment pass runs after each go-live, on
each shift change and at `LIVE_SWEEP_INTERVAL_SECONDS` (0 turns the periodic pass off; the go-live and shift passes still run).

- **Staff accounts.** Real panel accounts only (OWNER / MODERATION / SUPPORT, each with their own authenticator). Since
  D271 the OWNER grants them from the panel's «الموظفون والصلاحيات» (email or `@username` of an existing app account, a
  reason, the OWNER's fresh code; `admin-admin grant` still works). The panel then shows the new staff member's next steps:
  sign in at `https://admin.kabsolive.com` with the app account's email and password, enrol the authenticator, open
  «البث الآن» and turn on «في المناوبة». Nothing is assigned while nobody is on shift (the OWNER's «من في المناوبة» shows
  the lives nobody watches). Revoking a person's last watch role takes them off shift and hands their lives on at once;
  revoking their last panel role also ends their panel sessions.
- **Media load.** A visible watch is one extra subscriber per watched live (video and audio of the host and seats), from
  the staff member's browser. Watching all assigned lives at once multiplies that; staff open «بثوثي» lives one at a time.
- **Behaviour change in the panel.** «مشاهدة» now joins visibly (the host and viewers see «فريق كابسو» in the viewer list);
  OWNER / MODERATION switch «مراقبة خفية» for the D250 hidden observer. Card previews stay hidden.
- **Rollback.** The tables are only read by D260 code; an older API ignores them (a `team:` participant joined from an older
  panel cannot happen: the token comes from the new API).

### 5.56 VIP items in the bag «عناصر VIP في الحقيبة» (migration `20270308090000_vip_bag`; D264) — [IMPLEMENTED, draft contract v1.65-live; not deployed, not device-tested]

CONVENTIONS §10.97. The migration adds `vip_memberships.off_perks` (text[], default empty, checked against the six wearable
perk codes) and, once, takes off the bag frame / profile card of members active at deploy time where their tier holds that
perk (owner: one worn item per kind — they wore both). No env setting. The VIP items are derived from the membership on
every `GET /me/bag` (nothing to backfill or sweep).

- **Visible change.** Active VIP members: the bag lists their tier items with the membership's time; where they wore a bag
  frame or card (the free «الأرنب الملكي» included), the VIP one is worn instead after the migration — they can wear the
  bag one again from the bag. A new VIP purchase does the same; when VIP ends those slots stay empty.
- **Older apps.** They show the VIP-only items under «أدوات أخرى» and ignore `UserVip.off`, so until updated they still
  draw a VIP item that is taken off or covered by a bag item (e.g. the VIP card with the bag's card).
- **Rollback.** An older API ignores `off_perks`; the bag rows the migration took off stay off (re-wear from the bag).

### 5.57 The store «المتجر» (migrations `20270310090000_store_enums`, `20270310090100_store`; D270) — [IMPLEMENTED, draft contract v1.84-social; not deployed, not device-tested]

CONVENTIONS §10.98. The first migration adds enum values only (`bag_category` CHAT_BUBBLE / ENTRY_BANNER / ENTRY_EFFECT,
`bag_item_source` STORE, `wallet_ledger_reason` and `cherry_ledger_reason` STORE_PURCHASE) and the `store_currency` type;
the second creates `store_items`, `store_item_prices`, `store_purchases` and extends both ledgers' sign CHECKs in place
(read from the catalogue, as `20270206090100_referrals`). Additive; no backfill, no env setting. The runtime role gets DML
through the default privileges.

- **Object storage.** Store art uploads (`POST /admin/store/uploads`) go under `media/store/` in the public bucket, like
  VIP / gift art; `MEDIA_PUBLIC_BASE_URL` (or the panel's storage settings) must be set or uploads answer 409
  `no_public_url`. The raw-bytes body parser covers the new path (`app.setup.ts`).
- **After deploy.** Nothing is on sale until the OWNER adds items in the panel «المتجر» (Programs → المتجر,
  `/store`): kind, names ar / en, a PNG still + an SVGA or MP4 animation, a price per duration (7 / 14 / 30 days) per
  currency, order, «جديد», then «تفعيل». Every change asks a reason and is audited (`store.item.*`); sales are listed on
  the same page.
- **Older apps.** They do not show the store card's screen (it stayed «قريباً» before D270), list a bought store item in
  the bag with a plain tile and ignore `UserSummary.wear` (a worn store item shows nothing to them).
- **Rollback.** An older API never reads the new tables; store items already in bags stay as bag rows (the categories
  are enum values an older app ignores). Enum values cannot be dropped; leave them.


### 5.58 «نقاط PK» on the stage, withdrawal −3, «جولة أخرى» after a dare (migration `20270311090000_pk_forfeit_points`; D276) — [IMPLEMENTED, draft contract v1.67-live; not deployed, not device-tested]

The migration adds `pk_dare_settings.forfeit_points` (default −3) and replaces the `pk_dare_settings_shape` CHECK under
the same name with its range (−100 … 100). Additive; no backfill. **No new env setting and no flag to turn on**:
«جولة أخرى» (D242) has none — it needs only `PK_ENABLED` (on for PK at all) and is limited by `PK_REMATCH_MAX` (5 in a
row; 0 = unlimited — keep it above 0 or unlimited, never set it to a value already reached) and answered within
`PK_REMATCH_ACCEPT_SECONDS` (15).

- **Withdrawal («PK الأحكام» only).** In a DARES match a host who withdraws from the battle (FORFEIT «إنهاء التحدي»
  during it, DISCONNECT, AWAY) now gets the panel's «الانسحاب من تحدي الأحكام» value (−3) instead of the loss's 0, still a
  loss; both withdrew → both (no longer a draw). A NORMAL PK is unchanged. Ending in the result phase is not a withdrawal. Change it in «أحكام PK» → «نقاط PK والإعدادات» (OWNER, audited).
- **After a dare.** While a rematch is still allowed, the result stays `PK_RESULT_SECONDS` (60) after a DARES match's
  dare ends (was `PK_DARE_OUTCOME_SECONDS`, 8 — too short to offer «جولة أخرى»).
- **Older apps** ignore `PkSideState.pkPoints` and `PkMatch.forfeitPoints`; the new app shows nothing for them against
  an older API. Order: API (migration) first, then the panel, then the app.

### 5.59 «فريق كابسو» from the app (migration `20270312090000_staff_app_tools`; D273) — [IMPLEMENTED, draft contract v1.68-live; not deployed, not device-tested]

CONVENTIONS §10.96.6–§10.96.8. The migration adds `admin_app_grants` (the staff tools' step-up, bound to an app session;
CHECKs on the expiry and the end reason), `notifications.live_room_id` and `reports.context_live_room_id` (nullable FKs,
partial indexes) and the enum values `live_moderation_kind.WARN`, `notification_type.LIVE_STAFF_REPORT` (no backfill; the
runtime role gets DML through the default privileges). Optional env: `STAFF_APP_GRANT_SECONDS` (43200),
`RATE_LIMIT_STAFF_APP_USER` (`300/900`), `RATE_LIMIT_STAFF_STEP_UP_USER` (`10/900`). Needs `ADMIN_TOTP_KEY` (the step-up
answers 503 without it, like the panel).

- **Staff.** Every OWNER / MODERATION / SUPPORT account is «فريق كابسو» in every live it opens from the app at once (no
  setting). Tell staff: the app's Me tab → «فريق كابسو» → «فتح الأدوات» with the code of the authenticator they enrolled at
  admin.kabsolive.com (staff who never signed in to the panel must enrol there first); «في المناوبة» works from the phone.
- **Behaviour change.** Staff accounts can no longer send gifts / taps / bullets or take a seat in a live; users can no
  longer kick, mute or remove panel accounts (incl. FINANCE). Report alerts reach the staff member's phone (push needs
  Firebase, §5.40).
- **Order.** API (with its migration) first, then the app. An older app on the new API: staff join as «فريق كابسو» (the
  server decides) but see no tools; gifts / taps are refused with a generic message.
- **Rollback.** The new columns and table are only read by D273 code; an older API ignores them (WARN rows and
  LIVE_STAFF_REPORT notifications would be unknown values to it — delete them before rolling back the code).
### 5.60 The host's targets in cherries «هدف الهدايا» / «هدف هدايا الحظ» (migration `20270313090000_host_targets_cherries`; D277) — [IMPLEMENTED, draft contract v1.69-live; not deployed, not device-tested]

CONVENTIONS §10.62.1. **The unit of two stored task targets changes** from coins to cherries; nothing else is stored
differently. The migration:

- adds the metrics `HOST_GIFT_CHERRIES` and `HOST_LUCKY_CHERRIES` to `task_definitions_shape` (same constraint name);
- «هدف الهدايا» `P_HOST_GIFTS` (was «استقبل هدايا في بثك (بالعملات)», `HOST_GIFT_COINS`): `band_targets` and `target`
  × 10 cherries per coin × 65 % (the POPULAR host share), floored. The defaults are 100 000 / 250 000 / 500 000 /
  1 000 000 coins, which become **650 000 / 1 625 000 / 3 250 000 / 6 500 000 cherries**. The days' offers
  (`task_assignments.target`) of that task are converted the same way, so today's progress compares cherries with
  cherries;
- «هدف هدايا الحظ» `HOST_LUCKY_COINS` (the code is kept, because claims are keyed by it): × 10 × 10 % (the lucky host share)
  = **the same numbers**, 20 000 / 50 000 / 100 000 / 200 000, now in cherries;
- renames both tasks (ar / en). Rewards and the daily and monthly caps are unchanged. Only rows still on the old
  metric are converted, so values changed with `task-admin` are converted too, and a second run changes nothing.

**Check before deploying:** the conversion assumes the defaults `CHERRIES_PER_COIN=10`, `GIFT_HOST_SHARE_PERCENTS`
POPULAR 65 and `LUCKY_GIFT_HOST_SHARE_PERCENT=10`. If production runs with other values, correct the two tasks afterwards
with `task-admin` (it now prints cherry targets as «… cherries (≈ $…)»). No env setting; nothing to backfill.

What is counted: «هدف الهدايا» counts the cherries the ledger credited for gifts outside the lucky category from other
ACTIVE people. «هدف هدايا الحظ» counts the cherries of lucky gifts, the host's own sends to themself included (D128
allows them). Both are net of admin reversals.

Order: API (with its migration) first, then the app. An older app reads `cherries` (now the same as `gifts`) and shows
the lucky number as before; at the default 10 % share, a lucky coin is 1 cherry. Its sheet still says «(عملات)» for
the lucky target. The new app on an older server falls back to `cherries`. The badges sit in fixed slots
(`apps/mobile/assets/host_targets/`, PROVENANCE): to swap in the owner's art, replace the file. No code change is needed.
Rollback: an older API does not know the two new metrics, so it hides both tasks (`isTaskMetric`); re-run the
inverse (÷ 6.5 / ÷ 1, metric back) with `task-admin` if needed.


### 5.61 Profile tags «منشنات» (migration `20270314090000_profile_tags`; D278b) — [IMPLEMENTED, draft contract v1.85-social; not deployed, not device-tested]

CONVENTIONS §10.99. Adds `user_profiles.tags` (`VARCHAR(24)[] NOT NULL DEFAULT '{}'`) and the CHECK
`user_profiles_tags_count` (at most 10). Every existing profile gets an empty set; nothing to backfill, no env setting.
The column add with a constant default is metadata-only on PostgreSQL ≥ 11 (no table rewrite). Order: API (with its
migration) first, then the app; an older app ignores `tags`, and an older API leaves it out (the app shows no chips).

### 5.62 Smart host targets and the generated Task Center «الأهداف الذكية» (migrations `20270315090000_host_target_engine_enums`, `20270315090100_host_target_engine`, `20270315090200_host_target_tracks`; D281, D281b) — [IMPLEMENTED, draft contracts v1.71-live / v1.86-social; not deployed, not device-tested]

CONVENTIONS §10.62.2 (targets: the catalogue, the assignment, the profit-share reward) and §10.41.4 (the Task Center's
generated catalogue and smart assignment). The migrations:

- add the cherry ledger reason `HOST_TARGET_REWARD` (its own migration) and extend `cherry_ledger_reason_sign` in place
  (a credit);
- widen `task_definitions_shape` with the metrics `GIFT_COUNT_SENT`, `CATEGORY_GIFTS_SENT`, `GIFTED_HOSTS`, `FAMILY_JOIN`,
  `FAMILY_CHAT_MESSAGES`, `PK_BATTLES`, `PK_WINS` and seed seven pool templates (`P_SEND_GIFT_OF`, `P_SEND_CATEGORY`,
  `P_GIFT_HOSTS`, `P_FAMILY_JOIN`, `P_FAMILY_CHAT`, `P_PK_BATTLES`, `P_PK_WINS`; an existing code is left alone);
- add to `task_assignments` the generated variant's columns (`variant`, `subject`, `window_from`, `window_to`,
  `name_ar`, `name_en`, `reason`; CHECK `task_assignments_variant_shape`; index `task_assignments_user_day_idx`) — old
  rows keep NULLs;
- create `host_target_settings` (one row: the knobs with the owner's defaults 50 / 75 / 90 percentiles, 150 / 250 / 400
  bps, 7 / 3 no-repeat days, 30 history days, 10-point completion shift; `engine_from` NULL) and
  `host_target_assignments` (a host's three targets of a day; CHECK `host_target_assignments_shape`). Runtime grants come
  from the default privileges (KL-013).

**The switch is automatic and keeps today:** the API's first read after the deploy sets `engine_from` to the NEXT day
(the programs' zone, `LIVE_RANKINGS_TIME_ZONE`). Until then every host keeps D277's two targets and their progress, and
the Task Center keeps today's list; from that day the three smart targets and the generated tasks start, and the fixed
`HOST_LUCKY_COINS` / pool `P_HOST_GIFTS` tasks are no longer offered (their rows stay; history and claims untouched). To
start on a chosen day instead, set `host_target_settings.engine_from` before the deploy's first read (migration role).

**Economy settings read (no new env):** `COIN_RETAIL_USD_PER_MILLION` (12.5), `CHERRY_PAYOUT_RATE` (1000000:110),
`CHERRIES_PER_COIN` (10), `GIFT_HOST_SHARE_PERCENTS` (65 / 50), `LUCKY_GIFT_HOST_SHARE_PERCENT` (10) and
**`LUCKY_GIFT_RTP_PERCENT` — set it to the owner's 75 on the server** (the code default is 85, which makes lucky targets
pay less). The rewards are a share of the profit these give (§10.62.2 worked example: a hard 3 000 000-cherry target →
$2.469 profit → 89 790 cherries); they are locked task cherries (withdrawal, store and cherry sales wait for the unlock
rule) and are outside the Task Center caps. The panel «الأهداف الذكية» (OWNER only) changes the knobs with a reason
(audited) and shows each host's «لماذا هذا الهدف».

Load: a host's first read of the day runs ~7 history queries over `history_days` of their gifts (indexes
`live_gift_recipients_user_idx`, the ledger's reference index) and a person's first Task Center read one 7-day query per
offered metric; later reads use the stored day. Order: API first (the new fields are additive; an older app ignores
`daily`, shows the generated names and unknown metrics with the generic icon), then the app and the panel. Rollback: an
older API ignores the new tables and columns and hides the new templates (unknown metrics, `isTaskMetric`), but it
cannot read a `HOST_TARGET_REWARD` ledger row (an unknown enum value): once a target has been paid, roll the API back
only to a build that knows the reason.

**D281b** (`20270315090200_host_target_tracks`): `host_target_assignments.track` (GIFTS / LUCKY, existing rows GIFTS),
primary key `(user_id, day, track, level)`, the kinds CHECK with the lucky kinds; `host_target_settings.new_host_defaults`
(JSONB, NULL = the code's values). Six targets a day per host (three gifts, three lucky). **When the real gift prices are
set,** raise the new-host defaults in the panel «الأهداف الذكية» (OWNER); everything else follows the hosts' history and
the current prices by itself.
### 5.68 Recharge-agent employees act for the agent: cherry purchases and the orders inbox (migration `20270321090000_recharge_employee_acts`; D287) — [IMPLEMENTED, draft contract v1.87-social; not deployed, not device-tested]

CONVENTIONS §10.100. Additive: `recharge_employees.can_buy_cherries` / `receives_orders` (BOOLEAN NOT NULL DEFAULT
true — every existing employee keeps both ON, as the owner asked), `recharge_cherry_requests.acted_by` / `decided_by`
and `recharge_orders.claimed_by` / `claimed_at` (nullable UUID / timestamp), two partial indexes; the cherry request's shape CHECK is replaced (it now also allows `created_by` = `acted_by`, an
employee who created it for the agent — re-adding it scans `recharge_cherry_requests` once). Adding a column with
a constant default is a metadata-only change in PostgreSQL ≥ 11 (no table rewrite). No new setting, no new role
grant (the columns inherit the tables' grants). «On shift» is the employee's weekly hours (§10.48), not the staff
«في المناوبة» of D286 (`admin_shifts`). The port of the local-only D252 work (numbered §5.52 there).

Order: API (with the migration) first, then the panel, then the app. An older app keeps working: it ignores the new
fields; an employee on an older app still gets 403 / 409 with a message when the server refuses, and the employee's
hub shows «بيع كرز» (the host flow) until the app is updated. Rollback: the columns can stay (nothing reads them in
older code).

**Check after deploying:** as an agent add (or open) an employee — «الموظفون» shows the two switches ON; with the
employee's phone on shift, «شراء كرز» → a host's username → the host confirms → the agent's stock grows by
floor(cherries × 93 220 / 1 000 000) and the employee's «شراء الكرز» count moves; off shift the employee reads the
requests with «خارج ساعات عملك». A buyer's order notifies the agent and the on-shift employee; once one of them sends
the payment details the other sees «تم استلامه بواسطة موظف آخر». Adding a Kabso Team account (MODERATION, SUPPORT,
FINANCE or BD) as an employee is refused with «هذا الحساب من فريق كابسو…»; an employee given such a role reads only
until the role is taken away (owner's decision; no migration — the roles are read live).

### 5.69 The shared report queue «البلاغات المشتركة», and no code for the ban and content deletion (migration `20270322090000_shared_reports`; D288) — [IMPLEMENTED, draft contract v1.78-live; not deployed, not device-tested]

CONVENTIONS §10.101. (§5.68 is left free for another branch.) The migration adds the `notification_type` value
`STAFF_REPORT_NEW`, `notifications.report_id` (FK to `reports`, cascade, partial index) and `reports_resolved_idx`
(the resolved tab). The value is only written by the new API, so deploy the migration with (or before) the API. No new
server setting.

- **Tell the team:** the ban «حظر», deleting a post or story for good and starting an account's deletion no longer ask
  for the authenticator code (the temporary password, the e-mail change, money, roles, device bans, the settings and
  the panel sign-in still do).
  SUPPORT now sees every report in the panel and in the app («أنا» › «بلاغات»); every new report notifies every
  moderator and support member; whoever handles it presses «تم حله» (with an optional note) and it is resolved for
  everyone. The OWNER and the moderators can reopen (not the support).
- **The app's channel:** the D288 app creates the Android channel `kabso_staff` («بلاغات فريق كابسو»); older apps show
  these pushes on the default channel. It plays the general sound (owner: no separate sound).
- **Checks after deploy:** a test report from a normal account shows on the panel's «البلاغات» badge and in each
  staff phone's inbox; `SELECT count(*) FROM notifications WHERE type = 'STAFF_REPORT_NEW' AND read_at IS NULL;`; the
  audit rows `moderation.report.alert`, `moderation.report.resolve`, `admin.user.ban` and `account.deletion.requested`.

### 5.70 Gift and store badges «شارات الهدايا والمتجر» (migration `20270323090000_item_badges`; D289) — [IMPLEMENTED, draft contract v1.79-live; not deployed, not device-tested]

CONVENTIONS §10.102. Expand only: the migration adds the `item_badge` type, `badges item_badge[]` and three
`badge_*_until` columns to `gifts` and `store_items`, backfills (a gift's NEW and a store item's `is_new` → «جديد» ending
14 days after the migration; a gift's EVENT → «موسمي» without an end) and adds the CHECKs. `gifts.badge` and
`store_items.is_new` stay and are written in step by the API, so a rollback to the previous API keeps working (it shows
«جديد» without an end again). Both tables are the panel's catalogue (small): the UPDATEs take row locks for milliseconds.
Deploy the panel with the API (the panel's form sends `badges`; the old panel's `badge` / `isNew` are still accepted).

- **D289b «حذف»:** migration `20270323090100_store_item_delete` adds `store_items.hidden_at` and the CHECK
  `store_items_hidden_off` (hidden ⇒ off); deploy it with the API and the panel. A real delete removes the item's art
  from the bucket when no other item uses it (best effort, logged on failure); nothing else touches storage.
- **Settings:** none. Ends are compared at read time (no sweeper, no cron).
- **Tell the owner:** the gift and store forms now have «الشارات»; uploading an effect pre-selects the sound badge and
  «شاشة كاملة» (marked «تلقائي»); every «موسمي» migrated from «فعالية» has no end until a date is set — the gift and
  store lists mark them «حدد تاريخ الانتهاء» and count them (owner D289-Q2: set a date on each); every «جديد» ends
  14 days after the deploy unless a date is set.
- **Checks after deploy:** `SELECT badges, count(*) FROM gifts GROUP BY 1;` and the same for `store_items`;
  `SELECT count(*) FROM gifts WHERE 'SEASONAL' = ANY(badges) AND badge_seasonal_until IS NULL;` (the migrated ones);
  `GET /api/v1/gifts/catalogue` lists `badges`.

### 5.71 Level-raise requests «طلب رفع ليفيل» (migrations `20270324090000_level_raise_enums`, `20270324090100_level_raise`; D290) — [IMPLEMENTED, draft contract v1.89-social; not deployed, not device-tested]

CONVENTIONS §10.103. The migrations add `level_raise_requests`, `level_raise_source_apps` (seeded: Zafa CONFIRMED by
the owner, twelve ESTIMATE apps and OTHER, all FACTOR × 0.5 except Zafa), `level_raise_settings` (one row, the
defaults), `notifications.level_raise_request_id`, three `notification_type` values and the media kind
`LEVEL_RAISE_VIDEO` (the `media_assets` kind / duration / poster CHECKs are replaced). Runtime grants come from the
default privileges. Deploy with the API (an older API never writes the new kind).

- **No new environment variables.** The panel's video upload is a raw body of at most 100 MiB on
  `/api/v1/admin/level-raise-videos` only: Caddy's `request_body` limit for the admin site (if one is set) must allow
  it; the API holds the bytes in memory once per upload.
- **Before use (PP-49):** the OWNER reviews the weights («طلبات رفع الليفيل» → «الإعدادات») and the source-app table
  (every row but Zafa is an estimate), and the team is told who may send requests (MODERATION, SUPPORT).
- **The video is deleted after the decision** (owner): the decision sets `level_raise_requests.video_deleted_at`; the
  API then deletes the objects (video, poster, thumb) and the `media_assets` row at once, and the media sweep
  (`MEDIA_SWEEP_INTERVAL_SECONDS`, default as today) retries any left over after a storage failure — never set it to 0
  in production. The evidence stays (asset id, length, size, display size; the audit rows `level.raise.approve` /
  `.reject` carry `video.deletedAt`). Leftovers: `SELECT count(*) FROM level_raise_requests WHERE video_deleted_at IS NOT
  NULL AND video_media_id IS NOT NULL;` should be 0 after a sweep.
- **Duplicates:** the unique partial index `level_raise_requests_source_once` (one PENDING / APPROVED request per source
  app + account ID) is created by the same migration (empty table: no backfill).
- **Checks after deploy:** `SELECT code, mode, confidence, aliases FROM level_raise_source_apps ORDER BY sort;` (14 rows) and
  `SELECT * FROM level_raise_settings;` (one row: 1000000, 7, 1000000, 20, 15, 40, 1, 2, 1, 2, 30).

### 5.72 Medal levels (migration `20270325090000_medal_levels`; D291) — [IMPLEMENTED, draft contract v1.81-live; not deployed, not device-tested]

CONVENTIONS §10.104. The migration adds the types `MedalCategory` / `MedalMetric`, `medals.category` / `.metric` (the
nine medals' tabs and metrics are set), the table `medal_levels` (seeded with the default thresholds, §10.104.2),
`user_medals.level` (default 1) / `.level_reached_at` (= `awarded_at` for existing rows) and `notifications.medal_level`.
The runtime role gets DML through the default privileges (no GRANT). Every medal held before stays **level 1** until the
backfill — which is correct (level 1 is the old rule), so the API can be deployed first and the backfill run after.

- **Backfill, once after the deploy** (from then on levels rise with each event): without `--notify` so old activity
  does not flood inboxes. From `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/medals-admin.js backfill
  ```

  It prints `Awarded n medals.` and `Raised n medal levels.`; idempotent (a second run prints 0 and 0); never lowers a
  level; one `medals.backfill` audit row with `{awarded, levelUps}` plus `medals.level_up` per level above 1
  (`via: backfill`). Run it again whenever the panel lowers a threshold, so past activity reaches the new level.
- **Checks after deploy:** `SELECT medal_code, count(*), max(threshold) FROM medal_levels GROUP BY 1;` (9 medals, 27
  levels) and `SELECT medal_code, level, count(*) FROM user_medals GROUP BY 1, 2 ORDER BY 1, 2;` after the backfill.
- **«ملوك الثروة» (§10.104.7):** two more migrations in order — `20270325090100_medal_wealth_metric` (only the enum value
  `GIFTS_SENT_COINS`; it must commit before the next one uses it) and `20270325090200_medal_wealth_kings`
  (`medal_levels.icon_asset`, `medal_metric_totals`, the medal and its six levels). Deploy the API with them (an older API
  never adds to the totals). The same one-off `medals-admin backfill` then sets every sender's total from history
  (`live_gifts` without lucky gifts, plus `cp_gifts`) and raises their level. Check:
  `SELECT count(*), max(value) FROM medal_metric_totals WHERE metric = 'GIFTS_SENT_COINS';` and
  `SELECT level, count(*) FROM user_medals WHERE medal_code = 'WEALTH_KINGS' GROUP BY 1;`.
- **Retiring the charm / live-hours codes (§10.104.8):** `20270325090300_medal_retire_name_icons` sets `medals.retired`
  for CHARM_10/50/100 and LIVE_HOURS_10/100, clears them from showcases and renumbers the rest; their `user_medals` rows
  stay. Check: the query in PP-50 returns 0.
- **«سيد الحظ» (§10.104.9):** two more migrations in order — `20270325090400_medal_lucky_metric` (only the enum value
  `LUCKY_GIFTS_SENT_COINS`) and `20270325090500_medal_lucky_master` (the medal and its four levels, 500 M … 10 B). The
  same backfill sets the totals from the LUCKY `live_gifts`. Check:
  `SELECT count(*), max(value) FROM medal_metric_totals WHERE metric = 'LUCKY_GIFTS_SENT_COINS';` and
  `SELECT level, count(*) FROM user_medals WHERE medal_code = 'LUCKY_MASTER' GROUP BY 1;`.
- **Panel:** «الميداليات» (`catalog.view` reads, the OWNER edits with the code; retired codes read-only). No new settings.

### 5.73 Automatic verification badges «شارة التوثيق» (migration `20270326090000_verification_badges`; D293) — [IMPLEMENTED, draft contract v1.90-social; not deployed, not device-tested]

CONVENTIONS §10.105. The migration adds the type `verification_badge`, the table `user_verification_badges` (empty) and
the one-row `verification_badge_settings` with the **owner's defaults**: 300 000 000 coins sold and 300 000 000 cherries
bought by a recharge agent, more than 30 active hosts and 300 000 000 cherries received for a host agent's agency — all
"more than", over the last 30 days. The runtime role gets DML through the default privileges (no GRANT). Nobody shows a
badge until the first recompute.

- **Settings:** `VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS` (default **3600** = hourly; 1 … 86 400; the owner said daily
  is enough, hourly keeps a restart from postponing it by a day; `0` turns the sweeper off and is **refused in
  production**). The thresholds are edited in the panel «شارات التوثيق» (OWNER, the code again), not in env files.
- **First-run backfill, once after the deploy** (afterwards the sweeper and the immediate recomputes keep it current).
  From `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/verification-admin.js recompute
  ```

  It prints `Verification badges: n granted, n changed, n removed, n kept.`; idempotent (a second run prints 0 granted,
  0 changed, 0 removed); one `verification.recompute` audit row plus `verification.badge.change` per person
  (`cause: backfill`). Several API instances are safe: one recompute at a time (an advisory transaction lock).
- **Checks after deploy:** `SELECT badge, count(*) FROM user_verification_badges GROUP BY 1;` (OWNER = the OWNER
  accounts, STAFF = the team) and `SELECT last_run_at FROM verification_badge_settings;` (moves every interval).
- **Panel:** «شارات التوثيق» under «المستخدمون» (`verification.view`: OWNER, MODERATION, SUPPORT, FINANCE read; the OWNER
  edits with a reason and the code); the badge on each user page.

### 5.74 Profile tag icons (migration `20270327090000_profile_tag_icons`; D292) — [IMPLEMENTED, draft contract v1.91-social; not deployed, not device-tested]

CONVENTIONS §10.106. The migration adds `user_profiles.tag_icons` (`varchar(24)[]`, default empty) with the CHECKs
`user_profiles_tag_icons_len` (empty or one per tag) and `user_profiles_tag_icons_values` (the closed set or
`flag:XX`). Existing rows stay empty and read as `default` for every tag; no backfill. The runtime role keeps its DML
on `user_profiles` (no GRANT). Additive: deploy the migration with the API (an older API ignores the column; an older
app ignores `tagIcons` and keeps the icons when it edits its tags).

- **Check after the deploy:** `SELECT count(*) FROM user_profiles WHERE cardinality(tag_icons) NOT IN (0, cardinality(tags))` → 0.

### 5.76 Content creators go live «صانع محتوى» (migrations `20270329090000_creator_lives_enums`, `20270329090100_creator_lives`; D295) — [IMPLEMENTED, draft contract v1.82-live; not deployed, not device-tested]

CONVENTIONS §10.108. Two migrations, in order (the first only adds enum values — `live_host_source` CREATOR,
`creator_application_status` REVOKED, `agency_close_reason` BANNED, `cherry_ledger_reason` AGENCY_FORFEIT — which must
commit before the second uses them). The second adds `creator_applications.source` / `agency_id` / `revoked_*`, the
trigger `kabso_creator_host_exclusive` on `live_hosts` and `creator_members`, the table `agency_bans` (append-only for
the runtime group: UPDATE / DELETE revoked) and extends `cherry_ledger_reason_sign` (AGENCY_FORFEIT is a debit). It
**backfills** `live_hosts` CREATOR for every existing creator member who holds no hosting permission. Deploy the API with
the migrations (an older API would list creators' lives without the interleave and pay them 65 %).

- **New config (all optional; defaults are the owner's):** `GIFT_CREATOR_SHARE_PERCENT=70` (a creator's live, every
  recipient a creator; owner, was 72), `GIFT_CREATOR_QUIP_SHARE_PERCENT=60` (quips there; owner 2026-11-06), `CREATOR_AGENCY_COMMISSION=true`
  (agencies earn their commission on their creator members' gifts, from the platform's part; owner 2026-11-06: yes).
  Lucky gifts keep `LUCKY_GIFT_HOST_SHARE_PERCENT`; DM / CP gifts keep theirs.
- **Data checks before the migration** (read-only; run as the migration role):
  - both roles already — a creator member who also holds a hosting permission of another source:
    `SELECT m.user_id, h.source, h.granted_at, m.activated_at FROM creator_members m JOIN live_hosts h ON h.user_id = m.user_id WHERE h.source <> 'CREATOR';`
    The migration does NOT fail on these rows and leaves them untouched (nothing is dropped); the trigger only guards new
    writes. **Owner 2026-11-06 (decided): a person can never be both, and there is no automatic rule** — the team
    resolves each row by hand in the panel by revoking ONE role: «سحب البث» (the host revoke) removes the host permission
    and gives the membership's `CREATOR` permission back at once (audited `live.host.grant` `resolvedBothRoles`), or
    «طلبات صناع المحتوى» → «إلغاء العضوية» ends the membership and the host permission stays. Until then such a person
    keeps the host source and is shown as a creator. **Can such rows exist on staging?** Not ruled out: D285's approval
    of a creator application did not check the hosting permission (its own e2e approved a host as a creator), and D285's
    HOST / CREATOR exclusivity covers the *recruitment attribution* only, not the memberships. So a host approved as a
    creator between the D285 deploy and this migration is a both-roles row — run the query; on a database where no
    creator application was ever approved it returns none.
  - members the backfill skipped (none expected; a room-number clash): after the migration,
    `SELECT m.user_id FROM creator_members m LEFT JOIN live_hosts h ON h.user_id = m.user_id WHERE h.user_id IS NULL;`
    → 0 rows (else run the migration's backfill `INSERT … ON CONFLICT DO NOTHING` again).
- **Checks after deploy:** `SELECT source, count(*) FROM live_hosts GROUP BY 1;` (CREATOR = the members count);
  `SELECT host_share_bps, count(*) FROM live_gifts WHERE created_at > now() - interval '1 day' GROUP BY 1;` (7000 /
  6000 appear once creators receive gifts); `GET /live/rooms?tab=new` alternates host / creator and every row has
  `hostIsCreator`.
- **The agency ban (OWNER):** `banAdminAgency` writes one `agency_bans` row and at most one `AGENCY_FORFEIT` ledger row per
  agency; check `SELECT a.agency_id, a.forfeited_cherries, l.delta FROM agency_bans a LEFT JOIN cherry_ledger l ON l.reason = 'AGENCY_FORFEIT' AND l.reference_id = a.agency_id::text;`
  (`delta = −forfeited_cherries`, none when 0). Money already withdrawn and the members' earnings are never touched (owner,
  decided 2026-11-06). Only the creators the OWNER ticked as fake are revoked (`agency_bans.creator_user_ids`; the
  others stay creators, released from the agency).
- **Rollback:** the API before D295 ignores the new columns and table; the enum values stay. Do not roll back after a
  ban or a creator activation by an agency without the owner (the forfeit is in the ledger).

### 5.77 Reports open their content for the staff, with actions (migration `20270330090000_report_resolution_action`; D296) — [IMPLEMENTED, draft contract v1.93-social; not deployed, not device-tested]

CONVENTIONS §10.109. (§5.73–§5.76 belong to other branches.) The migration adds `reports.resolution_action` (VARCHAR 20,
NULL) with the CHECK `reports_resolution_action_check` (null while OPEN; one of WARN, RESTRICT, SUSPEND, BAN,
REMOVE_CONTENT, DELETE_CONTENT, DELETE_ACCOUNT, DISMISS). Old rows keep NULL. Deploy the migration with (or before) the
API: the new API writes the column on every report action, the panel's too. No new server setting.

- **Tell the team:** in the app, «أنا» › «بلاغات» › a report (or the report's notification) now opens the reported post,
  reel, comment, story, profile, live or — for a message — the **whole conversation** as it was when it was reported
  (owner's decision; every opening is logged). The buttons are the role's: MODERATION warn, restrict, suspend, ban, hide,
  delete for good; the OWNER also deletes an account; SUPPORT the temporary suspension and «تم حله». The two deletions ask
  to type «حذف» / DELETE. An action resolves **only that report**; others on the same item stay in the queue.
- **Storage:** a DM report now copies up to 20 pictures / voice clips of the conversation to `reports/dm/<reportId>/` in
  the media bucket (private); the DM sweeper deletes them with the snapshot 30 days after the report is resolved.
- **The bug:** reporting a person from a conversation, a profile or a live was answered «غير موجود» and never reached the
  team; fixed in the API alone (the apps already in people's hands start working once the API is deployed). Reporting a
  person from a conversation keeps the conversation only with the new app (it sends `dmConversationId`).
- **Checks after deploy:** `SELECT resolution_action, count(*) FROM reports WHERE status <> 'OPEN' GROUP BY 1;`;
  `SELECT count(*) FROM reports WHERE dm_snapshot ? 'thread';`; a test USER report from the app's chat menu shows in
  «بلاغات» with the conversation; the audit rows `moderation.report.dm_read` and `moderation.report.action` with
  `via: app`.

### 5.78 Creator tasks «مهام صانع المحتوى» and the generated catalogue (migrations `20270331090000_creator_tasks_enums`, `20270331090100_creator_tasks`, `20270331090200_task_generator`; D297) — [IMPLEMENTED, draft contract v1.94-social; not deployed, not device-tested]

CONVENTIONS §10.110. The first migration only adds the enum value `program_audience` `CREATORS` (it must commit before
the second uses it); the second adds `task_pool_bands.creator_count` (set to `host_count`), the five metrics and the
group CREATOR to the task CHECKs, seeds the six daily `P_CR_…` templates and the four weekly `CREATOR_WEEKLY_…` tasks
(`ON CONFLICT DO NOTHING`: a row the team already made keeps its values) and the CHECK `events_audience_not_creators`.
No new table, no GRANT, no new setting: the caps are the existing `TASK_DAILY_CAP_CHERRIES` and `TASK_MONTHLY_CAP_MINOR`.
Deploy the API with the migrations (an older API would show members no creator tasks and could not read the band row's
new column — harmless, it never selects it).

- **Seed (only for a database that did not run the migration's insert, e.g. restored from before it):** from
  `/opt/kabso/infra/deploy`, `docker compose --profile jobs run --rm migrate node dist/cli/task-admin.js seed-defaults`
  — prints `Added 0 default task(s), 0 pool template(s) and 10 creator task(s).` the first time, `… and 0 …` after.
- **Checks after deploy:**
  `SELECT code, period, audience, pool_group, band_targets, band_rewards, enabled FROM task_definitions WHERE audience = 'CREATORS' ORDER BY sort_order;`
  (10 rows, all enabled) and `SELECT band, daily_count, host_count, creator_count FROM task_pool_bands ORDER BY band;`
  (creator 2 · 2 · 2 · 3). `task-admin list` prints them with their money; `task-admin bands` prints the creator counts.
- **Changes (owner, no release):** `task-admin set P_CR_VIEWS --targets 100,250,500,1000 --rewards 3000,4000,6000,8000`,
  `task-admin set CREATOR_WEEKLY_SHARES --enabled false`, `task-admin band 4 --creator-count 2` (≤ `--count`). A day's
  creator tasks are fixed at its first read; changes apply from the next day (weekly values from the next read).
- **Follow-up migration `20270331090200_task_generator` (§10.110.1):** the metric `HOST_LIVE_DAYS`, the four extra fixed
  weekly tasks, `task_assignments.variant` accepting `G.…`, and the generator's 32 template rows (`G_CR_…`, `G_HO_…`)
  **switched ON** for both audiences. The catalogue itself is code (315 120 tasks per audience); nothing else to load.
  From the deploy, a creator's or host's NEXT day (and week) without a list comes from the generator; lists already made
  stay. Checks: `task-admin generator status` (ON / ON, 315 120 each), `task-admin generator count --verify`,
  `task-admin generator preview <username>`, and
  `SELECT task_code, count(*) FROM task_assignments WHERE variant LIKE 'G.%' GROUP BY 1;` after the first day.
- **Switch off / on (owner, no release):** `docker compose --profile jobs run --rm migrate node dist/cli/task-admin.js
  generator off CREATORS` (or `HOSTS`) — the hand-made creator / host pool and the fixed weekly tasks (6 / 4) apply from
  the next list; `generator on …` brings the generator back. Audited (`task.update`, target `task_generator`).
- **Interaction with D295 (creators go live):** none at deploy — a member keeps only creator tasks whatever their
  hosting permission. Either order of deploy works.

### 5.79 «مدرسة المحتوى» / Content School and «لاعب الأحكام» / Dares Player (migrations `20270401090000_medal_requirement_metrics`, `20270401090100_medal_content_school`, `20270401090200_medal_dares_player`, `20270401090300_medal_dares_only_points`; D300) — [IMPLEMENTED, draft contract v1.83-live; not deployed, not device-tested]

CONVENTIONS §10.111. Interpretations owner-confirmed 2026-11-07 (creators only, levels kept; ACTIVE accounts, never self;
posts and reels).

- **Migrations, in order.** `20270401090000_medal_requirement_metrics` adds only the five `MedalMetric` values (they
  must commit before the next one uses them); `20270401090100_medal_content_school` adds `medal_level_requirements`,
  `post_views.counted_views` (`INTEGER NOT NULL DEFAULT 1`, CHECK ≥ 1 — the column add is metadata-only on PostgreSQL 16,
  no rewrite; the CHECK is validated by one scan of `post_views` under the migration's lock, seconds at today's size), the medal `CONTENT_SCHOOL`, its four levels and twelve requirements. Runtime role: default
  privileges, no GRANT. Deploy the API with them (an older API would not add to `counted_views`).
- **Setting:** `MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS` (default **600**; 1 … 86 400; `0` is refused in production). Each
  run reads the creators with three indexed sums each and counts exactly only those whose upper bounds reach their next
  level; it logs `Content-creator medals raised` only when something changed.
- **Backfill, once after the deploy** (exact for every creator; without `--notify` so it does not flood inboxes). From
  `/opt/kabso/infra/deploy`:

  ```bash
  docker compose --profile jobs run --rm migrate node dist/cli/medals-admin.js backfill
  ```

  It prints the usual `Awarded n medals.` / `Raised n medal levels.` (with `CONTENT_SCHOOL n` when any); idempotent; a
  second run prints 0 and 0. Views recorded before the migration count once per viewer and post (`counted_views` = 1):
  a lower bound of the real views (accepted by the owner). Likes and views of posts later deleted or removed by
  moderation count too (owner decision).
- **Checks after deploy:** `SELECT level, metric, threshold FROM medal_level_requirements WHERE medal_code =
  'CONTENT_SCHOOL' ORDER BY 1, 2;` (12 rows) and, after the backfill, `SELECT level, count(*) FROM user_medals WHERE
  medal_code = 'CONTENT_SCHOOL' GROUP BY 1;`.
- **«لاعب الأحكام» (§10.111.7):** `20270401090200_medal_dares_player` (the medal and its four levels, 1 500 … 20 000 PK
  points; the enum value comes with the first migration), then `20270401090300_medal_dares_only_points` (owner: «PK
  أحكام» only — renames the metric `PK_POINTS` → `PK_DARES_POINTS`, adds `pk_host_records.dares_points` and fills it
  from the DARES matches' `pk_point_events`, and moves both D300 medals to ACHIEVEMENT with the other medals). From the
  deploy on, each positive DARES points event raises the level in its own transaction; NORMAL matches never do. The same
  one-off `medals-admin backfill` raises every host from `pk_host_records.dares_points` (prints `DARES_PLAYER n`).
  Checks: `SELECT count(*) FROM pk_host_records r WHERE r.dares_points <> coalesce((SELECT sum(e.points) FROM
  pk_point_events e JOIN pk_matches m ON m.id = e.match_id WHERE m.type = 'DARES' AND e.host_id = r.host_id), 0);`
  → 0, and `SELECT level, count(*) FROM user_medals WHERE medal_code = 'DARES_PLAYER' GROUP BY 1;`.
- **App:** the art ships in the app (`assets/medals/medal_content_school_l1` … `_l4.webp`,
  `medal_dares_player_l1` … `_l4.webp`); an older app shows the medal's generic icon and «level / next level» progress.

### 5.80 The app owner's profile «صفحة صاحب البرنامج» (migrations `20270402090000_owner_profile_enums`, `20270402090100_owner_profile`, `20270402090200_owner_announcement_enums`, `20270402090300_owner_announcements`, `20270402090400_owner_profit`; D301) — [IMPLEMENTED, draft contract v1.95-social; not deployed, not device-tested]

CONVENTIONS §10.112. The first migration only adds `notification_type` `OWNER_FEEDBACK_NEW` (it must commit before
anything uses it); the second replaces the `media_assets` kind / duration / poster CHECKs (adds `PROFILE_COVER_VIDEO`,
≤ 60 s with a poster), adds `posts.official_at` (+ the partial index `posts_official_author_published_idx`), the
tables `owner_cover_videos`, `owner_journey_milestones` (CHECKs on the texts, the date and the icon; one «الأحدث» per
owner) and `owner_feedback` (CHECKs on the status, the text and the shape), `notifications.owner_feedback_id` and
`users_last_active_idx` (an index on `users.last_active_at`: on a large `users` table it is built while the migration
holds its lock — a few seconds per million rows). Runtime grants come from the default privileges
(`20261016120000_runtime_role_grants`); no new setting and no new secret. Deploy the API with the migrations; the app
needs the new build for the owner's layout (an older app shows the owner's profile like any other).

- **Who is the owner:** an ACTIVE account holding the OWNER panel role (`admin-admin grant`). Every such account gets
  the layout; revoking the role ends it at once (the stored data stays, unshown).
- **Storage:** the cover videos are stored unchanged like reels (`media/{id}/video.mp4|.mov` + the poster); the
  pictures of «اقترح ميزة / أبلغ عن موظف» go to the private prefix `private/owner-feedback/{id}/{n}.webp` (never public;
  the panel streams them). Nothing deletes them yet (owner question PP-58).
- **Cache:** «لوحة المؤسس» is one Redis key `owner:dashboard:v1` (60 s; under the API's key prefix).
- **Checks after deploy:**
  `SELECT count(*) FROM owner_feedback;` (0), `SELECT conname FROM pg_constraint WHERE conname LIKE 'owner_%';`,
  `\d+ users` shows `users_last_active_idx`; from the app as the owner, «تعديل الملف» shows «فيديو الغلاف»; from another
  account, the owner's profile shows «متابعة المؤسس» and «اقترح ميزة / أبلغ»; the panel shows «صندوق المؤسس» to the
  OWNER only.
- **Rollback:** the API before D301 ignores the new tables and column; the CHECKs accept every older kind.
- **Follow-up (owner, same day) — bilingual announcements:** apply `20270402090200_owner_announcement_enums` (only
  `notification_type` `OWNER_ANNOUNCEMENT`; it must commit first) then `20270402090300_owner_announcements`
  (`posts.text_en`, `posts_official_latest_idx`, the partial unique index `notifications_owner_announcement_once` — built
  over `notifications` while the migration holds its lock — and `owner_announcement_fanouts`). **Fan-out load:** an
  announcement writes one notification row per ACTIVE account, 1 000 per step every 5 s and right after the publish
  (≈ 1 M rows take ≈ 1 h 25 min at the sweeper's pace; several API instances share the work). The pushes go through the
  existing outbox (200 rows a round, `PUSH_DISPATCH_INTERVAL_MS`) with the usual per-person gap, so on a large base most
  people see the row in the app and only part get a push; no new setting. **Checks:**
  `SELECT post_id, recipients, done_at FROM owner_announcement_fanouts ORDER BY started_at DESC LIMIT 5;` and the audit
  `owner.announcement.fanout_done`.
- **Owner answers (PP-58):** the inbox keeps items until the owner deletes them (`deleteAdminOwnerInboxItem` also
  deletes the private pictures); «دخل اليوم» counts only money Kabso receives (store card top-ups less refunds + agents'
  stock purchases), other currencies on their own lines.
- **The founder in search (§10.112.9):** `GET /search/featured` (no migration, no setting): the app's search shows the
  primary ACTIVE OWNER first (a card before typing, a pinned row while typing). Check: as an ordinary account, the
  search screen shows the founder's card; as an account blocking him (or blocked by him), nothing.
- **«الربح» and the fixed costs (§10.112.10):** apply `20270402090400_owner_profit` (the table `owner_fixed_costs` and
  the small partial index `wallet_ledger_free_coins_idx` — built over `wallet_ledger` while the migration holds its lock;
  only event-prize, task and check-in coin rows are indexed). Settings read (no secret): `CHERRY_PAYOUT_RATE` (owner:
  `1000000:110`, $1.10 per 1 000 000 cherries — the same value the withdrawals use), `ADMIN_REPORT_CARD_FEE_BPS` /
  `_FIXED_MINOR` (owner CP-039 Q3: 290 / 30 — the store records card amounts gross), `ADMIN_DASHBOARD_TIME_ZONE`, and the
  new `OWNER_PROFIT_COIN_VALUE_MINOR_PER_MILLION` (default 1200: the owner's lowest agent price, $120 per 10 000 000
  coins; read only by «الربح»). The owner enters the fixed costs himself (app or panel «التكاليف الثابتة»); until then
  «بعد» counts none. **Checks:** `SELECT count(*) FROM owner_fixed_costs;`; as the owner, `GET /owner/profit` answers
  with «قبل» equal to the dashboard's income (plus held chargebacks) and «بعد» below it.

### 5.81 The staff sign in with the staff ID (no migration; D302) — [IMPLEMENTED, draft contract v1.84-live; not deployed, not device-tested]

CONVENTIONS §10.96.12 (D302). `login` (app) and `adminLogin` (panel) also take the official staff ID («Kabso01», any
case, `@`, leading zeros; «Kabso» for the primary OWNER) and resolve it to its **current** holder through `staff_ids`
(already readable by the runtime role since D283c). **No migration, no new setting, no GRANT.** Deploy the API with
the apps; an older app or panel just does not mention the staff ID in its field label (an older panel's email-type
field refuses a staff ID in the browser — the email keeps working).

- **Checks after deploy:** sign in to the app with a staff member's `Kabso01` (and `kabso1`) and their password → 200,
  `user.staffId = Kabso01`; a revoked or suspended staff member's number with the right password → 401
  `AUTH_INVALID_CREDENTIALS`; the panel with `Kabso01` + password → `next: TOTP_VERIFY` (the authenticator code is
  still asked). `SELECT metadata FROM audit_logs WHERE action = 'auth.login.success' ORDER BY created_at DESC LIMIT 5;`
  shows `{"identifierType": "staff_id"}` for those sign-ins.
- **Rollback:** the previous API simply reads a staff ID as a username / email again (no data to undo).

### 5.67 Staff work without a code, and the automatic shift (migration `20270320090000_staff_auto_shift`; D286) — [IMPLEMENTED, draft contract v1.76-live; not deployed, not device-tested]

CONVENTIONS §10.96.14. The migration adds `admin_shifts.started_via` (`panel | app | auto`, CHECK, default `panel` for
the existing rows) and `admin_shifts.last_activity_at` (with a partial index of the automatic shifts on), and replaces
the CHECK `account_restrictions_shape` so it accepts `via = 'app'` (a fix: the app's timed NO_LIVE / SUSPEND failed).
Deploy with the API: an older API never writes `auto`.

- **Settings:** `STAFF_SHIFT_IDLE_OFF_SECONDS` (default 7200 = 2 h; 0 = never; ≤ 86 400) — an automatic shift goes off
  after this long without staff work (checked at `LIVE_SWEEP_INTERVAL_SECONDS`). `STAFF_APP_GRANT_SECONDS` and
  `RATE_LIMIT_STAFF_STEP_UP_USER` now only serve the deprecated step-up route.
- **Tell the team:** the app's staff tools no longer ask for the authenticator code; entering a live as staff, using a
  tool or opening «بثوثي» (app or panel) turns «في المناوبة» on — turn it off by hand when the shift ends (else it goes
  off after 2 h without staff work, unless it was switched on by hand). The code is still asked for the panel sign-in,
  device bans, the team's roles / regions / authenticator resets, every money action and the settings.
- **Checks after deploy:** `SELECT started_via, count(*) FROM admin_shifts WHERE on_shift GROUP BY 1;` and the audit
  rows `admin.shift.on` / `admin.shift.off` with `"via": "auto"`.

### 5.66 Recruitment by staff «الاستقطاب» and the role BD (migrations `20270319090000_staff_recruits_enums`, `20270319090100_staff_recruits`; D285) — [IMPLEMENTED, draft contract v1.75-live; not deployed, not device-tested]

CONVENTIONS §10.96.13. Deploy the two migrations in order (the first only adds enum values: `admin_permission` BD and
`cherry_ledger_reason` STAFF_RECRUIT_COMMISSION). The second adds `recruiter_user_id` to the agency, recharge and host
applications, the creator programme (`creator_applications`, `creator_members`), `staff_recruitments`,
`staff_recruit_settings` (one row, the owner's defaults **1 %** hosts / creators / agencies, **0.75 %** recharge agents)
and `staff_recruit_commissions` (**append-only** for the runtime group; CHECK `staff_recruit_commissions_guard`), extends
the ledger sign rule and lets `kabso_admin_panel_role` grant BD.

- **Settings:** `RECRUIT_COMMISSION_SWEEP_INTERVAL_SECONDS` (default 3600 = hourly; it pays only finished days, each
  once; **0 is refused in production**), `RECRUIT_COMMISSION_CATCH_UP_DAYS` (7, 1–60: how many past days a run still pays
  after the API was down — older unpaid days are lost, so keep the API up or raise it before a long pause). The day is
  `LIVE_RANKINGS_TIME_ZONE`'s. The money constants are D281's (`COIN_RETAIL_USD_PER_MILLION`, `CHERRY_PAYOUT_RATE`,
  `CHERRIES_PER_COIN`, `GIFT_HOST_SHARE_PERCENTS`, the lucky RTP / share); a recharge top-up counts only in
  `CHERRY_PAYOUT_CURRENCY`.
- **Granting BD:** «الموظفون والصلاحيات» (OWNER, code + reason) or `pnpm admin:admin grant <email|@username|KabsoNN> BD`
  (it gets the next staff ID). BD signs in to the panel (authenticator enrolment as every role) and sees only
  «استقطاباتي». Set its regions on the same page for its line «تطوير الأعمال — الوطن العربي».
- **The OWNER:** «الاستقطاب» (shares per type, per staff member, reassign a recruit — code + reason, audited) and «طلبات
  صناع المحتوى» (OWNER, SUPPORT). Commissions are withdrawable cherries: staff withdrawals arrive in «السحوبات» like any.
- **Checks after deploy:** `SELECT * FROM staff_recruit_settings;` shows 100 / 100 / 100 / 75; the log line
  `Recruit commissions paid` appears once a day has finished with recruits.

### 5.65 The primary OWNER's staff ID «Kabso» (migration `20270318090000_staff_ids_owner`; D283d) — [IMPLEMENTED, draft contract v1.74-live; not deployed, not device-tested]

CONVENTIONS §10.96.12. Runs right after §5.64's migration (deploy them together). It replaces the CHECK with
`staff_ids_number_nonnegative` (`>= 0`), replaces `kabso_assign_staff_id(uuid)` with `kabso_assign_staff_id(uuid,
boolean)` (no runtime EXECUTE) and `kabso_admin_panel_role`, then **renumbers** `staff_ids`: the account holding OWNER
with the earliest OWNER grant becomes number 0 — shown as plain **«Kabso»** — and every other row 1, 2, 3, … in its
order (so the first staff member is `Kabso01`). Safe only because no staff ID has been released yet; never renumber
after release. Check with `pnpm admin:admin list` (the primary OWNER's line starts with `Kabso`). Any later OWNER gets the
next number. No env setting. The app shows the staff region line only in the official bio card (no server change).

### 5.64 The official staff ID «Kabso01» (migration `20270317090000_staff_ids`; D283c) — [IMPLEMENTED, draft contract v1.73-live; not deployed, not device-tested]

CONVENTIONS §10.96.12. The migration creates `staff_ids` (`number` PK with CHECK `staff_ids_number_positive`, `user_id`
UNIQUE with FK `ON DELETE SET NULL`, `assigned_at`) and **revokes INSERT / UPDATE / DELETE / TRUNCATE from the runtime
group** (read-only, like `user_admin_permissions`; KL-013 test updated); adds the SECURITY DEFINER function
`kabso_assign_staff_id(uuid)` (no runtime EXECUTE) and replaces `kabso_admin_panel_role` so that every grant gives the
person their number in the same transaction (advisory lock `kabso:staff-id`, MAX + 1). It then **backfills** the current
holders of OWNER / MODERATION / SUPPORT / FINANCE in the order of their first grant — (D283d, §5.65, then makes the
primary OWNER «Kabso» and the staff Kabso01, …). Check after the deploy with `pnpm admin:admin list` (each line now starts with the staff ID). No env setting.

- **Numbers are retired, never reused:** a revoke keeps the number for the person (hidden while they hold no role) and
  a re-grant shows it again; never delete rows from `staff_ids` by hand.
- **Usernames** that look like a staff ID (`kabso` + digits, any case, look-alikes such as `kabs0`) are now refused for
  new accounts and username changes; existing accounts that already have one keep it (tell support if one exists).
- **Order:** API (with its migration) first, then the panel, then the app; older apps simply keep showing the @username.
  **Rollback:** an older API ignores the table; the replaced `kabso_admin_panel_role` keeps working with it (it only also
  writes `staff_ids`).

### 5.63 The Kabso Team's limited accounts and regions (migration `20270316090000_staff_limits_regions`; D283) — [IMPLEMENTED, draft contract v1.72-live; not deployed, not device-tested]

CONVENTIONS §10.96.10–11. The migration adds `posts.announcement` (`BOOLEAN NOT NULL DEFAULT false`),
`user_profiles.staff_avatar` (`BOOLEAN NOT NULL DEFAULT false`) and `staff_saved_avatar_url` (CHECK
`user_profiles_staff_saved_avatar`: only while `staff_avatar`), and the table `admin_staff_regions` (`user_id`, `region`,
`assigned_at`; CHECK `admin_staff_regions_code` with the 13 region codes; FK cascade to `users`). Constant defaults:
metadata-only, no rewrite; the runtime role gets DML through the default privileges (KL-013 test added). No env setting
(the team picture's URL uses `API_PUBLIC_URL`, default `https://api.kabsolive.com`).

- **At the API's start** every MODERATION / SUPPORT / FINANCE account without OWNER gets the team picture as its
  `avatar_url` (its own photo URL kept in `staff_saved_avatar_url`), and an account no longer such gets its photo back —
  so the first start after the deploy applies it to the existing staff. Grants and revokes (panel and `admin-admin` CLI)
  apply it at once; a CLI grant uses the CLI process's `API_PUBLIC_URL` and the next API start corrects a different one.
  The picture is served by the API at `GET /api/v1/staff/team-avatar.png` (public; the file
  `apps/api/assets/staff/kabso_team_avatar.png` is copied into the image — the Dockerfile copies `apps/api/assets`).
- **Behaviour change for those accounts only** (tell the staff): no going live (every mode), no hosting application or
  scheduled live, posts and reels only as an official announcement «إعلان رسمي — فريق كابسو» (no stories, no reposts), no
  family (create / join), no VIP or store purchase, no tasks / check-in, the picture, cover and frame cannot be changed,
  no levels anywhere (their points still accrue). The OWNER's account is unchanged. Older apps: staff see their usual
  menus but the server refuses with 403 `STAFF_ACCOUNT_LIMITED`; the team picture shows (it is their `avatarUrl`).
- **Regions:** the OWNER assigns them in «الموظفون والصلاحيات» → the member's «المناطق» (the code again and a reason;
  audited `admin.team.regions`). Until then nobody has a region and the assignment is by load, as before.
- **Order:** API (with its migration) first, then the panel, then the app. **Rollback:** an older API ignores the new
  columns and table, but the staff's `avatar_url` stays the team picture's URL (served only by this version) — before
  rolling back run `UPDATE user_profiles SET avatar_url = staff_saved_avatar_url, staff_saved_avatar_url = NULL,
  staff_avatar = false WHERE staff_avatar;`.

### 5.83 Gift events «فعاليات الهدايا» and animated / video banners (migrations `20270404090000_gift_events_enums`, `20270404090100_gift_events`; D303) — [IMPLEMENTED API + panel; app partial (see the board); draft contract v1.97-social; not deployed, not device-tested]

CONVENTIONS §10.114. (Numbers chosen above every other branch's: §5.79–§5.82 belong to D300–D302.) The first migration
only adds enum values (`event_metric` `EVENT_GIFTS`, `bag_item_source` `EVENT`, `cherry_ledger_reason` `EVENT_PRIZE`,
`notification_type` `EVENT_PRIZE_WON`); they must commit before the second uses them. The second adds `event_gifts`,
`event_boards`, `event_prize_payouts` (the runtime role gets DML through the default privileges), `events.time_zone` /
`created_by_id`, the `event_results` board columns (existing rows become board `MAIN`, `entrant_key` = their user; the
two unique indexes are recreated per board), `home_banners.kind` / `video_media_id` / `event_id`, `notifications.event_id`,
the media kind `BANNER_VIDEO` and the duration / poster CHECKs for banner media, the cherry reason/sign rule for
`EVENT_PRIZE`, and relaxes `events_audience_not_creators` to gift events. Deploy the API with the migrations (an older API
does not know the new metric; it never creates one).

- **No new setting.** The sweeper is the existing `EVENTS_SWEEP_INTERVAL_SECONDS` (must not be 0 in production: gift
  events are frozen and paid by it **automatically at the end**; `EVENT_PRIZE_REVIEW_HOURS` applies to the D166 events
  only). The video body limit (31 MB raw on `POST /api/v1/admin/banner-video-uploads`) is in the API; a reverse proxy in
  front of the API must allow at least **31 MB** request bodies on that path (as for the level-raise videos, §5.71).
- **Follow-ups (same migrations):** `event_badges` + `event_badge_levels` (medals with levels) and `user_event_badges`
  (`expires_at` null = permanent), `events.background_key` / `background_poster_key` / `title_key` / `overlay_key`
  (CHECK `events_art_keys`), media kind `EVENT_VIDEO` is never a media row (event art lives under `media/events/…` in
  the media bucket; nothing sweeps it — delete unused art by hand if needed). Raw upload paths needing a 31 MB proxy
  limit: `/api/v1/admin/banner-video-uploads`, `/api/v1/admin/event-uploads`, `/api/v1/staff/event-uploads`.
- **With D301 (integration `claude/kl-int17`):** D301's `20270402090100_owner_profile` and this branch's
  `20270404090100_gift_events` both rewrite the `media_assets` CHECKs `media_assets_kind_known`,
  `media_assets_duration_shape` and `media_assets_poster_shape`; applied in order, the second dropped
  `PROFILE_COVER_VIDEO`. `20270406090000_media_kind_checks_merge` (after `20270405090000_global_strip_settings`)
  restores the union (PROFILE_COVER_VIDEO and BANNER_VIDEO). Apply all three with the same deploy; until it runs the
  owner's cover-video upload fails (500). Check: `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname =
  'media_assets_kind_known';` names both kinds.
- **Who can create:** the capability `events.manage` is **OWNER only** (code: `admin-permissions.ts`); widening it is a
  code change the owner decides (PP-60).
- **Checks after deploy:** `SELECT count(*) FROM event_results WHERE board <> 'MAIN';` (0 before any gift event);
  `\d event_prize_payouts` (unique `event_prize_payouts_once`); `SELECT kind, count(*) FROM home_banners GROUP BY kind;`
  (every existing row `IMAGE`). In the panel «البانرات والفعاليات»: create a gift event (it lists with state UPCOMING or
  RUNNING), upload a short MP4 as a home banner with a poster and open `GET /api/v1/home/banners` (kind `VIDEO`).
- **Running an event:** the leaderboards are live (`/events/{id}/leaderboard?board=…`). Suspected fraud: **hold** the
  payout (panel «إيقاف الصرف» or the app) before the end; investigate; `release` (or leave held). Paid prizes are not
  taken back by the system: a reversal is manual (`control-admin` / panel balance adjustment; bag items with `bag-admin
  revoke`).
- **After an event:** `SELECT r.board, r.rank, r.prize_status, p.status FROM event_results r LEFT JOIN event_prize_payouts p
  ON p.result_id = r.id WHERE r.event_id = '<id>' ORDER BY r.board, r.rank;` and the `event.payout` audit row.

### 5.84 The global strips «شريط الهدايا» and «شريط الألعاب» (migration `20270405090000_global_strip_settings`; D305) — [IMPLEMENTED, draft contract v1.85-live; not deployed, not device-tested]

CONVENTIONS §10.115. §5.81–§5.83 belong to other branches.

- **Migration:** `20270405090000_global_strip_settings` adds `notification_settings.gift_strip` and `game_strip`
  (BOOLEAN NOT NULL DEFAULT true). An existing table: no GRANT, no backfill (no row = all on, as before). Apply with the
  API image as usual (`prisma migrate deploy`); old API versions ignore the columns.
- **Migration (2):** the same migration extends the `site_settings` key CHECK with `globalStrips` (the panel's
  thresholds; no row inserted).
- **Thresholds:** the OWNER sets both in the panel («إعدادات الموقع» → «شريطا الهدايا والألعاب»; `site.settings`,
  audited; effective within 30 s, no restart). Fallback configuration (API `.env`, restart): `GIFT_GLOBAL_TICKER_MIN_COINS`
  default **500 000** on ONE gift's price (was 1 000 on the send's total: a server that set its own value keeps it —
  check `.env`), `GAME_WIN_TICKER_MIN_TICKETS` default **1 000 000**.
- **Behaviour change on deploy:** a gift strip now also shows in the live where the gift was sent (apps before this
  version ignore that message there, so nothing changes for them); the gift strip pace is unchanged (one every 3 s for
  the whole service); game wins have their own lane and gate (one every 3 s), so both strips can show at once.
- **Games:** no game pays ticket prizes yet; the hook a game calls is `LiveGiftTickerService.offerGameWin` (§10.115).
  Nothing to configure until a game exists.
- **Order:** API (with its migration) first, then the panel, then the app (the app reads `giftStrip` / `gameStrip` with a default of on,
  so an older API is fine). **Rollback:** an older API ignores the two columns; `GIFT_GLOBAL_TICKER_MIN_COINS` falls
  back to 1 000 unless set.

### 5.85 Recharge-agent price tiers $12.15 / $12.10 / $12.00 (no migration; D306) — [IMPLEMENTED; config default only]

CONVENTIONS §10.48 (owner 2026-11-07).

- **Setting:** `RECHARGE_AGENT_PRICE_TIERS` default is now `0:1215,100000000:1210,300000000:1200` (USD cents per
  1 000 000 coins: $12.15 below 100 000 000, $12.10 from 100 000 000, $12.00 from 300 000 000; was
  `0:1200,100000000:1195,300000000:1190`). `RECHARGE_AGENT_ACTIVATION_MIN_COINS` is unchanged (30 000 000).
- **Server:** the owner has already set `RECHARGE_AGENT_PRICE_TIERS=0:1215,100000000:1210,300000000:1200` in the API
  env (`/etc/kabso/api.env`); keep it (or remove it to use the same default). It is read when the container starts:
  after a change recreate the API (`docker compose up -d api` from `/opt/kabso/infra/deploy`, as `update.sh` does;
  `docker compose restart` does not re-read `env_file`). Check with
  `docker compose exec api printenv RECHARGE_AGENT_PRICE_TIERS`.
- **Effect:** only new `recharge-admin topup` records use the new prices (a different paid amount still needs
  `--note`); top-ups already recorded keep their stored tier and price. «الربح» (D301) still values given-away coins at
  `OWNER_PROFIT_COIN_VALUE_MINOR_PER_MILLION` = 1200, now equal to the lowest tier.
- **Rollback:** set the old value `0:1200,100000000:1195,300000000:1190` and recreate the API.

### 5.86 The founder's page: bilingual bio, no team badge, the video with sound (migration `20270407090000_owner_bio`; D307) — [IMPLEMENTED, draft contract v1.98-social; not deployed, not device-tested]

CONVENTIONS §10.112.1, §10.112.11 (owner 2026-11-08).

- **Migration:** `20270407090000_owner_bio` creates `owner_bios` (one row per owner: `bio_ar`, `bio_en`, each null or
  1–300 characters; FK to `users`, ON DELETE CASCADE). A new table: runtime grants come from the default privileges
  (`20261016120000_runtime_role_grants`); no backfill (no row = the app's default founder text). Apply with the API
  image as usual (`prisma migrate deploy`); older API versions ignore the table.
- **API:** `PUT /api/v1/owner/bio` (`setOwnerBio`, owner only, audited `owner.bio.update`); `ownerBio` on
  `GET /users/{username}` and `GET /me` for the owner only. No setting, no env variable.
- **App:** the founder's page shows no «فريق كابسو» badge, plays the cover video by itself **with sound** (mute button
  kept; it pauses when the page is left or covered and in the background) and shows the bio in the app's language
  (else the built-in default text). The owner edits the bio in «لوحة المؤسس» → «بايو المؤسس».
- **Order:** API (with its migration) first, then the app (an older API sends no `ownerBio`: the app shows the default
  text). **Rollback:** an older API ignores `owner_bios`; an older app ignores `ownerBio` (it shows the ordinary bio).

### 5.87 Recharge agents' cherry rate 94 500 (no migration; D308) — [IMPLEMENTED; config default only]

CONVENTIONS §10.48 (owner 2026-11-08).

- **Setting:** `RECHARGE_AGENT_CHERRY_RATE` default is now `1000000:94500` (1 000 000 cherries a host sells to an agent
  → 94 500 coins in the agent's stock, rounded down; was `1000000:93220`). Minimum, step, cap and the host's cash
  payout (`CHERRY_PAYOUT_RATE`) are unchanged.
- **Server:** the owner has already set `RECHARGE_AGENT_CHERRY_RATE=1000000:94500` in the API env
  (`/etc/kabso/api.env`); keep it (or remove it to use the same default). It is read when the container starts:
  after a change recreate the API (`docker compose up -d api` from `/opt/kabso/infra/deploy`); check with
  `docker compose exec api printenv RECHARGE_AGENT_CHERRY_RATE`.
- **Effect:** only requests created after the API restarts use the new rate (`coins` is computed at creation and
  stored on the request); conversions already confirmed — and open requests created before — keep their stored
  amounts. The app reads the rate from the server (`coinsPerCherryUnit`), so no app update is needed.
- **Rollback:** set `1000000:93220` and recreate the API.

### 5.88 The four «first» medals retired (migration `20270407090100_medal_retire_firsts`; D313) — [IMPLEMENTED; no contract change; not deployed]

CONVENTIONS §10.104.8a (owner 2026-11-08).

- **Migration:** `20270407090100_medal_retire_firsts` sets `medals.retired` for `FIRST_LIVE`, `BULLET_FIRST`,
  `FIRST_FAMILY`, `FIRST_CP`, clears their showcase positions and renumbers each affected person's remaining worn medals
  (D291's SQL). Data only, idempotent in effect; apply with the API image as usual (`prisma migrate deploy`). Nothing to
  configure; no backfill (the earned rows stay as history). Run `medals-admin backfill` only as before — it awards
  nothing retired.
- **Effect at once:** the medals page, profiles and showcases stop showing the four; nobody is notified. An older API
  ignores the flag only if rolled back below D291 (not supported).
- **Rollback:** `UPDATE medals SET retired = false WHERE code IN ('FIRST_LIVE','BULLET_FIRST','FIRST_FAMILY','FIRST_CP');`
  (the cleared showcase positions are not restored).

### 5.89 Rooms rank by cherries (migration `20270408090000_live_room_cherries`; D310) — [IMPLEMENTED, draft contract v1.86-live; not deployed, not device-tested]

CONVENTIONS §10.116 (owner 2026-11-08). §5.86–§5.88 are another branch's.

- **Migration:** adds `live_rooms.cherries` (CHECK ≥ 0), backfills the rooms that are LIVE at that moment from the cherry
  ledger, and swaps the two popular indexes (score → cherries). It reads `cherry_ledger` joined to the live sends of the
  rooms LIVE now only; on a busy database run it at a quiet hour. No setting, no GRANT (default privileges).
- **Behaviour change on deploy:** «الرائج» (`tab=popular`), «مميز» and «رائج» order by the room's cherries; taps no longer
  move a room. The live cursor moves to v3: an app paging across the deploy gets one 400 `cursor` and reloads. The
  popularity boards and PK are unchanged (points).
- **Order:** API (with the migration) first, then the app (it reads `cherries` / `roomCherries` and falls back to the
  host's cherries on an older server). **Rollback:** an older API ignores the column (its index on the score is gone:
  re-create `live_rooms_live_popular_idx` / `live_rooms_live_cat_popular_idx` from `20261028090000_live_taps` if rolling
  back for long).

### 5.90 «إجراءات المؤسس» — the founder's moderation actions (migration `20270408090300_owner_moderation`; D311) — [IMPLEMENTED, draft contract v1.99-social; not deployed, not device-tested]

CONVENTIONS §10.117 (owner 2026-11-08).

- **Migration:** the table `owner_moderation_actions` (one row per action, keyed by the app's `clientId`). No GRANT.
- **New optional setting:** `RATE_LIMIT_OWNER_MODERATION_USER` (default `30/900`). Nothing else to configure: the owner
  is whoever holds the OWNER panel role (D301).
- **Security note (owner decision):** these actions need no authenticator code for the OWNER in the app (the panel and
  every other role keep their step-up rules, D286 / D288). Every action is audited (`owner.moderation.action` and the
  reused `admin.user.*` / `account.deletion.requested` rows, `via: app`).
- **Order:** API first, then the app (an older API answers 404 and the app shows the error in the dialog).
  **Rollback:** an older API ignores the table.

### 5.91 Custom gifts «مُخصَّص» (migrations `20270408090100_custom_gift_enums`, `20270408090200_custom_gifts`; D312) — [IMPLEMENTED, draft contract v1.100-social; not deployed, not device-tested]

CONVENTIONS §10.118 (owner 2026-11-08).

- **Migrations, in order:** the enum values (`gift_category_kind` `CUSTOM`, `wallet_ledger_reason` `GIFT_OWNER_ROYALTY`,
  `GIFT_OWNER_ROYALTY_REVERSAL`; their own migration), then `gifts.owner_user_id` (FK RESTRICT, CHECK
  `gifts_custom_owner`), the seeded category `CUSTOM` «مُخصَّص» (sort 60), the ledger's sign rule extended in place and the
  index `wallet_ledger_gift_owner_idx`. `prisma migrate deploy` applies both in order.
- **New optional settings (API env, defaults are the owner's):** `GIFT_CUSTOM_SHARE_PERCENT=60` (the recipients' share
  of a custom gift everywhere), `GIFT_CUSTOM_OWNER_PERCENT=3` (the gift owner's coins). Read at start: recreate the API
  after a change (`docker compose up -d api`). Each send stores its share, so a change applies to later sends only.
- **Panel:** «الهدايا» → choose «مُخصَّص» → «صاحب الهدية (Kabso ID)» is required (an ACTIVE account). The category can be
  renamed / reordered in «التصنيفات», never turned off.
- **Reversal:** `economy-admin reverse-gift <send>` now also takes the owner's coins back (may leave a negative balance).
- **Order:** API first, then the panel, then the app (an older app shows the custom tab as a plain tab and sends with
  coins; a bag send of a custom gift is refused by the API). **Rollback:** an older API cannot read a gift whose category
  is CUSTOM as special — disable the custom gifts first.

### 5.92 The boards' month and year (migration `20270408090400_live_rankings_month_year`; D314) — [IMPLEMENTED, draft contract v1.87-live; not deployed, not device-tested]

CONVENTIONS §10.119 (owner 2026-11-08).

- **Migration:** the table `live_host_points_monthly` (host, local month start, points) and a backfill from the hourly
  rows still kept (15 days), months taken in **UTC**. No new config: the months follow `LIVE_RANKINGS_TIME_ZONE`.
- **A server whose `LIVE_RANKINGS_TIME_ZONE` is not UTC** re-runs the backfill with its zone, once, right after the
  migration and **before** the new API takes traffic (replace `Asia/Riyadh`):
  `TRUNCATE live_host_points_monthly; INSERT INTO live_host_points_monthly (host_user_id, month_start, points) SELECT
  host_user_id, date_trunc('month', hour_start AT TIME ZONE 'Asia/Riyadh') AT TIME ZONE 'Asia/Riyadh', SUM(points) FROM
  live_host_points_hourly GROUP BY 1, 2 HAVING SUM(points) > 0;` (as the migration role).
- **Do not change `LIVE_RANKINGS_TIME_ZONE` afterwards** without re-running that backfill (the monthly rows are keyed by
  the zone's months; older months cannot be rebuilt once their hourly rows are swept).
- **Order:** API first (an older app never asks for MONTH / YEAR), then the app. **Rollback:** an older API ignores the
  table (left in place; the sweeper of the new API removes rows after 400 days).

### 5.93 «مجنون اللعب» — game tickets spent (migration `20270408090500_game_ticket_spends`; D315) — [IMPLEMENTED as a hook, draft contract v1.88-live; not deployed, not device-tested]

CONVENTIONS §10.120 (owner 2026-11-08).

- **Migration:** the ledger `game_ticket_spends` (unique `(game_code, reference)`) and its rollups
  `game_ticket_spends_hourly` / `game_ticket_spends_monthly`. Empty until a game exists.
- **New optional setting (API env):** `LIVE_GAMES_ENABLED=false` (default). Keep it false — the app hides the
  «مجنون اللعب» tab — until the first game ships and records each spend with `recordGameTicketSpendIn` in the transaction
  that debits the tickets; then set `true` and recreate the API (`docker compose up -d api`). The API answers
  `board=GAMES` either way.
- **Order:** API first, then the app (an older app has no third tab). **Rollback:** an older API ignores the tables and
  never sends `gamesEnabled` (the app reads it as false: the tab hides).

### 5.94 Lucky wins in the chat (D318; no migration) — [IMPLEMENTED, draft contract v1.89-live; not deployed, not device-tested]

CONVENTIONS §10.121 (owner 2026-11-08).

- **New optional setting (API env):** `LUCKY_CHAT_MIN_MULTIPLIER=250` — must be one of `LUCKY_GIFT_MULTIPLIERS` (the API
  refuses to start otherwise; check it when changing the multipliers). The OWNER's panel value («إعدادات الموقع» →
  «شريطا الهدايا والألعاب» → «مكاسب الحظ في التكست») wins and applies within 30 s without a restart.
- **Order:** API, then the panel, then the app (an older app keeps a line for every win; an older panel leaves the value
  as it is). **Rollback:** an older API ignores the extra field in the `globalStrips` row.

### 5.95 Data messages through a short LiveKit outage (D319; no migration, no config) — [IMPLEMENTED; not deployed]

CONVENTIONS §10.123. Nothing to set: `broadcastData` retries a 503 / 404 in the background for ≈ 11.5 s. After deploying,
a `data message (topic …) to room … dropped after 5 retries` warning in the API logs means LiveKit had the room closed
for longer — look at the host's connection / LiveKit's `departure timeout`, not at the API.

### 5.96 «الأغنى» — the Richest board (migration `20270408090600_live_rich_board`; D320) — [IMPLEMENTED, draft contract v1.90-live; not deployed, not device-tested]

CONVENTIONS §10.124 (owner 2026-11-08).

- **Migration:** the tables `gift_coins_sent_hourly` / `gift_coins_sent_monthly` and a backfill from the sends kept —
  `live_gifts` not reversed and `cp_gifts`: hourly rows for the last 15 days, monthly rows for the last 400 days, months
  in **UTC**. No new config.
- **A server whose `LIVE_RANKINGS_TIME_ZONE` is not UTC** re-runs the monthly part with its zone, once, right after the
  migration and before the new API takes traffic (replace `Asia/Riyadh`; as the migration role):
  `TRUNCATE gift_coins_sent_monthly; INSERT INTO gift_coins_sent_monthly (user_id, month_start, coins) SELECT user_id,
  date_trunc('month', created_at AT TIME ZONE 'Asia/Riyadh') AT TIME ZONE 'Asia/Riyadh', SUM(coins) FROM (SELECT
  sender_id AS user_id, created_at, total_coins AS coins FROM live_gifts g WHERE total_coins > 0 AND created_at >= now() -
  interval '400 days' AND NOT EXISTS (SELECT 1 FROM cherry_ledger c WHERE c.reference_id = g.id::text AND c.reason =
  'GIFT_REVERSAL') UNION ALL SELECT sender_id, created_at, amount FROM cp_gifts WHERE amount > 0 AND created_at >= now() -
  interval '400 days') s GROUP BY 1, 2;`
- **Order:** API first, then the app (an older app keeps its greyed «قريبًا» tab). **Rollback:** an older API ignores the
  tables; a newer app then gets 400 on `board=RICH` and shows the error text on that tab.

### 5.97 Gift prices up to 100 000 000 coins (migration `20270408090700_gift_price_cap`; D323) — [IMPLEMENTED, draft contract v1.91-live; not deployed]

CONVENTIONS §10.23 (owner 2026-11-08: «تاج الافتتاح» at 3 000 000 coins).

- **Migration:** redefines the CHECK `gifts_price_range` as `price_coins BETWEEN 1 AND 100000000 OR (price_coins = 0
  AND category = 'QUIPS')` (was 1 000 000). A metadata change on `gifts` (a quick table scan under a short lock); no
  data change, no new config.
- **Order:** migration, then the API, then the admin panel (an older panel still stops at 1 000 000 in the browser; an
  older API refuses more than 1 000 000 with 400). Then the owner creates or edits the gift in «الهدايا».
- **Also in this release:** the host-target and recruit reports compute a recipient's share of a send's charge in
  `numeric` (a large send to many recipients made them fail with `bigint out of range`).
- **Rollback:** an older API keeps working with gifts priced above 1 000 000 (it reads and sends them; only its admin
  validation refuses such a price on an edit). Re-adding the old CHECK fails while such a gift exists — lower those
  prices first (`gift-admin update <code> --price …`).


### 5.99 Events v2 «الفعاليات» (migrations `20270409090000_events_v2_enums`, `20270409090100_events_v2`; D325) — [IMPLEMENTED, draft contract v1.101-social; not deployed, not device-tested]

CONVENTIONS §10.127 (owner 2026-11-08 / 11-09: one events system; phase A — server and panel). §5.98 is left for D324.

- **Migrations:** (1) a new enum `event_audience` and the notification type `EVENT_STARTED` (their own migration: enum
  values are used by the next one). (2) `events` gains `status` (every existing row `PUBLISHED`), `recurrence`
  (`NONE`), `period` / `period_starts_at` / `period_ends_at`, `scoring` (`MULTIPLIER`), `counted_gifts`
  (`EVENT_GIFTS`), `banner_media_id`, `start_notified_at` and `published_at` (both set to `created_at` on existing rows,
  so **no start notification is sent for an event that already exists**); `starts_at` becomes nullable (drafts only,
  CHECK `events_shape`); `events.audience` moves to `event_audience` (same values plus AGENCIES, CP);
  `event_gifts.points_per_coin` becomes NUMERIC(7,2) (the integers keep their value); `event_results.period` (0) with
  its unique keys rebuilt; new tables `event_periods` (filled with period 0 of every frozen event), `event_milestones`,
  `event_milestone_grants`; `gifts.event_id`, `store_items.event_id` (FK RESTRICT, partial indexes, CHECKs
  `gifts_event_plain`, `store_items_event_exclusive`); a partial unique index on `notifications`. Table rewrites:
  `events` and `event_gifts` (`ALTER COLUMN … TYPE`; small tables) — a short lock; `event_results` index rebuild.
- **Behaviour once deployed:** running D166 / D303 events go on under their rules (verified by their e2e suites). The
  events sweeper (`EVENTS_SWEEP_INTERVAL_SECONDS`) now also announces each published event's start once to its
  audience (one `INSERT … SELECT` of up to every ACTIVE account — EVERYONE events write one notification row per
  account; pushed by the general outbox within its 10-minute window), rolls recurring periods over, and gives
  milestones. No new config. A gift event's board shows the top 20 (was 100).
- **Order:** migrations, then the API, then the admin panel (the new «الفعاليات» page; an older panel keeps its D303
  editor, which sends published bodies only). The app needs no update (drafts never reach it; new fields are additive).
- **Launch festival:** nothing is seeded. When the owner asks: «الفعاليات» › «قالب مهرجان الانطلاقة» in the panel, or
  `docker compose --profile jobs run --rm migrate node dist/cli/event-admin.js festival-draft --reason "<why>"`
  (creates the DRAFT and its four gifts without art; the owner uploads the art, reviews the proposed prizes, sets the
  dates and publishes in the panel).
- **Rollback:** an older API ignores the new columns but would treat a DRAFT as a published event without dates (its code
  reads `starts_at` as non-null) — before rolling back, delete or publish every draft (`SELECT id FROM events WHERE
  status = 'DRAFT'`); recurring events would stop rolling over (their current period freezes at the series end only);
  event-exclusive gifts would be listed and bought at any time (unlist them: `gift-admin disable <code>`). Reverting the
  migration is not supported (data in the new tables); restore from the pre-release backup if needed.


### 5.100 Events v2 follow-ups (migration `20270409090200_events_v2_followups`; D334) — [IMPLEMENTED, draft contract v1.102-social; not deployed, not device-tested]

CONVENTIONS §10.127.11 (owner answers 2026-11-09). Deploy after §5.99 (it needs `20270409090100_events_v2`).

- **Migration:** two columns, no data rewrite beyond their fill: `events.creators_as_hosts` BOOLEAN NOT NULL — every
  existing event gets **false** (D295's rule kept: content creators stay out of its HOSTS audience), then the default
  becomes **true** (every event made afterwards counts creators as hosts); `event_boards.shown` INTEGER NOT NULL DEFAULT
  20 with CHECK `event_boards_shown` (1–100) — every existing board keeps showing 20. Both `ADD COLUMN … DEFAULT` on
  small tables (PostgreSQL 11+: no rewrite); a short lock.
- **Behaviour once deployed:**
  - A HOSTS event made after the deploy is listed, bannered and announced to content creators too; its start
    notification therefore reaches more accounts than a D295-era one. Events made before keep their audience.
  - `GET /home/banners` filters event banners per signed-in user by the event's audience (one extra query per call; the
    response stays `Cache-Control: private` and `Vary: Authorization`). An event's banner is now made for every audience
    at publish. Banners added by `banner-admin --event` to a non-EVERYONE event stop reaching people outside its
    audience.
  - **Money:** a send from the bag of an event's own gift (prize pieces) credits the recipients **no cherries and no
    agency / parent commission** (`live_gifts.host_share_bps = 0`); every other send is unchanged. Check after the first
    festival: `SELECT count(*) FROM live_gifts g JOIN gifts x ON x.code = g.gift_code WHERE g.source = 'BAG' AND
    x.event_id IS NOT NULL AND g.host_share_bps <> 0` is 0 for sends after the deploy.
  - A board lists `shown` places (20 unless the panel sets 1–100). A held event with milestones and no board prizes is no
    longer settled at its freeze; it is paid (milestones given) at the release.
- **Order:** migration, then the API, then the admin panel (the «عدد المعروضين» field; an older panel omits it and the
  stored value is kept). The app needs no update (`shown` is additive; it already lists what `data` holds).
- **Launch festival:** made after this deploy, its gifts are «هدية المهرجان 1…4» (codes `kabso_festival_gift_1` … `_4`)
  with «شاشة كاملة» on gifts 3 and 4; the owner renames them in the panel. A festival draft made before (codes
  `kabso_launch_*`) keeps its names — rename them in the panel or delete the draft and make it again.
- **Rollback:** an older API ignores both columns: HOSTS events go back to D295's audience, every board shows 20, event
  banners are listed to everyone again (unpublish or end a non-EVERYONE event's banner first if that matters), and bag
  prize pieces would credit cherries again — disable those gifts (`gift-admin disable <code>`) before rolling back if
  prize pieces are outstanding. Dropping the columns is not needed.

### 5.101 «حذف» of a gift (migration `20270410090000_gift_archive`; D338) — [IMPLEMENTED, draft contract v1.103-social; not deployed]

CONVENTIONS §10.131 (owner 2026-11-09: «أريد زر لإزالتهم وليس فقط إيقافهم»). §5.100 is left for D334.

- **Migration:** `gifts.archived_at` (nullable) and the CHECK `gifts_archived_off` (archived ⇒ off). Metadata only on the
  small `gifts` table (the CHECK scans it under a short lock); no data change, no new config.
- **Order:** migration, then the API, then the admin panel (the «حذف» button, the «المحذوفة» filter and «استعادة»). The
  apps need no update: an archived gift is off (not in the catalogue, not bought), while its pieces already in bags stay
  in the bag and are sent until they run out (owner: «مخفية الا ان تنتهي من حقيبة المستخدمين ثم تحذف»).
- **Finishing:** once nobody holds a piece, an archived gift with no history is deleted (with its files), one with
  history stays archived. This runs right after a bag send of an archived gift and on the events sweeper's interval
  (`EVENTS_SWEEP_INTERVAL_SECONDS`, already required non-zero in production; no new setting); by hand:
  `docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js finish`.
- **Storage:** a real delete (a gift nothing ever used) removes its uploaded files from the bucket when no other gift
  names them (best effort; a failure is logged and only leaves the files). `gift-admin delete` does the same when the job
  has the `S3_*` settings, otherwise it says the files stay. Archiving touches no file.
- **Rollback:** an older API ignores `archived_at`; archived gifts stay off (the CHECK holds while the column exists),
  and an older panel shows them as plain disabled gifts — do not enable them there (the CHECK refuses it); restore them
  first with the new API, or `UPDATE gifts SET archived_at = NULL WHERE …` before switching them on.

### 5.102 Archived chats and group messages (migrations `20270411090000_dm_groups_enums`, `20270411090100_dm_archive_groups`; D339) — [IMPLEMENTED, draft contract v1.104-social; not deployed, not device-tested]

CONVENTIONS §10.132, §10.133 (owner 2026-11-09: «الدردشات، طلبات المراسلة، المؤرشفة، رسائل جماعية»). §5.100 / §5.101,
PP-70–PP-73 and openapi v1.103-social are taken on `staging` by D334–D338; this section (PP-74, v1.104-social) is numbered
after them.

- **Migrations** (in this order; the enum value goes first in a migration of its own, as D155 did):
  `20270411090000_dm_groups_enums` adds `report_target_type` `DM_GROUP`; `20270411090100_dm_archive_groups` adds the
  nullable `dm_participants.archived_at`, the tables `dm_groups`, `dm_group_members`, `dm_group_messages` (CHECKs on the
  name and the message content), `reports.target_dm_group_id` (no foreign key) with its index and the open-once unique
  index, and redefines the CHECKs `media_assets_kind_known` (+ `DM_GROUP_PHOTO`) and `reports_one_target` (+ the group
  target). No GRANT (default privileges), no backfill; existing rows satisfy the new CHECKs (they only accept more).
- **Settings** (all optional; defaults shown):

  | Variable | Default | Meaning |
  | --- | --- | --- |
  | `DM_GROUP_MAX_MEMBERS` | `100` | The most members of a group, its creator included. 3–256 |
  | `RATE_LIMIT_DM_GROUP_CREATE_USER` | `2/86400` | `POST /dm/groups` per user (owner: 2 new groups a day; refused attempts count) |

  Group messages count in `RATE_LIMIT_DM_SEND_USER`, the other group and archive writes in `RATE_LIMIT_DM_WRITE_USER`;
  group messages live `DM_RETENTION_HOURS` and the existing DM sweeper (`DM_SWEEP_INTERVAL_SECONDS`) deletes them with
  their files. Pushes reuse `PUSH_MESSAGES_GAP_SECONDS` (per member and group; Android tag `dmg:<groupId>`) and need the
  D152 key (§5.16).
- **Media:** a group's photo is the new upload kind `DM_GROUP_PHOTO` (a centre-cropped square like `FAMILY_EMBLEM`);
  its pictures and voice notes reuse `DM_IMAGE` / `DM_VOICE`.
- **Order:** migrations, then the API, then the admin panel (the `DM_GROUP` report label and snapshot), then the app.
  An older app keeps working: it never sees groups (it reads `listDmConversations`), but an archived conversation (only
  a newer app archives) leaves its inbox until a message from the peer brings it back.
- **Rollback:** an older API ignores the new tables and column (an archived conversation is back in every inbox; groups
  disappear from the app until the API returns). Dropping the tables loses the groups and their messages (they live 24 h
  anyway); `DM_GROUP` reports would then need to be resolved first (the CHECK names the column).

### 5.103 Event results and full-screen announcements (migration `20270412090000_event_announcements`; D340) — [IMPLEMENTED, draft contract v1.105-social; not deployed, not device-tested]

CONVENTIONS §10.134 (owner 2026-11-09). Deploy after §5.100 (it needs `20270409090200_events_v2_followups`); independent
of D338's §5.101 (`20270410090000_gift_archive`) and D339's §5.102 (`20270411090000`…`0100`) — the migrations touch
different tables; the timestamp keeps it after them.

- **Migration:** `events.announce_fullscreen` BOOLEAN NOT NULL — every existing event gets **false** (an event running
  at the deploy is not suddenly announced full screen to everyone), then the default becomes **true**;
  `event_prize_payouts.announced_at` TIMESTAMPTZ — every existing payout is written `created_at` (no burst of old
  «مبروك» after the deploy) — and the partial index `event_prize_payouts_unannounced_idx`; the new table
  `event_start_announcements` (event, user) with its FKs (ON DELETE CASCADE). Small tables; a short lock. Account
  deletion also deletes the person's `event_start_announcements` rows.
- **Behaviour once deployed:**
  - `getEventLeaderboard` on a final board returns the caller's final place whatever it is (one extra ranked query over
    the frozen period's window when the caller is below the frozen top 100) and `me.prizeStatus`.
  - `GET /events/announcements` (default per-user rate limit): at most one payout query, one events query (≤ 50 rows)
    and one audience check per candidate. The app calls it on open, on each return to the foreground and when a live is
    left. `POST /events/announcements/{id}/seen` writes one row (idempotent).
  - The first published gift event that **starts after the deploy** is announced full screen (once per person) to its
    audience once the sweeper has sent `EVENT_STARTED`; switch it off per event in the panel's design step.
- **Order:** migration, API, admin panel (the switch; an older panel omits it and the stored value is kept), then the
  app (an older app ignores the new endpoints and `prizeStatus`; it still shows «باقي N نقطة للتأهل» after the end).
- **Check after deploy:** `SELECT count(*) FROM event_prize_payouts WHERE announced_at IS NULL` is 0 right after the
  migration; `SELECT announce_fullscreen, count(*) FROM events GROUP BY 1` shows only false until a new event is made.
- **Rollback:** the previous API ignores the columns and the table; leave them (dropping is not needed).

### 5.104 The direct share «تفعّل من خلالنا دون وكيل» (no migration; D341) — [IMPLEMENTED, draft contract v1.106-social; not deployed]

CONVENTIONS §10.140 (owner 2026-11-09: «لو مضيف تفعل من خلالنا دون وكيل … ولو صانع المحتوى تفعل من خلالنا تصبح نسبته
٧٥٪», corrected: the direct host 70 %). §5.102–§5.103 are left for D339 / D340.

- **New config (all optional; defaults are the owner's):** `GIFT_DIRECT_HOST_SHARE_PERCENT=70` (a normal gift whose
  recipients are all direct hosts — the hosting permission and no ACTIVE agency membership: 1 000 000 coins → 7 000 000
  cherries, instead of 65 %) and `GIFT_DIRECT_CREATOR_SHARE_PERCENT=75` (the same in a content creator's live, instead of
  `GIFT_CREATOR_SHARE_PERCENT` 70: → 7 500 000). Each is a percentage 0–100 with at most two decimals; anything else stops
  the API at boot. Quips, lucky, custom, DM and CP gifts keep their settings; agency members keep 65 % / 70 % and the
  agency commission on top.
- **No migration, no backfill:** the share is stored per send, so only sends after the API update take it; earlier sends
  keep their stored share. The apps and the panel need no update (they show the stored `shareBps`).
- **Cost check before switching on** (read-only, as the migration role; last 30 days of direct sends that the new rate
  would have raised, in cherries):
  `SELECT sum(gr.coins * 5 * 10 / 100) AS extra_cherries FROM live_gift_recipients gr JOIN live_gifts g ON g.id = gr.gift_id
  WHERE g.room_id IS NOT NULL AND g.host_share_bps = 6500 AND g.created_at > now() - interval '30 days'
  AND NOT EXISTS (SELECT 1 FROM agency_earnings e WHERE e.gift_id = g.id);` (an upper bound: it also counts guests
  without the hosting permission).
- **Rollback:** set `GIFT_DIRECT_HOST_SHARE_PERCENT=65` and `GIFT_DIRECT_CREATOR_SHARE_PERCENT=70` (the shares it replaces;
  `max` keeps the category share) or deploy the previous API; sends already made keep the share they stored.

