/**
 * KL-013 / KL-013b / SEC-011 / PP-01: least-privilege database roles, proven against real
 * PostgreSQL.
 *
 * DATABASE_URL is the DML-only runtime login the API uses (member of this database's group
 * `kabso_runtime_<database>` only); MIGRATION_DATABASE_URL is the migration/owner role. See
 * infra/postgres/bootstrap-roles.sql and docs/DEPLOYMENT.md §5.1.
 *
 * The KL-013b tests that create databases and roles or run the bootstrap script need an admin
 * connection (KABSO_TEST_ADMIN_DATABASE_URL, plus `psql` on PATH); they are required in CI.
 */
import 'reflect-metadata';
import { createHash, createHmac, pbkdf2Sync, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { PrismaPg } from '@prisma/adapter-pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaService } from '../../src/prisma/prisma.service.js';
import {
  RUNTIME_ROLE_FACTS_SQL,
  UnsafeDatabaseRoleError,
  assessRuntimeRole,
  runtimeRoleFactsSql,
  type RuntimeRoleFacts,
} from '../../src/prisma/runtime-role-check.js';
import {
  ADMIN_URL,
  connectError,
  databaseOf,
  ident,
  lit,
  migrateDeploy,
  runBootstrap,
  scramVerifier,
  urlWith,
  withClient,
} from '../helpers/db-admin.js';
import { buildTestConfig, withMigrationClient } from '../helpers/test-app.js';

/** PostgreSQL insufficient_privilege (42501) as surfaced through Prisma's pg adapter. */
const PERMISSION_DENIED = /permission denied|must be owner|42501/i;

const suffix = randomBytes(4).toString('hex');
/** Table created by the MIGRATION role after the grant migration, like a future Phase 2 table. */
const LATER_TABLE = `kl013_later_${suffix}`;

/** This database and its runtime group (KL-013b: one group per database). */
const DB = databaseOf(process.env.DATABASE_URL!);
const RUNTIME_GROUP = `kabso_runtime_${DB}`;

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
    await expect(runtimeExec(`GRANT ${ident(RUNTIME_GROUP)} TO "${migrationUser}"`)).rejects.toThrow(
      PERMISSION_DENIED,
    );
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
      // KL-058: the points ledger and level history are append-only like the audit log.
      const appendOnly = ['audit_logs', 'points_ledger', 'level_history'].includes(row.table);
      // KL-058: admin permissions are granted by the migration role only.
      const readOnly = row.table === 'user_admin_permissions';
      expect({ table: row.table, owner: row.owner, s: row.s, i: row.i, u: row.u, d: row.d }).toEqual({
        table: row.table,
        owner: migrationUser,
        s: true,
        i: !readOnly,
        u: !appendOnly && !readOnly,
        d: !appendOnly && !readOnly,
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
    // CP-012 (v1.8-live): the popular keyset indexes order by the score.
    expect(byName.live_rooms_live_popular_idx).toContain('(score DESC, started_at DESC, id DESC)');
    expect(byName.live_rooms_live_cat_popular_idx).toContain(
      '(category_id, score DESC, started_at DESC, id DESC)',
    );
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
      // CP-014 (20261030090000_live_room_edit): the info version is never negative.
      'live_rooms_info_version_nonneg',
      // CP-012 (20261028090000_live_taps): the score is never negative.
      'live_rooms_score_nonneg',
      // CP-011 (20261027090000_live_seats): the seat count matches the mode; theme slug; version.
      'live_rooms_seat_count_mode',
      'live_rooms_seats_version_nonneg',
      'live_rooms_theme_format',
      'live_rooms_time_order',
      'live_rooms_title_length',
      // CP-014: the topic is 1–100 code points or NULL.
      'live_rooms_topic_length',
      'live_rooms_viewer_count_nonneg',
    ]);
    // CP-014: the Contribution list of a room reads the tappers in rank order.
    const rank = await runtime.$queryRawUnsafe<{ def: string }[]>(`
      SELECT indexdef AS def FROM pg_indexes
       WHERE schemaname = 'public' AND indexname = 'live_room_tappers_room_rank_idx'`);
    expect(rank[0]?.def).toContain('(room_id, counted DESC, last_batch_at, user_id)');
  });
});

