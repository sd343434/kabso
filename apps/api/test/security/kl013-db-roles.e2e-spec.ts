/**
 * KL-013 / SEC-011 / PP-01: least-privilege database roles, proven against real PostgreSQL.
 *
 * DATABASE_URL is the DML-only runtime role (member of kabso_runtime) the API uses;
 * MIGRATION_DATABASE_URL is the migration/owner role. See infra/postgres/bootstrap-roles.sql and
 * docs/DEPLOYMENT.md §5.1.
 */
import 'reflect-metadata';
import { randomBytes } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaService } from '../../src/prisma/prisma.service.js';
import {
  RUNTIME_ROLE_FACTS_SQL,
  UnsafeDatabaseRoleError,
  assessRuntimeRole,
  type RuntimeRoleFacts,
} from '../../src/prisma/runtime-role-check.js';
import { buildTestConfig, withMigrationClient } from '../helpers/test-app.js';

/** PostgreSQL insufficient_privilege (42501) as surfaced through Prisma's pg adapter. */
const PERMISSION_DENIED = /permission denied|must be owner|42501/i;

const suffix = randomBytes(4).toString('hex');
/** Table created by the MIGRATION role after the grant migration, like a future Phase 2 table. */
const LATER_TABLE = `kl013_later_${suffix}`;

let runtime: PrismaClient;
let runtimeUser: string;
let migrationUser: string;

async function scalar<T>(client: PrismaClient, sql: string): Promise<T> {
  const rows = await client.$queryRawUnsafe<{ v: T }[]>(sql);
  return rows[0]!.v;
}

function runtimeExec(sql: string): Promise<number> {
  return runtime.$executeRawUnsafe(sql);
}

beforeAll(async () => {
  runtime = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL!, max: 2 }),
  });
  runtimeUser = await scalar<string>(runtime, 'SELECT current_user::text AS v');
  migrationUser = await withMigrationClient((m) => scalar<string>(m, 'SELECT current_user::text AS v'));
  await withMigrationClient((m) =>
    m.$executeRawUnsafe(`CREATE TABLE "${LATER_TABLE}" (id serial PRIMARY KEY, note text NOT NULL)`),
  );
});

afterAll(async () => {
  await withMigrationClient((m) => m.$executeRawUnsafe(`DROP TABLE IF EXISTS "${LATER_TABLE}"`));
  await runtime.$disconnect();
});

describe('KL-013 role layout', () => {
  it('the API connects as a different role than the migrations', () => {
    expect(runtimeUser).not.toBe(migrationUser);
  });

  it('the runtime role passes the boot-time least-privilege check', async () => {
    const [facts] = await runtime.$queryRawUnsafe<RuntimeRoleFacts[]>(RUNTIME_ROLE_FACTS_SQL);
    expect(facts!.user).toBe(runtimeUser);
    expect(assessRuntimeRole(facts!)).toEqual([]);
  });

  it('the migration role owns the schema and fails the runtime check', async () => {
    const facts = await withMigrationClient(async (m) => {
      const [row] = await m.$queryRawUnsafe<RuntimeRoleFacts[]>(RUNTIME_ROLE_FACTS_SQL);
      return row!;
    });
    expect(facts.superuser).toBe(false);
    expect(facts.createRole).toBe(false);
    expect(facts.bypassRls).toBe(false);
    expect(facts.ownedSchemas).toContain('public');
    expect(facts.ownedRelations).toContain('public.users');
    expect(assessRuntimeRole(facts).join('\n')).toMatch(/migration\/owner role/);
  });
});

