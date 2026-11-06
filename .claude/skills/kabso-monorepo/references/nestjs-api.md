# NestJS API (`apps/api`, package `@kabso/api`)

Authoritative: `apps/api/README.md`, `apps/api/package.json`, `docs/contracts/CONVENTIONS.md`, the `api`
job in `.github/workflows/ci.yml`.

## Facts

- Layout: `src/main.ts`, `src/app.module.ts`, `src/app.setup.ts`, `src/config/`, `src/common/`,
  `src/prisma/`, `src/redis/`, `src/logging/`, `src/cli/` (operator CLIs, run as `pnpm <name>:admin`),
  and `src/modules/<module>/`.
- File names are kebab-case, e.g. `recharge-orders.service.ts`.
- Errors: throw the project's exceptions with a contract error code (`src/common/errors/error-codes.ts`,
  `app-exception.ts`, `error-mapping.ts`). Codes and HTTP statuses come from `CONVENTIONS.md` §4. Do not
  invent a code without updating the contract first.
- Response shapes come from `docs/contracts/openapi.yaml`. A shape change is a contract change: run
  `/kabso-contract-change`.

## Tests

- Unit: Vitest, `*.spec.ts` next to the code (`vitest.config.ts`).
- End-to-end: `test/**/*.e2e-spec.ts` (`vitest.e2e.config.ts`), run against real PostgreSQL and Redis.
  Files run sequentially and truncate all tables.
  - The database name must end in `_test`.
  - The API connects as the runtime role (`DATABASE_URL`); migrations and truncation use
    `MIGRATION_DATABASE_URL`.
  - Optional `KABSO_TEST_ADMIN_DATABASE_URL` enables the role tests.
  - See "e2e" in `apps/api/README.md`.
- Helpers live in `test/helpers/`: `test-app.ts`, fakes for storage, media and payment providers, and
  `openapi.ts`.
- The admin-server smoke test runs with `pnpm --filter @kabso/api smoke:admin-server`.

## Checks (the same commands as the CI `api` job, run from the repository root)

```sh
pnpm install --frozen-lockfile
pnpm --filter ./apps/api prisma:generate
NODE_OPTIONS=--max-old-space-size=6144 pnpm --filter ./apps/api lint   # type-aware lint needs the heap
pnpm --filter ./apps/api format:check
pnpm --filter ./apps/api typecheck
pnpm --filter ./apps/api test
pnpm --filter ./apps/api test:e2e        # needs the database and Redis described above
pnpm --filter ./apps/api build
```

Running e2e needs a local PostgreSQL 16 and Redis, with the roles from
`infra/postgres/bootstrap-roles.sql`. If they are not available, report e2e as "not run".
