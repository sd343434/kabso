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

- Credentials are dev defaults overridable from `.env`; database `kabso_dev`, user `kabso`.
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
| `api` | `apps/api/**`, root `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, or the workflow file changed | Node 22, pnpm (version from `packageManager`, store cached) → `install --frozen-lockfile` → `prisma:generate` → `prisma:migrate:deploy` → `lint` → `format:check` → `typecheck` → `test` → `test:e2e` → `build`. Postgres 16.15 and Redis 7.4 service containers, pinned by digest, with health checks. |
| `mobile` | `apps/mobile/**`, design tokens, or the workflow file changed | Flutter 3.47.7 (SDK and pub cache cached) → `pub get --enforce-lockfile` → `build_runner build` → fail on drift (`git diff --exit-code` plus untracked files) → `dart format --set-exit-if-changed lib test` → `flutter analyze` → `flutter test` |
| `android` | same as `mobile` | Temurin 17 with Gradle cache, the Android SDK from the runner image, then `flutter build apk --debug`. The APK is uploaded as an artifact kept for 7 days. **Never run in the authoring environment (no Android SDK, blocker B6).** |
| `ios` | `workflow_dispatch`, or a push to `main` that changes mobile | `macos-latest`, `flutter build ios --no-codesign`. Gated because macOS minutes cost about 10 times Linux minutes. **Never run in the authoring environment.** |
| `contracts` | `docs/contracts/**`, `redocly.yaml`, `tools/redocly/**`, or the workflow file changed | `npm ci --ignore-scripts` in `tools/redocly` (Redocly CLI 2.57.0 pinned by `package-lock.json` with sha512 integrity), then `redocly lint` with the rules in `redocly.yaml`; results shown as PR annotations |
| `secrets` | always | gitleaks 8.30.1 CLI (download checked against its SHA-256) scans the full git history with redacted output |
| `ci-ok` | always | **Allowlist:** passes only if every job's result is `success` or `skipped` (path-filtered or gated); any other result (`failure`, `cancelled`, `abandoned`, `timed_out`, missing, or a future value) fails and names the job. Since KL-010c: run 29 passed while `ios` was `abandoned` (no macOS runner) under the old failure/cancelled denylist. **Make this the only required status check** in branch protection. |

CI test configuration lives in the workflow `env`. It contains clearly fake values
(`ci_test_password_not_secret`, `ci-test-only-jwt-secret-…`, `ci-test-only-rate-limit-…`)
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
  the secret manager, followed by a rolling restart.
- **Required, not yet implemented (SEC-011 / KL-013):** the API must use a least-privilege
  database role (DML only); migrations run as a separate migration role with DDL rights. Today
  the API connects as the schema owner — acceptable for local development only. Design: §5.1.

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

### 5.1 Database roles (SEC-011) — [DESIGNED; implementation KL-013 (A3 + A8), required before any deployment]

Today the API and the migrations use the same owner role. Target:

| Role | Login | Used by | Rights |
| ---- | ----- | ------- | ------ |
| `kabso_migrator` | yes | the pre-deploy migration job only (`prisma migrate deploy`) | owns schema `public` and every table, sequence and type in it; DDL |
| `kabso_app` | yes | API pods (`DATABASE_URL`) | `CONNECT`; `USAGE` on schema; `SELECT, INSERT, UPDATE, DELETE` on app tables; `INSERT, SELECT` only on `audit_logs`; `USAGE, SELECT` on sequences; no `TRUNCATE`, `REFERENCES`, `TRIGGER`, DDL, or access to `_prisma_migrations` |
| bootstrap / admin (managed-service master user) | break-glass only | environment bootstrap | creates the two roles; never used by an application |

**1. Environment bootstrap** (run once per environment as the admin user; passwords come from
the secret manager, never from a migration):

```sql
CREATE ROLE kabso_migrator LOGIN PASSWORD :'migrator_password'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE kabso_app LOGIN PASSWORD :'app_password'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 200;
ALTER ROLE kabso_app SET statement_timeout = '15s';
ALTER ROLE kabso_app SET idle_in_transaction_session_timeout = '30s';

REVOKE ALL ON DATABASE kabso FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE kabso TO kabso_migrator;
GRANT CONNECT ON DATABASE kabso TO kabso_app;
ALTER SCHEMA public OWNER TO kabso_migrator;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;   -- already the default since PostgreSQL 15
GRANT USAGE ON SCHEMA public TO kabso_app;
```

**2. Grants in a Prisma migration** (runs as `kabso_migrator`, so it lives with the schema):

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kabso_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO kabso_app;
REVOKE ALL ON TABLE _prisma_migrations FROM kabso_app;
REVOKE UPDATE, DELETE ON TABLE audit_logs FROM kabso_app;   -- append-only audit trail

-- Objects created later by kabso_migrator get the same grants automatically.
ALTER DEFAULT PRIVILEGES FOR ROLE kabso_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kabso_app;
ALTER DEFAULT PRIVILEGES FOR ROLE kabso_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO kabso_app;
```

Design rules and open points for KL-013:

- Migrations **must run as `kabso_migrator`**: default privileges only apply to objects
  created by that role. A migration run as the admin user would create tables `kabso_app`
  cannot read.
- Any future append-only or sensitive table gets an explicit `REVOKE` in the migration that
  creates it (the default privileges grant full DML).
- Two connection strings: `DATABASE_URL` (`kabso_app`) for the API, and a separate migration
  URL (name to be agreed with A3, e.g. `MIGRATION_DATABASE_URL`, read by
  `apps/api/prisma.config.ts`) available only to the migration job.
- The grant migration references `kabso_app`, so the role must exist everywhere migrations
  run: local compose (an init script under `infra/postgres/`), the CI service container (a
  setup step before `prisma:migrate:deploy`), staging and production (bootstrap above).
- CI then runs the e2e suite as `kabso_app` and adds negative tests (`UPDATE audit_logs`,
  `TRUNCATE`, `CREATE TABLE` must fail) so the separation cannot regress silently.
- Until KL-013 ships, the API connects as the owner: acceptable for local development and
  CI only. **No staging or production deployment before KL-013** (blocker B10).

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
- The Android debug APK and unsigned iOS build compile in CI (run 13); neither has been
  installed on a device or emulator.
- The Dependabot `cooldown` / `ignore` settings were validated against the published schema;
  their effect is only visible in the next weekly Dependabot run.
- The per-platform `TRUST_PROXY` values in §3.1 are based on each platform's documented
  `X-Forwarded-For` behaviour and must be verified on the real deployment.