describe('KL-013 runtime role cannot run DDL or administrative commands', () => {
  it.each([
    ['CREATE TABLE', 'CREATE TABLE kl013_forbidden (id int)'],
    ['CREATE TEMP TABLE', 'CREATE TEMP TABLE kl013_forbidden_tmp (id int)'],
    ['CREATE SCHEMA', 'CREATE SCHEMA kl013_forbidden'],
    ['CREATE INDEX', 'CREATE INDEX kl013_forbidden_idx ON users (created_at)'],
    ['CREATE FUNCTION', 'CREATE FUNCTION kl013_forbidden() RETURNS int LANGUAGE sql AS $$ SELECT 1 $$'],
    ['ALTER TABLE ADD COLUMN', 'ALTER TABLE users ADD COLUMN kl013_forbidden int'],
    ['ALTER TABLE DISABLE TRIGGER', 'ALTER TABLE audit_logs DISABLE TRIGGER ALL'],
    ['ALTER TABLE OWNER', 'ALTER TABLE sessions OWNER TO CURRENT_USER'],
    ['DROP TABLE', 'DROP TABLE users'],
    ['DROP TABLE (audit)', 'DROP TABLE audit_logs'],
    ['TRUNCATE', 'TRUNCATE TABLE sessions'],
    ['TRUNCATE (audit)', 'TRUNCATE TABLE audit_logs'],
    ['CREATE ROLE', 'CREATE ROLE kl013_forbidden LOGIN'],
    ['ALTER ROLE', 'ALTER ROLE CURRENT_USER CREATEDB'],
    ['CREATE DATABASE', 'CREATE DATABASE kl013_forbidden'],
    ['ALTER SCHEMA OWNER', 'ALTER SCHEMA public OWNER TO CURRENT_USER'],
  ])('%s is refused', async (_name, sql) => {
    await expect(runtimeExec(sql)).rejects.toThrow(PERMISSION_DENIED);
  });

  it('GRANT of role membership is refused', async () => {
    await expect(runtimeExec(`GRANT "${migrationUser}" TO CURRENT_USER`)).rejects.toThrow(PERMISSION_DENIED);
    await expect(runtimeExec(`GRANT kabso_runtime TO "${migrationUser}"`)).rejects.toThrow(PERMISSION_DENIED);
  });

  it('GRANT on an object without rights is refused', async () => {
    await expect(runtimeExec('GRANT ALL ON TABLE _prisma_migrations TO PUBLIC')).rejects.toThrow(
      PERMISSION_DENIED,
    );
  });

  it('GRANT of privileges it holds (no grant option) changes nothing', async () => {
    // PostgreSQL answers these with a WARNING ("no privileges were granted"), not an error:
    // prove the ACLs are unchanged instead.
    const acl = (rel: string) =>
      scalar<string>(
        runtime,
        `SELECT coalesce(relacl::text, '') AS v FROM pg_class WHERE oid = '${rel}'::regclass`,
      );
    const schemaAcl = () =>
      scalar<string>(runtime, `SELECT nspacl::text AS v FROM pg_namespace WHERE nspname = 'public'`);
    const [usersBefore, schemaBefore] = [await acl('users'), await schemaAcl()];

    await runtimeExec('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO PUBLIC').catch(() => 0);
    await runtimeExec('GRANT ALL ON TABLE users TO CURRENT_USER').catch(() => 0);
    await runtimeExec('GRANT CREATE ON SCHEMA public TO CURRENT_USER').catch(() => 0);

    expect(await acl('users')).toBe(usersBefore);
    expect(await schemaAcl()).toBe(schemaBefore);
    expect(await scalar<boolean>(runtime, `SELECT has_schema_privilege('public', 'CREATE') AS v`)).toBe(
      false,
    );
    expect(await scalar<boolean>(runtime, `SELECT has_table_privilege('users', 'TRUNCATE') AS v`)).toBe(
      false,
    );
  });

  it('cannot read or change the migration history', async () => {
    await expect(runtime.$queryRawUnsafe('SELECT * FROM _prisma_migrations')).rejects.toThrow(
      PERMISSION_DENIED,
    );
    await expect(runtimeExec('DELETE FROM _prisma_migrations')).rejects.toThrow(PERMISSION_DENIED);
  });
});

