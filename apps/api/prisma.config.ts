// Prisma 7 configuration. Prisma 7 no longer loads `.env` itself, so it is loaded here
// (apps/api/.env — copy `.env.example`). Variables already present in the environment win.
//
// The Prisma CLI (migrate, db, studio) connects as the MIGRATION role, which owns the schema
// (SEC-011 / KL-013, docs/DEPLOYMENT.md §5.1): MIGRATION_DATABASE_URL. The API uses DATABASE_URL
// (the DML-only runtime role) and never reads this file. DATABASE_URL is only a fallback for
// single-role setups; the runtime role cannot run DDL, so a missing MIGRATION_DATABASE_URL fails
// closed (and the grant migration refuses to run as anything but the schema owner).
import 'dotenv/config';
import { defineConfig } from 'prisma/config';

// CLI commands that connect to a database. Others (generate, validate, format, version)
// must keep working without a database URL — e.g. `prisma generate` in CI or a Docker build.
const DATABASE_COMMANDS = new Set(['migrate', 'db', 'studio']);

const command = process.argv.slice(2).find((arg) => !arg.startsWith('-'));
const migrationUrl = process.env.MIGRATION_DATABASE_URL?.trim() ?? '';
const databaseUrl = migrationUrl !== '' ? migrationUrl : (process.env.DATABASE_URL?.trim() ?? '');

if (databaseUrl === '' && command !== undefined && DATABASE_COMMANDS.has(command)) {
  throw new Error(
    `MIGRATION_DATABASE_URL is not set, but \`prisma ${command}\` needs a database connection.\n` +
      'Copy apps/api/.env.example to apps/api/.env and set MIGRATION_DATABASE_URL to the migration ' +
      'role (e.g. postgresql://kabso_migrator:<password>@localhost:5432/kabso_dev?schema=public).',
  );
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    url: databaseUrl,
  },
});
