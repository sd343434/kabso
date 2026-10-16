# Kabso Live API (`@kabso/api`)

NestJS 12 + Prisma 7.10 (`prisma-client` generator, `@prisma/adapter-pg`) + PostgreSQL 16 +
Redis 7. Implements the Phase 1 contract in [`docs/contracts/openapi.yaml`](../../docs/contracts/openapi.yaml)
following [`CONVENTIONS.md`](../../docs/contracts/CONVENTIONS.md). Endpoint authorization rules:
[`docs/API_SPECIFICATION.md`](../../docs/API_SPECIFICATION.md). Schema: [`docs/DATABASE_SCHEMA.md`](../../docs/DATABASE_SCHEMA.md).

## Quick start

```bash
pnpm install                       # from the repo root (pnpm workspace)
cd apps/api
cp .env.example .env               # then set JWT_ACCESS_SECRET (openssl rand -base64 48)
# DB roles: `docker compose up` creates them on first start; otherwise run
# infra/postgres/bootstrap-roles.sql as an admin (docs/DEPLOYMENT.md §5.1)
pnpm prisma:migrate:deploy         # as MIGRATION_DATABASE_URL; or prisma:migrate:dev
pnpm db:seed                       # optional; dev only, refuses NODE_ENV=production
pnpm start:dev                     # http://localhost:3000/health/ready
```

Prisma 7 does not read `.env` itself; `prisma.config.ts` loads `apps/api/.env` via dotenv
(variables already set in the environment take precedence). The Prisma client is generated into
`src/generated/prisma` (gitignored) by `pnpm prisma:generate` (also run by `pnpm build`).

## Scripts (names are relied upon by CI)

| Script                    | What it does                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------- |
| `build`                   | `prisma generate` + `tsc -p tsconfig.build.json` → `dist/`                            |
| `start`                   | `node dist/main.js` (run `build` first)                                               |
| `start:dev`               | Nest CLI watch mode                                                                   |
| `lint`                    | ESLint (typescript-eslint, type-checked rules)                                        |
| `format` / `format:check` | Prettier write / check                                                                |
| `typecheck`               | `tsc --noEmit` over src, tests, prisma, configs                                       |
| `test`                    | Unit tests (Vitest, `src/**/*.spec.ts`) — no DB/Redis needed                          |
| `test:e2e`                | E2E tests (Vitest + supertest, `test/**/*.e2e-spec.ts`) against real Postgres + Redis |
| `prisma:generate`         | Generate the Prisma client                                                            |
| `prisma:migrate:dev`      | Create/apply migrations in development                                                |
| `prisma:migrate:deploy`   | Apply committed migrations (CI/prod)                                                  |
| `db:seed`                 | Dev seed (demo + admin users, random passwords printed once)                          |

### E2E tests

```bash
DATABASE_URL=postgresql://kabso_app_test:kabso_app_test_dev_password@localhost:5432/kabso_test?schema=public \
MIGRATION_DATABASE_URL=postgresql://kabso_migrator:kabso_migrator_dev_password@localhost:5432/kabso_test?schema=public \
REDIS_URL=redis://localhost:6379/15 \
pnpm test:e2e
# optional: KABSO_TEST_ADMIN_DATABASE_URL=postgresql://kabso:kabso_dev_password@localhost:5432/kabso_test
# runs the KL-013b tests that create scratch databases/roles and run the bootstrap (needs psql >= 15)
```

- The API under test connects as the DML-only **runtime role** (`DATABASE_URL`); migrations and
  the per-file `TRUNCATE` run as the **migration role** (`MIGRATION_DATABASE_URL`). Both must
  point at the same database with different roles (SEC-011; docker compose creates `kabso_test`
  with its own runtime login `kabso_app_test` — one runtime login per database — on first start).
- The global setup runs `prisma migrate deploy` itself (no separate step needed) and **refuses
  any database whose name does not end in `_test`**, because every test file truncates all
  tables.
- Each test app uses a random `REDIS_KEY_PREFIX` and deletes its keys on teardown, so a shared
  Redis is safe. Test config is built programmatically (`test/helpers/test-app.ts`); no `.env.test`.
- The `MailSender` port is replaced by a capturing test double so tests can read tokens.

## Configuration

All variables are validated with zod at boot (`src/config/env.schema.ts`); the process exits with a
list of problems if any is invalid (secret values are never printed). See `.env.example` for the
full list. Notable rules:

- `DATABASE_URL` is the least-privilege **runtime role** (SEC-011, docs/DEPLOYMENT.md §5.1).
  After connecting, the API checks its own role and every role it can reach through membership
  (`src/prisma/runtime-role-check.ts`): superuser, `CREATEROLE`/`CREATEDB`/`REPLICATION`/
  `BYPASSRLS`, any reachable role other than `kabso_runtime_<database>`, owning any schema or
  table, `CREATE`/`TEMPORARY` on the database or `CREATE` on a schema, `TRUNCATE`/`REFERENCES`/
  `TRIGGER` on a table, `UPDATE`/`DELETE` on `audit_logs`, access to `_prisma_migrations`, grant
  options, or privileges in another database. In `production` any
  finding aborts the boot (`db.runtime_role_check failed — refusing to start`); elsewhere it is
  logged as a warning. `MIGRATION_DATABASE_URL` (the schema owner) is read only by the Prisma
  CLI (`prisma.config.ts`, falling back to `DATABASE_URL`) and must not be given to the API.

- `JWT_ACCESS_SECRET` ≥ 32 bytes. In `production` it must be base64/base64url decoding to
  ≥ 32 bytes and pass an entropy check (placeholders, typed passphrases, repeated or sequential
  characters are refused). Generate with `openssl rand -base64 48`.
- `REGISTRATION_CODE_KEY` (optional, ≥ 32 bytes, SEC-029): source of the key (HKDF, info
  `registration-code/v1`) that HMACs registration codes. When unset, `RATE_LIMIT_KEY_SECRET` is
  used instead (outside production that is random per process when unset, so pending
  registrations do not survive a restart). In production it must pass the same secret checks and
  differ from both other secrets. **Rotation:** changing the source key (or
  `RATE_LIMIT_KEY_SECRET` while this is unset) invalidates every live pending code — verify then
  answers the generic 422 and users request a new code with `register/resend` (pending rows
  expire within 2 h anyway). Setting it lets `RATE_LIMIT_KEY_SECRET` rotate without that effect.
- Verify-first registration (contract v1.2): `REGISTRATION_TTL_SECONDS` (1800),
  `REGISTRATION_MAX_LIFETIME_SECONDS` (7200; absolute cap from creation, resend never extends it,
  v1.2.3 SEC-026),
  `REGISTRATION_NOTICE_INTERVAL_SECONDS` (3600), `REGISTRATION_CLEANUP_INTERVAL_SECONDS` (600; an
  in-process `setInterval` per API instance deletes expired `pending_registrations`; 0 disables;
  register/verify also delete expired rows lazily). Post-response work (mail, notices) runs in
  `BackgroundTasks`, drained on shutdown before Prisma/Redis disconnect.
- `LOGIN_RECENT_SUCCESS_TTL_SECONDS` (30 days, SEC-023) and `RESERVED_DISPLAY_NAME_TERMS`
  (KL-017; default = CONVENTIONS §6 list, without `staff`/`مشرف` since v1.2.4 and `رسمي` since
  v1.2.6; whole-word match, also on separator-joined words and single-letter runs) and
  `RESERVED_DISPLAY_NAME_BRAND_TERMS` (default `kabso,كابسو`; matched anywhere inside a word,
  v1.2.3). Matching uses the vendored Unicode `confusables.txt` — see
  `src/modules/users/data/README.md` for its source, checksum and update steps.
- Live discovery (contract v1.3, KL-037): `LIVE_HOSTING_ENABLED` (default `false`; go-live and
  heartbeat answer 503 `LIVE_HOSTING_UNAVAILABLE` unless exactly `true`; turning it on in
  staging/production needs owner approval, B1), `LIVE_HEARTBEAT_INTERVAL_SECONDS` (15, 5–60),
  `LIVE_HEARTBEAT_STALE_SECONDS` (45, ≥ 2 × interval), `LIVE_SWEEP_INTERVAL_SECONDS` (15; 0
  disables the in-process stale-room sweeper and is refused in production),
  `LIVE_SWEEP_BATCH_SIZE` (500, 1–5000; v1.3.1 / SEC-035: the sweeper ends stale rooms in batches
  of this size, each in its own transaction with explicit timeouts, never overlapping within an
  instance, and stops a run after 100 batches or 10 s; lists only filter stale rooms), `LIVE_CURSOR_KEY`
  (optional source of the list-cursor HMAC key, HKDF info `live-cursor/v1`; unset → derived from
  `RATE_LIMIT_KEY_SECRET`; in production a set value must pass the secret checks and differ from
  the other secrets; rotation only invalidates outstanding cursors) and the v1.3 per-user limits
  `RATE_LIMIT_LIVE_*` / `RATE_LIMIT_PROFILE_USER` / `RATE_LIMIT_FOLLOW_*` (each replaces the
  default authenticated bucket for its endpoint; in production `RATE_LIMIT_LIVE_HEARTBEAT_USER`
  must allow at least 2 × the heartbeat cadence). Numeric settings accept plain decimal integers
  only (no exponent, hex, sign, padding or empty value).