describe('CP-012 score tables (live_room_scores, live_room_tappers) under the KL-013 roles', () => {
  const ids = {
    user: '0192f1c2-0000-7000-8000-00000000b001',
    room: '0192f1c2-0000-7000-8000-00000000b002',
  };

  afterAll(async () => {
    await withMigrationClient(async (m) => {
      await m.$executeRawUnsafe(`DELETE FROM live_rooms WHERE id = '${ids.room}'`);
      await m.$executeRawUnsafe(`DELETE FROM users WHERE id = '${ids.user}'`);
    });
  });

  it('are owned by the migration role and have their CHECK constraints', async () => {
    const owners = await runtime.$queryRawUnsafe<{ t: string; owner: string }[]>(`
      SELECT c.relname::text AS t, pg_get_userbyid(c.relowner)::text AS owner
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname IN ('live_room_scores', 'live_room_tappers')
       ORDER BY 1`);
    expect(owners).toEqual([
      { t: 'live_room_scores', owner: migrationUser },
      { t: 'live_room_tappers', owner: migrationUser },
    ]);
    const checks = await runtime.$queryRawUnsafe<{ name: string }[]>(`
      SELECT conname::text AS name FROM pg_constraint
       WHERE contype = 'c' AND conrelid IN ('live_room_scores'::regclass, 'live_room_tappers'::regclass)
       ORDER BY 1`);
    expect(checks.map((c) => c.name)).toEqual(['live_room_scores_nonneg', 'live_room_tappers_counted']);
  });

  it('the runtime role has DML on both; the CHECKs hold; DDL and TRUNCATE are refused', async () => {
    await runtimeExec(
      `INSERT INTO users (id, email, password_hash, updated_at) VALUES ('${ids.user}', 'cp012-${suffix}@example.com', 'x', now())`,
    );
    await runtimeExec(
      `INSERT INTO live_rooms (id, host_user_id, title, status, mode, updated_at) VALUES ('${ids.room}', '${ids.user}', 'Probe', 'LIVE'::live_room_status, 'SOLO'::live_room_mode, now())`,
    );
    await runtimeExec(`INSERT INTO live_room_scores (room_id, tap_points) VALUES ('${ids.room}', 3)`);
    await runtimeExec(
      `INSERT INTO live_room_tappers (room_id, user_id, counted, last_batch_at) VALUES ('${ids.room}', '${ids.user}', 3, now())`,
    );
    expect(await runtimeExec(`UPDATE live_rooms SET score = score + 3 WHERE id = '${ids.room}'`)).toBe(1);
    expect(
      await runtimeExec(
        `UPDATE live_room_scores SET tap_points = tap_points + 1 WHERE room_id = '${ids.room}'`,
      ),
    ).toBe(1);
    await expect(runtimeExec(`UPDATE live_rooms SET score = -1 WHERE id = '${ids.room}'`)).rejects.toThrow(
      /live_rooms_score_nonneg/,
    );
    await expect(
      runtimeExec(`UPDATE live_room_scores SET support_points = -1 WHERE room_id = '${ids.room}'`),
    ).rejects.toThrow(/live_room_scores_nonneg/);
    await expect(
      runtimeExec(`UPDATE live_room_tappers SET counted = 10001 WHERE room_id = '${ids.room}'`),
    ).rejects.toThrow(/live_room_tappers_counted/);
    for (const sql of [
      'TRUNCATE TABLE live_room_scores',
      'TRUNCATE TABLE live_room_tappers',
      'ALTER TABLE live_room_tappers DROP CONSTRAINT live_room_tappers_counted',
      'DROP INDEX live_rooms_live_popular_idx',
    ]) {
      await expect(runtimeExec(sql), sql).rejects.toThrow(PERMISSION_DENIED);
    }
    // The rows go with the room (ON DELETE CASCADE).
    expect(await runtimeExec(`DELETE FROM live_rooms WHERE id = '${ids.room}'`)).toBe(1);
    expect(
      Number(
        await scalar<bigint>(
          runtime,
          `SELECT (SELECT count(*) FROM live_room_scores WHERE room_id = '${ids.room}') + (SELECT count(*) FROM live_room_tappers WHERE room_id = '${ids.room}') AS v`,
        ),
      ),
    ).toBe(0);
  });
});

