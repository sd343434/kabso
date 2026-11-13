/**
 * D343 (owner 2026-11-09; contract v1.108-social, CONVENTIONS §10.142): the sign-up field «رمز الدعوة أو رمز المشرف»
 * takes a friend's invite code (D217) or a supervisor's staff ID (D285), checked by the server (`checkSignupCode`, the
 * 400 at `register`); a staff ID attributes the new account to that supervisor (GRANTED / WITHHELD with the reason),
 * who is then the recruiter of the person's later application, and the attribution cannot be changed; credit only for
 * a new person — a device that already had a Kabso account (created or signed in on it) or a mailbox registered
 * before (also a purged account's, within the retention) withholds the invite reward and the recruit while the account
 * is created all the same; the marks' retention and backfill; the supervisor's personal link; the panel's list. End to
 * end against PostgreSQL + Redis.
 */
import { createHash, randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { ReferralSweeper } from '../src/modules/referrals/referrals.service.js';
import { parseSignupCode } from '../src/modules/referrals/signup-codes.js';
import { purgeAccountIn, requestDeletionIn } from '../src/modules/users/account-deletion.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const DAY = 86_400_000;

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
  readonly deviceKey: string | null;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

/** A device key as the app sends it (64 lower-case hex). */
const newDeviceKey = () => createHash('sha256').update(randomUUID()).digest('hex');

describe('D343 contract coverage', () => {
  it('openapi v1.108-social declares the check, the panel list and the new fields', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'checkSignupCode POST /api/v1/auth/signup-code/check',
        'listAdminSignupRecruits GET /api/v1/admin/recruits/signups',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.SignupCreditStatus as { enum: string[] }).enum).toEqual(['GRANTED', 'WITHHELD']);
    expect(Object.keys(schemas.StaffRecruitList!.properties as object)).toEqual(
      expect.arrayContaining(['signupCode', 'signupLink', 'signups']),
    );
    const check = operations().find((o) => o.operationId === 'checkSignupCode')!;
    expect(check.spec.security).toEqual([]);
  });

  it('the field reads an invite code, a staff ID and an invite link of either', () => {
    expect(parseSignupCode('k7qm-4p2x')).toEqual({ kind: 'INVITE', code: 'K7QM4P2X' });
    expect(parseSignupCode('@kabso7')).toEqual({ kind: 'SUPERVISOR', code: 'Kabso07', number: 7 });
    expect(parseSignupCode('KABSO012')).toEqual({ kind: 'SUPERVISOR', code: 'Kabso12', number: 12 });
    expect(parseSignupCode('https://kabsolive.com/i/Kabso07')).toMatchObject({ code: 'Kabso07' });
    expect(parseSignupCode('https://kabsolive.com/i/K7QM4P2X/')).toMatchObject({ code: 'K7QM4P2X' });
    expect(parseSignupCode('!!')).toBeNull();
    expect(parseSignupCode('@someone.else')).toBeNull();
  });
});

