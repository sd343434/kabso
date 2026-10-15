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
pnpm prisma:migrate:deploy         # or prisma:migrate:dev while changing the schema
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
DATABASE_URL=postgresql://kabso:kabso_dev@localhost:5432/kabso_test?schema=public \
REDIS_URL=redis://localhost:6379/15 \
pnpm test:e2e
```

- The global setup runs `prisma migrate deploy` against `DATABASE_URL` itself (no separate step
  needed) and **refuses any database whose name does not end in `_test`**, because every test file
  truncates all tables.
- Each test app uses a random `REDIS_KEY_PREFIX` and deletes its keys on teardown, so a shared
  Redis is safe. Test config is built programmatically (`test/helpers/test-app.ts`); no `.env.test`.
- The `MailSender` port is replaced by a capturing test double so tests can read tokens.

## Configuration

All variables are validated with zod at boot (`src/config/env.schema.ts`); the process exits with a
list of problems if any is invalid (secret values are never printed). See `.env.example` for the
full list. Notable rules:

- `JWT_ACCESS_SECRET` ≥ 32 bytes. In `production` it must be base64/base64url decoding to
  ≥ 32 bytes and pass an entropy check (placeholders, typed passphrases, repeated or sequential
  characters are refused). Generate with `openssl rand -base64 48`.
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
  modules/users      /me, username availability, account persistence
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
