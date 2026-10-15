import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const apiRoot = fileURLToPath(new URL('..', import.meta.url));

/** Applies migrations to the e2e database once before the suite. */
export default function setup(): void {
  const databaseUrl = process.env.DATABASE_URL;
  const redisUrl = process.env.REDIS_URL;
  if (!databaseUrl || !redisUrl) {
    throw new Error(
      'test:e2e needs DATABASE_URL and REDIS_URL, e.g.\n' +
        '  DATABASE_URL=postgresql://kabso:kabso_dev@localhost:5432/kabso_test?schema=public \\\n' +
        '  REDIS_URL=redis://localhost:6379/15 pnpm test:e2e',
    );
  }
  const dbName = new URL(databaseUrl).pathname.replace(/^\//, '');
  if (!dbName.endsWith('_test')) {
    throw new Error(
      `Refusing to run e2e tests against "${dbName}": database name must end with "_test" (tables are truncated).`,
    );
  }
  execFileSync('pnpm', ['exec', 'prisma', 'migrate', 'deploy'], {
    cwd: apiRoot,
    env: { ...process.env, DATABASE_URL: databaseUrl },
    stdio: 'inherit',
  });
}