describe('D343 «رمز الدعوة أو رمز المشرف»', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let sweeper: ReferralSweeper;
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
  const auth = (u: { token: string }) => ({
    Authorization: `Bearer ${u.token}`,
    'X-Forwarded-For': nextIp(),
  });

  const registerRaw = (opts: { code?: string; deviceKey?: string | null; email?: string } = {}) => {
    const deviceKey = opts.deviceKey === undefined ? newDeviceKey() : opts.deviceKey;
    const payload = newUser({
      device: {
        name: 'Pixel 9',
        platform: 'android',
        appVersion: '1.0.0',
        installId: `install-${randomUUID()}`,
        ...(deviceKey ? { deviceKey } : {}),
      },
      ...(opts.email ? { email: opts.email } : {}),
      ...(opts.code !== undefined ? { referralCode: opts.code } : {}),
    });
    const ip = nextIp();
    return {
      payload,
      ip,
      deviceKey,
      send: () => ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload),
    };
  };
  const signup = async (opts: { code?: string; deviceKey?: string | null; email?: string } = {}) => {
    const r = registerRaw(opts);
    const email = String(r.payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const reg = await r.send();
    expect(reg.status, JSON.stringify(reg.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', r.ip)
      .send({ email, code: mail.code, device: r.payload.device });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email,
      password: r.payload.password,
      token: res.body.tokens.accessToken as string,
      deviceKey: r.deviceKey,
    } satisfies TestUser;
  };
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
  const revoke = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, p.email, role as never)));
  const staffIdOf = async (u: TestUser) => {
    const row = await ctx.prisma.staffId.findUniqueOrThrow({ where: { userId: u.id } });
    return `Kabso${String(row.number).padStart(2, '0')}`;
  };
  const supervisor = async (role = 'MODERATION') => {
    const s = await signup();
    await grant(s, role);
    return { user: s, code: await staffIdOf(s) };
  };
  const inviteCodeOf = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/referral').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return res.body.code as string;
  };
  const check = (code: string) =>
    ctx.http.post('/api/v1/auth/signup-code/check').set('X-Forwarded-For', nextIp()).send({ code });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];
  const signupRow = (u: TestUser) => ctx.prisma.staffSignupRecruit.findUnique({ where: { userId: u.id } });
  const referralOf = (u: TestUser) => ctx.prisma.referral.findUnique({ where: { inviteeUserId: u.id } });
  const purge = (u: TestUser) =>
    ctx.prisma.$transaction((tx) =>
      purgeAccountIn(tx, u.id, new Date(clock), {
        quarantineDays: 0,
        specialGraceDays: 30,
        legalHoldDays: 90,
        via: 'ADMIN',
      }),
    );

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
    const p = await signup();
    for (const role of roles) await grant(p, role);
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
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

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      RATE_LIMIT_HOST_APPLY_USER: '1000/900',
      REFERRAL_SWEEP_INTERVAL_SECONDS: '0',
      RATE_LIMIT_SIGNUP_CODE_IP: '10000/900',
      SIGNUP_IDENTITY_RETENTION_DAYS: '365',
    });
    sweeper = ctx.app.get(ReferralSweeper);
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('checkSignupCode: INVITE, SUPERVISOR (any case, @, link); anything else not_found; malformed invalid_format', async () => {
    const friend = await signup();
    const code = await inviteCodeOf(friend);
    const sup = await supervisor();
    const bd = await supervisor('BD');
    const support = await supervisor('SUPPORT');

    const inv = await check(code.toLowerCase());
    expect(inv.status, JSON.stringify(inv.body)).toBe(200);
    expectContract(inv, 'checkSignupCode');
    expect(inv.body).toEqual({ kind: 'INVITE', code });
    for (const typed of [
      sup.code,
      sup.code.toLowerCase(),
      `@${sup.code}`,
      `https://kabsolive.com/i/${sup.code}`,
    ]) {
      const res = await check(typed);
      expect(res.status, typed).toBe(200);
      expect(res.body).toEqual({ kind: 'SUPERVISOR', code: sup.code });
    }
    expect((await check(bd.code)).body).toEqual({ kind: 'SUPERVISOR', code: bd.code });
    // SUPPORT cannot recruit; an unknown code; a closed account's code — all the same answer.
    for (const typed of [support.code, 'ZZZZZZZZ', 'Kabso9999']) {
      const res = await check(typed);
      expect(res.status, typed).toBe(400);
      expectContract(res, 'checkSignupCode');
      expect(issueOf(res)).toEqual({ field: 'code', issue: 'not_found' });
      expect(JSON.stringify(res.body)).not.toContain(support.user.username);
    }
    const bad = await check('!!');
    expect(bad.status).toBe(400);
    expect(issueOf(bad)).toEqual({ field: 'code', issue: 'invalid_format' });
    await ctx.prisma.user.update({ where: { id: friend.id }, data: { status: 'SUSPENDED' } });
    expect(issueOf(await check(code))).toEqual({ field: 'code', issue: 'not_found' });
    await ctx.prisma.user.update({ where: { id: friend.id }, data: { status: 'ACTIVE' } });
  });

  it('register: an unknown code is a 400 on the field, whatever the email (an existing one too); nothing is mailed', async () => {
    const existing = await signup();
    for (const email of [undefined, existing.email]) {
      const r = registerRaw({ code: 'ZZZZZZZZ', ...(email ? { email } : {}) });
      const before = ctx.mail.sent.length;
      const res = await r.send();
      expect(res.status, JSON.stringify(res.body)).toBe(400);
      expectContract(res, 'register');
      expect(issueOf(res)).toEqual({ field: 'referralCode', issue: 'not_found' });
      expect(ctx.mail.sent.length).toBe(before);
    }
  });

  it('a supervisor staff ID: GRANTED, audited, counted on «استقطاباتي» with the link; the later form keeps that supervisor', async () => {
    const sup = await supervisor();
    const other = await supervisor();
    const u = await signup({ code: sup.code.toLowerCase() });
    expect(await signupRow(u)).toMatchObject({
      recruiterUserId: sup.user.id,
      code: sup.code,
      status: 'GRANTED',
      withholdReason: null,
    });
    expect(await referralOf(u)).toBeNull();
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'staff.recruit.signup', targetId: u.id },
    });
    expect(audit?.metadata).toMatchObject({ code: sup.code, recruiter: sup.user.id, status: 'GRANTED' });

    const mine = await ctx.http.get('/api/v1/me/staff/recruits').set(auth(sup.user));
    expect(mine.status, JSON.stringify(mine.body)).toBe(200);
    expectContract(mine, 'getMyStaffRecruits');
    expect(mine.body).toMatchObject({
      signupCode: sup.code,
      signupLink: `http://localhost:3000/i/${sup.code}`,
      signups: { granted: 1, withheld: 0 },
    });

    // Cannot be changed afterwards: no invite code later, and the form's recruiter is not read.
    const friend = await signup();
    const friendCode = await inviteCodeOf(friend);
    const later = await ctx.http.post('/api/v1/me/referral/apply').set(auth(u)).send({ code: friendCode });
    expect(later.status, JSON.stringify(later.body)).toBe(409);
    expectContract(later, 'applyReferralCode');
    expect(issueOf(later)?.issue).toBe('ALREADY_REFERRED');
    const apply = await ctx.http
      .post('/api/v1/me/creator-application')
      .set(auth(u))
      .send({
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@c'],
        bio: 'x',
        recruiter: other.code,
      });
    expect(apply.status, JSON.stringify(apply.body)).toBe(201);
    const app = await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: u.id } });
    expect(app.recruiterUserId).toBe(sup.user.id);
  });

  it('a device that already had a Kabso account (created or signed in on it): credit withheld, account created', async () => {
    const sup = await supervisor();
    const friend = await signup();
    const code = await inviteCodeOf(friend);
    const phone = newDeviceKey();
    const first = await signup({ deviceKey: phone });
    // A second account on that phone with the staff ID / with the invite code.
    const viaStaff = await signup({ code: sup.code, deviceKey: phone });
    expect(await signupRow(viaStaff)).toMatchObject({
      status: 'WITHHELD',
      withholdReason: 'DEVICE_HAD_ACCOUNT',
    });
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: viaStaff.id } })).status).toBe('ACTIVE');

    const phone2 = newDeviceKey();
    // Signing in on a phone counts too (the session keeps the device's HMAC).
    const login = await ctx.http.post('/api/v1/auth/login').send({
      identifier: first.email,
      password: first.password,
      device: { platform: 'android', deviceKey: phone2 },
    });
    expect(login.status, JSON.stringify(login.body)).toBe(200);
    const viaInvite = await signup({ code, deviceKey: phone2 });
    expect(await referralOf(viaInvite)).toMatchObject({
      status: 'REJECTED',
      rejectReason: 'DEVICE_HAD_ACCOUNT',
    });
    expect(
      await ctx.prisma.referralReward.count({ where: { referralId: (await referralOf(viaInvite))!.id } }),
    ).toBe(0);

    // The inviter's own phone: SELF_DEVICE.
    const inviterPhone = newDeviceKey();
    const inviter = await signup({ deviceKey: inviterPhone });
    const self = await signup({ code: await inviteCodeOf(inviter), deviceKey: inviterPhone });
    expect(await referralOf(self)).toMatchObject({ status: 'REJECTED', rejectReason: 'SELF_DEVICE' });

    // A fresh phone is credited.
    const fresh = await signup({ code, deviceKey: newDeviceKey() });
    expect(await referralOf(fresh)).toMatchObject({ status: 'PENDING', rejectReason: null });

    const withheld = await ctx.http.get('/api/v1/me/staff/recruits').set(auth(sup.user));
    expect(withheld.body.signups).toEqual({ granted: 0, withheld: 1 });
  });

  it('a mailbox registered before (an alias of a live account, a purged account within the retention): withheld', async () => {
    const sup = await supervisor();
    const friend = await signup();
    const code = await inviteCodeOf(friend);
    const tag = randomUUID().slice(0, 8);
    await signup({ email: `ali.${tag}@gmail.com` });
    const alias = await signup({ code: sup.code, email: `a.l.i.${tag}+promo@gmail.com` });
    expect(await signupRow(alias)).toMatchObject({ status: 'WITHHELD', withholdReason: 'EMAIL_HAD_ACCOUNT' });

    const gone = await signup({ email: `gone.${tag}@example.com` });
    await ctx.prisma.$transaction((tx) =>
      requestDeletionIn(tx, gone.id, new Date(clock), 30, { via: 'APP' }),
    );
    await purge(gone);
    const mark = await ctx.prisma.signupEmailMark.findUniqueOrThrow({ where: { userId: gone.id } });
    expect(mark.purgedAt).not.toBeNull();
    const back = await signup({ code, email: `gone.${tag}@example.com` });
    expect(await referralOf(back)).toMatchObject({ status: 'REJECTED', rejectReason: 'EMAIL_HAD_ACCOUNT' });

    // After the retention the mark goes; the same mailbox then counts as new.
    const sweep = await sweeper.sweepSignupMarks(new Date(clock + 366 * DAY));
    expect(sweep.expired).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.signupEmailMark.findUnique({ where: { userId: gone.id } })).toBeNull();
    await purge(back);
    await sweeper.sweepSignupMarks(new Date(clock + 2 * 366 * DAY));
    const third = await signup({ code: sup.code, email: `gone.${tag}@example.com` });
    expect(await signupRow(third)).toMatchObject({ status: 'GRANTED' });
  });

  it('the supervisor left the team between register and verify: WITHHELD RECRUITER_INACTIVE', async () => {
    const sup = await supervisor();
    const r = registerRaw({ code: sup.code });
    const email = String(r.payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    expect((await r.send()).status).toBe(202);
    await revoke(sup.user, 'MODERATION');
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email, code: mail.code, device: r.payload.device });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const row = await ctx.prisma.staffSignupRecruit.findUnique({
      where: { userId: res.body.user.id as string },
    });
    expect(row).toMatchObject({ status: 'WITHHELD', withholdReason: 'RECRUITER_INACTIVE' });
  });

  it('marks of accounts made before the migration are written by the sweeper; deletion keeps only the hash', async () => {
    const u = await signup();
    const mark = await ctx.prisma.signupEmailMark.findUniqueOrThrow({ where: { userId: u.id } });
    expect(mark.emailHash).toMatch(/^[0-9a-f]{64}$/);
    expect(mark.emailHash).not.toContain(u.email.split('@')[0]!);
    await ctx.prisma.signupEmailMark.delete({ where: { userId: u.id } });
    const r = await sweeper.sweepSignupMarks(new Date(clock));
    expect(r.backfilled).toBeGreaterThanOrEqual(1);
    expect((await ctx.prisma.signupEmailMark.findUniqueOrThrow({ where: { userId: u.id } })).emailHash).toBe(
      mark.emailHash,
    );
  });

  it('the panel: listAdminSignupRecruits shows credited and withheld with the reason (OWNER only)', async () => {
    const sup = await supervisor();
    const phone = newDeviceKey();
    const a = await signup({ code: sup.code, deviceKey: phone });
    const b = await signup({ code: sup.code, deviceKey: phone });
    const owner = await makeAdmin(['OWNER']);
    const res = await ctx.http
      .get('/api/v1/admin/recruits/signups')
      .query({ recruiter: sup.user.id })
      .set('Cookie', owner.cookie);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listAdminSignupRecruits');
    const rows = res.body.data as { user: { id: string }; status: string; withholdReason: string | null }[];
    expect(rows.map((r) => [r.user.id, r.status, r.withholdReason])).toEqual([
      [b.id, 'WITHHELD', 'DEVICE_HAD_ACCOUNT'],
      [a.id, 'GRANTED', null],
    ]);
    const only = await ctx.http
      .get('/api/v1/admin/recruits/signups')
      .query({ status: 'WITHHELD', recruiter: sup.user.id })
      .set('Cookie', owner.cookie);
    expect((only.body.data as unknown[]).length).toBe(1);
    const moderator = await makeAdmin(['MODERATION']);
    const denied = await ctx.http.get('/api/v1/admin/recruits/signups').set('Cookie', moderator.cookie);
    expect(denied.status).toBe(403);
  });
});
