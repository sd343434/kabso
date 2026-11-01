/**
 * D223 (owner 2026-11-01: «الجهاز الواحد لا يمكنه عمل غير حسابين لكنه يمكن فتح حسابات مختلفة»; contract v1.78-social,
 * CONVENTIONS §10.75): one device may CREATE at most SIGNUP_MAX_ACCOUNTS_PER_DEVICE (2) accounts — deleted and
 * pending-deletion ones included — while signing in to any number of accounts stays open. The device is
 * `DeviceInfo.deviceKey` (stored only as an HMAC); a sign-up without one is not counted. The panel's «الجهاز» lists the
 * accounts of a user's sign-up device (`users.device_view`, audited) and an OWNER may grant that device an exception
 * (`users.device_exception`, the code again, a reason, audited). End to end against PostgreSQL + Redis.
 */
import { createHash, randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { requestDeletionIn, purgeAccountIn } from '../src/modules/users/account-deletion.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
  readonly ip: string;
  readonly deviceKey: string | null;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}
interface DeviceView {
  known: boolean;
  platform: string | null;
  defaultMax: number;
  maxAccounts: number;
  count: number;
  exception: {
    maxAccounts: number;
    reason: string;
    grantedBy: { id: string; username: string } | null;
  } | null;
  accounts: { id: string; username: string; status: string; self: boolean }[];
}

/** What the app sends: a salted SHA-256 of the platform id (here of a random stand-in). */
const newDeviceKey = () =>
  createHash('sha256').update(`kabso-test-salt:android:${randomUUID()}`).digest('hex');

describe('D223 contract coverage', () => {
  it('openapi v1.78-social declares DeviceInfo.deviceKey, the 409 and the panel routes', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAdminDeviceSignups GET /api/v1/admin/users/{userId}/device-signups',
        'grantAdminDeviceException PUT /api/v1/admin/users/{userId}/device-signups/exception',
        'removeAdminDeviceException POST /api/v1/admin/users/{userId}/device-signups/exception/remove',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    const deviceKey = (schemas.DeviceInfo!.properties as Record<string, { pattern?: string }>).deviceKey;
    expect(deviceKey?.pattern).toBe('^[0-9a-f]{64}$');
    for (const o of operations().filter((x) => x.path.includes('/device-signups'))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
    // The register routes document DEVICE_ACCOUNT_LIMIT under 409.
    const register = operations().find((o) => o.path === '/api/v1/auth/register' && o.method === 'post')!;
    const verify = operations().find(
      (o) => o.path === '/api/v1/auth/register/verify' && o.method === 'post',
    )!;
    expect(JSON.stringify((register.spec.responses as Record<string, unknown>)['409'])).toContain(
      'DEVICE_ACCOUNT_LIMIT',
    );
    expect(JSON.stringify((verify.spec.responses as Record<string, unknown>)['409'])).toContain(
      'DEVICE_ACCOUNT_LIMIT',
    );
  });
});

