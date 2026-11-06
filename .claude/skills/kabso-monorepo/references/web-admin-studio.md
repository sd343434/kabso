# React web apps (`apps/admin`, `apps/studio`)

Authoritative: each app's `package.json`, the `admin` and `studio` jobs in `.github/workflows/ci.yml`,
`infra/deploy/Caddyfile` (each app's site block and CSP), `docs/DEPLOYMENT.md`.

## Facts

- `@kabso/admin` is the admin panel. `@kabso/studio` is the streamer's browser studio («استوديو البث»,
  board D247). Both are React + Vite + TypeScript static apps in the pnpm workspace
  (`pnpm-workspace.yaml`).
- Each calls the API under the same origin, `/api/*`, proxied by Caddy. The Content-Security-Policy is
  set in `infra/deploy/Caddyfile`. A new external origin, for example a media server, needs a CSP
  change there; that change affects deployment.
- Strings: admin has `src/i18n.ts` plus per-decision `src/i18n-d<NNN>.ts` dictionaries; studio has
  `src/i18n.ts`. Both carry Arabic and English. See [l10n-rtl.md](l10n-rtl.md).
- Tests: Vitest (`pnpm --filter <pkg> test`). Each app has a Playwright config for `e2e`, which CI does
  not run.

## Checks (the same commands as CI, run from the repository root)

```sh
pnpm install --frozen-lockfile --ignore-scripts --filter @kabso/admin
pnpm --filter @kabso/admin typecheck
pnpm --filter @kabso/admin lint
pnpm --filter @kabso/admin test
pnpm --filter @kabso/admin build
```

For the studio, run the same four commands with `@kabso/studio` in place of `@kabso/admin`.
