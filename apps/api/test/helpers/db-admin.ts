/**
 * Helpers for the database-role e2e tests (KL-013 / KL-013b) that need a PostgreSQL admin:
 * creating scratch databases and roles and running infra/postgres/bootstrap-roles.sql with psql.
 *
 * The admin connection comes from KABSO_TEST_ADMIN_DATABASE_URL (CI: the service container's
 * POSTGRES_USER). Without it those tests are skipped locally; in CI (CI=true) they are required.
 */
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client.js';

const repoRoot = fileURLToPath(new URL('../../../../', import.meta.url));
const apiRoot = fileURLToPath(new URL('../../', import.meta.url));

export const BOOTSTRAP_SQL = `${repoRoot}infra/postgres/bootstrap-roles.sql`;
export const SCRAM_VERIFIER_SCRIPT = `${repoRoot}infra/postgres/scram-verifier.mjs`;
export const ADMIN_URL = process.env.KABSO_TEST_ADMIN_DATABASE_URL?.trim() || undefined;

/** SQL string literal. */
export function lit(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** SQL identifier. */
export function ident(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

/** `base` with another database and/or credentials. */
export function urlWith(base: string, change: { db?: string; user?: string; password?: string }): string {
  const url = new URL(base);
  if (change.db !== undefined) url.pathname = `/${encodeURIComponent(change.db)}`;
  if (change.user !== undefined) url.username = encodeURIComponent(change.user);
  if (change.password !== undefined) url.password = encodeURIComponent(change.password);
  return url.toString();
}

export function databaseOf(url: string): string {
  return decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
}

export function userOf(url: string): string {
  return decodeURIComponent(new URL(url).username);
}

export async function withClient<T>(url: string, fn: (client: PrismaClient) => Promise<T>): Promise<T> {
  const client = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });
  try {
    return await fn(client);
  } finally {
    await client.$disconnect();
  }
}

/** Connects and runs `SELECT 1`; resolves to the error message, or `null` on success. */
export async function connectError(url: string): Promise<string | null> {
  try {
    await withClient(url, (c) => c.$queryRawUnsafe('SELECT 1'));
    return null;
  } catch (err) {
    return err instanceof Error ? err.message : String(err);
  }
}

export interface PsqlResult {
  readonly status: number | null;
  readonly output: string;
}

/** Runs bootstrap-roles.sql with psql as the admin against `db`, with only `env` set. */
export function runBootstrap(adminUrl: string, db: string, env: Record<string, string>): PsqlResult {
  const admin = new URL(adminUrl);
  const result = spawnSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-f', BOOTSTRAP_SQL], {
    encoding: 'utf8',
    env: {
      PATH: process.env.PATH ?? '',
      PGHOST: admin.hostname,
      PGPORT: admin.port || '5432',
      PGUSER: decodeURIComponent(admin.username),
      PGPASSWORD: decodeURIComponent(admin.password),
      PGDATABASE: db,
      ...env,
    },
  });
  if (result.error) throw result.error;
  return { status: result.status, output: `${result.stdout}${result.stderr}` };
}

/** Runs infra/postgres/scram-verifier.mjs with the password on stdin. */
export function scramVerifier(password: string): PsqlResult {
  const result = spawnSync(process.execPath, [SCRAM_VERIFIER_SCRIPT], { encoding: 'utf8', input: password });
  if (result.error) throw result.error;
  return { status: result.status, output: `${result.stdout}${result.stderr}`.trim() };
}

/** `prisma migrate deploy` against another database, as its migration role. */
export function migrateDeploy(migrationUrl: string): PsqlResult {
  const result = spawnSync('pnpm', ['exec', 'prisma', 'migrate', 'deploy'], {
    cwd: apiRoot,
    encoding: 'utf8',
    env: { ...process.env, MIGRATION_DATABASE_URL: migrationUrl, DATABASE_URL: migrationUrl },
  });
  if (result.error) throw result.error;
  return { status: result.status, output: `${result.stdout}${result.stderr}` };
}