describe('CP-013 chat tables (live_chat_messages, live_chat_mutes) under the KL-013 roles', () => {
  const ids = {
    user: '0192f1c2-0000-7000-8000-00000000c001',
    other: '0192f1c2-0000-7000-8000-00000000c002',
    room: '0192f1c2-0000-7000-8000-00000000c003',
    message: '0192f1c2-0000-7000-8000-00000000c004',
    client: '0192f1c2-0000-7000-8000-00000000c005',
  };

  afterAll(async () => {
    await withMigrationClient(async (m) => {
      await m.$executeRawUnsafe(`DELETE FROM live_rooms WHERE id = '${ids.room}'`);
      await m.$executeRawUnsafe(`DELETE FROM users WHERE id IN ('${ids.user}', '${ids.other}')`);
    });
  });

  it('are owned by the migration role and have their CHECK constraints', async () => {
    const owners = await runtime.$queryRawUnsafe<{ t: string; owner: string }[]>(`
      SELECT c.relname::text AS t, pg_get_userbyid(c.relowner)::text AS owner
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname IN ('live_chat_messages', 'live_chat_mutes')
       ORDER BY 1`);
    expect(owners).toEqual([
      { t: 'live_chat_messages', owner: migrationUser },
      { t: 'live_chat_mutes', owner: migrationUser },
    ]);
    const checks = await runtime.$queryRawUnsafe<{ name: string }[]>(`
      SELECT conname::text AS name FROM pg_constraint
       WHERE contype = 'c' AND conrelid IN ('live_chat_messages'::regclass, 'live_chat_mutes'::regclass)
       ORDER BY 1`);
    expect(checks.map((c) => c.name)).toEqual([
      'live_chat_messages_deleted_state',
      'live_chat_messages_text_length',
      'live_chat_mutes_not_self',
    ]);
  });

  it('the runtime role has DML on both; the CHECKs and the clientId key hold; DDL and TRUNCATE are refused', async () => {
    for (const id of [ids.user, ids.other]) {
      await runtimeExec(
        `INSERT INTO users (id, email, password_hash, updated_at) VALUES ('${id}', 'cp013-${id.slice(-4)}-${suffix}@example.com', 'x', now())`,
      );
    }
    await runtimeExec(
      `INSERT INTO live_rooms (id, host_user_id, title, status, mode, updated_at) VALUES ('${ids.room}', '${ids.user}', 'Probe', 'LIVE'::live_room_status, 'SOLO'::live_room_mode, now())`,
    );
    expect(
      await scalar<boolean>(runtime, `SELECT chat_enabled AS v FROM live_rooms WHERE id = '${ids.room}'`),
    ).toBe(true);
    const insert = (id: string, text: string) =>
      runtimeExec(
        `INSERT INTO live_chat_messages (id, room_id, user_id, client_id, text, author_role) VALUES ('${id}', '${ids.room}', '${ids.other}', '${ids.client}', '${text}', 'VIEWER'::live_chat_author_role)`,
      );
    await insert(ids.message, 'hello');
    await expect(insert('0192f1c2-0000-7000-8000-00000000c006', 'again')).rejects.toThrow(
      /live_chat_messages_client_once/,
    );
    await expect(insert('0192f1c2-0000-7000-8000-00000000c007', '')).rejects.toThrow(
      /live_chat_messages_text_length/,
    );
    await expect(
      runtimeExec(`UPDATE live_chat_messages SET deleted_by_id = '${ids.user}' WHERE id = '${ids.message}'`),
    ).rejects.toThrow(/live_chat_messages_deleted_state/);
    expect(
      await runtimeExec(
        `UPDATE live_chat_messages SET deleted_at = now(), deleted_by_id = '${ids.user}' WHERE id = '${ids.message}'`,
      ),
    ).toBe(1);
    await runtimeExec(
      `INSERT INTO live_chat_mutes (room_id, user_id, muted_by_id) VALUES ('${ids.room}', '${ids.other}', '${ids.user}')`,
    );
    await expect(
      runtimeExec(
        `INSERT INTO live_chat_mutes (room_id, user_id, muted_by_id) VALUES ('${ids.room}', '${ids.user}', '${ids.user}')`,
      ),
    ).rejects.toThrow(/live_chat_mutes_not_self/);
    for (const sql of [
      'TRUNCATE TABLE live_chat_messages',
      'TRUNCATE TABLE live_chat_mutes',
      'ALTER TABLE live_chat_messages DROP CONSTRAINT live_chat_messages_text_length',
      'DROP INDEX live_chat_messages_room_created_idx',
    ]) {
      await expect(runtimeExec(sql), sql).rejects.toThrow(PERMISSION_DENIED);
    }
    // The rows go with the room (ON DELETE CASCADE).
    expect(await runtimeExec(`DELETE FROM live_rooms WHERE id = '${ids.room}'`)).toBe(1);
    expect(
      Number(
        await scalar<bigint>(
          runtime,
          `SELECT (SELECT count(*) FROM live_chat_messages WHERE room_id = '${ids.room}') + (SELECT count(*) FROM live_chat_mutes WHERE room_id = '${ids.room}') AS v`,
        ),
      ),
    ).toBe(0);
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

// ---------------------------------------------------------------------------------------------
// KL-013b: fixes for the KL-007f findings
// ---------------------------------------------------------------------------------------------

type Sql = Pick<PrismaClient, '$queryRawUnsafe' | '$executeRawUnsafe'>;

class Rollback extends Error {}

/** Runs `fn` in a transaction that is always rolled back; returns what `fn` returned. */
async function inRolledBackTx<T>(client: PrismaClient, fn: (tx: Sql) => Promise<T>): Promise<T> {
  let result: { value: T } | undefined;
  try {
    await client.$transaction(async (tx) => {
      result = { value: await fn(tx) };
      throw new Rollback();
    });
  } catch (err) {
    if (!(err instanceof Rollback)) throw err;
  }
  return result!.value;
}

/** The boot guard's facts for `role`, evaluated through `client`. */
async function factsOf(client: Sql, role: string): Promise<RuntimeRoleFacts> {
  const [row] = await client.$queryRawUnsafe<RuntimeRoleFacts[]>(runtimeRoleFactsSql(lit(role)));
  return row!;
}

async function value<T>(client: Sql, sql: string): Promise<T> {
  const rows = await client.$queryRawUnsafe<{ v: T }[]>(sql);
  return rows[0]!.v;
}

describe('KL-013b KL7F-01: one runtime group per database', () => {
  it('the runtime login is a member of this database group only and reaches no other database', async () => {
    const [facts] = await runtime.$queryRawUnsafe<RuntimeRoleFacts[]>(RUNTIME_ROLE_FACTS_SQL);
    expect(facts).toMatchObject({
      runtimeGroup: RUNTIME_GROUP,
      inRuntimeGroup: true,
      unexpectedRoles: [],
      otherDatabases: [],
      databaseTemp: false,
    });
  });

  it('the group is NOLOGIN and holds CONNECT on this database only', async () => {
    const group = await runtime.$queryRawUnsafe<{ login: boolean; dbs: string[] }[]>(`
      SELECT r.rolcanlogin AS login,
             ARRAY(SELECT d.datname::text FROM pg_database d, aclexplode(d.datacl) a
                    WHERE a.grantee = r.oid ORDER BY 1) AS dbs
        FROM pg_roles r WHERE r.rolname = ${lit(RUNTIME_GROUP)}`);
    expect(group).toEqual([{ login: false, dbs: [DB] }]);
    expect(
      await value<boolean>(
        runtime,
        `SELECT has_database_privilege(${lit(RUNTIME_GROUP)}, current_database(), 'TEMPORARY') AS v`,
      ),
    ).toBe(false);
  });

  it('PUBLIC and the legacy cluster-wide group kabso_runtime hold nothing in this database', async () => {
    for (const priv of ['CONNECT', 'TEMPORARY', 'CREATE']) {
      expect(
        await value<boolean>(
          runtime,
          `SELECT has_database_privilege('public', current_database(), '${priv}') AS v`,
        ),
        priv,
      ).toBe(false);
    }
    const legacy = await runtime.$queryRawUnsafe<
      { db: boolean; tables: bigint; schema: boolean; defaults: bigint }[]
    >(`
      SELECT has_database_privilege(r.oid, current_database(), 'CONNECT, TEMPORARY, CREATE') AS db,
             (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'public'
                 AND has_table_privilege(r.oid, c.oid, 'SELECT, INSERT, UPDATE, DELETE')) AS tables,
             -- The role's OWN entries on schema public: has_schema_privilege() would also count
             -- PUBLIC's USAGE, which every role has (kept on purpose, see the next test).
             EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(n.nspacl) a
                      WHERE n.nspname = 'public' AND a.grantee = r.oid) AS schema,
             (SELECT count(*) FROM pg_default_acl d, aclexplode(d.defaclacl) a WHERE a.grantee = r.oid) AS defaults
        FROM pg_roles r WHERE r.rolname = 'kabso_runtime'`);
    for (const row of legacy) {
      expect({ ...row, tables: Number(row.tables), defaults: Number(row.defaults) }).toEqual({
        db: false,
        tables: 0,
        schema: false,
        defaults: 0,
      });
    }
  });

  it('PUBLIC keeps only USAGE on schema public (name lookup; no CREATE, no table privileges)', async () => {
    // Deliberate: CONNECT on the database is the gate (PUBLIC and other databases' groups have
    // none), and USAGE alone grants no access to any table, sequence or function in the schema.
    const pub = await runtime.$queryRawUnsafe<{ schema: string; objects: bigint }[]>(`
      SELECT (SELECT string_agg(a.privilege_type, ',' ORDER BY a.privilege_type)
                FROM pg_namespace n, aclexplode(n.nspacl) a
               WHERE n.nspname = 'public' AND a.grantee = 0) AS schema,
             (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace,
                     aclexplode(c.relacl) a
               WHERE n.nspname = 'public' AND a.grantee = 0) AS objects`);
    expect(pub.map((r) => ({ schema: r.schema, objects: Number(r.objects) }))).toEqual([
      { schema: 'USAGE', objects: 0 },
    ]);
  });

  it('future tables are granted to this database group (default privileges)', async () => {
    const acl = await value<string>(
      runtime,
      `SELECT string_agg(a.privilege_type, ',' ORDER BY a.privilege_type) AS v
         FROM pg_default_acl d, aclexplode(d.defaclacl) a
        WHERE d.defaclobjtype = 'r' AND d.defaclnamespace = 'public'::regnamespace
          AND a.grantee = ${lit(RUNTIME_GROUP)}::regrole`,
    );
    expect(acl).toBe('DELETE,INSERT,SELECT,UPDATE');
  });
});

describe('KL-013b KL7F-03: the boot guard checks object-level grants', () => {
  it.each([
    [
      'UPDATE on audit_logs',
      'GRANT UPDATE ON audit_logs TO {login}',
      /append-only rows: public\.audit_logs \(UPDATE\)/,
    ],
    [
      'column UPDATE on audit_logs',
      'GRANT UPDATE (action) ON audit_logs TO {login}',
      /public\.audit_logs \(UPDATE\)/,
    ],
    [
      'DELETE on audit_logs (via the group)',
      'GRANT DELETE ON audit_logs TO {group}',
      /public\.audit_logs \(DELETE\)/,
    ],
    [
      'SELECT on _prisma_migrations',
      'GRANT SELECT ON _prisma_migrations TO {login}',
      /privileges on _prisma_migrations/,
    ],
    [
      'column SELECT on _prisma_migrations',
      'GRANT SELECT (id) ON _prisma_migrations TO {group}',
      /_prisma_migrations/,
    ],
    [
      'a grant option on a table',
      'GRANT SELECT ON users TO {login} WITH GRANT OPTION',
      /grant options on table public\.users/,
    ],
    [
      'a grant option via the group',
      'GRANT SELECT ON sessions TO {group} WITH GRANT OPTION',
      /grant options on table public\.sessions/,
    ],
    [
      'a grant option on the schema',
      'GRANT USAGE ON SCHEMA public TO {login} WITH GRANT OPTION',
      /grant options on schema public/,
    ],
  ])('%s is reported', async (_name, grant, expected) => {
    const problems = await withMigrationClient((m) =>
      inRolledBackTx(m, async (tx) => {
        await tx.$executeRawUnsafe(
          grant.replace('{login}', ident(runtimeUser)).replace('{group}', ident(RUNTIME_GROUP)),
        );
        return assessRuntimeRole(await factsOf(tx, runtimeUser));
      }),
    );
    expect(problems.join('\n')).toMatch(expected);
  });

  it('the same inspection of the real runtime login is clean (grants above were rolled back)', async () => {
    const facts = await withMigrationClient((m) => factsOf(m, runtimeUser));
    expect(assessRuntimeRole(facts)).toEqual([]);
  });
});

describe('KL-013b KL7F-06: functions are not executable by PUBLIC', () => {
  it('no routine in schema public is executable by PUBLIC', async () => {
    const count = await value<bigint>(
      runtime,
      `SELECT count(*) AS v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND has_function_privilege('public', p.oid, 'EXECUTE')`,
    );
    expect(Number(count)).toBe(0);
  });

  it('a function the migration role creates later is executable by neither PUBLIC nor the runtime login', async () => {
    const result = await withMigrationClient((m) =>
      inRolledBackTx(m, async (tx) => {
        await tx.$executeRawUnsafe(
          `CREATE FUNCTION public.kl013b_later_fn() RETURNS int LANGUAGE sql AS $$ SELECT 1 $$`,
        );
        return tx.$queryRawUnsafe<{ pub: boolean; app: boolean }[]>(`
          SELECT has_function_privilege('public', 'public.kl013b_later_fn()', 'EXECUTE') AS pub,
                 has_function_privilege(${lit(runtimeUser)}, 'public.kl013b_later_fn()', 'EXECUTE') AS app`);
      }),
    );
    expect(result).toEqual([{ pub: false, app: false }]);
  });
});

describe('KL-013b KL7F-08: the grant migration only runs as the schema owner', () => {
  const file = readFileSync(
    new URL(
      '../../prisma/migrations/20261016130000_per_database_runtime_group/migration.sql',
      import.meta.url,
    ),
    'utf8',
  );
  const doBlock = /^DO \$\$[\s\S]*?^\$\$;$/m.exec(file)![0];
  const rest = file
    .slice(file.indexOf(doBlock) + doBlock.length)
    .split('\n')
    .filter((line) => !line.startsWith('--'))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);

  it('is refused for the runtime login', async () => {
    await expect(runtimeExec(doBlock)).rejects.toThrow(/must run as the owner of schema public/);
  });

  it('re-runs cleanly (idempotent) as the migration role', async () => {
    expect(rest).toHaveLength(2);
    const problems = await withMigrationClient((m) =>
      inRolledBackTx(m, async (tx) => {
        await tx.$executeRawUnsafe(doBlock);
        for (const statement of rest) await tx.$executeRawUnsafe(statement);
        return assessRuntimeRole(await factsOf(tx, runtimeUser));
      }),
    );
    expect(problems).toEqual([]);
  });
});

// ----------------------------- tests that need a PostgreSQL admin -----------------------------

describe('KL-013b admin connection', () => {
  it.runIf(process.env.CI === 'true')('KABSO_TEST_ADMIN_DATABASE_URL is set in CI', () => {
    expect(ADMIN_URL).toBeDefined();
  });
});

/** RFC 5802 verifier computed in-process (to feed the bootstrap a dev default in verifier form). */
function verifierOf(password: string): string {
  const salt = randomBytes(16);
  const salted = pbkdf2Sync(password, salt, 4096, 32, 'sha256');
  const stored = createHash('sha256')
    .update(createHmac('sha256', salted).update('Client Key').digest())
    .digest('base64');
  const server = createHmac('sha256', salted).update('Server Key').digest('base64');
  return `SCRAM-SHA-256$4096:${salt.toString('base64')}$${stored}:${server}`;
}

describe.runIf(ADMIN_URL)(
  'KL-013b KL7F-02: memberships reachable from the runtime login are rejected',
  () => {
    const admin = () => urlWith(ADMIN_URL!, { db: DB });
    const probe = `kl013b_probe_${suffix}`;
    const createRoleHolder = `kl013b_cr_${suffix}`;
    const loginProbe = `kl013b_login_${suffix}`;
    const loginPassword = randomBytes(18).toString('hex');

    beforeAll(async () => {
      await withClient(admin(), async (a) => {
        await a.$executeRawUnsafe(`CREATE ROLE ${ident(probe)} NOLOGIN`);
        await a.$executeRawUnsafe(`GRANT ${ident(RUNTIME_GROUP)} TO ${ident(probe)}`);
        await a.$executeRawUnsafe(`CREATE ROLE ${ident(createRoleHolder)} NOLOGIN CREATEROLE`);
        await a.$executeRawUnsafe(`CREATE ROLE ${ident(loginProbe)} LOGIN PASSWORD ${lit(loginPassword)}`);
        await a.$executeRawUnsafe(`GRANT ${ident(RUNTIME_GROUP)} TO ${ident(loginProbe)}`);
      });
    });

    afterAll(async () => {
      await withClient(admin(), async (a) => {
        for (const role of [probe, createRoleHolder, loginProbe]) {
          await a.$executeRawUnsafe(`DROP ROLE IF EXISTS ${ident(role)}`);
        }
      });
    });

    it('a plain member of the group is accepted (baseline)', async () => {
      const facts = await withClient(admin(), (a) => factsOf(a, probe));
      expect(assessRuntimeRole(facts)).toEqual([]);
    });

    it.each([
      'pg_execute_server_program',
      'pg_read_all_data',
      'pg_write_all_data',
      'pg_read_server_files',
      'pg_write_server_files',
      'kabso_runtime',
    ])('membership in %s (SET TRUE, INHERIT FALSE) is rejected', async (role) => {
      const problems = await withClient(admin(), (a) =>
        inRolledBackTx(a, async (tx) => {
          await tx.$executeRawUnsafe(`GRANT ${ident(role)} TO ${ident(probe)} WITH INHERIT FALSE, SET TRUE`);
          return assessRuntimeRole(await factsOf(tx, probe));
        }),
      );
      expect(problems.join('\n')).toMatch(new RegExp(`is a member of .*${role}`));
    });

    it('membership (even without SET or INHERIT) in a CREATEROLE role is rejected', async () => {
      const facts = await withClient(admin(), (a) =>
        inRolledBackTx(a, async (tx) => {
          await tx.$executeRawUnsafe(
            `GRANT ${ident(createRoleHolder)} TO ${ident(probe)} WITH INHERIT FALSE, SET FALSE`,
          );
          return factsOf(tx, probe);
        }),
      );
      expect(facts.createRole).toBe(true);
      expect(assessRuntimeRole(facts).join('\n')).toMatch(
        /has CREATEROLE \(directly or through role membership\)/,
      );
    });

    it('TEMPORARY on the database is rejected', async () => {
      const problems = await withClient(admin(), (a) =>
        inRolledBackTx(a, async (tx) => {
          await tx.$executeRawUnsafe(`GRANT TEMPORARY ON DATABASE ${ident(DB)} TO ${ident(probe)}`);
          return assessRuntimeRole(await factsOf(tx, probe));
        }),
      );
      expect(problems.join('\n')).toMatch(/TEMPORARY tables/);
    });

    it('production boot refuses a login with a SET-only pg_read_all_data membership', async () => {
      const url = urlWith(process.env.DATABASE_URL!, { user: loginProbe, password: loginPassword });
      const boot = async () => {
        const prisma = new PrismaService({
          ...buildTestConfig({ LOG_LEVEL: 'silent' }),
          databaseUrl: url,
          isProduction: true,
        });
        try {
          await prisma.onModuleInit();
        } finally {
          await prisma.$disconnect();
        }
      };
      await expect(boot()).resolves.toBeUndefined();
      await withClient(admin(), (a) =>
        a.$executeRawUnsafe(`GRANT pg_read_all_data TO ${ident(loginProbe)} WITH INHERIT FALSE, SET TRUE`),
      );
      await expect(boot()).rejects.toThrow(/is a member of pg_read_all_data/);
    });
  },
);

describe.runIf(ADMIN_URL)('KL-013b bootstrap script: cross-database isolation, atomicity, rotation', () => {
  const admin = (db = DB) => urlWith(ADMIN_URL!, { db });
  const dbB = `kl013b_${suffix}_test`;
  const dbC = `kl013b_${suffix}_c_test`;
  const groupB = `kabso_runtime_${dbB}`;
  const migB = `kl013b_mig_${suffix}`;
  const appB = `kl013b_app_${suffix}`;
  const app2 = `kl013b_app2_${suffix}`;
  const nologin = `kl013b_nologin_${suffix}`;
  const migC = `kl013b_migc_${suffix}`;
  const appC = `kl013b_appc_${suffix}`;
  const pw = { mig: randomBytes(16).toString('hex'), app: randomBytes(16).toString('hex') };
  const app2Password = randomBytes(16).toString('hex');
  const devEnv = () => ({
    KABSO_DB_ENV: 'development',
    KABSO_DB_MIGRATOR_USER: migB,
    KABSO_DB_MIGRATOR_PASSWORD: pw.mig,
    KABSO_DB_APP_USER: appB,
    KABSO_DB_APP_PASSWORD: pw.app,
  });
  const urlB = (user: string, password: string) =>
    urlWith(process.env.DATABASE_URL!, { db: dbB, user, password });

  beforeAll(async () => {
    await withClient(admin(), (a) => a.$executeRawUnsafe(`CREATE DATABASE ${ident(dbB)}`));
    const boot = runBootstrap(ADMIN_URL!, dbB, devEnv());
    expect(boot.output).not.toMatch(/ERROR/);
    expect(boot.status).toBe(0);
    const migrate = migrateDeploy(urlB(migB, pw.mig));
    expect(migrate.status, migrate.output).toBe(0);
  }, 120_000);

  afterAll(async () => {
    await withClient(admin(), async (a) => {
      for (const db of [dbB, dbC])
        await a.$executeRawUnsafe(`DROP DATABASE IF EXISTS ${ident(db)} WITH (FORCE)`);
      for (const role of [migB, appB, app2, nologin, groupB, migC, appC, `kabso_runtime_${dbC}`]) {
        await a.$executeRawUnsafe(`DROP ROLE IF EXISTS ${ident(role)}`);
      }
    });
  });

  it('bootstrap + migrate deploy on an empty database give a runtime login that passes the guard', async () => {
    const facts = await withClient(urlB(appB, pw.app), async (c) => {
      const [row] = await c.$queryRawUnsafe<RuntimeRoleFacts[]>(RUNTIME_ROLE_FACTS_SQL);
      return row!;
    });
    expect(facts.runtimeGroup).toBe(groupB);
    expect(assessRuntimeRole(facts)).toEqual([]);
  });

  it("the runtime login of one database cannot connect to another one's (both directions)", async () => {
    const denied = /permission denied for database|not have CONNECT/i;
    expect(await connectError(urlWith(process.env.DATABASE_URL!, { db: dbB }))).toMatch(denied);
    expect(await connectError(urlWith(process.env.DATABASE_URL!, { user: appB, password: pw.app }))).toMatch(
      denied,
    );
  });

  it('neither runtime group holds any privilege in the other database', async () => {
    const rows = await withClient(admin(), (a) =>
      a.$queryRawUnsafe<{ ab: boolean; ba: boolean }[]>(`
        SELECT has_database_privilege(${lit(RUNTIME_GROUP)}, ${lit(dbB)}, 'CONNECT, TEMPORARY, CREATE') AS ab,
               has_database_privilege(${lit(groupB)}, ${lit(DB)}, 'CONNECT, TEMPORARY, CREATE') AS ba`),
    );
    expect(rows).toEqual([{ ab: false, ba: false }]);
  });

  it('refuses a runtime login that already serves another database, and changes nothing', async () => {
    const run = runBootstrap(ADMIN_URL!, dbB, {
      ...devEnv(),
      KABSO_DB_APP_USER: runtimeUser,
      KABSO_DB_APP_PASSWORD: randomBytes(16).toString('hex'),
    });
    expect(run.status).not.toBe(0);
    expect(run.output).toMatch(new RegExp(`is a member of ${RUNTIME_GROUP}`));
    expect(await connectError(process.env.DATABASE_URL!)).toBeNull(); // password unchanged
    const member = await withClient(admin(), (a) =>
      value<boolean>(a, `SELECT pg_has_role(${lit(runtimeUser)}, ${lit(groupB)}, 'MEMBER') AS v`),
    );
    expect(member).toBe(false);
  });

  it('refuses when the group already holds privileges in another database', async () => {
    await withClient(admin(), (a) =>
      a.$executeRawUnsafe(`GRANT CONNECT ON DATABASE ${ident(DB)} TO ${ident(groupB)}`),
    );
    try {
      const run = runBootstrap(ADMIN_URL!, dbB, devEnv());
      expect(run.status).not.toBe(0);
      expect(run.output).toMatch(/other database\(s\)/);
    } finally {
      await withClient(admin(), (a) =>
        a.$executeRawUnsafe(`REVOKE CONNECT ON DATABASE ${ident(DB)} FROM ${ident(groupB)}`),
      );
    }
  });

  it('refuses to reset the password of a role used by another database (strict mode)', async () => {
    const run = runBootstrap(ADMIN_URL!, dbB, {
      KABSO_DB_ENV: 'production',
      KABSO_DB_MIGRATOR_USER: migrationUser,
      KABSO_DB_MIGRATOR_PASSWORD: verifierOf(randomBytes(16).toString('hex')),
      KABSO_DB_APP_USER: appB,
      KABSO_DB_APP_PASSWORD: verifierOf(pw.app),
    });
    expect(run.status).not.toBe(0);
    expect(run.output).toMatch(/other database\(s\)/);
    expect(await connectError(process.env.MIGRATION_DATABASE_URL!)).toBeNull();
  });

  it('refuses to turn an existing NOLOGIN role into a login (KL7F-04), and changes nothing', async () => {
    await withClient(admin(), (a) => a.$executeRawUnsafe(`CREATE ROLE ${ident(nologin)} NOLOGIN`));
    const run = runBootstrap(ADMIN_URL!, dbB, { ...devEnv(), KABSO_DB_APP_USER: nologin });
    expect(run.status).not.toBe(0);
    expect(run.output).toMatch(/is NOLOGIN; refusing/);
    const state = await withClient(admin(), (a) =>
      a.$queryRawUnsafe<{ login: boolean; member: boolean }[]>(`
        SELECT rolcanlogin AS login, pg_has_role(oid, ${lit(groupB)}, 'MEMBER') AS member
          FROM pg_roles WHERE rolname = ${lit(nologin)}`),
    );
    expect(state).toEqual([{ login: false, member: false }]);
  });

  it('is one transaction: a failure after the first changes leaves nothing behind (KL7F-04)', async () => {
    await withClient(admin(), (a) => a.$executeRawUnsafe(`CREATE DATABASE ${ident(dbC)}`));
    await withClient(admin(dbC), (a) => a.$executeRawUnsafe('DROP SCHEMA public'));
    const run = runBootstrap(ADMIN_URL!, dbC, {
      ...devEnv(),
      KABSO_DB_MIGRATOR_USER: migC,
      KABSO_DB_APP_USER: appC,
    });
    expect(run.status).not.toBe(0);
    expect(run.output).toMatch(/schema "public" does not exist/);
    const leftovers = await withClient(admin(), (a) =>
      a.$queryRawUnsafe<{ roles: string[]; acl: string | null }[]>(`
        SELECT ARRAY(SELECT rolname::text FROM pg_roles
                      WHERE rolname IN (${lit(migC)}, ${lit(appC)}, ${lit(`kabso_runtime_${dbC}`)})) AS roles,
               (SELECT datacl::text FROM pg_database WHERE datname = ${lit(dbC)}) AS acl`),
    );
    expect(leftovers).toEqual([{ roles: [], acl: null }]);
  });

  it('outside development only SCRAM verifiers are accepted, and dev defaults are refused', async () => {
    const plain = runBootstrap(ADMIN_URL!, dbB, { ...devEnv(), KABSO_DB_ENV: 'production' });
    expect(plain.status).not.toBe(0);
    expect(plain.output).toMatch(/must be a SCRAM-SHA-256 verifier/);

    expect(scramVerifier('kabso_app_dev_password').status).not.toBe(0);
    const devDefault = runBootstrap(ADMIN_URL!, dbB, {
      ...devEnv(),
      KABSO_DB_ENV: 'production',
      KABSO_DB_MIGRATOR_PASSWORD: verifierOf(pw.mig),
      KABSO_DB_APP_PASSWORD: verifierOf('kabso_app_dev_password'),
    });
    expect(devDefault.status).not.toBe(0);
    expect(devDefault.output).toMatch(/known development default/);
    expect(await connectError(urlB(appB, pw.app))).toBeNull(); // nothing changed

    // Rotation through the bootstrap with verifiers from infra/postgres/scram-verifier.mjs.
    const next = { mig: randomBytes(16).toString('hex'), app: randomBytes(16).toString('hex') };
    const verifiers = { mig: scramVerifier(next.mig), app: scramVerifier(next.app) };
    expect(verifiers.app.status).toBe(0);
    expect(verifiers.app.output).toMatch(/^SCRAM-SHA-256\$4096:/);
    const strict = runBootstrap(ADMIN_URL!, dbB, {
      ...devEnv(),
      KABSO_DB_ENV: 'production',
      KABSO_DB_MIGRATOR_PASSWORD: verifiers.mig.output,
      KABSO_DB_APP_PASSWORD: verifiers.app.output,
    });
    expect(strict.output).not.toMatch(/ERROR/);
    expect(strict.status).toBe(0);
    expect(await connectError(urlB(appB, next.app))).toBeNull();
    expect(await connectError(urlB(appB, pw.app))).toMatch(/password authentication failed/);
    expect(await connectError(urlB(migB, next.mig))).toBeNull();
    Object.assign(pw, next);
  });

  it('a re-run removes a legacy (KL-013) kabso_runtime membership and CONNECT', async () => {
    await withClient(admin(), async (a) => {
      await a.$executeRawUnsafe(`GRANT kabso_runtime TO ${ident(appB)}`);
      await a.$executeRawUnsafe(`GRANT CONNECT ON DATABASE ${ident(dbB)} TO kabso_runtime`);
    });
    const run = runBootstrap(ADMIN_URL!, dbB, devEnv());
    expect(run.output).not.toMatch(/ERROR/);
    expect(run.status).toBe(0);
    const state = await withClient(admin(), (a) =>
      a.$queryRawUnsafe<{ member: boolean; connect: boolean }[]>(`
        SELECT pg_has_role(${lit(appB)}, 'kabso_runtime', 'MEMBER') AS member,
               has_database_privilege('kabso_runtime', ${lit(dbB)}, 'CONNECT') AS connect`),
    );
    expect(state).toEqual([{ member: false, connect: false }]);
  });

  it('zero-downtime rotation: add a second runtime login, retire the first, never the last', async () => {
    const add = runBootstrap(ADMIN_URL!, dbB, {
      KABSO_DB_MODE: 'add-runtime-login',
      KABSO_DB_ENV: 'development',
      KABSO_DB_APP_USER: app2,
      KABSO_DB_APP_PASSWORD: app2Password,
    });
    expect(add.output).not.toMatch(/ERROR/);
    expect(add.status).toBe(0);
    await withClient(urlB(app2, app2Password), async (c) => {
      const [row] = await c.$queryRawUnsafe<RuntimeRoleFacts[]>(RUNTIME_ROLE_FACTS_SQL);
      expect(assessRuntimeRole(row!)).toEqual([]);
      expect(Number(await value<bigint>(c, 'SELECT count(*) AS v FROM users'))).toBeGreaterThanOrEqual(0);
    });

    const retire = runBootstrap(ADMIN_URL!, dbB, {
      KABSO_DB_MODE: 'retire-runtime-login',
      KABSO_DB_ENV: 'development',
      KABSO_DB_APP_USER: appB,
    });
    expect(retire.output).not.toMatch(/ERROR/);
    expect(retire.status).toBe(0);
    // Retired = NOLOGIN, password NULL, no group membership. With password authentication the
    // server checks the (now absent) password before rolcanlogin, so the refusal is 28P01; with
    // trust/peer/cert authentication NOLOGIN refuses instead. Both refusals are guaranteed.
    expect(await connectError(urlB(appB, pw.app))).toMatch(
      /password authentication failed|not permitted to log in/i,
    );
    const retired = await withClient(admin(), (a) =>
      a.$queryRawUnsafe<{ login: boolean; member: boolean; superuser: boolean }[]>(`
        SELECT r.rolcanlogin AS login, pg_has_role(r.oid, ${lit(groupB)}, 'MEMBER') AS member,
               (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) AS superuser
          FROM pg_roles r WHERE r.rolname = ${lit(appB)}`),
    );
    expect(retired.map(({ login, member }) => ({ login, member }))).toEqual([
      { login: false, member: false },
    ]);
    if (retired[0]!.superuser) {
      // pg_authid is readable by superusers only (the CI admin is one).
      const noPassword = await withClient(admin(), (a) =>
        value<boolean>(a, `SELECT rolpassword IS NULL AS v FROM pg_authid WHERE rolname = ${lit(appB)}`),
      );
      expect(noPassword).toBe(true);
    }
    expect(await connectError(urlB(app2, app2Password))).toBeNull();

    const last = runBootstrap(ADMIN_URL!, dbB, {
      KABSO_DB_MODE: 'retire-runtime-login',
      KABSO_DB_ENV: 'development',
      KABSO_DB_APP_USER: app2,
    });
    expect(last.status).not.toBe(0);
    expect(last.output).toMatch(/last runtime login/);
    expect(await connectError(urlB(app2, app2Password))).toBeNull();
  });
});