describe('KL-013 runtime role DML', () => {
  it('can INSERT, SELECT, UPDATE and DELETE application rows', async () => {
    const email = `kl013-${suffix}@example.com`;
    const user = await runtime.user.create({ data: { email, passwordHash: 'x' } });
    expect((await runtime.user.findUnique({ where: { id: user.id } }))?.email).toBe(email);
    await runtime.user.update({ where: { id: user.id }, data: { status: 'SUSPENDED' } });
    await runtime.user.delete({ where: { id: user.id } });
    expect(await runtime.user.findUnique({ where: { id: user.id } })).toBeNull();
  });

  it('audit_logs is append-only: INSERT and SELECT work, UPDATE and DELETE are refused', async () => {
    const entry = await runtime.auditLog.create({ data: { action: `kl013.probe.${suffix}` } });
    expect(await runtime.auditLog.count({ where: { id: entry.id } })).toBe(1);
    await expect(
      runtime.auditLog.update({ where: { id: entry.id }, data: { action: 'tampered' } }),
    ).rejects.toThrow(PERMISSION_DENIED);
    await expect(runtime.auditLog.delete({ where: { id: entry.id } })).rejects.toThrow(PERMISSION_DENIED);
  });

  it('deleting a user still nulls the audit actor (FK action runs as the table owner)', async () => {
    const user = await runtime.user.create({
      data: { email: `kl013-fk-${suffix}@example.com`, passwordHash: 'x' },
    });
    const entry = await runtime.auditLog.create({ data: { action: 'kl013.fk', actorUserId: user.id } });
    await runtime.user.delete({ where: { id: user.id } });
    expect((await runtime.auditLog.findUnique({ where: { id: entry.id } }))?.actorUserId).toBeNull();
  });

  it('every application table grants DML to the runtime role (default privileges kept working)', async () => {
    const rows = await runtime.$queryRawUnsafe<
      { table: string; s: boolean; i: boolean; u: boolean; d: boolean; owner: string }[]
    >(`
      SELECT c.relname::text AS "table",
             has_table_privilege(c.oid, 'SELECT') AS s, has_table_privilege(c.oid, 'INSERT') AS i,
             has_table_privilege(c.oid, 'UPDATE') AS u, has_table_privilege(c.oid, 'DELETE') AS d,
             pg_get_userbyid(c.relowner)::text AS owner
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND c.relname <> '_prisma_migrations'
       ORDER BY 1`);
    expect(rows.length).toBeGreaterThanOrEqual(10);
    // KL-037: the v1.3 tables came through default privileges (no GRANT in their migration).
    expect(rows.map((r) => r.table)).toEqual(
      expect.arrayContaining(['live_categories', 'live_rooms', 'follows']),
    );
    for (const row of rows) {
      const appendOnly = row.table === 'audit_logs';
      expect({ table: row.table, owner: row.owner, s: row.s, i: row.i, u: row.u, d: row.d }).toEqual({
        table: row.table,
        owner: migrationUser,
        s: true,
        i: true,
        u: !appendOnly,
        d: !appendOnly,
      });
    }
  });
});

describe('KL-013 tables created later by the migration role (ALTER DEFAULT PRIVILEGES)', () => {
  it('are DML-accessible by the runtime role, including their sequences', async () => {
    await runtimeExec(`INSERT INTO "${LATER_TABLE}" (note) VALUES ('a'), ('b')`);
    expect(Number(await scalar<bigint>(runtime, `SELECT count(*) AS v FROM "${LATER_TABLE}"`))).toBe(2);
    expect(await runtimeExec(`UPDATE "${LATER_TABLE}" SET note = 'c' WHERE note = 'a'`)).toBe(1);
    expect(await runtimeExec(`DELETE FROM "${LATER_TABLE}" WHERE note = 'b'`)).toBe(1);
  });

  it.each([
    ['ALTER TABLE', `ALTER TABLE "${LATER_TABLE}" ADD COLUMN extra int`],
    ['DROP TABLE', `DROP TABLE "${LATER_TABLE}"`],
    ['TRUNCATE', `TRUNCATE TABLE "${LATER_TABLE}"`],
    ['CREATE INDEX', `CREATE INDEX kl013_later_idx ON "${LATER_TABLE}" (note)`],
    ['ALTER SEQUENCE', `ALTER SEQUENCE "${LATER_TABLE}_id_seq" RESTART`],
  ])('but %s is refused', async (_name, sql) => {
    await expect(runtimeExec(sql)).rejects.toThrow(PERMISSION_DENIED);
  });
});

