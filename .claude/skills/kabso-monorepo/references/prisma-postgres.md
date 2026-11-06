# Prisma and PostgreSQL

Authoritative: `apps/api/prisma/schema.prisma`, `apps/api/prisma/migrations/`, `docs/DATABASE_SCHEMA.md`,
`docs/DEPLOYMENT.md` §5.1 (database roles), `infra/postgres/bootstrap-roles.sql`, `apps/api/README.md`.

## Facts

- PostgreSQL 16 (board D2). One schema file: `apps/api/prisma/schema.prisma`.
- Migrations: `apps/api/prisma/migrations/<YYYYMMDDHHMMSS>_<snake_name>/migration.sql`, applied with
  `prisma migrate deploy` under the migration role (`MIGRATION_DATABASE_URL`).
- Least privilege: the API runs as a DML-only runtime role (`DATABASE_URL`), a member of the group role
  `kabso_runtime`. The migration `20261016120000_runtime_role_grants` sets `ALTER DEFAULT PRIVILEGES`
  for objects that the migration role creates in `public`. Read it to see which object types are covered
  before assuming a new object needs, or does not need, an explicit grant.
- The timestamps are ordering keys, not real clock times; existing ones run ahead of the calendar. Pick a
  value greater than the highest migration on **every** remote branch (`staging` and unmerged
  `claude/*`), because other agents' work also takes numbers:
  `git fetch origin && git for-each-ref --format='%(refname)' refs/remotes/origin | xargs -I{} git ls-tree --name-only {} apps/api/prisma/migrations/ | sort -u | tail -3`.
  If two branches already use the same timestamp, report it; do not renumber someone else's migration.
- Never edit an applied migration. Add a new one.

## Approval

Applying migrations to any shared database, running `prisma migrate reset`, dropping a database and
deploying all need the owner's approval. Local `_test` databases you created yourself are fine.

## Checks

The `/kabso-db-migration` workflow lists them. In short: `prisma:generate`, the migration applied to a
fresh `_test` database, the related e2e tests, and the API checks in
[nestjs-api.md](nestjs-api.md).
