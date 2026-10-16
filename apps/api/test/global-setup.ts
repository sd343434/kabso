import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const apiRoot = fileURLToPath(new URL('..', import.meta.url));

const USAGE =
  'test:e2e needs DATABASE_URL (runtime role), MIGRATION_DATABASE_URL (migration role) and ' +
  'REDIS_URL for the same *_test database, e.g.\n' +
  '  DATABASE_URL=postgresql://kabso_app:<pw>@localhost:5432/kabso_test?schema=public \\\n' +
  '  MIGRATION_DATABASE_URL=postgresql://kabso_migrator:<pw>@localhost:5432/kabso_test?schema=public \\\n' +
  '  REDIS_URL=redis://localhost:6379/15 pnpm test:e2e\n' +
  'Create the roles first with infra/postgres/bootstrap-roles.sql (docs/DEPLOYMENT.md §5.1).';

/**
 * Applies migrations (as the migration role) to the e2e database once before the suite. The
 * tests themselves run the API as the DML-only runtime role (SEC-011 / KL-013).
 */
export default function setup(): void {
  const databaseUrl = process.env.DATABASE_URL;
  const migrationUrl = process.env.MIGRATION_DATABASE_URL;
  const redisUrl = process.env.REDIS_URL;
  if (!databaseUrl || !migrationUrl || !redisUrl) throw new Error(USAGE);

  const runtime = new URL(databaseUrl);
  const migration = new URL(migrationUrl);
  const dbName = runtime.pathname.replace(/^\//, '');
  if (!dbName.endsWith('_test')) {
    throw new Error(
      `Refusing to run e2e tests against "${dbName}": database name must end with "_test" (tables are truncated).`,
    );
  }
  if (migration.pathname !== runtime.pathname || migration.host !== runtime.host) {
    throw new Error(`DATABASE_URL and MIGRATION_DATABASE_URL must point at the same database.\n${USAGE}`);
  }
  if (decodeURIComponent(migration.username) === decodeURIComponent(runtime.username)) {
    throw new Error(
      `DATABASE_URL and MIGRATION_DATABASE_URL use the same role "${runtime.username}"; the e2e suite ` +
        `runs the API as the runtime role.\n${USAGE}`,
    );
  }
  execFileSync('pnpm', ['exec', 'prisma', 'migrate', 'deploy'], {
    cwd: apiRoot,
    env: { ...process.env, MIGRATION_DATABASE_URL: migrationUrl },
    stdio: 'inherit',
  });
}
