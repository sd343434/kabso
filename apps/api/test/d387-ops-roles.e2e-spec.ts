/**
 * D387 (owner 2026-11-12, contract v1.139-social, CONVENTIONS §10.176): the operations staff roles, end to end against
 * PostgreSQL + Redis:
 *
 *  - the capability matrix: each of the nine roles reaches exactly its own reads and writes (a write outside the role is
 *    403 before validation; inside it, the empty body is 400); the revenue reads answer 403 to every non-OWNER role,
 *    FINANCE included, and 200 to the OWNER; the masked aggregates are null without `revenue.view`;
 *  - MODERATION backward compatibility: TRUST_SAFETY is MODERATION (the CLI alias), and a moderator keeps every
 *    capability they held before D387;
 *  - the shift schedule: only MODERATION / SUPPORT / VIP_CARE, no overlap, «في المناوبة الآن», the next slots, the staff
 *    app's `scheduledShift`, the report resolve audit (`onShift`, `scheduled`), losing the role clears the slots;
 *  - compensations: within the limits → GRANTED (ledger `STAFF_COMPENSATION`), over them → PENDING → approve / reject,
 *    the daily reset, the history, the audit; the OWNER's limits with the code again;
 *  - the official social accounts: CRUD, https only, the order, the public list.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, parseRole, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { CAPABILITIES, PANEL_ROLES, type Capability } from '../src/modules/admin-panel/admin-permissions.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

/** What MODERATION held before D387 (origin/staging): none of it may be lost (TRUST_SAFETY = MODERATION). */
const MODERATION_BEFORE_D387: readonly Capability[] = [
  'dashboard.view',
  'users.view',
  'users.balances',
  'users.ledger',
  'users.ban',
  'users.avatar',
  'recharge.agents',
  'recharge.topups.view',
  'reports.view',
  'reports.act',
  'reports.resolve',
  'reports.reopen',
  'recharge.disputes',
  'recharge.disputes.resolve',
  'users.list',
  'users.sessions',
  'hosts.applications',
  'lives.view',
  'lives.manage',
  'users.control_view',
  'users.lock',
  'users.restrict',
  'users.profile_edit',
  'users.content',
  'lives.watch',
  'lives.reports',
  'lives.moderate',
  'devices.ban',
  'lives.watch.hidden',
  'recruits.mine',
  'levels.raise.request',
  'verification.view',
  'store_iap.view',
  'support.whatsapp',
  'support.whatsapp.manage',
  'support.whatsapp.view',
];

describe('D387 contract coverage', () => {
  it('openapi v1.139-social declares the operations roles operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAdminLiveOpsHome GET /api/v1/admin/role-homes/live-ops',
        'getAdminTalentHome GET /api/v1/admin/role-homes/talent',
        'getAdminTrustSafetyHome GET /api/v1/admin/role-homes/trust-safety',
        'getAdminVipCareHome GET /api/v1/admin/role-homes/vip-care',
        'getAdminCommunityHome GET /api/v1/admin/role-homes/community',
        'getAdminStaffSchedule GET /api/v1/admin/staff-schedule',
        'createAdminStaffScheduleSlot POST /api/v1/admin/staff-schedule',
        'updateAdminStaffScheduleSlot PUT /api/v1/admin/staff-schedule/{slotId}',
        'deleteAdminStaffScheduleSlot POST /api/v1/admin/staff-schedule/{slotId}/remove',
        'getAdminCompensationSettings GET /api/v1/admin/compensations/settings',
        'updateAdminCompensationSettings PUT /api/v1/admin/compensations/settings',
        'listAdminCompensations GET /api/v1/admin/compensations',
        'createAdminCompensation POST /api/v1/admin/compensations',
        'approveAdminCompensation POST /api/v1/admin/compensations/{compensationId}/approve',
        'rejectAdminCompensation POST /api/v1/admin/compensations/{compensationId}/reject',
        'listAdminSocialAccounts GET /api/v1/admin/social-accounts',
        'createAdminSocialAccount POST /api/v1/admin/social-accounts',
        'reorderAdminSocialAccounts PUT /api/v1/admin/social-accounts/order',
        'updateAdminSocialAccount PUT /api/v1/admin/social-accounts/{accountId}',
        'deleteAdminSocialAccount DELETE /api/v1/admin/social-accounts/{accountId}',
        'listOfficialSocialAccounts GET /api/v1/social-accounts',
      ]),
    );
  });
});