describe('KL-037 v1.3 tables (live_categories, live_rooms, follows) under the KL-013 roles', () => {
  const ids = {
    user: '0192f1c2-0000-7000-8000-00000000a001',
    other: '0192f1c2-0000-7000-8000-00000000a002',
    category: '0192f1c2-0000-7000-8000-00000000a003',
    room: '0192f1c2-0000-7000-8000-00000000a004',
  };

  afterAll(async () => {
    await withMigrationClient(async (m) => {
      await m.$executeRawUnsafe(`DELETE FROM live_rooms WHERE id = '${ids.room}'`);
      await m.$executeRawUnsafe(`DELETE FROM live_categories WHERE id = '${ids.category}'`);
      await m.$executeRawUnsafe(`DELETE FROM users WHERE id IN ('${ids.user}', '${ids.other}')`);
    });
  });

  it('are owned by the migration role', async () => {
    const owners = await runtime.$queryRawUnsafe<{ t: string; owner: string }[]>(`
      SELECT c.relname::text AS t, pg_get_userbyid(c.relowner)::text AS owner
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname IN ('live_categories', 'live_rooms', 'follows')
       ORDER BY 1`);
    expect(owners).toEqual([
      { t: 'follows', owner: migrationUser },
      { t: 'live_categories', owner: migrationUser },
      { t: 'live_rooms', owner: migrationUser },
    ]);
  });

  it('the runtime role can SELECT, INSERT, UPDATE and DELETE on all three (and use the enums)', async () => {
    for (const id of [ids.user, ids.other]) {
      await runtimeExec(
        `INSERT INTO users (id, email, password_hash, updated_at) VALUES ('${id}', 'kl037-${id.slice(-4)}-${suffix}@example.com', 'x', now())`,
      );
    }
    await runtimeExec(
      `INSERT INTO live_categories (id, slug, name_ar, name_en, updated_at) VALUES ('${ids.category}', 'kl037-${suffix}', 'تجربة', 'Probe', now())`,
    );
    await runtimeExec(
      `INSERT INTO live_rooms (id, host_user_id, title, category_id, status, mode, updated_at) VALUES ('${ids.room}', '${ids.user}', 'Probe', '${ids.category}', 'LIVE'::live_room_status, 'SOLO'::live_room_mode, now())`,
    );
    await runtimeExec(
      `INSERT INTO follows (follower_id, followee_id) VALUES ('${ids.other}', '${ids.user}')`,
    );
    for (const table of ['live_categories', 'live_rooms', 'follows']) {
      expect(
        Number(await scalar<bigint>(runtime, `SELECT count(*) AS v FROM ${table}`)),
      ).toBeGreaterThanOrEqual(1);
    }
    expect(await runtimeExec(`UPDATE live_categories SET sort_order = 5 WHERE id = '${ids.category}'`)).toBe(
      1,
    );
    expect(
      await runtimeExec(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED'::live_room_end_reason, ended_at = now() WHERE id = '${ids.room}'`,
      ),
    ).toBe(1);
    expect(await runtimeExec(`DELETE FROM follows WHERE follower_id = '${ids.other}'`)).toBe(1);
    expect(await runtimeExec(`DELETE FROM live_rooms WHERE id = '${ids.room}'`)).toBe(1);
    expect(await runtimeExec(`DELETE FROM live_categories WHERE id = '${ids.category}'`)).toBe(1);
  });

  it.each([
    ['TRUNCATE live_rooms', 'TRUNCATE TABLE live_rooms'],
    ['TRUNCATE follows', 'TRUNCATE TABLE follows'],
    ['TRUNCATE live_categories', 'TRUNCATE TABLE live_categories'],
    ['ALTER TABLE follows', 'ALTER TABLE follows ADD COLUMN kl037_forbidden int'],
    ['ALTER TABLE live_rooms DROP CONSTRAINT', 'ALTER TABLE live_rooms DROP CONSTRAINT live_rooms_end_state'],
    ['DROP INDEX (one LIVE room per host)', 'DROP INDEX live_rooms_one_live_per_host'],
    ['CREATE INDEX', 'CREATE INDEX kl037_forbidden_idx ON live_rooms (title)'],
    ['ALTER TYPE', "ALTER TYPE live_room_status ADD VALUE 'PAUSED'"],
    ['DROP TABLE', 'DROP TABLE live_categories'],
  ])('%s is refused', async (_name, sql) => {
    await expect(runtimeExec(sql)).rejects.toThrow(PERMISSION_DENIED);
  });

  it('the hand-written partial indexes and CHECK constraints exist', async () => {
    const indexes = await runtime.$queryRawUnsafe<{ name: string; def: string }[]>(`
      SELECT indexname::text AS name, indexdef AS def FROM pg_indexes
       WHERE schemaname = 'public' AND tablename IN ('live_rooms', 'follows', 'live_categories')`);
    const byName = Object.fromEntries(indexes.map((i) => [i.name, i.def]));
    for (const name of [
      'live_rooms_one_live_per_host',
      'live_rooms_live_popular_idx',
      'live_rooms_live_new_idx',
      'live_rooms_live_cat_popular_idx',
      'live_rooms_live_cat_new_idx',
      'live_rooms_live_heartbeat_idx',
    ]) {
      expect(byName[name], name).toMatch(/WHERE \(status = 'LIVE'::live_room_status\)$/);
    }
    expect(byName.live_rooms_one_live_per_host).toMatch(/^CREATE UNIQUE INDEX/);
    expect(Object.keys(byName)).toEqual(
      expect.arrayContaining([
        'live_rooms_host_started_idx',
        'live_rooms_category_id_idx',
        'follows_pkey',
        'follows_followee_id_created_at_idx',
        'live_categories_slug_key',
      ]),
    );
    const checks = await runtime.$queryRawUnsafe<{ name: string }[]>(`
      SELECT conname::text AS name FROM pg_constraint
       WHERE contype = 'c' AND conrelid IN ('live_rooms'::regclass, 'follows'::regclass, 'live_categories'::regclass)
       ORDER BY 1`);
    expect(checks.map((c) => c.name)).toEqual([
      'follows_no_self_follow',
      'live_categories_name_ar_length',
      'live_categories_name_en_length',
      'live_categories_slug_format',
      'live_rooms_end_state',
      'live_rooms_time_order',
      'live_rooms_title_length',
      'live_rooms_viewer_count_nonneg',
    ]);
  });
});

describe('KL-013 boot-time guard (PrismaService)', () => {
  function service(databaseUrl: string, isProduction: boolean): PrismaService {
    return new PrismaService({ ...buildTestConfig({ LOG_LEVEL: 'silent' }), databaseUrl, isProduction });
  }

  it('production boot refuses the migration/owner role (fail closed)', async () => {
    const prisma = service(process.env.MIGRATION_DATABASE_URL!, true);
    try {
      await expect(prisma.onModuleInit()).rejects.toBeInstanceOf(UnsafeDatabaseRoleError);
    } finally {
      await prisma.$disconnect();
    }
  });

  it('production boot accepts the runtime role', async () => {
    const prisma = service(process.env.DATABASE_URL!, true);
    try {
      await expect(prisma.onModuleInit()).resolves.toBeUndefined();
    } finally {
      await prisma.onApplicationShutdown();
    }
  });

  it('outside production the owner role only produces a warning', async () => {
    const prisma = service(process.env.MIGRATION_DATABASE_URL!, false);
    try {
      await expect(prisma.onModuleInit()).resolves.toBeUndefined();
    } finally {
      await prisma.onApplicationShutdown();
    }
  });
});
