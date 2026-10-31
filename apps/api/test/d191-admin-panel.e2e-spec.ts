/**
 * D191 (owner 2026-10-31; contract v1.60-social, CONVENTIONS §10.54, CP-034): the admin panel API — its own sign-in
 * (password + mandatory TOTP with QR enrolment, hashed single-use recovery codes, lockout), the HttpOnly cookie
 * session with CSRF and expiry, the role × capability matrix checked on the server, audited mutations, the TOTP
 * re-entry for financial actions, private recharge pictures (audited per view, forbidden per role), and the panel
 * running the very rules of the CLIs (`admin-admin`, `recharge-admin`, `economy-admin`). End to end against
 * PostgreSQL + Redis with the in-memory object storage.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { CAPABILITIES, PANEL_ROLES, type Capability } from '../src/modules/admin-panel/admin-permissions.js';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { privateKeyOf } from '../src/modules/recharge/recharge-core.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const run = promisify(execFile);
const cli = (file: string, args: string[]) =>
  run('node', ['--import', 'tsx', `src/cli/${file}`, ...args], {
    env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
  });

const COOKIE = '__Host-kabso_admin';

interface Person {
  readonly id: string;
  readonly email: string;
  readonly password: string;
  readonly username: string;
  readonly token: string;
}

interface Admin extends Person {
  secret: string;
  cookie: string;
  csrf: string;
  recoveryCodes: string[];
}

describe('D191 contract coverage', () => {
  it('openapi v1.60-social declares exactly the panel operations', () => {
    const ops = operations()
      .filter((o) =>
        /^\/api\/v1\/(admin\/(auth|dashboard|users|recharge|withdrawals|moderation|site-settings)|site)(\/|$)/.test(
          o.path,
        ),
      )
      .map((o) => o.operationId)
      .sort();
    expect(ops).toEqual(
      [
        'adminLogin',
        'startAdminTotpEnrolment',
        'confirmAdminTotpEnrolment',
        'verifyAdminTotp',
        'getAdminSession',
        'adminLogout',
        'getAdminDashboard',
        'searchAdminUsers',
        'getAdminUser',
        'banAdminUser',
        'unbanAdminUser',
        'removeAdminUserAvatar',
        'giftAdminSpecialUsername',
        'revokeAdminSpecialUsername',
        'listAdminRechargeApplications',
        'getAdminRechargeApplication',
        'getAdminRechargeApplicationPhoto',
        'approveAdminRechargeApplication',
        'rejectAdminRechargeApplication',
        'listAdminRechargeAgents',
        'topUpAdminRechargeAgent',
        'suspendAdminRechargeAgent',
        'reinstateAdminRechargeAgent',
        'setAdminRechargeAgentCap',
        'listAdminWithdrawals',
        'payAdminWithdrawal',
        'rejectAdminWithdrawal',
        'listAdminPanelReports',
        'actOnAdminPanelReport',
        'getAdminSiteSettings',
        'updateAdminSiteSettings',
        'getSiteSettings',
      ].sort(),
    );
  });
});

describe('D191 admin panel', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  /** The clock the API and the authenticator codes read (Date only, moved forward between codes). */
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    // A code works once: move to the next 30-second step before every code.
    advance(30_000);
    return totpCode(secret, clock);
  };

  const signup = async (): Promise<Person> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      email: payload.email,
      password: payload.password,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };

  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    expect(line).toMatch(/HttpOnly/);
    expect(line).toMatch(/Secure/);
    expect(line).toMatch(/SameSite=Strict/);
    expect(line).toMatch(/Path=\//);
    return line.split(';')[0]!;
  };

  const login = (email: string, password: string) =>
    ctx.http.post('/api/v1/admin/auth/login').send({ email, password });

  /** An admin with these roles, granted through the CLI rule, enrolled through the API. */
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await login(p.email, p.password);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'adminLogin');
    expect(res.body.next).toBe('TOTP_ENROL');
    const pending = cookieOf(res);
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', res.body.csrfToken as string);
    expect(enrol.status).toBe(200);
    expectContract(enrol, 'startAdminTotpEnrolment');
    const secret = enrol.body.secret as string;
    expect(enrol.body.otpauthUri).toContain(`secret=${secret}`);
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', res.body.csrfToken as string)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    expectContract(confirm, 'confirmAdminTotpEnrolment');
    expect(confirm.body.recoveryCodes).toHaveLength(10);
    return {
      ...p,
      secret,
      cookie: cookieOf(confirm),
      csrf: confirm.body.session.csrfToken as string,
      recoveryCodes: confirm.body.recoveryCodes as string[],
    };
  };

  /** A new signed-in session (sessions idle out while the clock moves on). */
  const relogin = async (...admins: Admin[]) => {
    for (const a of admins) {
      const res = await login(a.email, a.password);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      const v = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', cookieOf(res))
        .set('X-CSRF-Token', res.body.csrfToken as string)
        .send({ code: nextCode(a.secret) });
      expect(v.status, JSON.stringify(v.body)).toBe(200);
      a.cookie = cookieOf(v);
      a.csrf = v.body.csrfToken as string;
    }
  };

  const get = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const post = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: { createdAt: 'asc' },
    });

  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_LOCKOUT_ATTEMPTS: '3',
        ADMIN_LOCKOUT_SECONDS: '600',
        ADMIN_SESSION_IDLE_SECONDS: '600',
        ADMIN_SESSION_MAX_SECONDS: '3600',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  afterEach(() => {
    vi.setSystemTime(clock);
  });

  describe('sign-in', () => {
    it('refuses wrong passwords, unknown emails and non-admins with the same 401', async () => {
      const plain = await signup();
      for (const res of [
        await login(owner.email, 'wrong-password-1'),
        await login(`nobody-${randomUUID()}@example.test`, 'x'),
        await login(plain.email, plain.password),
      ]) {
        expect(res.status).toBe(401);
        expect(res.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
        expect(res.headers['set-cookie']).toBeUndefined();
      }
      // A user token of the app is no panel session.
      const bearer = await ctx.http
        .get('/api/v1/admin/dashboard')
        .set('Authorization', `Bearer ${owner.token}`);
      expect(bearer.status).toBe(401);
      const failures = await audits('admin.login.failure');
      expect(failures.map((f) => (f.metadata as { reason: string }).reason)).toEqual(
        expect.arrayContaining(['bad_password', 'unknown', 'not_admin']),
      );
      // Nothing secret in the audit rows.
      expect(JSON.stringify(failures)).not.toContain('wrong-password-1');
    });

    it('a later sign-in needs a code: TOTP, single use; a recovery code works once', async () => {
      const res = await login(owner.email, owner.password);
      expect(res.body.next).toBe('TOTP_VERIFY');
      const pending = cookieOf(res);
      const csrf = res.body.csrfToken as string;
      // A pending session opens nothing but the second factor.
      expect((await ctx.http.get('/api/v1/admin/dashboard').set('Cookie', pending)).status).toBe(401);
      const verify = (body: object) =>
        ctx.http
          .post('/api/v1/admin/auth/totp/verify')
          .set('Cookie', pending)
          .set('X-CSRF-Token', csrf)
          .send(body);
      const used = nextCode(owner.secret);
      const ok = await verify({ code: used });
      expect(ok.status, JSON.stringify(ok.body)).toBe(200);
      expectContract(ok, 'verifyAdminTotp');
      expect(ok.body.roles).toEqual(['OWNER']);
      expect(ok.body.capabilities).toEqual(Object.keys(CAPABILITIES));
      const active = cookieOf(ok);
      expect(active).not.toBe(pending);
      // The pending cookie is dead after promotion (no fixation).
      expect((await verify({ code: used })).status).toBe(401);
      const me = await ctx.http.get('/api/v1/admin/auth/session').set('Cookie', active);
      expect(me.status).toBe(200);
      expectContract(me, 'getAdminSession');
      // The code just used is consumed: a new sign-in in the same 30 seconds cannot replay it.
      const replayLogin = await login(owner.email, owner.password);
      const reused = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', cookieOf(replayLogin))
        .set('X-CSRF-Token', replayLogin.body.csrfToken as string)
        .send({ code: used });
      expect(reused.status, JSON.stringify(reused.body)).toBe(403);
      expect(reused.body.error.code).toBe('ADMIN_TOTP_INVALID');

      // Recovery code: once.
      const code = owner.recoveryCodes[0]!;
      const second = await login(owner.email, owner.password);
      const c2 = cookieOf(second);
      const r1 = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', c2)
        .set('X-CSRF-Token', second.body.csrfToken as string)
        .send({ recoveryCode: code.toUpperCase() });
      expect(r1.status).toBe(200);
      const third = await login(owner.email, owner.password);
      const r2 = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', cookieOf(third))
        .set('X-CSRF-Token', third.body.csrfToken as string)
        .send({ recoveryCode: code });
      expect(r2.status).toBe(403);
      expect(r2.body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect((await audits('admin.recovery_code.used', undefined)).length).toBe(1);
      const stored = await ctx.prisma.adminRecoveryCode.findMany({ where: { userId: owner.id } });
      expect(stored).toHaveLength(10);
      expect(JSON.stringify(stored)).not.toContain(code);
      // The secret is stored encrypted.
      const cred = await ctx.prisma.adminCredential.findUniqueOrThrow({ where: { userId: owner.id } });
      expect(cred.totpSecretEnc).toMatch(/^v1\./);
      expect(cred.totpSecretEnc).not.toContain(owner.secret);
      // The failed attempts so far were reset by the successes.
      await ctx.prisma.adminCredential.update({ where: { userId: owner.id }, data: { failedAttempts: 0 } });
    });

    it('locks the account after failed codes and ends its sessions', async () => {
      const victim = await makeAdmin(['SUPPORT']);
      const res = await login(victim.email, victim.password);
      const pending = cookieOf(res);
      const verify = (code: string) =>
        ctx.http
          .post('/api/v1/admin/auth/totp/verify')
          .set('Cookie', pending)
          .set('X-CSRF-Token', res.body.csrfToken as string)
          .send({ code });
      expect((await verify('000000')).body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect((await verify('000001')).body.error.code).toBe('ADMIN_TOTP_INVALID');
      const locked = await verify('000002');
      expect(locked.status).toBe(429);
      expect(locked.body.error.code).toBe('ADMIN_LOCKED');
      expect(Number(locked.headers['retry-after'])).toBeGreaterThan(0);
      // The already signed-in session ended too, and the password stage is locked.
      expect((await get(victim, '/admin/auth/session')).status).toBe(401);
      const again = await login(victim.email, victim.password);
      expect(again.status).toBe(429);
      expect(again.body.error.code).toBe('ADMIN_LOCKED');
      expect((await audits('admin.login.locked')).some((a) => a.actorUserId === victim.id)).toBe(true);
      // After the lock, signing in works again.
      advance(601_000);
      expect((await login(victim.email, victim.password)).status).toBe(200);
    });

    it('locks an email after failed passwords (the same for any email)', async () => {
      const victim = await makeAdmin(['FINANCE']);
      for (let i = 0; i < 3; i++) expect((await login(victim.email, `bad-${i}`)).status).toBe(401);
      const r = await login(victim.email, victim.password);
      expect(r.status).toBe(429);
      expect(r.body.error.code).toBe('ADMIN_LOCKED');
      const ghost = `ghost-${randomUUID()}@example.test`;
      for (let i = 0; i < 3; i++) expect((await login(ghost, 'x')).status).toBe(401);
      expect((await login(ghost, 'x')).status).toBe(429);
    });

    it('requires the CSRF token on every change', async () => {
      await relogin(owner);
      const target = await signup();
      const noToken = await ctx.http
        .post(`/api/v1/admin/users/${target.id}/ban`)
        .set('Cookie', owner.cookie)
        .send({ reason: 'spam' });
      expect(noToken.status).toBe(403);
      expect(noToken.body.error.code).toBe('ADMIN_CSRF_INVALID');
      const wrong = await ctx.http
        .post(`/api/v1/admin/users/${target.id}/ban`)
        .set('Cookie', owner.cookie)
        .set('X-CSRF-Token', moderator.csrf)
        .send({ reason: 'spam' });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_CSRF_INVALID');
      expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('ACTIVE');
    });

    it('expires an idle session; logout ends it; a revoked role applies at once', async () => {
      const a = await makeAdmin(['MODERATION']);
      expect((await get(a, '/admin/dashboard')).status).toBe(200);
      advance(601_000);
      expect((await get(a, '/admin/dashboard')).status).toBe(401);

      const b = await makeAdmin(['MODERATION']);
      const out = await post(b, '/admin/auth/logout');
      expect(out.status).toBe(204);
      expect((await get(b, '/admin/dashboard')).status).toBe(401);
      expect((await audits('admin.logout')).some((x) => x.actorUserId === b.id)).toBe(true);

      const c = await makeAdmin(['MODERATION']);
      expect((await get(c, '/admin/moderation/reports')).status).toBe(200);
      await cli('admin-admin.ts', ['revoke', c.email, 'MODERATOR']);
      expect((await get(c, '/admin/moderation/reports')).status).toBe(401);
    });
  });

  describe('permission matrix', () => {
    beforeAll(() => relogin(owner, moderator, support, finance));
    /** One read per capability that has one; the mutations are covered below. */
    const READS: Partial<Record<Capability, string>> = {
      'dashboard.view': '/admin/dashboard',
      'users.view': '/admin/users?q=a',
      'recharge.applications': '/admin/recharge/applications',
      'recharge.agents': '/admin/recharge/agents',
      'withdrawals.view': '/admin/withdrawals',
      'reports.view': '/admin/moderation/reports',
      'site.settings': '/admin/site-settings',
    };
    it('every role gets exactly its capabilities (server-side)', async () => {
      const byRole: Record<string, Admin> = {
        OWNER: owner,
        MODERATION: moderator,
        SUPPORT: support,
        FINANCE: finance,
      };
      for (const role of PANEL_ROLES) {
        const a = byRole[role]!;
        const me = await get(a, '/admin/auth/session');
        expect(me.body.roles).toEqual([role]);
        for (const [cap, path] of Object.entries(READS)) {
          const allowed = (CAPABILITIES[cap as Capability] as readonly string[]).includes(role);
          const res = await get(a, path);
          expect(res.status, `${role} ${cap} ${path}`).toBe(allowed ? 200 : 403);
          if (!allowed) expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
          expect(me.body.capabilities.includes(cap)).toBe(allowed);
        }
      }
      // A mutation outside the role: refused before anything changes.
      const t = await signup();
      expect((await post(support, `/admin/users/${t.id}/ban`, { reason: 'x' })).status).toBe(403);
      expect(
        (
          await post(moderator, `/admin/recharge/agents/${t.id}/topup`, {
            coins: '1',
            paidUsd: '1',
            totpCode: '000000',
          })
        ).status,
      ).toBe(403);
      expect(
        (
          await post(finance, `/admin/users/${t.id}/special-username`, {
            username: 'vipname',
            permanent: true,
            reason: 'x',
          })
        ).status,
      ).toBe(403);
      const put = await ctx.http
        .put('/api/v1/admin/site-settings')
        .set('Cookie', finance.cookie)
        .set('X-CSRF-Token', finance.csrf)
        .send({ socials: { instagram: null, tiktok: null, whatsapp: null }, topupEnabled: true });
      expect(put.status).toBe(403);
      // Without any cookie: 401.
      expect((await ctx.http.get('/api/v1/admin/dashboard')).status).toBe(401);
    });
  });

  describe('sections', () => {
    beforeAll(() => relogin(owner, moderator, support, finance));
    it('dashboard: real aggregates', async () => {
      const res = await get(owner, '/admin/dashboard');
      expect(res.status).toBe(200);
      expectContract(res, 'getAdminDashboard');
      // Owner 2026-10-31: «today» is the Asia/Riyadh day (ADMIN_DASHBOARD_TIME_ZONE default), not UTC.
      const since = new Date(res.body.since as string);
      expect(
        new Intl.DateTimeFormat('en-GB', {
          timeZone: 'Asia/Riyadh',
          hour: '2-digit',
          minute: '2-digit',
          hourCycle: 'h23',
        }).format(since),
      ).toBe('00:00');
      expect(Date.now() - since.getTime()).toBeLessThan(86_400_000);
      expect(res.body.today.newUsers).toBe(
        await ctx.prisma.user.count({ where: { createdAt: { gte: new Date(res.body.since as string) } } }),
      );
      expect(res.body.pending.reports).toBe(await ctx.prisma.report.count({ where: { status: 'OPEN' } }));
    });

    it('users: search, audited profile, ban/unban, special username — each audited with actor, reason and IP', async () => {
      const u = await signup();
      const byName = await get(support, `/admin/users?q=${u.username}`);
      expect(byName.status).toBe(200);
      expectContract(byName, 'searchAdminUsers');
      expect(byName.body.data.map((r: { id: string }) => r.id)).toContain(u.id);
      expect((await get(support, `/admin/users?q=${encodeURIComponent(u.email)}`)).body.data[0].id).toBe(
        u.id,
      );
      expect((await get(support, `/admin/users?q=${u.id}`)).body.data[0].id).toBe(u.id);

      const detail = await get(finance, `/admin/users/${u.id}`);
      expect(detail.status).toBe(200);
      expectContract(detail, 'getAdminUser');
      expect(detail.body.balances).toEqual({ coins: 0, cherries: 0, lockedTaskCherries: 0 });
      expect(detail.body.ledger).not.toBeNull();
      // Owner 2026-10-31: the moderator «مشرف» sees the balances (read-only), not the ledger rows.
      const modView = await get(moderator, `/admin/users/${u.id}`);
      expect(modView.status).toBe(200);
      expectContract(modView, 'getAdminUser');
      expect(modView.body.balances).toEqual({ coins: 0, cherries: 0, lockedTaskCherries: 0 });
      expect(modView.body.ledger).toBeNull();
      expect((await audits('admin.user.view', u.id)).map((a) => a.actorUserId).sort()).toEqual(
        [finance.id, moderator.id].sort(),
      );

      const ban = await post(moderator, `/admin/users/${u.id}/ban`, { reason: 'spam account' });
      expect(ban.status).toBe(200);
      expectContract(ban, 'banAdminUser');
      // The app session dies at once.
      expect([401, 403]).toContain(
        (await ctx.http.get('/api/v1/me').set('Authorization', `Bearer ${u.token}`)).status,
      );
      expect((await post(moderator, `/admin/users/${u.id}/ban`, { reason: 'again' })).body.error.code).toBe(
        'ADMIN_ACTION_REFUSED',
      );
      expect((await post(moderator, `/admin/users/${u.id}/ban`, {})).status).toBe(400);
      const unban = await post(owner, `/admin/users/${u.id}/unban`, { reason: 'appeal accepted' });
      expect(unban.body.status).toBe('ACTIVE');
      const [b] = await audits('admin.user.ban', u.id);
      expect(b).toMatchObject({ actorUserId: moderator.id, targetType: 'user' });
      expect(b!.ip).toBeTruthy();
      expect(b!.metadata).toEqual({
        reason: 'spam account',
        before: 'ACTIVE',
        after: 'SUSPENDED',
        via: 'panel',
      });

      // A moderator may not ban another admin; nobody bans themself.
      expect((await post(moderator, `/admin/users/${support.id}/ban`, { reason: 'x' })).status).toBe(403);
      expect((await post(owner, `/admin/users/${owner.id}/ban`, { reason: 'x' })).body.error.code).toBe(
        'ADMIN_ACTION_REFUSED',
      );

      const name = `vip${randomUUID().slice(0, 6)}`;
      const gift = await post(support, `/admin/users/${u.id}/special-username`, {
        username: name,
        days: 7,
        reason: 'contest',
      });
      expect(gift.status, JSON.stringify(gift.body)).toBe(200);
      expectContract(gift, 'giftAdminSpecialUsername');
      expect(gift.body.baseUsername).toBe(u.username);
      expect(
        (
          await post(support, `/admin/users/${u.id}/special-username`, {
            username: 'coin9999',
            permanent: true,
            reason: 'x',
          })
        ).body.error.code,
      ).toBe('ADMIN_ACTION_REFUSED');
      const after = await get(support, `/admin/users/${u.id}`);
      expect(after.body.user.username).toBe(name);
      expect(after.body.user.baseUsername).toBe(u.username);
      const revoke = await post(support, `/admin/users/${u.id}/special-username/revoke`, { reason: 'ended' });
      expect(revoke.status).toBe(200);
      const [g] = await audits('special_username.grant', u.id);
      expect(g).toMatchObject({ actorUserId: support.id });
      expect(g!.metadata).toMatchObject({ via: 'panel', reason: 'contest' });
      const [e] = await audits('special_username.end', u.id);
      expect(e).toMatchObject({ actorUserId: support.id });
    });

    it('recharge: private pictures audited per view and forbidden per role; approve, top-up with TOTP; the CLI is the same rule', async () => {
      const applicant = await signup();
      const appId = randomUUID();
      const photoKey = privateKeyOf(appId, 'photo');
      const selfieKey = privateKeyOf(appId, 'selfie');
      storage.putRaw(photoKey, Buffer.from('RIFF-photo-bytes'), 'image/webp');
      storage.putRaw(selfieKey, Buffer.from('RIFF-selfie-bytes'), 'image/webp');
      await ctx.prisma.rechargeAgentApplication.create({
        data: {
          id: appId,
          userId: applicant.id,
          fullName: 'سارة محمد',
          phone: '+201001112223',
          photoKey,
          selfieKey,
          locations: [{ country: 'EG', cities: ['Cairo'] }],
          paymentMethods: [{ country: 'EG', type: 'VODAFONE_CASH' }],
        },
      });
      const list = await get(support, '/admin/recharge/applications?status=PENDING');
      expectContract(list, 'listAdminRechargeApplications');
      expect(JSON.stringify(list.body)).not.toContain('سارة');
      const detail = await get(support, `/admin/recharge/applications/${appId}`);
      expectContract(detail, 'getAdminRechargeApplication');
      expect(detail.body.fullName).toBe('سارة محمد');
      expect(detail.body.photos).toEqual({ photo: true, selfie: true });
      const photo = await get(support, `/admin/recharge/applications/${appId}/photos/photo`);
      expect(photo.status).toBe(200);
      expect(photo.headers['content-type']).toBe('image/webp');
      expect(photo.headers['cache-control']).toBe('private, no-store');
      expect(Buffer.from(photo.body as Buffer).toString()).toBe('RIFF-photo-bytes');
      for (const who of [moderator, finance]) {
        expect((await get(who, `/admin/recharge/applications/${appId}/photos/photo`)).status).toBe(403);
        expect((await get(who, `/admin/recharge/applications/${appId}`)).status).toBe(403);
      }
      expect((await get(support, `/admin/recharge/applications/${appId}/photos/other`)).status).toBe(404);
      expect((await audits('recharge.application.photo_view', appId)).map((a) => a.actorUserId)).toEqual([
        support.id,
      ]);
      expect((await audits('recharge.application.view', appId)).map((a) => a.actorUserId)).toEqual([
        support.id,
      ]);

      const approve = await post(support, `/admin/recharge/applications/${appId}/approve`);
      expect(approve.status, JSON.stringify(approve.body)).toBe(200);
      expect((await post(support, `/admin/recharge/applications/${appId}/approve`)).body.error.code).toBe(
        'ADMIN_ACTION_REFUSED',
      );
      const [ap] = await audits('recharge.application.approve', appId);
      expect(ap).toMatchObject({ actorUserId: support.id });
      expect(ap!.metadata).toMatchObject({ via: 'panel', before: 'PENDING', after: 'APPROVED' });

      const agents = await get(finance, '/admin/recharge/agents');
      expectContract(agents, 'listAdminRechargeAgents');
      expect(agents.body.pricing.activationMinCoins).toBe(30_000_000);
      // Financial: the code again — missing or wrong is refused and nothing changes.
      const topup = (body: object) => post(finance, `/admin/recharge/agents/${applicant.id}/topup`, body);
      expect((await topup({ coins: '30000000', paidUsd: '360' })).status).toBe(400);
      const wrong = await topup({ coins: '30000000', paidUsd: '360', totpCode: '123456' });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect(await ctx.prisma.rechargeTopup.count({ where: { agentUserId: applicant.id } })).toBe(0);
      const ok = await topup({ coins: '30000000', paidUsd: '360', totpCode: nextCode(finance.secret) });
      expect(ok.status, JSON.stringify(ok.body)).toBe(200);
      expectContract(ok, 'topUpAdminRechargeAgent');
      expect(ok.body).toMatchObject({
        first: true,
        stockCoins: 30_000_000,
        expectedMinor: 36_000,
        paidMinor: 36_000,
      });
      expect(ok.body.code).toMatch(/^coin[0-9]{4}$/);
      // The same code twice is refused (replay).
      const replay = await topup({
        coins: '1000000',
        paidUsd: '12',
        totpCode: totpCode(finance.secret, clock),
      });
      expect(replay.body.error.code).toBe('ADMIN_TOTP_INVALID');
      await ctx.prisma.adminCredential.update({ where: { userId: finance.id }, data: { failedAttempts: 0 } });
      const [t] = await audits('recharge.topup');
      expect(t).toMatchObject({ actorUserId: finance.id });
      expect(t!.metadata).toMatchObject({
        via: 'panel',
        coins: 30_000_000,
        first: true,
        stockAfter: 30_000_000,
      });

      // The CLI runs the same rule: its row differs only by `via` and the actor.
      await cli('recharge-admin.ts', ['topup', ok.body.code as string, '1000000', '--paid', '12']);
      const rows = await audits('recharge.topup');
      expect(rows).toHaveLength(2);
      const viaOf = (r: (typeof rows)[number]) => (r.metadata as { via: string }).via;
      const panelRow = rows.find((r) => viaOf(r) === 'panel')!;
      const cliRow = rows.find((r) => viaOf(r) === 'cli')!;
      expect(cliRow).toMatchObject({ actorUserId: null });
      expect(panelRow).toMatchObject({ actorUserId: finance.id });
      expect(Object.keys(cliRow.metadata as object).sort()).toEqual(
        Object.keys(panelRow.metadata as object).sort(),
      );
      expect(cliRow.metadata).toMatchObject({ coins: 1_000_000 });

      const cap = await post(finance, `/admin/recharge/agents/${applicant.id}/cap`, {
        cap: '5000000',
        reason: 'new agent',
      });
      expect(cap.body).toEqual({ dailyCherryCap: 5_000_000 });
      const sus = await post(support, `/admin/recharge/agents/${applicant.id}/suspend`, {
        reason: 'complaints',
      });
      expect(sus.body.status).toBe('SUSPENDED');
      const rein = await post(support, `/admin/recharge/agents/${applicant.id}/reinstate`, {
        reason: 'resolved',
      });
      expect(rein.body.status).toBe('ACTIVE');
      for (const action of ['recharge.cap', 'recharge.suspend', 'recharge.reinstate']) {
        const [row] = await audits(action, applicant.id);
        expect(row?.actorUserId, action).toBeTruthy();
        expect((row!.metadata as { via: string }).via).toBe('panel');
      }
    });

    it('withdrawals: mark paid with a reference (TOTP), reject with a reason (refund, TOTP); CLI and panel share the rule', async () => {
      const host = await signup();
      await ctx.prisma.$transaction(async (tx) => {
        const w = await tx.cherryWallet.upsert({
          where: { userId: host.id },
          create: { userId: host.id, cherries: 40_000_000n },
          update: { cherries: { increment: 40_000_000n } },
        });
        await tx.cherryLedgerEntry.create({
          data: {
            userId: host.id,
            delta: 40_000_000n,
            balanceAfter: w.cherries,
            reason: 'GIFT_RECEIVED',
            referenceId: randomUUID(),
          },
        });
      });
      const request = () =>
        ctx.http
          .post('/api/v1/wallet/me/cherries/withdrawals')
          .set('Authorization', `Bearer ${host.token}`)
          .set('Idempotency-Key', randomUUID())
          .send({ amountMinor: 1000, payoutDetails: 'Vodafone Cash 01001112223' });
      const first = await request();
      expect(first.status, JSON.stringify(first.body)).toBe(201);
      const list = await get(finance, '/admin/withdrawals');
      expectContract(list, 'listAdminWithdrawals');
      const w1 = list.body.data.find((w: { user: { id: string } }) => w.user.id === host.id);
      expect(w1.payoutDetails).toBe('Vodafone Cash 01001112223');
      expect(
        (await post(support, `/admin/withdrawals/${w1.id}/pay`, { reference: 'x', totpCode: '000000' }))
          .status,
      ).toBe(403);
      const noCode = await post(finance, `/admin/withdrawals/${w1.id}/pay`, { reference: 'TX-1' });
      expect(noCode.status).toBe(400);
      const paid = await post(finance, `/admin/withdrawals/${w1.id}/pay`, {
        reference: 'TX-778899',
        note: 'sent',
        totpCode: nextCode(finance.secret),
      });
      expect(paid.status, JSON.stringify(paid.body)).toBe(200);
      expectContract(paid, 'payAdminWithdrawal');
      expect(
        (await ctx.prisma.cherryWithdrawal.findUniqueOrThrow({ where: { id: w1.id } })).decisionNote,
      ).toBe('ref: TX-778899 — sent');
      const again = await post(finance, `/admin/withdrawals/${w1.id}/pay`, {
        reference: 'x',
        totpCode: nextCode(finance.secret),
      });
      expect(again.body.error.code).toBe('ADMIN_ACTION_REFUSED');

      const second = await request();
      const before = (await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: host.id } }))
        .cherries;
      const rej = await post(finance, `/admin/withdrawals/${second.body.id}/reject`, {
        reason: 'wrong number',
        totpCode: nextCode(finance.secret),
      });
      expect(rej.status, JSON.stringify(rej.body)).toBe(200);
      expectContract(rej, 'rejectAdminWithdrawal');
      const afterRefund = (await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: host.id } }))
        .cherries;
      expect(afterRefund - before).toBe(BigInt(rej.body.cherries as number));

      // The CLI decides a third one through the same rule.
      const third = await request();
      await cli('economy-admin.ts', ['withdrawal-pay', third.body.id as string, '--note', 'cli ref']);
      const pays = await audits('cherry.withdrawal.pay');
      const panelRow = pays.find((p) => p.targetId === w1.id)!;
      const cliRow = pays.find((p) => p.targetId === third.body.id)!;
      expect(panelRow).toMatchObject({ actorUserId: finance.id });
      expect(cliRow).toMatchObject({ actorUserId: null });
      expect(Object.keys(cliRow.metadata as object).sort()).toEqual(
        Object.keys(panelRow.metadata as object).sort(),
      );
      expect((await audits('cherry.withdrawal.reject', second.body.id as string))[0]!.metadata).toMatchObject(
        {
          note: 'wrong number',
          via: 'panel',
        },
      );
    });

    it('reports: preview, dismiss, warn and ban the author (audited)', async () => {
      const author = await signup();
      const reporter = await signup();
      const report = (username: string) =>
        ctx.http
          .post('/api/v1/reports')
          .set('Authorization', `Bearer ${reporter.token}`)
          .send({ targetType: 'USER', targetId: username, reason: 'HARASSMENT', note: 'rude' });
      expect((await report(author.username)).status).toBe(201);
      const list = await get(moderator, '/admin/moderation/reports');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminPanelReports');
      const r = list.body.data.find(
        (x: { preview: { author: { id: string } | null } }) => x.preview.author?.id === author.id,
      );
      expect(r).toBeTruthy();
      expect(
        (await post(moderator, `/admin/moderation/reports/${r.id}/actions`, { action: 'WARN' })).status,
      ).toBe(400);
      const warn = await post(moderator, `/admin/moderation/reports/${r.id}/actions`, {
        action: 'WARN',
        note: 'be kind',
      });
      expect(warn.status, JSON.stringify(warn.body)).toBe(200);
      expectContract(warn, 'actOnAdminPanelReport');
      expect(warn.body.status).toBe('ACTIONED');
      expect(
        await ctx.prisma.notification.count({
          where: { recipientId: author.id, type: 'MODERATION_WARNING' },
        }),
      ).toBe(1);
      const inbox = await ctx.http
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${author.token}`);
      expect(inbox.body.data.map((n: { type: string }) => n.type)).toContain('MODERATION_WARNING');
      expect((await audits('admin.user.warn', author.id))[0]).toMatchObject({ actorUserId: moderator.id });

      expect((await report(author.username)).status).toBe(201);
      const r2 = (await get(moderator, '/admin/moderation/reports')).body.data.find(
        (x: { preview: { author: { id: string } | null } }) => x.preview.author?.id === author.id,
      );
      const ban = await post(moderator, `/admin/moderation/reports/${r2.id}/actions`, {
        action: 'BAN',
        note: 'repeat',
      });
      expect(ban.status).toBe(200);
      expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: author.id } })).status).toBe(
        'SUSPENDED',
      );
      expect(
        (await audits('moderation.report.action')).filter(
          (a) => (a.metadata as { via?: string }).via === 'panel',
        ),
      ).toHaveLength(2);

      const other = await signup();
      expect((await report(other.username)).status).toBe(201);
      const r3 = (await get(owner, '/admin/moderation/reports')).body.data.find(
        (x: { preview: { author: { id: string } | null } }) => x.preview.author?.id === other.id,
      );
      const dismiss = await post(owner, `/admin/moderation/reports/${r3.id}/actions`, { action: 'DISMISS' });
      expect(dismiss.body.status).toBe('DISMISSED');
      expect(
        (await post(owner, `/admin/moderation/reports/${r3.id}/actions`, { action: 'DISMISS' })).body.error
          .code,
      ).toBe('REPORT_ALREADY_RESOLVED');
    });

    it('site settings: OWNER edits (audited before/after); public read', async () => {
      const pub0 = await ctx.http.get('/api/v1/site/settings');
      expect(pub0.status).toBe(200);
      expectContract(pub0, 'getSiteSettings');
      expect(pub0.body).toEqual({
        socials: { instagram: null, tiktok: null, whatsapp: null },
        topupEnabled: false,
      });
      const put = (body: object) =>
        ctx.http
          .put('/api/v1/admin/site-settings')
          .set('Cookie', owner.cookie)
          .set('X-CSRF-Token', owner.csrf)
          .send(body);
      const none = { instagram: null, tiktok: null, whatsapp: null };
      // Other hosts or shapes: 400 invalid_value on the field, nothing changed (D192's rules).
      for (const [socials, field] of [
        [{ ...none, instagram: 'https://evil.example/x' }, 'socials.instagram'],
        [{ ...none, instagram: 'http://instagram.com/kabsolive' }, 'socials.instagram'],
        [{ ...none, tiktok: 'https://www.tiktok.com/kabsolive' }, 'socials.tiktok'],
        [{ ...none, whatsapp: 'https://api.whatsapp.com/send?phone=966500000000' }, 'socials.whatsapp'],
        [{ ...none, whatsapp: '0500000000', instagram: 'https://instagram.com/ok' }, 'socials.whatsapp'],
      ] as const) {
        const bad = await put({ socials, topupEnabled: false });
        expect(bad.status, JSON.stringify(socials)).toBe(400);
        expectContract(bad, 'updateAdminSiteSettings');
        expect(bad.body.error.details).toContainEqual({ field, issue: 'invalid_value' });
      }
      for (const body of [
        {},
        { socials: { ...none, facebook: 'https://facebook.com/x' }, topupEnabled: false },
        { socials: none, topupEnabled: 'yes' },
      ]) {
        expect((await put(body)).status, JSON.stringify(body)).toBe(400);
      }
      expect((await ctx.http.get('/api/v1/site/settings')).body).toEqual(pub0.body);
      const ok = await put({
        socials: {
          instagram: 'https://instagram.com/kabsolive/',
          tiktok: 'https://tiktok.com/@kabsolive',
          whatsapp: '+966 50 123 4567',
        },
        topupEnabled: true,
        reason: 'launch',
      });
      expect(ok.status, JSON.stringify(ok.body)).toBe(200);
      expectContract(ok, 'updateAdminSiteSettings');
      // One standard form, stored and served (what the website's common.js accepts).
      const expected = {
        socials: {
          instagram: 'https://www.instagram.com/kabsolive',
          tiktok: 'https://www.tiktok.com/@kabsolive',
          whatsapp: 'https://wa.me/966501234567',
        },
        topupEnabled: true,
      };
      expect(ok.body).toEqual(expected);
      const pub = await ctx.http.get('/api/v1/site/settings');
      expect(pub.body).toEqual(expected);
      expect(pub.headers['cache-control']).toBe('public, max-age=60');
      const [row] = await audits('site.settings.update');
      expect(row).toMatchObject({ actorUserId: owner.id });
      expect(row!.metadata).toMatchObject({
        before: { topupEnabled: false },
        after: { topupEnabled: true },
        reason: 'launch',
        via: 'panel',
      });
    });

    it('every panel mutation left an audit row with the actor and the IP', async () => {
      const rows = await ctx.prisma.auditLog.findMany({
        where: { metadata: { path: ['via'], equals: 'panel' } },
      });
      expect(rows.length).toBeGreaterThan(10);
      for (const r of rows) {
        expect(r.actorUserId, r.action).toBeTruthy();
        expect(r.ip, r.action).toBeTruthy();
      }
    });
  });

  it('is off without ADMIN_TOTP_KEY (503)', async () => {
    const off = await createTestApp({});
    try {
      const res = await off.http.post('/api/v1/admin/auth/login').send({ email: 'a@b.test', password: 'x' });
      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('ADMIN_PANEL_UNAVAILABLE');
      expect((await off.http.get('/api/v1/admin/dashboard')).status).toBe(503);
    } finally {
      await off.close();
    }
  });
});
