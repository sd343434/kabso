---
name: kabso-db-migration
description: Steps for a Kabso Prisma/PostgreSQL schema change, including naming, runtime-role grants, contract and ownership updates, and verification on a fresh _test database. Use when adding or changing tables, columns, enums or indexes.
disable-model-invocation: true
---

# /kabso-db-migration

Read `.claude/skills/kabso-monorepo/references/prisma-postgres.md` and `docs/DEPLOYMENT.md` §5.1 first.

1. **Contract and ownership.** Do these first: the schema change appears in
   `docs/contracts/CONVENTIONS.md` (§8 ownership row for new tables) and in the contract if the API
   changes (`/kabso-contract-change`). Financial and auth tables need a Security review (§8).
2. **Schema.** Edit `apps/api/prisma/schema.prisma`.
3. **Migration.** Add `apps/api/prisma/migrations/<YYYYMMDDHHMMSS>_<snake_name>/migration.sql`.
   - The timestamp must sort after every migration on all remote branches; check with the command in
     `prisma-postgres.md`.
   - Follow how existing migrations grant the runtime role; do not guess.
   - Never edit an applied migration.
4. **Generate.** Run `pnpm --filter ./apps/api prisma:generate`.
5. **Apply locally.** Use a fresh local database whose name ends in `_test`, migrated as the migration
   role (`apps/api/README.md`, "e2e"). Never point at a shared or server database.
6. **Test.** Run the related e2e tests and the API checks (`/kabso-verify`).

Ask the owner before applying migrations anywhere shared, before `prisma migrate reset` or dropping a
database, and before any commit or push.