describe('D387 operations staff roles', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  // Thursday 2027-03-18 09:00 UTC (weekday 4, minute 540; both zones are UTC here).
  let clock = Date.parse('2027-03-18T09:00:00.000Z');
  const setNow = (ms: number) => {
    clock = ms;
    vi.setSystemTime(clock);
  };
  const advance = (ms: number) => setNow(clock + ms);
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  /** A code of the next 30-second step (a code is accepted once). */
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, parseRole(role))));
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
  /** A new panel session for an admin (the idle timeout is 10 minutes and the tests move the clock). */
  const relogin = async (a: Admin) => {
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: a.email, password: a.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const pending = cookieOf(res);
    const second = await ctx.http
      .post('/api/v1/admin/auth/totp/verify')
      .set('Cookie', pending)
      .set('X-CSRF-Token', res.body.csrfToken as string)
      .send({ code: nextCode(a.secret) });
    expect(second.status, JSON.stringify(second.body)).toBe(200);
    a.cookie = cookieOf(second);
    a.csrf = second.body.csrfToken as string;
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1/admin${path}`).set('Cookie', a.cookie);
  const send = (method: 'post' | 'put' | 'delete', a: Admin, path: string, body: object = {}) =>
    ctx.http[method](`/api/v1/admin${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const apost = (a: Admin, path: string, body: object = {}) => send('post', a, path, body);
  const aput = (a: Admin, path: string, body: object = {}) => send('put', a, path, body);
  const adelete = (a: Admin, path: string) => send('delete', a, path);
  const audits = (action: string) =>
    ctx.prisma.auditLog.findMany({ where: { action }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] });

  const byRole: Record<string, Admin> = {};
  let owner: Admin;
  let mod: Admin;
  let support: Admin;
  let finance: Admin;
  let vip: Admin;
  let community: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      RATE_LIMIT_STAFF_APP_USER: '100000/900',
      LIVE_RANKINGS_TIME_ZONE: 'UTC',
      ADMIN_DASHBOARD_TIME_ZONE: 'UTC',
    });
    for (const role of PANEL_ROLES) byRole[role] = await makeAdmin([role]);
    owner = byRole.OWNER!;
    mod = byRole.MODERATION!;
    support = byRole.SUPPORT!;
    finance = byRole.FINANCE!;
    vip = byRole.VIP_CARE!;
    community = byRole.COMMUNITY!;
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });
  const reloginAll = async () => {
    for (const a of Object.values(byRole)) await relogin(a);
  };

  describe('the capability matrix', () => {
    /** One read per capability: 200 inside the role, 403 `AUTH_FORBIDDEN` outside it. */
    const READS: [Capability, string][] = [
      ['revenue.view', '/dashboard'],
      ['revenue.view', '/stats/overview'],
      ['revenue.view', '/stats/series'],
      ['revenue.view', '/finance/report?from=2027-03-01&to=2027-03-02'],
      ['revenue.view', '/store/sales'],
      ['dashboard.view', '/stats/attention'],
      ['home.live_ops', '/role-homes/live-ops'],
      ['home.talent', '/role-homes/talent'],
      ['home.trust_safety', '/role-homes/trust-safety'],
      ['home.vip_care', '/role-homes/vip-care'],
      ['home.community', '/role-homes/community'],
      ['staff.schedule.view', '/staff-schedule'],
      ['compensation.grant', '/compensations'],
      ['compensation.grant', '/compensations/settings'],
      ['social.accounts', '/social-accounts'],
      ['site.public', '/site-settings'],
      ['site.settings', '/camera-fx'],
      ['catalog.view', '/gifts'],
      ['lives.view', '/lives'],
      ['agencies.view', '/agencies'],
      ['hosts.applications', '/host-applications'],
      ['creators.applications', '/creator-applications'],
      ['recruits.mine', '/recruits/mine'],
      ['levels.raise.request', '/level-raises'],
      ['host_targets.view', '/host-targets/settings'],
      ['pk_dares.view', '/pk-dares'],
      ['reports.view', '/moderation/reports'],
      ['recharge.topups.view', '/finance/recharge-topups'],
    ];
    /** One write per capability with an empty body: 400 inside the role (validation), 403 outside it (the guard). */
    const WRITES: [Capability, 'post' | 'put', string][] = [
      ['gifts.manage', 'post', '/gifts'],
      ['banners.manage', 'post', '/banners'],
      ['boosts.manage', 'put', '/live-boost-prices'],
      ['site.public', 'put', '/site-settings'],
      ['social.accounts', 'post', '/social-accounts'],
      ['staff.schedule.manage', 'post', '/staff-schedule'],
      ['compensation.grant', 'post', '/compensations'],
      ['compensation.settings', 'put', '/compensations/settings'],
      ['compensation.approve', 'post', `/compensations/${randomUUID()}/approve`],
      ['compensation.approve', 'post', `/compensations/${randomUUID()}/reject`],
      ['catalog.manage', 'post', '/vip/tiers'],
    ];

    it('each role reaches exactly its own capabilities; revenue is the OWNER’s alone', async () => {
      await reloginAll();
      // `revenue.view` is OWNER only and can never be given to another role.
      expect(CAPABILITIES['revenue.view']).toEqual(['OWNER']);
      for (const role of PANEL_ROLES) {
        const a = byRole[role]!;
        const me = await aget(a, '/auth/session');
        expect(me.body.roles).toEqual([role]);
        for (const [cap, path] of READS) {
          const allowed = (CAPABILITIES[cap] as readonly string[]).includes(role);
          const res = await aget(a, path);
          expect(res.status, `${role} ${cap} GET ${path} ${JSON.stringify(res.body).slice(0, 300)}`).toBe(
            allowed ? 200 : 403,
          );
          if (!allowed) expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
          expect(me.body.capabilities.includes(cap), `${role} ${cap}`).toBe(allowed);
        }
        for (const [cap, method, path] of WRITES) {
          const allowed = (CAPABILITIES[cap] as readonly string[]).includes(role);
          const res = await send(method, a, path, {});
          expect(res.status, `${role} ${cap} ${method} ${path}`).toBe(allowed ? 400 : 403);
        }
      }
      // FINANCE in particular: no dashboard, no financial report, no store sales.
      for (const path of ['/dashboard', '/stats/overview', '/finance/report?from=2027-03-01&to=2027-03-02']) {
        expect((await aget(finance, path)).status).toBe(403);
      }
      expect((await aget(owner, '/dashboard')).status).toBe(200);
    });

    it('the role homes answer the contract with no money figure', async () => {
      const homes: [Capability, string, string][] = [
        ['home.live_ops', '/role-homes/live-ops', 'getAdminLiveOpsHome'],
        ['home.talent', '/role-homes/talent', 'getAdminTalentHome'],
        ['home.trust_safety', '/role-homes/trust-safety', 'getAdminTrustSafetyHome'],
        ['home.vip_care', '/role-homes/vip-care', 'getAdminVipCareHome'],
        ['home.community', '/role-homes/community', 'getAdminCommunityHome'],
      ];
      for (const [cap, path, op] of homes) {
        const role = CAPABILITIES[cap].find((r) => r !== 'OWNER')!;
        const res = await aget(byRole[role]!, path);
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, op);
        expect(JSON.stringify(res.body)).not.toMatch(/coins|revenue|usd|cherries|commission|profit/i);
      }
    });

    it('the aggregates are masked without revenue.view; FINANCE keeps the amounts of each request', async () => {
      const fin = await aget(finance, '/finance/recharge-topups');
      expect(fin.status).toBe(200);
      expectContract(fin, 'listAdminRechargeTopups');
      expect(fin.body.totals).toBeNull();
      const own = await aget(owner, '/finance/recharge-topups');
      expect(own.body.totals).not.toBeNull();
      // LIVE_OPS reads the gifts without their coin spending.
      const gifts = await aget(byRole.LIVE_OPS!, '/gifts');
      expect(gifts.status).toBe(200);
      for (const g of gifts.body.data as { coinsSpent: unknown }[]) expect(g.coinsSpent).toBeNull();
    });

    it('site.public: COMMUNITY may not switch the website top-up (payments.settings)', async () => {
      const current = await aget(community, '/site-settings');
      expect(current.status).toBe(200);
      const res = await aput(community, '/site-settings', {
        ...current.body,
        topupEnabled: !current.body.topupEnabled,
        reason: 'try',
      });
      expect([400, 403]).toContain(res.status);
      if (res.status === 403) expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
    });
  });

  describe('MODERATION backward compatibility (TRUST_SAFETY)', () => {
    it('TRUST_SAFETY is MODERATION: the alias grants MODERATION and nothing held before D387 is lost', async () => {
      expect(parseRole('TRUST_SAFETY')).toBe('MODERATION');
      expect(parseRole('moderator')).toBe('MODERATION');
      const ts = await makeAdmin(['TRUST_SAFETY']);
      const me = await aget(ts, '/auth/session');
      expect(me.body.roles).toEqual(['MODERATION']);
      for (const cap of MODERATION_BEFORE_D387) {
        expect(me.body.capabilities, cap).toContain(cap);
        expect(CAPABILITIES[cap] as readonly string[], cap).toContain('MODERATION');
      }
      expect(me.body.capabilities).toContain('home.trust_safety');
      expect(me.body.capabilities).not.toContain('revenue.view');
      expect((await aget(ts, '/moderation/reports')).status).toBe(200);
      expect((await aget(ts, '/role-homes/trust-safety')).status).toBe(200);
    });
  });

  describe('the shift schedule', () => {
    const slot = (a: Admin, userId: string, weekday: number, startMinute: number, endMinute: number) =>
      apost(a, '/staff-schedule', { userId, weekday, startMinute, endMinute, reason: 'rota' });

    it('schedules MODERATION / SUPPORT / VIP_CARE only, never overlapping; shows who is on shift now and next', async () => {
      await reloginAll();
      // Thursday 12:00 UTC (weekday 4, minute 720).
      setNow(Date.parse('2027-03-18T12:00:00.000Z'));
      expect((await slot(finance, mod.id, 4, 480, 960)).status).toBe(403);
      // Not schedulable: FINANCE, COMMUNITY.
      const wrong = await slot(owner, finance.id, 4, 480, 960);
      expect(wrong.status).toBe(409);
      expect(issueOf(wrong)?.issue).toBe('schedule_role');
      expect((await slot(owner, community.id, 4, 480, 960)).status).toBe(409);
      // Shape: end after start.
      const shape = await slot(owner, mod.id, 4, 600, 600);
      expect(shape.status).toBe(400);
      // Thursday 08:00–16:00 for the moderator (covers now, 12:00), 16:00–24:00 for support, Friday 00:00–08:00 VIP care.
      const created = await slot(owner, mod.id, 4, 480, 960);
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      expectContract(created, 'createAdminStaffScheduleSlot');
      expect((await slot(owner, support.id, 4, 960, 1440)).status).toBe(201);
      expect((await slot(owner, vip.id, 5, 0, 480)).status).toBe(201);
      const overlap = await slot(owner, mod.id, 4, 900, 1000);
      expect(overlap.status).toBe(409);
      expect(issueOf(overlap)?.issue).toBe('schedule_overlap');
      // Touching ends do not overlap.
      expect((await slot(owner, mod.id, 4, 960, 1000)).status).toBe(201);

      const view = await aget(support, '/staff-schedule');
      expect(view.status).toBe(200);
      expectContract(view, 'getAdminStaffSchedule');
      expect(view.body.now).toEqual({ weekday: 4, minute: 720 });
      expect(view.body.shift.onShiftNow.map((p: { userId: string }) => p.userId)).toEqual([mod.id]);
      // Next: the moderator's and support's 16:00 slots (a tie), then VIP care's Friday 00:00.
      const next = (view.body.shift.next as { person: { userId: string } }[]).map((n) => n.person.userId);
      expect(next.slice(0, 2).sort()).toEqual([mod.id, support.id].sort());
      expect(next[2]).toBe(vip.id);
      expect(view.body.me).toEqual({ onShiftNow: false });
      expect((await aget(mod, '/staff-schedule')).body.me).toEqual({ onShiftNow: true });
      const homeTs = await aget(mod, '/role-homes/trust-safety');
      expect(homeTs.body.shift.onShiftNow.map((p: { userId: string }) => p.userId)).toEqual([mod.id]);
      expect(await audits('staff.schedule.create')).toHaveLength(4);

      // The staff app: «في المناوبة الآن» (a fresh app token: the clock moved past the access token's life).
      const appToken = async (u: TestUser) => {
        const res = await ctx.http
          .post('/api/v1/auth/login')
          .send({ identifier: u.email, password: u.password });
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        return { token: res.body.tokens.accessToken as string };
      };
      const modApp = await appToken(mod);
      const supportApp = await appToken(support);
      const appMod = await ctx.http.get('/api/v1/staff/me').set(auth(modApp));
      expect(appMod.status).toBe(200);
      expectContract(appMod, 'getStaffStatus');
      expect(appMod.body.scheduledShift).toBe(true);
      const appSupport = await ctx.http.get('/api/v1/staff/me').set(auth(supportApp));
      expect(appSupport.body.scheduledShift).toBe(false);
    });

    it('edits and removes a slot with a reason (audited)', async () => {
      const view = await aget(owner, '/staff-schedule');
      const vipSlot = (view.body.slots as { id: string; person: { userId: string } }[]).find(
        (s) => s.person.userId === vip.id,
      )!;
      const moved = await aput(owner, `/staff-schedule/${vipSlot.id}`, {
        userId: vip.id,
        weekday: 5,
        startMinute: 60,
        endMinute: 480,
        reason: 'later start',
      });
      expect(moved.status, JSON.stringify(moved.body)).toBe(200);
      expectContract(moved, 'updateAdminStaffScheduleSlot');
      const gone = await apost(owner, `/staff-schedule/${vipSlot.id}/remove`, { reason: 'not needed' });
      expect(gone.status).toBe(200);
      expectContract(gone, 'deleteAdminStaffScheduleSlot');
      expect(await audits('staff.schedule.update')).toHaveLength(1);
      expect(await audits('staff.schedule.delete')).toHaveLength(1);
      expect((await aput(vip, `/staff-schedule/${vipSlot.id}`, {})).status).toBe(403);
    });

    it('the report resolve audit records whether the resolver was on shift; reports reach everyone', async () => {
      const author = await signup();
      const reporter = await signup();
      const mkReport = async () => {
        const post = await ctx.http
          .post('/api/v1/posts')
          .set(auth(author))
          .set('Idempotency-Key', randomUUID())
          .send({ text: `a post ${randomUUID()}` });
        expect(post.status).toBe(201);
        advance(1000);
        const rep = await ctx.http
          .post('/api/v1/reports')
          .set(auth(reporter))
          .send({ targetType: 'POST', targetId: post.body.id, reason: 'SPAM' });
        expect(rep.status, JSON.stringify(rep.body)).toBe(201);
        return rep.body.id as string;
      };
      const first = await mkReport();
      // The new report reaches every staff member with reports.view, on shift or not (D288; the OWNER is the fallback).
      for (const s of [mod, support]) {
        const n = await ctx.prisma.notification.count({
          where: { recipientId: s.id, type: 'STAFF_REPORT_NEW', reportId: first },
        });
        expect(n, s.username).toBe(1);
      }
      const byMod = await apost(mod, `/moderation/reports/${first}/resolve`, { note: 'done' });
      expect(byMod.status, JSON.stringify(byMod.body)).toBe(200);
      const second = await mkReport();
      const bySupport = await apost(support, `/moderation/reports/${second}/resolve`, { note: 'done' });
      expect(bySupport.status).toBe(200);
      const rows = await audits('moderation.report.resolve');
      const meta = (id: string) =>
        rows.find((r) => (r.metadata as { reportId: string }).reportId === id)!.metadata;
      expect(meta(first)).toMatchObject({ onShift: true, scheduled: true });
      expect(meta(second)).toMatchObject({ onShift: false, scheduled: false });
      // Resolved for everyone.
      const open = await aget(support, '/moderation/reports');
      expect((open.body.data as { id: string }[]).map((r) => r.id)).not.toContain(first);
    });

    it('losing the last schedulable role clears the person’s slots', async () => {
      const extra = await makeAdmin(['SUPPORT']);
      expect((await slot(owner, extra.id, 1, 0, 60)).status).toBe(201);
      await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, extra.email, 'SUPPORT')));
      expect(await ctx.prisma.staffScheduleSlot.count({ where: { userId: extra.id } })).toBe(0);
    });
  });

  describe('compensations (VIP_CARE)', () => {
    const TIER = randomUUID();
    let person: TestUser;
    const balance = async (userId: string) =>
      (await ctx.prisma.wallet.findUnique({ where: { userId } }))?.coins ?? 0n;
    const give = (a: Admin, body: object) =>
      apost(a, '/compensations', {
        user: person.username,
        reason: 'stream dropped',
        totpCode: nextCode(a.secret),
        ...body,
      });

    beforeAll(async () => {
      person = await signup();
      await withMigrationClient((db) =>
        db.vipTier.create({
          data: {
            id: TIER,
            code: 'VIP_C1',
            nameAr: 'في آي بي',
            nameEn: 'VIP',
            sortOrder: 1,
            color: '#2E8B3D',
            priceCoins: 1_000_000n,
            durationDays: 30,
            enabled: true,
          },
        }),
      );
    });

    it('the OWNER sets the limits (the code again, audited); VIP_CARE reads them', async () => {
      await reloginAll();
      const before = await aget(vip, '/compensations/settings');
      expect(before.status).toBe(200);
      expectContract(before, 'getAdminCompensationSettings');
      expect(before.body).toMatchObject({
        dailyLimitCoins: 50_000,
        perGrantMaxCoins: 10_000,
        usedTodayCoins: 0,
      });
      expect(
        (
          await aput(owner, '/compensations/settings', {
            dailyLimitCoins: 15_000,
            perGrantMaxCoins: 8_000,
            reason: 'x',
            totpCode: '000000',
          })
        ).status,
      ).toBe(403);
      const set = await aput(owner, '/compensations/settings', {
        dailyLimitCoins: 15_000,
        perGrantMaxCoins: 8_000,
        reason: 'limits for the VIP care team',
        totpCode: nextCode(owner.secret),
      });
      expect(set.status, JSON.stringify(set.body)).toBe(200);
      expectContract(set, 'updateAdminCompensationSettings');
      expect(await audits('staff.compensation.settings')).toHaveLength(1);
      expect((await aput(vip, '/compensations/settings', {})).status).toBe(403);
    });

    it('within the limits → GRANTED through the ledger; over them → PENDING; the day resets', async () => {
      // Never to oneself or to a team member.
      const self = await apost(vip, '/compensations', {
        user: vip.username,
        kind: 'COINS',
        coins: 10,
        reason: 'stream dropped',
        totpCode: nextCode(vip.secret),
      });
      expect(self.status).toBe(409);
      expect(issueOf(self)?.issue).toBe('compensation_recipient');
      const toStaff = await apost(vip, '/compensations', {
        user: mod.username,
        kind: 'COINS',
        coins: 10,
        reason: 'stream dropped',
        totpCode: nextCode(vip.secret),
      });
      expect(toStaff.status).toBe(409);
      // A wrong code: nothing moves.
      const badCode = await apost(vip, '/compensations', {
        user: person.username,
        kind: 'COINS',
        coins: 10,
        reason: 'stream dropped',
        totpCode: '000000',
      });
      expect(badCode.status).toBe(403);

      const ok = await give(vip, { kind: 'COINS', coins: 5_000 });
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expectContract(ok, 'createAdminCompensation');
      expect(ok.body).toMatchObject({ status: 'GRANTED', valueCoins: 5_000, overLimit: null });
      expect(await balance(person.id)).toBe(5_000n);
      const entry = await ctx.prisma.walletLedgerEntry.findFirst({
        where: { userId: person.id, reason: 'STAFF_COMPENSATION' },
      });
      expect(entry).toMatchObject({ delta: 5_000n, referenceId: ok.body.id });

      // Over the per-grant maximum (8 000) → PENDING, nothing moves.
      const big = await give(vip, { kind: 'COINS', coins: 9_000 });
      expect(big.status).toBe(201);
      expect(big.body).toMatchObject({ status: 'PENDING', overLimit: 'per_grant' });
      // 5 000 + 7 000 = 12 000 ≤ 15 000 → granted; then 5 000 more is past the day → PENDING daily.
      expect((await give(vip, { kind: 'COINS', coins: 7_000 })).body.status).toBe('GRANTED');
      const daily = await give(vip, { kind: 'COINS', coins: 5_000 });
      expect(daily.body).toMatchObject({ status: 'PENDING', overLimit: 'daily' });
      expect(await balance(person.id)).toBe(12_000n);
      expect((await aget(vip, '/compensations/settings')).body.usedTodayCoins).toBe(12_000);

      // VIP days: ⌈1 000 000 × 3 ÷ 30⌉ = 100 000 > 8 000 → PENDING.
      const days = await give(vip, { kind: 'VIP_DAYS', days: 3, tierCode: 'VIP_C1' });
      expect(days.body).toMatchObject({ status: 'PENDING', valueCoins: 100_000, tierCode: 'VIP_C1' });
      // An item with no coin price for those days.
      const item = await give(vip, { kind: 'ITEM', itemCode: 'no_such_item', days: 7 });
      expect(item.status).toBe(409);
      expect(issueOf(item)?.issue).toBe('compensation_item');
      // Fields of another kind: 400.
      expect((await give(vip, { kind: 'COINS', coins: 1, days: 3 })).status).toBe(400);

      // The next day (UTC midnight) the limit resets.
      setNow(Date.parse('2027-03-19T00:05:00.000Z'));
      await relogin(vip);
      expect((await aget(vip, '/compensations/settings')).body.usedTodayCoins).toBe(0);
      expect((await give(vip, { kind: 'COINS', coins: 6_000 })).body.status).toBe('GRANTED');
      expect(await balance(person.id)).toBe(18_000n);

      expect(await audits('staff.compensation.grant')).toHaveLength(3);
      expect(await audits('staff.compensation.request')).toHaveLength(3);
    });

    it('the OWNER approves (the grant runs then) or rejects; a decided one → 409; history per role', async () => {
      await relogin(owner);
      await relogin(vip);
      const pending = await aget(owner, '/compensations?status=PENDING');
      expect(pending.status).toBe(200);
      expectContract(pending, 'listAdminCompensations');
      expect(pending.body.total).toBe(3);
      const [vipDays, daily, perGrant] = pending.body.data as { id: string; kind: string; coins: number }[];
      expect(vipDays!.kind).toBe('VIP_DAYS');
      expect(daily!.coins).toBe(5_000);
      expect(perGrant!.coins).toBe(9_000);

      // VIP_CARE cannot decide.
      expect(
        (await apost(vip, `/compensations/${perGrant!.id}/approve`, { totpCode: '000000' })).status,
      ).toBe(403);

      const approved = await apost(owner, `/compensations/${perGrant!.id}/approve`, {
        note: 'ok, long outage',
        totpCode: nextCode(owner.secret),
      });
      expect(approved.status, JSON.stringify(approved.body)).toBe(200);
      expectContract(approved, 'approveAdminCompensation');
      expect(approved.body).toMatchObject({ status: 'APPROVED', decidedBy: { id: owner.id } });
      expect(await balance(person.id)).toBe(27_000n);

      const vipOk = await apost(owner, `/compensations/${vipDays!.id}/approve`, {
        totpCode: nextCode(owner.secret),
      });
      expect(vipOk.status, JSON.stringify(vipOk.body)).toBe(200);
      const membership = await ctx.prisma.vipMembership.findUnique({ where: { userId: person.id } });
      expect(membership?.tierId).toBe(TIER);

      const rejected = await apost(owner, `/compensations/${daily!.id}/reject`, {
        reason: 'already covered',
      });
      expect(rejected.status).toBe(200);
      expectContract(rejected, 'rejectAdminCompensation');
      expect(rejected.body).toMatchObject({ status: 'REJECTED', decisionNote: 'already covered' });
      expect(await balance(person.id)).toBe(27_000n);

      const again = await apost(owner, `/compensations/${daily!.id}/approve`, {
        totpCode: nextCode(owner.secret),
      });
      expect(again.status).toBe(409);
      expect(issueOf(again)?.issue).toBe('compensation_decided');

      expect(await audits('staff.compensation.approve')).toHaveLength(2);
      expect(await audits('staff.compensation.reject')).toHaveLength(1);

      // The history: VIP_CARE sees their own (6), the OWNER everyone's — including the OWNER's own, never limited.
      const ownerGift = await apost(owner, '/compensations', {
        user: person.username,
        kind: 'COINS',
        coins: 500_000,
        reason: 'owner goodwill',
        totpCode: nextCode(owner.secret),
      });
      expect(ownerGift.body.status).toBe('GRANTED');
      expect((await aget(vip, '/compensations')).body.total).toBe(6);
      expect((await aget(owner, '/compensations')).body.total).toBe(7);
      const home = await aget(vip, '/role-homes/vip-care');
      expect(home.body.pendingCompensations).toBe(0);
    });
  });

  describe('the official social accounts', () => {
    it('CRUD by COMMUNITY / OWNER, https only, in order, links only; the public list', async () => {
      await reloginAll();
      const create = (a: Admin, platform: string, handle: string, url: string) =>
        apost(a, '/social-accounts', { platform, handle, url });
      for (const url of [
        'http://instagram.com/kabso',
        'javascript:alert(1)',
        'https://user:pw@instagram.com/kabso',
        'ftp://x.com',
        'https://',
        'https://insta gram.com/x',
      ]) {
        const bad = await create(community, 'INSTAGRAM', 'kabso', url);
        expect(bad.status, url).toBe(400);
        expect(issueOf(bad)).toEqual({ field: 'url', issue: 'invalid_value' });
      }
      // No secret field is accepted (strict body).
      expect(
        (
          await apost(community, '/social-accounts', {
            platform: 'X',
            handle: 'kabso',
            url: 'https://x.com/kabso',
            password: 'secret',
          })
        ).status,
      ).toBe(400);
      expect((await create(support, 'X', 'kabso', 'https://x.com/kabso')).status).toBe(403);

      const created = await create(community, 'INSTAGRAM', '@kabso.live', 'https://instagram.com/kabso.live');
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      expectContract(created, 'createAdminSocialAccount');
      expect((await create(owner, 'TIKTOK', '@kabso', 'https://www.tiktok.com/@kabso')).status).toBe(201);
      const list = await aget(community, '/social-accounts');
      expectContract(list, 'listAdminSocialAccounts');
      const [ig, tt] = (list.body.data as { id: string; platform: string }[]).map((a) => ({ body: a }));
      expect([ig!.body.platform, tt!.body.platform]).toEqual(['INSTAGRAM', 'TIKTOK']);

      const reordered = await aput(community, '/social-accounts/order', { ids: [tt!.body.id, ig!.body.id] });
      expect(reordered.status, JSON.stringify(reordered.body)).toBe(200);
      expectContract(reordered, 'reorderAdminSocialAccounts');
      const edited = await aput(community, `/social-accounts/${ig!.body.id}`, {
        platform: 'INSTAGRAM',
        handle: '@kabso',
        url: 'https://instagram.com/kabso',
      });
      expect(edited.status).toBe(200);
      expectContract(edited, 'updateAdminSocialAccount');
      expect(
        (
          await aput(community, `/social-accounts/${ig!.body.id}`, {
            platform: 'INSTAGRAM',
            handle: '@kabso',
            url: 'http://instagram.com/kabso',
          })
        ).status,
      ).toBe(400);

      const pub = await ctx.http.get('/api/v1/social-accounts');
      expect(pub.status).toBe(200);
      expectContract(pub, 'listOfficialSocialAccounts');
      expect(pub.headers['cache-control']).toContain('max-age=60');
      expect(pub.body).toEqual({
        data: [
          { platform: 'TIKTOK', handle: '@kabso', url: 'https://www.tiktok.com/@kabso' },
          { platform: 'INSTAGRAM', handle: '@kabso', url: 'https://instagram.com/kabso' },
        ],
      });

      const del = await adelete(community, `/social-accounts/${tt!.body.id}`);
      expect([200, 204]).toContain(del.status);
      expect((await ctx.http.get('/api/v1/social-accounts')).body.data).toHaveLength(1);
      for (const action of ['create', 'update', 'delete', 'reorder']) {
        expect((await audits(`site.social_account.${action}`)).length, action).toBeGreaterThan(0);
      }
      // No column can hold a secret.
      const cols = await ctx.prisma.$queryRaw<{ column_name: string }[]>`
        SELECT column_name FROM information_schema.columns WHERE table_name = 'official_social_accounts'`;
      expect(cols.map((c) => c.column_name).join(' ')).not.toMatch(/pass|token|secret|key/i);
    });
  });
});
