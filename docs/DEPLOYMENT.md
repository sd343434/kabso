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

The script is idempotent: it never overwrites an existing `.env`, replaces the
`JWT_ACCESS_SECRET` placeholder with `openssl rand -base64 48` output only while the
placeholder is still present, and only starts containers when a Docker daemon is reachable
(`docker compose up -d --wait` blocks until health checks pass). Verified locally by running
it twice without a daemon; shellcheck 0.11.0 reports no findings.

### 1.3 Infrastructure (`docker-compose.yml`) — [IMPLEMENTED, UNVERIFIED]

| Service | Image | Host port (127.0.0.1 only) | Volume | Health check |
| ------- | ----- | -------------------------- | ------ | ------------ |
| `postgres` | `postgres:16.15-alpine` | 5432 | `postgres-data` | `pg_isready` |
| `redis` | `redis:7.4-alpine` (AOF on) | 6379 | `redis-data` | `redis-cli ping` |
| `minio` (profile `storage`) | `pgsty/minio:RELEASE.2026-08-04T00-00-00Z` | 9000 API, 9001 console | `minio-data` | `GET /minio/health/live` |
| `minio-init` (profile `storage`) | same image, one-shot | — | — | creates `$S3_BUCKET` idempotently |

- Credentials are dev defaults overridable from `.env`; database `kabso_dev`, user `kabso`.
- The file validates with `docker compose config` (Compose v5.6.0 CLI, no daemon needed), but
  the containers have **not** been started in the authoring environment (no Docker daemon).
- **MinIO image note:** upstream MinIO no longer publishes community container images
  (`minio/minio` and `minio/mc` on Docker Hub are no longer pullable). The default is the
  community-maintained AGPL build by pgsty, which bundles `mc` and `curl`. Organisations with
  an approved mirror set `MINIO_IMAGE`. MinIO is local-only; cloud environments use S3 or R2.
- Reset everything: `docker compose --profile storage down -v` (deletes all local data).

### 1.4 Configuration

Root `.env.example` documents every variable for local development. The API reads plain
environment variables (validated with Zod at boot); export the root `.env` before starting it
(`set -a; . ./.env; set +a`) or use the API's own loader if `apps/api` documents one. The
mobile app gets only `API_BASE_URL` through `--dart-define`. It never receives secrets.

## 2. Continuous integration (`.github/workflows/ci.yml`) — [IMPLEMENTED, UNVERIFIED]

Triggers: every `pull_request`, pushes to `main` and `claude/**`, and manual
`workflow_dispatch`, which runs every job. Runs on the same PR or branch cancel each other, but
runs on `main` are never cancelled. The default token is `contents: read`; only the change
detector also gets `pull-requests: read`. Every third-party action is pinned to a full commit
SHA, and Dependabot proposes updates weekly.

| Job | Runs when | Steps |
| --- | --------- | ----- |
| `changes` | always | `dorny/paths-filter` → `api` / `mobile` / `contracts` outputs; also detects whether `apps/api` / `apps/mobile` exist yet |
| `api` | `apps/api/**`, root `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, or the workflow file changed | Node 22, pnpm (version from `packageManager`, store cached) → `install --frozen-lockfile` → `prisma:generate` → `prisma:migrate:deploy` → `lint` → `format:check` → `typecheck` → `test` → `test:e2e` → `build`. Postgres 16.15 and Redis 7.4 service containers with health checks. |
| `mobile` | `apps/mobile/**`, design tokens, or the workflow file changed | Flutter 3.47.7 (SDK and pub cache cached) → `pub get` → `build_runner build` → fail on drift (`git diff --exit-code` plus untracked files) → `dart format --set-exit-if-changed lib test` → `flutter analyze` → `flutter test` |
| `android` | same as `mobile` | Temurin 17 with Gradle cache, the Android SDK from the runner image, then `flutter build apk --debug`. The APK is uploaded as an artifact kept for 7 days. **Never run in the authoring environment (no Android SDK, blocker B6).** |
| `ios` | `workflow_dispatch`, or a push to `main` that changes mobile | `macos-latest`, `flutter build ios --no-codesign`. Gated because macOS minutes cost about 10 times Linux minutes. **Never run in the authoring environment.** |
| `contracts` | `docs/contracts/**`, `redocly.yaml`, or the workflow file changed | `npx @redocly/cli@2.57.0 lint` with the rules in `redocly.yaml`, results shown as PR annotations |
| `secrets` | always | gitleaks 8.30.1 CLI (download checked against its SHA-256) scans the full git history with redacted output |
| `ci-ok` | always | Fails if any job failed or was cancelled. **Make this the only required status check** in branch protection; skipped jobs count as passing. |

CI test configuration lives in the workflow `env`. It contains clearly fake values
(`ci_test_password_not_secret`, `ci-test-only-jwt-secret-…`) that only exist inside the
ephemeral job. No repository secrets are used by CI today.

**Bootstrap guard (temporary):** when `apps/api/package.json` or `apps/mobile/pubspec.yaml`
does not exist yet, the `api`/`mobile`/`android`/`ios` jobs are skipped and the run shows a
warning. These apps are being built in parallel. Remove the guard (the `present` step and the
`*_present` conditions) once KL-008 integrates both apps, so that losing an app fails CI.

**Command contract** the apps must provide: `apps/api/package.json` scripts `prisma:generate`,
`prisma:migrate:deploy`, `lint`, `typecheck`, `format:check`, `test`, `test:e2e`, `build`, and
a root `packageManager` field. `apps/mobile` must keep `build_runner` as a dev dependency and
commit its generated code (decision D5).

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

## 4. Secrets management — [DESIGNED]

- **No secret ever lives in the repository or in the mobile app binary.** `.gitignore`
  excludes `.env*` (except `.env.example`), keystores, `key.properties`, `*.p12` and
  Firebase configuration files. The `secrets` CI job scans the history with gitleaks on
  every run **[IMPLEMENTED]**.
- Runtime secrets (`DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`, SMTP, S3 and LiveKit
  keys) live in the cloud secret manager (AWS Secrets Manager or GCP Secret Manager). Each
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
  signs every user out. Database passwords rotate through the secret manager, followed by a
  rolling restart.
- The API uses a least-privilege database role. Migrations run as a separate migration role
  with DDL rights.

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
  dispatch or main. Neither has been run yet (see §2).

## 10. What is not verified

- The CI workflow has passed `actionlint` 1.7.12 (with shellcheck 0.11.0) but has **never run
  on GitHub**. The first PR run is the real test.
- The Docker Compose services have never been started (no daemon in the authoring
  environment).
- The Android and iOS builds have never been run (no Android SDK or Xcode, blocker B6).
- The `contracts` job **currently fails** on a real error in `docs/contracts/openapi.yaml`
  (see the KL-005 report); the contract owner must fix it.
