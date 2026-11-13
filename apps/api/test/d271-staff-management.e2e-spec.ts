/**
 * D271 (owner 2026-11-04, «اجعل امنحهم صلاحية من لوحة الأدمن»; contract v1.66-live, CONVENTIONS §10.96.5): the OWNER
 * manages the panel staff from «الموظفون والصلاحيات», end to end against PostgreSQL + Redis:
 *
 *  - OWNER only (MODERATION / SUPPORT / FINANCE 403 on the list and every change);
 *  - the step-up: no code → 400, a wrong code → 403 ADMIN_TOTP_INVALID and counted, a replayed code refused;
 *  - grant by `@username` and by email (D197's `email` still accepted); the answer names the account; a banned, locked
 *    or unknown account refused with its `issue`; the new staff member signs in, enrols and goes on shift;
 *  - revoke: one's own OWNER and a role not held refused; two OWNERs revoking each other at once leave one OWNER; the
 *    last watch role ends the shift and hands the person's live to another staff member on shift; the last role ends
 *    the panel sessions; reset-2fa ends the sessions;
 *  - every change audited with the OWNER as actor, the IP, `via: panel` and the reason; the CLI runs the same rules
 *    (it refuses the last active OWNER too: grant another OWNER first);
 *  - the team routes' own rate limit (`admin-team:ip`).
 */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const run = promisify(execFile);
const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

const D271_OPS = ['listAdminTeam', 'grantAdminTeamRole', 'revokeAdminTeamRole', 'resetAdminTeamTotp'];