describe('D223 accounts per device', { timeout: 600_000 }, () => {
  let ctx: TestContext;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `203.0.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const deviceOf = (deviceKey: string | null) => ({
    name: 'Pixel 9',
    platform: 'android',
    appVersion: '1.0.0',
    ...(deviceKey ? { deviceKey } : {}),
  });

  const register = async (deviceKey: string | null, ip = nextIp()) => {
    const payload = newUser({ device: deviceOf(deviceKey) });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    return { res, payload, email, ip, before };
  };
  const verify = async (
    r: Awaited<ReturnType<typeof register>>,
    device: Record<string, unknown> | undefined = r.payload.device,
  ) => {
    const mail = await ctx.mail.waitFor(r.email, 'code', r.before);
    return ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', r.ip)
      .send({ email: r.email, code: mail.code, ...(device ? { device } : {}) });
  };
  const signup = async (deviceKey: string | null = newDeviceKey()): Promise<TestUser> => {
    const r = await register(deviceKey);
    expect(r.res.status, JSON.stringify(r.res.body)).toBe(202);
    const res = await verify(r);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: r.email,
      password: String(r.payload.password),
      token: res.body.tokens.accessToken as string,
      ip: r.ip,
      deviceKey,
    };
  };
  const login = (u: TestUser, deviceKey: string | null) =>
    ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', nextIp())
      .send({ identifier: u.email, password: u.password, device: deviceOf(deviceKey) });
  const expectLimit = (res: request.Response, max: number) => {
    expect(res.status, JSON.stringify(res.body)).toBe(409);
    expect(res.body.error).toMatchObject({
      code: 'DEVICE_ACCOUNT_LIMIT',
      details: [{ field: 'device', issue: String(max) }],
    });
  };
  const audits = (action: string) =>
    ctx.prisma.auditLog.findMany({ where: { action }, orderBy: { createdAt: 'asc' } });

  // ---- the panel ---------------------------------------------------------------------------------------------
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup(null);
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const awrite = (a: Admin, method: 'post' | 'put', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
      REFRESH_TTL_SECONDS: String(60 * 86_400),
      REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
    });
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the 1st and 2nd sign-up of a device are allowed, the 3rd is refused at register; sign-in stays open', async () => {
    const key = newDeviceKey();
    const a = await signup(key);
    const b = await signup(key);
    // Stored only as an HMAC under the server's key: never the app's value.
    const rows = await ctx.prisma.deviceSignup.findMany({ where: { userId: { in: [a.id, b.id] } } });
    expect(rows).toHaveLength(2);
    expect(rows[0]!.deviceHash).toMatch(/^[0-9a-f]{64}$/);
    expect(rows[0]!.deviceHash).not.toBe(key);
    expect(rows[0]!.deviceHash).toBe(rows[1]!.deviceHash);
    expect(rows[0]!.platform).toBe('android');

    const third = await register(key);
    expectLimit(third.res, 2);
    expectContract(third.res, 'register');
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: third.email } })).toBe(0);
    expect(ctx.mail.sent.length).toBe(third.before); // no code mailed
    const refused = await audits('auth.registration.device_limit');
    expect(refused).toHaveLength(1);
    expect(refused[0]!.metadata).toEqual({ stage: 'register', count: 2, max: 2 });

    // The refusal depends on the device only: an address that already has an account gets the same 409.
    const existing = await ctx.http
      .post('/api/v1/auth/register')
      .set('X-Forwarded-For', nextIp())
      .send(newUser({ email: a.email, device: deviceOf(key) }));
    expectLimit(existing, 2);

    // Signing in is never limited: the device's two accounts and a third account made elsewhere.
    const c = await signup(newDeviceKey());
    for (const u of [a, b, c]) {
      const res = await login(u, key);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
    }
    // Signing in records nothing about the device key (only sign-ups count).
    expect(await ctx.prisma.deviceSignup.count({ where: { userId: c.id } })).toBe(1);
    expect(await ctx.prisma.deviceSignup.count({ where: { deviceHash: rows[0]!.deviceHash } })).toBe(2);
  });

  it('a deleted account (and one pending deletion) still counts: delete-and-recreate does not free a place', async () => {
    const key = newDeviceKey();
    const a = await signup(key);
    const b = await signup(key);
    // a: pending deletion (grace period), b: purged to a tombstone.
    await ctx.prisma.$transaction((tx) => requestDeletionIn(tx, a.id, new Date(clock), 30, { via: 'APP' }));
    await ctx.prisma.$transaction((tx) =>
      purgeAccountIn(tx, b.id, new Date(clock), {
        quarantineDays: 90,
        specialGraceDays: 30,
        legalHoldDays: 90,
        via: 'ADMIN',
      }),
    );
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('DELETED');
    expect(await ctx.prisma.deviceSignup.count({ where: { userId: { in: [a.id, b.id] } } })).toBe(2);
    expectLimit((await register(key)).res, 2);
  });

  it('a sign-up without a device key (the website, an older app) is allowed and not counted', async () => {
    const users: TestUser[] = [];
    for (let i = 0; i < 3; i++) users.push(await signup(null));
    expect(await ctx.prisma.deviceSignup.count({ where: { userId: { in: users.map((u) => u.id) } } })).toBe(
      0,
    );
    // A malformed key is a validation error, not a way around the rule.
    const bad = await ctx.http
      .post('/api/v1/auth/register')
      .set('X-Forwarded-For', nextIp())
      .send(newUser({ device: { platform: 'android', deviceKey: 'NOT-A-HASH' } }));
    expect(bad.status).toBe(400);
  });

  it('verify checks again: two pending sign-ups for the last place — the second is refused and released', async () => {
    const key = newDeviceKey();
    await signup(key);
    const p1 = await register(key);
    const p2 = await register(key);
    expect(p1.res.status).toBe(202);
    expect(p2.res.status).toBe(202);
    expect((await verify(p1)).status).toBe(201);
    const second = await verify(p2);
    expectLimit(second, 2);
    expectContract(second, 'registerVerify');
    // The pending registration is gone (its username is free again); no account was made.
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: p2.email } })).toBe(0);
    expect(await ctx.prisma.user.count({ where: { email: p2.email } })).toBe(0);
    const verifyRefusals = (await audits('auth.registration.device_limit')).filter(
      (r) => (r.metadata as { stage?: string }).stage === 'verify',
    );
    expect(verifyRefusals).toHaveLength(1);
    expect(verifyRefusals[0]!.metadata).toMatchObject({ count: 2, max: 2 });
  });

  it('the device verifying counts too, and a register without a key cannot be completed on a full device', async () => {
    const key = newDeviceKey();
    await signup(key);
    await signup(key);
    // Registered with no key (e.g. on the website), then the code is typed in the app on the full device.
    const r = await register(null);
    expect(r.res.status).toBe(202);
    expectLimit(await verify(r, deviceOf(key)), 2);
    // A sign-up registered on a full device's key but verified without one still uses the registered device.
    const other = newDeviceKey();
    const first = await signup(other);
    const r2 = await register(other);
    expect(r2.res.status).toBe(202);
    await signup(other); // takes the last place meanwhile
    expectLimit(await verify(r2, undefined), 2);
    expect(first.id).toBeTruthy();
  });

  it('the panel: SUPPORT sees the device accounts (audited); an OWNER grants an exception with the code again', async () => {
    const owner = await makeAdmin(['OWNER']);
    const support = await makeAdmin(['SUPPORT']);
    const finance = await makeAdmin(['FINANCE']);
    const key = newDeviceKey();
    const a = await signup(key);
    const b = await signup(key);
    await ctx.prisma.$transaction((tx) =>
      purgeAccountIn(tx, b.id, new Date(clock), {
        quarantineDays: 90,
        specialGraceDays: 30,
        legalHoldDays: 90,
        via: 'ADMIN',
      }),
    );

    const view = await aget(support, `/admin/users/${a.id}/device-signups`);
    expect(view.status, JSON.stringify(view.body)).toBe(200);
    expectContract(view, 'getAdminDeviceSignups');
    const v = view.body as DeviceView;
    expect(v).toMatchObject({
      known: true,
      platform: 'android',
      defaultMax: 2,
      maxAccounts: 2,
      count: 2,
      exception: null,
    });
    expect(v.accounts.map((x) => [x.id, x.status, x.self])).toEqual([
      [a.id, 'ACTIVE', true],
      [b.id, 'DELETED', false],
    ]);
    expect(JSON.stringify(view.body)).not.toMatch(/[0-9a-f]{64}/); // the hash is never shown
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'admin.device_signups.view', actorUserId: support.id, targetId: a.id },
      }),
    ).toBe(1);
    // A user created without a device: known false.
    const web = await signup(null);
    expect((await aget(owner, `/admin/users/${web.id}/device-signups`)).body).toMatchObject({
      known: false,
      count: 0,
      accounts: [],
    });
    expect((await aget(finance, `/admin/users/${a.id}/device-signups`)).status).toBe(403);
    expect((await aget(owner, `/admin/users/${randomUUID()}/device-signups`)).status).toBe(404);

    const path = `/admin/users/${a.id}/device-signups/exception`;
    // Only an OWNER; the code again; a reason.
    expect(
      (
        await awrite(support, 'put', path, {
          maxAccounts: 3,
          reason: 'x',
          totpCode: nextCode(support.secret),
        })
      ).status,
    ).toBe(403);
    expect(
      (await awrite(owner, 'put', path, { maxAccounts: 3, reason: 'x', totpCode: '000000' })).status,
    ).toBe(403);
    expect(
      (await awrite(owner, 'put', path, { maxAccounts: 3, totpCode: nextCode(owner.secret) })).status,
    ).toBe(400);
    expect(
      (await awrite(owner, 'put', path, { maxAccounts: 0, reason: 'x', totpCode: nextCode(owner.secret) }))
        .status,
    ).toBe(400);
    expect(await ctx.prisma.deviceSignupException.count()).toBe(0);
    expect(
      (
        await awrite(owner, 'put', `/admin/users/${web.id}/device-signups/exception`, {
          maxAccounts: 3,
          reason: 'x',
          totpCode: nextCode(owner.secret),
        })
      ).status,
    ).toBe(409);

    expectLimit((await register(key)).res, 2);
    const granted = await awrite(owner, 'put', path, {
      maxAccounts: 3,
      reason: 'Family phone, verified by support ticket',
      totpCode: nextCode(owner.secret),
    });
    expect(granted.status, JSON.stringify(granted.body)).toBe(200);
    expectContract(granted, 'grantAdminDeviceException');
    expect(granted.body).toMatchObject({
      maxAccounts: 3,
      count: 2,
      exception: {
        maxAccounts: 3,
        reason: 'Family phone, verified by support ticket',
        grantedBy: { id: owner.id },
      },
    });
    const grantAudit = (await audits('admin.device_exception.grant')).at(-1)!;
    expect(grantAudit).toMatchObject({ actorUserId: owner.id, targetId: a.id });
    expect(grantAudit.metadata).toMatchObject({
      maxAccounts: 3,
      before: null,
      defaultMax: 2,
      reason: 'Family phone, verified by support ticket',
      via: 'panel',
    });

    // The third account is allowed now; the fourth is refused with the device's own limit.
    const c = await signup(key);
    expect(c.id).toBeTruthy();
    expectLimit((await register(key)).res, 3);

    // Removing the exception brings the default back (the accounts made stay).
    const removePath = `${path}/remove`;
    expect((await awrite(owner, 'post', removePath, { reason: 'x', totpCode: '000000' })).status).toBe(403);
    const removed = await awrite(owner, 'post', removePath, {
      reason: 'Ticket closed',
      totpCode: nextCode(owner.secret),
    });
    expect(removed.status, JSON.stringify(removed.body)).toBe(200);
    expectContract(removed, 'removeAdminDeviceException');
    expect(removed.body).toMatchObject({ maxAccounts: 2, count: 3, exception: null });
    expect((await audits('admin.device_exception.remove')).at(-1)!.metadata).toMatchObject({
      before: 3,
      reason: 'Ticket closed',
    });
    expect(
      (await awrite(owner, 'post', removePath, { reason: 'x', totpCode: nextCode(owner.secret) })).status,
    ).toBe(409);
    expectLimit((await register(key)).res, 2);
  });
});
