import { describe, expect, it, vi } from 'vitest';
import {
  RUNTIME_ROLE_FACTS_SQL,
  UnsafeDatabaseRoleError,
  assessRuntimeRole,
  checkRuntimeRole,
  type RuntimeRoleFacts,
} from './runtime-role-check.js';

const SAFE: RuntimeRoleFacts = {
  user: 'kabso_app',
  runtimeGroup: 'kabso_runtime_kabso_test',
  inRuntimeGroup: true,
  unexpectedRoles: [],
  superuser: false,
  createRole: false,
  createDb: false,
  replication: false,
  bypassRls: false,
  ownedSchemas: [],
  ownedRelations: [],
  creatableSchemas: [],
  databaseCreate: false,
  databaseTemp: false,
  ddlLikeTablePrivileges: [],
  appendOnlyViolations: [],
  migrationHistoryAccess: false,
  grantOptions: [],
  otherDatabases: [],
};

function logger() {
  return { warn: vi.fn<(m: string) => void>(), fatal: vi.fn<(m: string) => void>() };
}

describe('assessRuntimeRole (SEC-011)', () => {
  it('accepts a DML-only role', () => {
    expect(assessRuntimeRole(SAFE)).toEqual([]);
  });

  it.each([
    [{ superuser: true }, 'is a superuser'],
    [{ createRole: true }, 'has CREATEROLE'],
    [{ createDb: true }, 'has CREATEDB'],
    [{ replication: true }, 'has REPLICATION'],
    [{ bypassRls: true }, 'has BYPASSRLS'],
    [{ ownedSchemas: ['public'] }, 'owns schema(s) public'],
    [{ ownedRelations: ['public.users'] }, 'owns public.users'],
    [{ creatableSchemas: ['public'] }, 'may CREATE objects in schema(s) public'],
    [{ databaseCreate: true }, 'may CREATE schemas in the database'],
    [{ ddlLikeTablePrivileges: ['public.audit_logs'] }, 'TRUNCATE/REFERENCES/TRIGGER on public.audit_logs'],
    // KL-013b (KL7F-01/02/03)
    [{ inRuntimeGroup: false }, 'is not a member of kabso_runtime_kabso_test'],
    [{ databaseTemp: true }, 'may create TEMPORARY tables in the database'],
    [
      { appendOnlyViolations: ['public.audit_logs (UPDATE)'] },
      'append-only rows: public.audit_logs (UPDATE)',
    ],
    [{ migrationHistoryAccess: true }, 'holds privileges on _prisma_migrations'],
    [{ grantOptions: ['table public.users'] }, 'holds grant options on table public.users'],
    [{ otherDatabases: ['kabso_prod'] }, 'other database(s) kabso_prod'],
  ] as const)('rejects %o', (patch, expected) => {
    const problems = assessRuntimeRole({ ...SAFE, ...patch });
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain(expected);
  });

  it.each([
    'pg_execute_server_program',
    'pg_read_all_data',
    'pg_write_all_data',
    'pg_read_server_files',
    'pg_write_server_files',
    'pg_database_owner',
    'kabso_runtime',
    'kabso_runtime_kabso_prod',
  ])('rejects any reachable role other than the runtime group: %s', (role) => {
    const problems = assessRuntimeRole({ ...SAFE, unexpectedRoles: [role] });
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain(`is a member of ${role} (only kabso_runtime_kabso_test is allowed`);
  });

  it('attributes reached through membership are named as such', () => {
    const problems = assessRuntimeRole({
      ...SAFE,
      unexpectedRoles: ['admins'],
      superuser: true,
      createRole: true,
    });
    expect(problems).toEqual([
      'is a superuser (directly or through role membership)',
      'has CREATEROLE (directly or through role membership)',
      expect.stringContaining('is a member of admins'),
    ]);
  });

  it('lists every problem of the owner role and truncates long lists', () => {
    const owned = Array.from({ length: 8 }, (_, i) => `public.t${i}`);
    const problems = assessRuntimeRole({
      ...SAFE,
      user: 'kabso_migrator',
      ownedSchemas: ['public'],
      ownedRelations: owned,
      creatableSchemas: ['public'],
      databaseCreate: true,
      ddlLikeTablePrivileges: owned,
    });
    expect(problems).toHaveLength(5);
    expect(problems.join('\n')).toContain('(8 total)');
  });
});

describe('checkRuntimeRole', () => {
  it('runs the catalog query and passes a safe role silently', async () => {
    const query = vi.fn(() => Promise.resolve([SAFE]));
    const log = logger();
    await expect(checkRuntimeRole(query, { enforce: true, logger: log })).resolves.toEqual([]);
    expect(query).toHaveBeenCalledWith(RUNTIME_ROLE_FACTS_SQL);
    expect(log.warn).not.toHaveBeenCalled();
    expect(log.fatal).not.toHaveBeenCalled();
  });

  it('fails closed in production with a clear fatal log line', async () => {
    const log = logger();
    const unsafe = { ...SAFE, user: 'kabso_migrator', ownedSchemas: ['public'] };
    const run = checkRuntimeRole(() => Promise.resolve([unsafe]), { enforce: true, logger: log });
    await expect(run).rejects.toBeInstanceOf(UnsafeDatabaseRoleError);
    await expect(run).rejects.toThrow(/"kabso_migrator".*owns schema\(s\) public.*SEC-011/);
    expect(log.fatal).toHaveBeenCalledTimes(1);
    expect(log.fatal.mock.calls[0]?.[0]).toMatch(/^db\.runtime_role_check failed — refusing to start\./);
  });

  it('fails closed in production when the role cannot be inspected', async () => {
    const log = logger();
    await expect(
      checkRuntimeRole(() => Promise.resolve([]), { enforce: true, logger: log }),
    ).rejects.toBeInstanceOf(UnsafeDatabaseRoleError);
    expect(log.fatal).toHaveBeenCalledTimes(1);
  });

  it('only warns outside production', async () => {
    const log = logger();
    const problems = await checkRuntimeRole(() => Promise.resolve([{ ...SAFE, superuser: true }]), {
      enforce: false,
      logger: log,
    });
    expect(problems).toEqual(['is a superuser']);
    expect(log.warn).toHaveBeenCalledTimes(1);
    expect(log.warn.mock.calls[0]?.[0]).toContain('not enforced outside production');
    expect(log.fatal).not.toHaveBeenCalled();
  });
});