describe('D271 contract coverage', () => {
  it('openapi v1.66-live describes the staff operations behind the admin session (CSRF on writes)', () => {
    const ops = operations().filter((o) => D271_OPS.includes(o.operationId));
    expect(ops.map((o) => o.operationId).sort()).toEqual([...D271_OPS].sort());
    for (const o of ops) {
      expect(String(o.spec.description)).toContain('(v1.66-live, D271');
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });
});

describe('D271 staff and permissions from the panel', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };

  const signup = async (): Promise<TestUser> => {
    const payload = newUser();
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
      token: ok.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  /** Signs `p` in to the panel and enrols the authenticator (what a new staff member does). */
  const panelSignIn = async (p: TestUser): Promise<Admin> => {
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
    expect(enrol.status, JSON.stringify(enrol.body)).toBe(200);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    return panelSignIn(p);
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const aput = (a: Admin, path: string, body: object = {}) =>
    ctx.http.put(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const issue = (res: request.Response) =>
    (res.body as { error?: { details?: { issue: string }[] } }).error?.details?.[0]?.issue;
  const lastAudit = (action: string, targetId: string) =>
    ctx.prisma.auditLog.findFirst({
      where: { action, targetId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });

  let media: MemoryLiveMedia;
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    media = new MemoryLiveMedia();
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        TRUST_PROXY: 'loopback',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_ADMIN_TEAM_IP: '1000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
    await withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
      );
      await db.$executeRawUnsafe(`DELETE FROM live_room_assignments`);
      await db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`);
    });
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('OWNER only: every other role gets 403 on the list and on each change', async () => {
    const target = await signup();
    for (const a of [moderator, support, finance]) {
      expect((await aget(a, '/admin/team')).status).toBe(403);
      expect(
        (
          await apost(a, '/admin/team/grant', {
            account: `@${target.username}`,
            role: 'SUPPORT',
            reason: 'x',
            totpCode: nextCode(a.secret),
          })
        ).status,
      ).toBe(403);
      expect(
        (
          await apost(a, `/admin/team/${owner.id}/revoke`, {
            role: 'OWNER',
            reason: 'x',
            totpCode: nextCode(a.secret),
          })
        ).status,
      ).toBe(403);
      expect(
        (await apost(a, `/admin/team/${owner.id}/reset-2fa`, { reason: 'x', totpCode: nextCode(a.secret) }))
          .status,
      ).toBe(403);
    }
    expect(await ctx.prisma.userAdminPermission.count({ where: { userId: target.id } })).toBe(0);
    // Without a session: 401.
    expect((await ctx.http.get('/api/v1/admin/team')).status).toBe(401);
  });

  it('the step-up: no code 400, a wrong code 403 (counted), a replayed code refused; nothing granted', async () => {
    const target = await signup();
    const body = { account: `@${target.username}`, role: 'MODERATION', reason: 'hired' };
    const none = await apost(owner, '/admin/team/grant', body);
    expect(none.status).toBe(400);
    const wrong = await apost(owner, '/admin/team/grant', { ...body, totpCode: '000000' });
    expect(wrong.status).toBe(403);
    expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    expect(
      (await ctx.prisma.adminCredential.findUniqueOrThrow({ where: { userId: owner.id } })).failedAttempts,
    ).toBe(1);
    const noReason = await apost(owner, '/admin/team/grant', {
      ...body,
      reason: ' ',
      totpCode: nextCode(owner.secret),
    });
    expect(noReason.status).toBe(400);
    const both = await apost(owner, '/admin/team/grant', {
      ...body,
      email: target.email,
      totpCode: nextCode(owner.secret),
    });
    expect(both.status).toBe(400);
    const code = nextCode(owner.secret);
    const ok = await apost(owner, '/admin/team/grant', { ...body, totpCode: code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    // A good code clears the failures.
    expect(
      (await ctx.prisma.adminCredential.findUniqueOrThrow({ where: { userId: owner.id } })).failedAttempts,
    ).toBe(0);
    // The same code again (a replay from a stolen request): refused.
    const replay = await apost(owner, `/admin/team/${target.id}/revoke`, {
      role: 'MODERATION',
      reason: 'x',
      totpCode: code,
    });
    expect(replay.status).toBe(403);
    expect(replay.body.error.code).toBe('ADMIN_TOTP_INVALID');
    expect(await ctx.prisma.userAdminPermission.count({ where: { userId: target.id } })).toBe(1);
    const undo = await apost(owner, `/admin/team/${target.id}/revoke`, {
      role: 'MODERATION',
      reason: 'cleanup',
      totpCode: nextCode(owner.secret),
    });
    expect(undo.status, JSON.stringify(undo.body)).toBe(200);
  });

  it('grant by @username or email; banned, locked or unknown refused; the new staff member signs in and goes on shift', async () => {
    const recruit = await signup();
    const ok = await apost(owner, '/admin/team/grant', {
      account: `@${recruit.username.toUpperCase()}`,
      role: 'MODERATION',
      reason: 'new moderator',
      totpCode: nextCode(owner.secret),
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'grantAdminTeamRole');
    expect(ok.body).toMatchObject({
      userId: recruit.id,
      role: 'MODERATION',
      madeAdmin: true,
      already: false,
      account: { email: recruit.email, username: recruit.username, totpEnrolled: false },
    });
    const audit = await lastAudit('admin.role.grant', recruit.id);
    expect(audit).toMatchObject({ actorUserId: owner.id });
    expect(audit!.ip).toBeTruthy();
    expect(audit!.metadata).toMatchObject({
      role: 'MODERATION',
      madeAdmin: true,
      reason: 'new moderator',
      via: 'panel',
    });
    // By email (D197's field) the same rule; a second grant of the same role changes nothing.
    const again = await apost(owner, '/admin/team/grant', {
      email: recruit.email,
      role: 'MODERATION',
      reason: 'again',
      totpCode: nextCode(owner.secret),
    });
    expect(again.status).toBe(200);
    expect(again.body.already).toBe(true);

    // Refusals with their issue; no role row, no audit.
    const unknown = await apost(owner, '/admin/team/grant', {
      account: '@nobody_like_this_d271',
      role: 'SUPPORT',
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(unknown.status).toBe(409);
    expect(issue(unknown)).toBe('team_no_account');
    const banned = await signup();
    await ctx.prisma.user.update({ where: { id: banned.id }, data: { status: 'SUSPENDED' } });
    const b = await apost(owner, '/admin/team/grant', {
      account: banned.email,
      role: 'SUPPORT',
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(b.status).toBe(409);
    expect(issue(b)).toBe('team_not_active');
    const locked = await signup();
    await withMigrationClient((db) =>
      db.accountRestriction.create({
        data: {
          userId: locked.id,
          kind: 'LOCK',
          reason: 'test',
          endsAt: new Date(clock + 86_400_000),
          via: 'cli',
        },
      }),
    );
    const l = await apost(owner, '/admin/team/grant', {
      account: `@${locked.username}`,
      role: 'SUPPORT',
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(l.status).toBe(409);
    expect(issue(l)).toBe('team_locked');
    for (const u of [banned, locked]) {
      expect(await ctx.prisma.userAdminPermission.count({ where: { userId: u.id } })).toBe(0);
      expect(await lastAudit('admin.role.grant', u.id)).toBeNull();
    }

    // The next steps: the recruit signs in, enrols, goes on shift; the OWNER's list shows it.
    const staff = await panelSignIn(recruit);
    const on = await aput(staff, '/admin/me/shift', { onShift: true });
    expect(on.status, JSON.stringify(on.body)).toBe(200);
    const team = await aget(owner, '/admin/team');
    expect(team.status).toBe(200);
    expectContract(team, 'listAdminTeam');
    const row = (team.body.data as { id: string }[]).find((m) => m.id === recruit.id);
    expect(row).toMatchObject({
      username: recruit.username,
      email: recruit.email,
      roles: ['MODERATION'],
      totpEnrolled: true,
      onShift: true,
    });
    expect((row as unknown as { shiftSince: string | null }).shiftSince).not.toBeNull();
    expect((row as unknown as { lastSignInAt: string | null }).lastSignInAt).not.toBeNull();
  });

  it("revoke: never one's own OWNER, a role not held 409; the last watch role ends the shift and hands the live on; the last role ends the sessions", async () => {
    const self = await apost(owner, `/admin/team/${owner.id}/revoke`, {
      role: 'OWNER',
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(self.status).toBe(409);
    expect(issue(self)).toBe('team_self_owner');
    const notHeld = await apost(owner, `/admin/team/${support.id}/revoke`, {
      role: 'FINANCE',
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(notHeld.status).toBe(409);
    expect(issue(notHeld)).toBe('team_not_held');

    // A staff member with SUPPORT + FINANCE, on shift, watching a live; the moderator also on shift.
    const s = await signup();
    await withMigrationClient(async (db) => {
      await db.$transaction((tx) => grantRoleIn(tx, s.email, 'SUPPORT'));
      await db.$transaction((tx) => grantRoleIn(tx, s.email, 'FINANCE'));
    });
    const staff = await panelSignIn(s);
    expect((await aput(staff, '/admin/me/shift', { onShift: true })).status).toBe(200);
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    advance(1000);
    const live = await ctx.http
      .post('/api/v1/live/rooms')
      .set('Authorization', `Bearer ${host.token}`)
      .send({ title: 'On air' });
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    const roomId = live.body.id as string;
    // The go-live pass runs in the background: wait for it, then make sure the live sits with `staff`.
    for (let i = 0; i < 200; i += 1) {
      if (await ctx.prisma.liveRoomAssignment.findUnique({ where: { roomId } })) break;
      await new Promise((r) => setTimeout(r, 10));
    }
    expect((await aput(moderator, '/admin/me/shift', { onShift: true })).status).toBe(200);
    await withMigrationClient((db) =>
      db.liveRoomAssignment.upsert({
        where: { roomId },
        create: { roomId, adminId: staff.id },
        update: { adminId: staff.id },
      }),
    );

    const r = await apost(owner, `/admin/team/${staff.id}/revoke`, {
      role: 'SUPPORT',
      reason: 'moved to finance only',
      totpCode: nextCode(owner.secret),
    });
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'revokeAdminTeamRole');
    expect(r.body).toEqual({ userId: staff.id, left: ['FINANCE'], shiftEnded: true });
    expect((await ctx.prisma.adminShift.findUniqueOrThrow({ where: { userId: staff.id } })).onShift).toBe(
      false,
    );
    const moved = await ctx.prisma.liveRoomAssignment.findUnique({ where: { roomId } });
    expect(moved?.adminId).not.toBe(staff.id);
    expect(moved?.adminId).toBeTruthy();
    expect((await lastAudit('admin.role.revoke', staff.id))!.metadata).toMatchObject({
      role: 'SUPPORT',
      left: ['FINANCE'],
      shiftEnded: true,
      reason: 'moved to finance only',
      via: 'panel',
    });
    // FINANCE left: the panel session lives on.
    expect((await aget(staff, '/admin/auth/session')).status).toBe(200);

    // The last role: sessions end.
    const last = await apost(owner, `/admin/team/${staff.id}/revoke`, {
      role: 'FINANCE',
      reason: 'left the company',
      totpCode: nextCode(owner.secret),
    });
    expect(last.status, JSON.stringify(last.body)).toBe(200);
    expect(last.body.left).toEqual([]);
    expect((await aget(staff, '/admin/auth/session')).status).toBe(401);
    expect(await ctx.prisma.adminSession.count({ where: { userId: staff.id, revokedAt: null } })).toBe(0);
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set('Authorization', `Bearer ${host.token}`);
  });

  it("reset-2fa: sessions end and the next sign-in enrols again; audited; never one's own", async () => {
    const own = await apost(owner, `/admin/team/${owner.id}/reset-2fa`, {
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(own.status).toBe(409);
    expect(issue(own)).toBe('team_self_reset');
    const reset = await apost(owner, `/admin/team/${support.id}/reset-2fa`, {
      reason: 'lost phone',
      totpCode: nextCode(owner.secret),
    });
    expect(reset.status, JSON.stringify(reset.body)).toBe(200);
    expect((await aget(support, '/admin/auth/session')).status).toBe(401);
    expect(await lastAudit('admin.totp.reset', support.id)).toMatchObject({ actorUserId: owner.id });
    expect((await lastAudit('admin.totp.reset', support.id))!.metadata).toMatchObject({
      reason: 'lost phone',
      via: 'panel',
    });
    support = await panelSignIn(support);
    expect((await aget(support, '/admin/auth/session')).status).toBe(200);
  });

  it('the CLI runs the same rules and still bootstraps (by @username too)', async () => {
    const p = await signup();
    const env = { ...process.env, DOTENV_CONFIG_QUIET: 'true' };
    const { stdout } = await run(
      'node',
      ['--import', 'tsx', 'src/cli/admin-admin.ts', 'grant', `@${p.username}`, 'SUPPORT'],
      {
        env,
      },
    );
    expect(stdout).toContain('SUPPORT granted');
    expect((await lastAudit('admin.role.grant', p.id))!.metadata).toMatchObject({ via: 'cli' });
    const list = await run('node', ['--import', 'tsx', 'src/cli/admin-admin.ts', 'list'], { env });
    expect(list.stdout).toContain(p.email);

    // The last active OWNER: the CLI refuses too (exit 1, grant another OWNER first); nothing changes, no audit row.
    const cli = (...args: string[]) =>
      run('node', ['--import', 'tsx', 'src/cli/admin-admin.ts', ...args], { env });
    const auditsBefore = await ctx.prisma.auditLog.count({
      where: { action: 'admin.role.revoke', targetId: owner.id },
    });
    const refused = await cli('revoke', owner.email, 'OWNER').then(
      () => null,
      (err: { code?: number; stderr?: string }) => err,
    );
    expect(refused?.code).toBe(1);
    expect(refused?.stderr).toContain('This is the last OWNER: grant OWNER to another active account first');
    expect(
      await ctx.prisma.userAdminPermission.count({ where: { userId: owner.id, permission: 'OWNER' } }),
    ).toBe(1);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'admin.role.revoke', targetId: owner.id } }),
    ).toBe(auditsBefore);
    // The usage text names the rule.
    const usage = await cli('revoke').then(
      () => null,
      (err: { stderr?: string }) => err,
    );
    expect(usage?.stderr).toContain('The last active OWNER cannot be revoked');
    // With another OWNER, the CLI hands ownership over: grant first, then revoke.
    expect((await cli('grant', p.email, 'OWNER')).stdout).toContain('OWNER granted');
    expect((await cli('revoke', `@${p.username}`, 'OWNER')).stdout).toContain('OWNER revoked');
    expect((await lastAudit('admin.role.revoke', p.id))!.metadata).toMatchObject({
      role: 'OWNER',
      via: 'cli',
    });
  });

  it('two OWNERs revoking each other at once leave exactly one OWNER (last; it may take the first OWNER)', async () => {
    const second = await makeAdmin(['OWNER']);
    advance(30_000);
    const [a, b] = await Promise.all([
      apost(owner, `/admin/team/${second.id}/revoke`, {
        role: 'OWNER',
        reason: 'race',
        totpCode: totpCode(owner.secret, clock),
      }),
      apost(second, `/admin/team/${owner.id}/revoke`, {
        role: 'OWNER',
        reason: 'race',
        totpCode: totpCode(second.secret, clock),
      }),
    ]);
    const statuses = [a.status, b.status].sort();
    expect(statuses[0], JSON.stringify([a.body, b.body])).toBe(200);
    // The loser: 409 team_last_owner (it waited for the lock), or 401 / 403 (its OWNER was already gone).
    expect([401, 403, 409]).toContain(statuses[1]);
    const loser = a.status === 200 ? b : a;
    if (loser.status === 409) expect(issue(loser)).toBe('team_last_owner');
    const owners = await ctx.prisma.userAdminPermission.count({
      where: { permission: 'OWNER', userId: { in: [owner.id, second.id] } },
    });
    expect(owners).toBe(1);
  });

  it('the team changes have their own rate limit (last: a fresh app empties the database)', async () => {
    const main = ctx;
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      RATE_LIMIT_ADMIN_TEAM_IP: '2/900',
    });
    try {
      const o = await makeAdmin(['OWNER']);
      const send = () => apost(o, `/admin/team/${o.id}/reset-2fa`, { reason: 'x' });
      expect((await send()).status).toBe(400);
      expect((await send()).status).toBe(400);
      const third = await send();
      expect(third.status).toBe(429);
      expect(third.body.error.code).toBe('RATE_LIMITED');
      // The list is not in that bucket.
      expect((await aget(o, '/admin/team')).status).toBe(200);
    } finally {
      await ctx.close();
      ctx = main;
    }
  });
});