- Text hygiene for `displayName` and live-room titles (contract v1.3.1 §6, SEC-036) uses vendored
  Unicode 17.0.0 / Emoji 17.0 data compiled into tables; see `src/modules/users/data/README.md`.
- `RATE_LIMIT_KEY_SECRET`: HMAC key for rate-limit Redis keys. Required in production (same
  rules, must differ from the JWT secret); generated per process when unset elsewhere.
- `ARGON2_MAX_CONCURRENCY` (default CPU count) / `ARGON2_MAX_QUEUE` (default 4 × CPU count):
  process-wide cap on Argon2 work; when full, login/register/reset answer 503
  `SERVICE_UNAVAILABLE` with `Retry-After: 1`. Set `UV_THREADPOOL_SIZE` ≥ the cap in the
  container environment (libuv default is 4).
- `MAIL_TRANSPORT=log` is the only transport and is **refused in production** (it writes token
  links to the log). SMTP is **BLOCKED (B2)** until a provider + sending domain exist.
- Rate limits: `RATE_LIMIT_*` as `<max>/<windowSeconds>` (defaults = CONVENTIONS §7).
- `TRUST_PROXY` decides how the client IP is derived for every per-IP rate limit (IPv6 clients
  are bucketed by /64). Allowed values:
  - `false` (default): no proxy; the socket address is used. Right when clients connect directly.
  - a hop count, e.g. `1`: exactly that many proxies in front that append to `X-Forwarded-For`.
    Wrong if clients can also reach the API directly (they could then spoof the header).
  - a comma-separated list of proxy IPs/CIDRs (or `loopback`, `linklocal`, `uniquelocal`):
    preferred when the load balancer subnet is known.
  - production also refuses `/0` ranges (`0.0.0.0/0`, `::/0`) and hop counts greater than 3
    (SEC-003a), and since v1.2.3 any IPv4 range broader than /8, IPv6 broader than /32, and
    `::ffff:0:0/96` (all IPv4-mapped addresses).
  - `true` trusts the client-controlled left-most `X-Forwarded-For` and is **refused when
    `NODE_ENV=production`** (SEC-003). The effective value is logged at startup
    (`trust proxy = …`). Per-platform values belong in `docs/DEPLOYMENT.md` (A8).

## Layout

```
src/
  main.ts, app.setup.ts, app.module.ts
  config/            zod env schema → typed AppConfig (APP_CONFIG token)
  common/            errors (codes, envelope, filter), request-id, zod pipe, rate limit, audit
  logging/           pino options + redaction list
  prisma/            PrismaService (adapter-pg)
  redis/             ioredis client (fail-fast, prefixed keys)
  modules/health     /health/live, /health/ready
  modules/auth       register/login/refresh/logout, email verify, password reset, sessions
  modules/users      /me, username availability, account persistence;
                     users/profiles: GET /users/{username}, AccountLifecycleService (v1.3)
  modules/live       v1.3 live categories, rooms, host lifecycle, stale sweeper, signed cursors
  modules/social     v1.3 follow graph (PUT/DELETE /users/{username}/follow)
  modules/mail       MailSender port + LogMailSender (dev)
prisma/              schema, migrations, seed
test/                e2e specs + helpers
```

## Tooling decisions

- **TypeScript 6.0.x, not 7.0.** TS 7.0.2 (the native port) ships no classic compiler API
  (`typescript` main export is only `lib/version.cjs`), and the toolchain still requires it:
  `typescript-eslint@8.71` peers `typescript <6.1.0`, `@nestjs/cli@12` depends on `~6.0.2`.
  Revisit when typescript-eslint supports TS 7.
- **Vitest + unplugin-swc, not Jest.** NestJS 12 packages are ESM-only (`"type": "module"`, no
  `require` export), so the app is ESM. Vitest runs ESM natively; SWC emits the decorator
  metadata Nest's DI needs (esbuild does not). Jest would need experimental VM modules.
