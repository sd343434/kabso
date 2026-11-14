/**
 * D302 (owner 2026-11-07, «المشرفين يدخلون من خلال وضع الايدي المميز والباسورد»; contract v1.84-live, CONVENTIONS
 * §10.96.12), end to end against PostgreSQL + Redis: the staff sign in with their official staff ID and password.
 *
 *  - app `login`: `identifier` «Kabso01», «kabso1», «@KABSO01» → the current holder; the primary OWNER's «Kabso»; the
 *    email and the username keep working; every existing rule still applies (password change required);
 *  - a revoked (retired) number, a suspended holder → 401 `AUTH_INVALID_CREDENTIALS`, the same answer as a wrong
 *    password or an unknown name, even with the right password;
 *  - a regular account is never reached through a staff ID or a look-alike, and a staff member never through a
 *    look-alike; a staff ID that is held wins over an old username spelled like it;
 *  - panel `adminLogin`: the `email` field takes the staff ID too; the authenticator is still required.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const DEVICE = { name: 'Pixel 9', platform: 'android', appVersion: '1.0.0' };

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
}

describe('D302 staff sign in with the staff ID', { timeout: 600_000 }, () => {
  let ctx: TestContext;
  let clock = Date.now();
  const nextCode = (secret: string) => {
    clock += 30_000;
    vi.setSystemTime(clock);
    return totpCode(secret, clock);
  };
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };

  let pwCounter = 0;
  const signup = async (): Promise<TestUser> => {
    // A password of its own: a sign-in through another person's name must fail on the password.
    pwCounter += 1;
    const payload = newUser({ password: `staff login ${pwCounter} battery horse staple` });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const ok = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    return {
      id: ok.body.user.id as string,
      username: ok.body.user.username as string,
      email,
      password: String(payload.password),
    };
  };
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
  const revoke = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, p.email, role as never)));
  const sql = (q: string) => withMigrationClient((db) => db.$executeRawUnsafe(q));
  const login = (identifier: string, password: string) =>
    ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', nextIp())
      .send({ identifier, password, device: DEVICE });
  /** The error as the client sees it, without the per-request id. */
  const errorOf = (res: request.Response) => {
    const { requestId: _requestId, ...rest } = res.body.error as Record<string, unknown>;
    return { status: res.status, ...rest };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const panelLogin = (email: string, password: string) =>
    ctx.http.post('/api/v1/admin/auth/login').set('X-Forwarded-For', nextIp()).send({ email, password });

  let owner: TestUser;
  let sara: TestUser; // SUPPORT → Kabso01
  let omar: TestUser; // MODERATION → Kabso02
  let gone: TestUser; // Kabso03, revoked
  let banned: TestUser; // Kabso04, suspended
  let regular: TestUser; // never staff; given the old look-alike username «kabs01»
  let oldName: TestUser; // never staff; given an old username spelled like a held staff ID («kabso02»)
  let INVALID: ReturnType<typeof errorOf>;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
    });
    owner = await signup();
    sara = await signup();
    omar = await signup();
    gone = await signup();
    banned = await signup();
    regular = await signup();
    oldName = await signup();
    expect((await grant(owner, 'OWNER')).staffId).toBe('Kabso');
    expect((await grant(sara, 'SUPPORT')).staffId).toBe('Kabso01');
    expect((await grant(omar, 'MODERATION')).staffId).toBe('Kabso02');
    expect((await grant(gone, 'FINANCE')).staffId).toBe('Kabso03');
    expect((await grant(banned, 'SUPPORT')).staffId).toBe('Kabso04');
    await revoke(gone, 'FINANCE');
    await sql(`UPDATE users SET status = 'SUSPENDED' WHERE id = '${banned.id}'`);
    // Usernames kept from before the staff-ID reservation (D283c): new sign-ups cannot take them.
    await sql(`UPDATE user_profiles SET username = 'kabs01' WHERE user_id = '${regular.id}'`);
    await sql(`UPDATE user_profiles SET username = 'kabso02' WHERE user_id = '${oldName.id}'`);
    const wrong = await login(sara.username, 'not the password at all');
    expect(wrong.status).toBe(401);
    INVALID = errorOf(wrong);
    expect(INVALID).toMatchObject({ status: 401, code: 'AUTH_INVALID_CREDENTIALS' });
  });

  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the staff ID signs in its holder (any case, «@», leading zeros); the OWNER with «Kabso»', async () => {
    for (const id of ['Kabso01', 'kabso1', '@KABSO01', 'kabso001']) {
      const res = await login(id, sara.password);
      expect(res.status, `${id} ${JSON.stringify(res.body)}`).toBe(200);
      expectContract(res, 'login');
      expect(res.body.user.id).toBe(sara.id);
      expect(res.body.user.username).toBe(sara.username);
      const me = await ctx.http
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${res.body.tokens.accessToken as string}`);
      expect(me.body.staffId).toBe('Kabso01');
    }
    for (const id of ['Kabso', 'kabso', '@KABSO']) {
      const res = await login(id, owner.password);
      expect(res.status, `${id} ${JSON.stringify(res.body)}`).toBe(200);
      expect(res.body.user.id).toBe(owner.id);
    }
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'auth.login.success', actorUserId: owner.id },
      orderBy: { createdAt: 'desc' },
      select: { metadata: true },
    });
    expect(audit?.metadata).toEqual({ identifierType: 'staff_id' });
  });

  it('the email and the username keep working', async () => {
    for (const [id, who] of [
      [sara.email, sara],
      [sara.username, sara],
      [omar.email.toUpperCase(), omar],
      [omar.username.toUpperCase(), omar],
    ] as const) {
      const res = await login(id, who.password);
      expect(res.status, `${id} ${JSON.stringify(res.body)}`).toBe(200);
      expect(res.body.user.id).toBe(who.id);
    }
  });

  it('a wrong password through the staff ID is the usual 401', async () => {
    const res = await login('Kabso02', 'not the password at all');
    expect(errorOf(res)).toEqual(INVALID);
  });

  it('a revoked number or a suspended holder: the same 401 as a wrong password, even with the right password', async () => {
    for (const [id, who] of [
      ['Kabso03', gone],
      ['kabso3', gone],
      ['Kabso04', banned],
      ['@kabso04', banned],
      ['Kabso77', sara], // never given
    ] as const) {
      const res = await login(id, who.password);
      expect(errorOf(res), id).toEqual(INVALID);
    }
    // The revoked person still signs in with their own username (a normal account again).
    expect((await login(gone.username, gone.password)).status).toBe(200);
    // The suspended one, through the username: the usual suspended answer after the right password (unchanged).
    expect((await login(banned.username, banned.password)).body.error.code).toBe('ACCOUNT_SUSPENDED');
  });

  it('nobody is reached through a look-alike; a held staff ID wins over an old username spelled like it', async () => {
    // «Kabso01» never reaches the regular account with the look-alike username «kabs01» …
    expect(errorOf(await login('Kabso01', regular.password))).toEqual(INVALID);
    // … and «kabs01» (its own username) never reaches the staff member.
    expect(errorOf(await login('kabs01', sara.password))).toEqual(INVALID);
    expect((await login('kabs01', regular.password)).body.user?.id).toBe(regular.id);
    for (const id of ['kabso01x', 'k4bso01', 'Kabso00', 'kabs0', 'kabso-01']) {
      expect(errorOf(await login(id, sara.password)), id).toEqual(INVALID);
    }
    // «kabso02» is held by omar: it signs in omar, not the old account named «kabso02».
    expect(errorOf(await login('kabso02', oldName.password))).toEqual(INVALID);
    expect((await login('kabso02', omar.password)).body.user?.id).toBe(omar.id);
    // That account still signs in with its email.
    expect((await login(oldName.email, oldName.password)).body.user?.id).toBe(oldName.id);
  });

  it('the existing rules still apply through the staff ID (password change required)', async () => {
    await sql(`UPDATE users SET password_change_required_at = now() WHERE id = '${omar.id}'`);
    const res = await login('Kabso02', omar.password);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
    await sql(`UPDATE users SET password_change_required_at = NULL WHERE id = '${omar.id}'`);
  });

  it('the panel: the staff ID in place of the email, then the authenticator', async () => {
    // First sign-in by staff ID: enrol the authenticator.
    const first = await panelLogin('Kabso01', sara.password);
    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expectContract(first, 'adminLogin');
    expect(first.body.next).toBe('TOTP_ENROL');
    const pending = cookieOf(first);
    const csrf = first.body.csrfToken as string;
    // The pending session opens nothing before the code.
    expect((await ctx.http.get('/api/v1/admin/dashboard').set('Cookie', pending)).status).toBe(401);
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    expect(enrol.status, JSON.stringify(enrol.body)).toBe(200);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    // Next time, any spelling of the staff ID: the code is asked again.
    const again = await panelLogin('@kabso1', sara.password);
    expect(again.status, JSON.stringify(again.body)).toBe(200);
    expect(again.body.next).toBe('TOTP_VERIFY');
    const wrongCode = await ctx.http
      .post('/api/v1/admin/auth/totp/verify')
      .set('Cookie', cookieOf(again))
      .set('X-CSRF-Token', again.body.csrfToken as string)
      .send({ code: nextCode(secret) === '000000' ? '111111' : '000000' });
    expect(wrongCode.status).toBe(403);
    expect(wrongCode.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const verify = await ctx.http
      .post('/api/v1/admin/auth/totp/verify')
      .set('Cookie', cookieOf(again))
      .set('X-CSRF-Token', again.body.csrfToken as string)
      .send({ code: nextCode(secret) });
    expect(verify.status, JSON.stringify(verify.body)).toBe(200);
    expectContract(verify, 'verifyAdminTotp');
    expect(verify.body.roles).toEqual(['SUPPORT']);
    // The OWNER with «Kabso»; the email still works.
    expect((await panelLogin('Kabso', owner.password)).status).toBe(200);
    expect((await panelLogin(owner.email, owner.password)).status).toBe(200);
  });

  it('the panel: a wrong password, a revoked / suspended / unknown staff ID and a look-alike are the same 401', async () => {
    const wrong = await panelLogin(omar.email, 'not the password at all');
    expect(wrong.status).toBe(401);
    const PANEL_INVALID = errorOf(wrong);
    expect(PANEL_INVALID).toMatchObject({ code: 'AUTH_INVALID_CREDENTIALS' });
    for (const [id, who] of [
      ['Kabso02', { password: 'not the password at all' }],
      ['Kabso03', gone],
      ['Kabso04', banned],
      ['Kabso77', sara],
      ['kabs01', sara],
      ['kabs01', regular],
    ] as const) {
      expect(errorOf(await panelLogin(id, who.password)), id).toEqual(PANEL_INVALID);
    }
  });
});
