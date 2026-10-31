/**
 * D197 (owner 2026-10-31; contract v1.65-social, CONVENTIONS §10.60, CP-039): the admin panel v2 API — the
 * read-only statistics on seeded rows (Asia/Riyadh days), the quick search, the tables with their audited CSV, a
 * user's tabs, agencies, lives (end a live), gifts and items, money (TOTP for the team refund), the audit viewer and
 * the team (grant / revoke / reset with TOTP through `kabso_admin_panel_role`), tasks / levels / special usernames /
 * waitlist — every route's capability per role, an audit row per change with `via: panel` and the reason, and the
 * CLIs still running the same rules. End to end against PostgreSQL + Redis.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { CAPABILITIES, PANEL_ROLES, type Capability } from '../src/modules/admin-panel/admin-permissions.js';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { dayStart } from '../src/modules/recharge/recharge-rules.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
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
const ZONE = 'Asia/Riyadh';

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
}

const D197_OPS = [
  'getAdminStatsOverview',
  'getAdminStatsSeries',
  'getAdminStatsAttention',
  'getAdminStatsActivity',
  'searchAdminEverything',
  'listAdminUsersTable',
  'listAdminUserLedger',
  'listAdminUserPosts',
  'listAdminUserAudit',
  'listAdminUserSessions',
  'revokeAdminUserSessions',
  'getAdminUserBag',
  'grantAdminUserBagItem',
  'revokeAdminUserBagItem',
  'listAdminAgencies',
  'createAdminAgency',
  'getAdminAgency',
  'suspendAdminAgency',
  'reinstateAdminAgency',
  'listAdminAgencyComplaints',
  'resolveAdminAgencyComplaint',
  'runAdminAgencyEvaluation',
  'listAdminLives',
  'getAdminLive',
  'endAdminLive',
  'listAdminLiveHosts',
  'grantAdminLiveHost',
  'revokeAdminLiveHost',
  'listAdminGifts',
  'createAdminGift',
  'updateAdminGift',
  'enableAdminGift',
  'disableAdminGift',
  'listAdminBagItems',
  'listAdminBanners',
  'enableAdminBanner',
  'disableAdminBanner',
  'removeAdminBanner',
  'listAdminEvents',
  'createAdminEvent',
  'endAdminEvent',
  'holdAdminEvent',
  'releaseAdminEvent',
  'listAdminRechargeTopups',
  'listAdminCardOrders',
  'refundAdminCardOrder',
  'listAdminTopupCases',
  'closeAdminTopupCase',
  'getAdminFinanceReport',
  'listAdminAudit',
  'listAdminAuditActions',
  'listAdminTeam',
  'grantAdminTeamRole',
  'revokeAdminTeamRole',
  'resetAdminTeamTotp',
  'listAdminTasks',
  'listAdminPanelLevels',
  'listAdminSpecialUsernames',
  'listAdminWaitlist',
];

describe('D197 contract coverage', () => {
  it('openapi v1.65-social declares the panel v2 operations, each with the admin session', () => {
    const mine = operations().filter((o) =>
      (typeof o.spec.description === 'string' ? o.spec.description : '').startsWith('(v1.65-social, D197)'),
    );
    expect(mine.map((o) => o.operationId).sort()).toEqual([...D197_OPS].sort());
    for (const o of mine) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') {
        expect(JSON.stringify(o.spec.parameters), o.operationId).toContain('AdminCsrf');
      }
    }
  });
});

describe('D197 admin panel v2', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
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
    return line.split(';')[0]!;
  };
  const login = (email: string, password: string) =>
    ctx.http.post('/api/v1/admin/auth/login').send({ email, password });

  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await login(p.email, p.password);
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
  const relogin = async (...admins: Admin[]) => {
    for (const a of admins) {
      const res = await login(a.email, a.password);
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
  const send = (method: 'post' | 'patch', a: Admin, path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const post = (a: Admin, path: string, body: object = {}) => send('post', a, path, body);
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: { createdAt: 'asc' },
    });
  const lastAudit = async (action: string, targetId?: string) => {
    const rows = await audits(action, targetId);
    expect(rows.length, action).toBeGreaterThan(0);
    return rows[rows.length - 1]!;
  };
  /** A panel change's audit row: the actor, the IP, `via: panel` and the reason. */
  const expectPanelAudit = async (
    action: string,
    targetId: string | undefined,
    actor: Admin,
    reason?: string,
  ) => {
    const row = await lastAudit(action, targetId);
    expect(row.actorUserId).toBe(actor.id);
    expect(row.ip).toBeTruthy();
    const meta = row.metadata as Record<string, unknown>;
    expect(meta.via).toBe('panel');
    if (reason !== undefined) expect(JSON.stringify(meta)).toContain(reason);
    return meta;
  };

  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  let plain: Person;
  let agentUser: Person;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        ADMIN_SESSION_MAX_SECONDS: '28800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        ADMIN_DASHBOARD_TIME_ZONE: ZONE,
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
    plain = await signup();
    agentUser = await signup();
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });
  afterEach(() => vi.setSystemTime(clock));

  describe('permission matrix', () => {
    it('every role gets exactly its capabilities on every v2 read (server-side)', async () => {
      const READS: Partial<Record<Capability, string>> = {
        'dashboard.view': '/admin/stats/overview',
        'users.list': '/admin/tables/users',
        'users.ledger': `/admin/users/${plain.id}/ledger`,
        'users.sessions': `/admin/users/${plain.id}/sessions`,
        'items.grant': `/admin/users/${plain.id}/bag`,
        'agencies.view': '/admin/agencies',
        'lives.view': '/admin/lives',
        'catalog.view': '/admin/gifts',
        'finance.view': '/admin/finance/card-orders',
        'audit.view': '/admin/audit',
        'team.manage': '/admin/team',
        'programs.view': '/admin/programs/tasks',
        'waitlist.view': '/admin/waitlist',
      };
      const byRole: Record<string, Admin> = {
        OWNER: owner,
        MODERATION: moderator,
        SUPPORT: support,
        FINANCE: finance,
      };
      for (const role of PANEL_ROLES) {
        const a = byRole[role]!;
        const me = await get(a, '/admin/auth/session');
        for (const [cap, path] of Object.entries(READS)) {
          const allowed = (CAPABILITIES[cap as Capability] as readonly string[]).includes(role);
          const res = await get(a, path);
          expect(res.status, `${role} ${cap} ${path} ${JSON.stringify(res.body).slice(0, 200)}`).toBe(
            allowed ? 200 : 403,
          );
          expect(me.body.capabilities.includes(cap), `${role} ${cap}`).toBe(allowed);
        }
      }
      // Mutations outside the role: refused before anything changes (and without CSRF: 403 too).
      const reason = { reason: 'x' };
      expect((await post(finance, '/admin/agency-evaluation', reason)).status).toBe(403);
      expect((await post(support, `/admin/lives/${randomUUID()}/end`, reason)).status).toBe(403);
      expect((await post(support, '/admin/gifts', { code: 'nope', reason: 'x' })).status).toBe(403);
      expect(
        (
          await post(moderator, `/admin/finance/card-orders/${randomUUID()}/refund`, {
            reason: 'x',
            totpCode: '000000',
          })
        ).status,
      ).toBe(403);
      expect(
        (
          await post(finance, '/admin/team/grant', {
            email: plain.email,
            role: 'SUPPORT',
            reason: 'x',
            totpCode: '000000',
          })
        ).status,
      ).toBe(403);
      expect((await get(moderator, '/admin/tables/users?format=csv')).status).toBe(403);
      const noCsrf = await ctx.http
        .post('/api/v1/admin/agency-evaluation')
        .set('Cookie', owner.cookie)
        .send(reason);
      expect(noCsrf.status).toBe(403);
      expect(noCsrf.body.error.code).toBe('ADMIN_CSRF_INVALID');
      // A bearer token of the app opens nothing.
      expect(
        (await ctx.http.get('/api/v1/admin/stats/overview').set('Authorization', `Bearer ${owner.token}`))
          .status,
      ).toBe(401);
    });
  });

  describe('statistics', () => {
    it('KPIs, the series and the attention list are exact aggregates of seeded rows on the Asia/Riyadh day', async () => {
      const now = new Date(clock);
      const since = dayStart(now, ZONE);
      const yesterday = new Date(since.getTime() - 3_600_000);
      // One account created «yesterday» (Riyadh).
      await ctx.prisma.user.update({ where: { id: agentUser.id }, data: { createdAt: yesterday } });
      // A recharge agent with two sales (today 1000, yesterday 700) and a website card order today (5000).
      const appId = randomUUID();
      await ctx.prisma.rechargeAgentApplication.create({
        data: { id: appId, userId: agentUser.id, status: 'APPROVED', decidedAt: now, purgedAt: now },
      });
      await ctx.prisma.rechargeAgent.create({
        data: {
          userId: agentUser.id,
          applicationId: appId,
          status: 'ACTIVE',
          code: 'coin9001',
          codeNumber: 9001,
          countries: ['SA'],
          locations: [],
          paymentTypes: [],
          activatedAt: now,
        },
      });
      await ctx.prisma.rechargeSale.createMany({
        data: [
          {
            agentUserId: agentUser.id,
            sellerUserId: agentUser.id,
            buyerUserId: plain.id,
            clientId: randomUUID(),
            coins: 1000n,
            createdAt: now,
          },
          {
            agentUserId: agentUser.id,
            sellerUserId: agentUser.id,
            buyerUserId: plain.id,
            clientId: randomUUID(),
            coins: 700n,
            createdAt: yesterday,
          },
        ],
      });
      await ctx.prisma.rechargeTopup.create({
        data: {
          agentUserId: agentUser.id,
          coins: 100_000n,
          tier: 'T1',
          pricePerMillionMinor: 1000,
          expectedMinor: 100n,
          paidMinor: 125n,
          currency: 'USD',
          first: true,
          createdAt: now,
        },
      });
      const terms = randomUUID();
      await ctx.prisma.topupTermsAcceptance.create({
        data: {
          id: terms,
          userId: plain.id,
          termsVersion: 't1',
          termsText: 'x',
          locale: 'ar',
          acceptedAt: now,
        },
      });
      const orderId = randomUUID();
      await ctx.prisma.topupOrder.create({
        data: {
          id: orderId,
          userId: plain.id,
          termsAcceptanceId: terms,
          packageId: '5000',
          coins: 5000n,
          amountMinor: 6250,
          currency: 'USD',
          paymentMethodTypes: ['card'],
          status: 'PAID',
          stripePaymentIntentId: 'pi_test_d197',
          creditedAt: now,
          createdAt: now,
        },
      });
      await ctx.prisma.topupCase.create({
        data: {
          id: randomUUID(),
          orderId,
          userId: plain.id,
          kind: 'EARLY_FRAUD_WARNING',
          stripeObjectId: 'issfr_d197',
          coinsReversed: 0n,
          attribution: {},
        },
      });
      // A gift sent today worth 300 coins, and a live on air.
      await ctx.prisma.gift.create({
        data: {
          code: 'd197_rose',
          category: 'POPULAR',
          nameAr: 'وردة',
          nameEn: 'Rose',
          priceCoins: 100,
          assetKey: 'gifts/rose',
        },
      });
      await ctx.prisma.liveGift.create({
        data: {
          senderId: plain.id,
          clientId: randomUUID(),
          giftCode: 'd197_rose',
          quantity: 3,
          source: 'COINS',
          unitPrice: 100,
          totalCoins: 300n,
          coinsCharged: 300n,
          recipientsKey: agentUser.id,
          comboId: randomUUID(),
          comboCount: 1,
          comboQuantity: 3n,
          hostShareBps: 5000,
          createdAt: now,
        },
      });
      await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: plain.id,
          title: 'D197 live',
          lastHeartbeatAt: now,
          startedAt: now,
          viewerCount: 7,
        },
      });

      const res = await get(owner, '/admin/stats/overview');
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getAdminStatsOverview');
      const k = res.body.kpis;
      const usersToday = await ctx.prisma.user.count({ where: { createdAt: { gte: since } } });
      expect(k.newUsers.today).toBe(usersToday);
      expect(k.newUsers.yesterday).toBe(1);
      expect(k.coinsSold.today).toBe(6000);
      expect(k.coinsSold.agentsToday).toBe(1000);
      expect(k.coinsSold.websiteToday).toBe(5000);
      expect(k.coinsSold.yesterday).toBe(700);
      expect(k.giftCoins.today).toBe(300);
      expect(k.giftCoins.giftsToday).toBe(1);
      expect(k.lives.value).toBe(1);
      expect(k.lives.today).toBe(1);
      expect(k.coinsSold.spark).toHaveLength(14);
      expect(k.coinsSold.spark.slice(-2)).toEqual([700, 6000]);
      expect(res.body.timeZone).toBe(ZONE);
      expect(res.body.since).toBe(since.toISOString());

      const series = await get(owner, '/admin/stats/series?days=7');
      expect(series.status).toBe(200);
      expectContract(series, 'getAdminStatsSeries');
      expect(series.body.days).toHaveLength(7);
      const last = series.body.days[6];
      expect(last.coinsSold).toBe(6000);
      expect(last.giftCoins).toBe(300);
      expect(series.body.days[5].agentCoins).toBe(700);
      expect((await get(owner, '/admin/stats/series?days=90')).body.days).toHaveLength(90);
      expect((await get(owner, '/admin/stats/series?days=12')).status).toBe(400);

      const att = await get(finance, '/admin/stats/attention');
      expectContract(att, 'getAdminStatsAttention');
      const kinds = att.body.items.map((i: { kind: string }) => i.kind);
      expect(kinds).toEqual(expect.arrayContaining(['WITHDRAWALS', 'AGENCY_COMPLAINTS', 'TOPUP_CASES']));
      expect(kinds).not.toContain('REPORTS');
      expect(att.body.items.find((i: { kind: string }) => i.kind === 'TOPUP_CASES').count).toBe(1);
      const modAtt = await get(moderator, '/admin/stats/attention');
      expect(modAtt.body.items.map((i: { kind: string }) => i.kind)).toEqual(['REPORTS']);
    });

    it('quick search finds users, agents by code and agencies', async () => {
      const res = await get(owner, `/admin/search?q=coin900`);
      expect(res.status).toBe(200);
      expectContract(res, 'searchAdminEverything');
      expect(res.body.agents.map((a: { code: string }) => a.code)).toEqual(['coin9001']);
      const byName = await get(moderator, `/admin/search?q=${plain.username}`);
      expect(byName.body.users[0].id).toBe(plain.id);
      // A moderator does not see agents (no recharge.agents).
      expect((await get(moderator, `/admin/search?q=coin900`)).body.agents).toEqual([]);
    });
  });

  describe('users', () => {
    it('the users table pages, sorts and filters; the CSV export is audited', async () => {
      const res = await get(owner, '/admin/tables/users?pageSize=2&page=1&sort=createdAt&order=asc');
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listAdminUsersTable');
      expect(res.body.data).toHaveLength(2);
      expect(res.body.total).toBeGreaterThanOrEqual(6);
      expect(res.body.data[0].id).toBe(agentUser.id); // created «yesterday»: the oldest
      const admins = await get(owner, '/admin/tables/users?role=ADMIN');
      expect(admins.body.total).toBe(4);
      const q = await get(owner, `/admin/tables/users?q=${plain.username}`);
      expect(q.body.data.map((u: { id: string }) => u.id)).toEqual([plain.id]);
      expect((await get(owner, '/admin/tables/users?sort=password')).status).toBe(400);
      const csv = await get(support, '/admin/tables/users?format=csv&role=ADMIN');
      expect(csv.status).toBe(200);
      expect(csv.headers['content-type']).toMatch(/text\/csv/);
      expect(csv.headers['content-disposition']).toMatch(/attachment; filename="kabso-users-/);
      expect(csv.text.split('\r\n')[0]).toBe(
        'id,username,display_name,email,status,role,country,created_at,last_active_at',
      );
      expect(csv.text.split('\r\n').filter(Boolean)).toHaveLength(5);
      const meta = await expectPanelAudit('admin.export.csv', 'users', support);
      expect(meta).toMatchObject({ table: 'users', count: 4, filters: { role: 'ADMIN' } });
    });

    it('a user page: ledger pages, posts, audit tab, sessions signed out with a reason (audited)', async () => {
      await ctx.prisma.walletLedgerEntry
        .createMany({
          data: [1, 2, 3].map((i) => ({
            userId: plain.id,
            delta: BigInt(i * 10),
            balanceAfter: BigInt(i * 10),
            reason: 'ADMIN_GRANT' as const,
            referenceId: `d197-${i}`,
          })),
        })
        .catch(() => undefined);
      const ledger = await get(finance, `/admin/users/${plain.id}/ledger?kind=coins&pageSize=2`);
      expect(ledger.status, JSON.stringify(ledger.body)).toBe(200);
      expectContract(ledger, 'listAdminUserLedger');
      const posts = await get(moderator, `/admin/users/${plain.id}/posts`);
      expectContract(posts, 'listAdminUserPosts');
      const sessions = await get(moderator, `/admin/users/${plain.id}/sessions`);
      expect(sessions.status).toBe(200);
      expectContract(sessions, 'listAdminUserSessions');
      expect(sessions.body.data.length).toBeGreaterThan(0);
      expect((await post(moderator, `/admin/users/${plain.id}/sessions/revoke`, {})).status).toBe(400);
      // A panel admin's sessions: OWNER only; one's own: refused.
      expect(
        (await post(moderator, `/admin/users/${support.id}/sessions/revoke`, { reason: 'x' })).status,
      ).toBe(403);
      expect((await post(owner, `/admin/users/${owner.id}/sessions/revoke`, { reason: 'x' })).status).toBe(
        409,
      );
      const revoke = await post(moderator, `/admin/users/${plain.id}/sessions/revoke`, {
        reason: 'stolen phone',
      });
      expect(revoke.status, JSON.stringify(revoke.body)).toBe(200);
      expectContract(revoke, 'revokeAdminUserSessions');
      expect(revoke.body.revoked).toBeGreaterThan(0);
      await expectPanelAudit('admin.user.sessions_revoke', plain.id, moderator, 'stolen phone');
      // The app's refresh fails now.
      expect((await get(moderator, `/admin/users/${plain.id}/sessions`)).body.data).toEqual([]);
      const audit = await get(owner, `/admin/users/${plain.id}/audit`);
      expectContract(audit, 'listAdminUserAudit');
      expect(audit.body.data.map((r: { action: string }) => r.action)).toContain(
        'admin.user.sessions_revoke',
      );
    });
  });

  describe('agencies', () => {
    let agencyId: string;
    let ownerOfAgency: Person;
    it('create (the economy-admin rule) → list → detail; suspend / reinstate audited with the reason', async () => {
      ownerOfAgency = await signup();
      await relogin(owner, moderator, support, finance);
      const bad = await post(support, '/admin/agencies', {
        ownerEmail: ownerOfAgency.email,
        ownerUserId: ownerOfAgency.id,
        reason: 'x',
      });
      expect(bad.status).toBe(400);
      const created = await post(support, '/admin/agencies', {
        ownerEmail: ownerOfAgency.email,
        reason: 'onboarding call',
      });
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      expectContract(created, 'createAdminAgency');
      agencyId = created.body.agencyId as string;
      expect(created.body.hostCode).toMatch(/^host[0-9]{2,}$/);
      const meta = await expectPanelAudit('agency.create', agencyId, support, 'onboarding call');
      expect(meta.owner).toBe(ownerOfAgency.id);
      // The same owner twice: the rule's refusal.
      const again = await post(support, '/admin/agencies', { ownerUserId: ownerOfAgency.id, reason: 'x' });
      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('ADMIN_ACTION_REFUSED');
      const list = await get(finance, '/admin/agencies?q=host');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminAgencies');
      expect(list.body.data.map((a: { id: string }) => a.id)).toContain(agencyId);
      const detail = await get(finance, `/admin/agencies/${agencyId}`);
      expectContract(detail, 'getAdminAgency');
      expect(detail.body.owner.id).toBe(ownerOfAgency.id);
      const sus = await post(owner, `/admin/agencies/${agencyId}/suspend`, { reason: 'fraud check' });
      expect(sus.status, JSON.stringify(sus.body)).toBe(200);
      const sm = await expectPanelAudit('host_agent.suspend', agencyId, owner, 'fraud check');
      expect(sm).toMatchObject({ before: 'ACTIVE', after: 'SUSPENDED' });
      expect((await post(owner, `/admin/agencies/${agencyId}/suspend`, { reason: 'x' })).status).toBe(409);
      const re = await post(owner, `/admin/agencies/${agencyId}/reinstate`, { reason: 'cleared' });
      expect(re.status).toBe(200);
      await expectPanelAudit('host_agent.reinstate', agencyId, owner, 'cleared');
      const csv = await get(owner, '/admin/agencies?format=csv');
      expect(csv.text.split('\r\n')[0]).toContain('invite_code');
    });

    it('a host complaint is resolved (release) and the rank evaluation runs, both audited', async () => {
      const host = await signup();
      const linkId = randomUUID();
      await ctx.prisma.agencyHost.create({
        data: { id: linkId, agencyId, hostUserId: host.id, commissionEligible: true },
      });
      const complaint = await ctx.prisma.agencyComplaint.create({
        data: { agencyHostId: linkId, hostUserId: host.id, agencyId, text: 'they took my cherries' },
      });
      const q = await get(support, '/admin/agency-complaints');
      expectContract(q, 'listAdminAgencyComplaints');
      expect(q.body.data[0].id).toBe(complaint.id);
      const move = await post(support, `/admin/agency-complaints/${complaint.id}/resolve`, {
        decision: 'move',
        note: 'x',
      });
      expect(move.status).toBe(400);
      const res = await post(support, `/admin/agency-complaints/${complaint.id}/resolve`, {
        decision: 'release',
        note: 'agreed',
      });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'resolveAdminAgencyComplaint');
      expect((await ctx.prisma.agencyHost.findUniqueOrThrow({ where: { id: linkId } })).status).toBe(
        'RELEASED',
      );
      await expectPanelAudit('agency.complaint.resolve', complaint.id, support, 'agreed');
      expect(
        (
          await post(support, `/admin/agency-complaints/${complaint.id}/resolve`, {
            decision: 'keep',
            note: 'x',
          })
        ).status,
      ).toBe(409);
      const ev = await post(owner, '/admin/agency-evaluation', { reason: 'month end' });
      expect(ev.status, JSON.stringify(ev.body)).toBe(200);
      expectContract(ev, 'runAdminAgencyEvaluation');
      await expectPanelAudit('agency.evaluate', '*', owner, 'month end');
    });

    it('the CLI still creates agencies through the same rule (via cli)', async () => {
      const p = await signup();
      const { stdout } = await cli('economy-admin.ts', ['agency-create', p.email]);
      expect(stdout).toMatch(/host code host[0-9]+/);
      const agency = await ctx.prisma.agency.findFirstOrThrow({ where: { ownerUserId: p.id } });
      const row = await lastAudit('agency.create', agency.id);
      expect((row.metadata as { via: string }).via).toBe('cli');
      expect(row.actorUserId).toBeNull();
    });
  });

  describe('lives', () => {
    it('lives now → details → END LIVE with a reason (audited, end reason ADMIN); hosting permissions', async () => {
      const host = await signup();
      const room = await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: host.id,
          title: 'Late show',
          lastHeartbeatAt: new Date(clock),
          startedAt: new Date(clock),
          viewerCount: 42,
        },
      });
      const list = await get(moderator, '/admin/lives');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminLives');
      expect(list.body.data[0].id).toBe(room.id); // most viewers first
      const detail = await get(support, `/admin/lives/${room.id}`);
      expectContract(detail, 'getAdminLive');
      expect(detail.body.viewers).toBe(42);
      expect((await post(moderator, `/admin/lives/${room.id}/end`, {})).status).toBe(400);
      await ctx.prisma.liveRoom.update({
        where: { id: room.id },
        data: { lastHeartbeatAt: new Date(clock) },
      });
      const end = await post(moderator, `/admin/lives/${room.id}/end`, { reason: 'nudity' });
      expect(end.status, JSON.stringify(end.body)).toBe(200);
      expectContract(end, 'endAdminLive');
      const after = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: room.id } });
      expect(after.status).toBe('ENDED');
      expect(after.endReason).toBe('ADMIN');
      const meta = await expectPanelAudit('admin.live.end', room.id, moderator, 'nudity');
      expect(meta).toMatchObject({ before: 'LIVE', after: 'ENDED', hostUserId: host.id });
      const twice = await post(moderator, `/admin/lives/${room.id}/end`, { reason: 'x' });
      expect(twice.status).toBe(409);

      const grant = await post(owner, '/admin/live-hosts/grant', {
        username: host.username,
        reason: 'partner',
      });
      expect(grant.status, JSON.stringify(grant.body)).toBe(200);
      expect(grant.body.changed).toBe(true);
      await expectPanelAudit('live.host.grant', host.id, owner, 'partner');
      const hosts = await get(support, '/admin/live-hosts');
      expectContract(hosts, 'listAdminLiveHosts');
      expect(hosts.body.data.map((h: { userId: string }) => h.userId)).toContain(host.id);
      const revoke = await post(owner, '/admin/live-hosts/revoke', {
        username: host.username,
        reason: 'ended contract',
      });
      expect(revoke.body.changed).toBe(true);
      await expectPanelAudit('live.host.revoke', host.id, owner, 'ended contract');
    });
  });

  describe('gifts and items', () => {
    it('gift CRUD through the gift-admin rule, each change audited with before/after and the reason', async () => {
      const body = {
        code: 'd197_star',
        category: 'LUCKY',
        nameAr: 'نجمة',
        nameEn: 'Star',
        priceCoins: 500,
        assetKey: 'gifts/star',
        badge: 'NEW',
        reason: 'autumn drop',
      };
      const created = await post(owner, '/admin/gifts', body);
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      expectContract(created, 'createAdminGift');
      await expectPanelAudit('gift.add', 'd197_star', owner, 'autumn drop');
      expect((await post(owner, '/admin/gifts', body)).status).toBe(409);
      expect((await post(owner, '/admin/gifts', { ...body, code: 'Bad Code' })).status).toBe(400);
      const tagOnly = await send('patch', owner, '/admin/gifts/d197_star', { tagCode: 'stars', reason: 'x' });
      expect(tagOnly.status).toBe(409); // a tag needs its names (the catalogue rule)
      const upd = await send('patch', owner, '/admin/gifts/d197_star', {
        priceCoins: 750,
        reason: 'price review',
      });
      expect(upd.status, JSON.stringify(upd.body)).toBe(200);
      expectContract(upd, 'updateAdminGift');
      expect(upd.body.changed).toEqual(['priceCoins']);
      const um = await expectPanelAudit('gift.update', 'd197_star', owner, 'price review');
      expect(um.changes).toEqual({ priceCoins: { from: 500, to: 750 } });
      const off = await post(owner, '/admin/gifts/d197_star/disable', { reason: 'pause' });
      expect(off.body).toEqual({ code: 'd197_star', enabled: false, changed: true });
      await expectPanelAudit('gift.disable', 'd197_star', owner, 'pause');
      expect((await post(owner, '/admin/gifts/d197_star/enable', { reason: 'back' })).body.changed).toBe(
        true,
      );
      const list = await get(finance, '/admin/gifts');
      expectContract(list, 'listAdminGifts');
      const star = list.body.data.find((g: { code: string }) => g.code === 'd197_star');
      expect(star).toMatchObject({ priceCoins: 750, lucky: true, enabled: true, badge: 'NEW' });
      expect(star.priceUsd).toBe('0.01');
      expect(
        (await send('patch', owner, '/admin/gifts/nope_gift', { priceCoins: 1, reason: 'x' })).status,
      ).toBe(404);
    });

    it('a frame is given and taken back through the bag-admin rule; active-host frames are refused', async () => {
      await ctx.prisma.bagItem.createMany({
        data: [
          {
            code: 'd197_frame',
            category: 'AVATAR_FRAME',
            nameAr: 'إطار',
            nameEn: 'Frame',
            assetKey: 'frames/x',
            sortOrder: 1,
          },
          {
            code: 'host_frame_blue',
            category: 'AVATAR_FRAME',
            nameAr: 'مضيف',
            nameEn: 'Host',
            assetKey: 'frames/h',
            sortOrder: 2,
          },
        ],
        skipDuplicates: true,
      });
      const items = await get(support, '/admin/bag-items');
      expectContract(items, 'listAdminBagItems');
      expect(items.body.data.find((i: { code: string }) => i.code === 'host_frame_blue').automatic).toBe(
        true,
      );
      const g = await post(support, `/admin/users/${plain.id}/bag/grant`, {
        code: 'd197_frame',
        days: 7,
        reason: 'contest prize',
      });
      expect(g.status, JSON.stringify(g.body)).toBe(200);
      expectContract(g, 'grantAdminUserBagItem');
      expect(g.body.outcome).toBe('added');
      await expectPanelAudit('bag.grant', plain.id, support, 'contest prize');
      expect(
        (
          await post(support, `/admin/users/${plain.id}/bag/grant`, {
            code: 'host_frame_blue',
            days: null,
            reason: 'x',
          })
        ).status,
      ).toBe(409);
      expect(
        (
          await post(support, `/admin/users/${support.id}/bag/grant`, {
            code: 'd197_frame',
            days: null,
            reason: 'x',
          })
        ).status,
      ).toBe(409);
      const bag = await get(support, `/admin/users/${plain.id}/bag`);
      expectContract(bag, 'getAdminUserBag');
      expect(bag.body.data.map((b: { code: string }) => b.code)).toContain('d197_frame');
      const r = await post(support, `/admin/users/${plain.id}/bag/revoke`, {
        code: 'd197_frame',
        reason: 'mistake',
      });
      expect(r.status).toBe(200);
      await expectPanelAudit('bag.revoke', plain.id, support, 'mistake');
      expect(
        (await post(support, `/admin/users/${plain.id}/bag/revoke`, { code: 'd197_frame', reason: 'x' }))
          .status,
      ).toBe(409);
    });

    it('events: create, end, hold, release through the event-admin rule (audited)', async () => {
      const start = new Date(clock - 3_600_000).toISOString();
      const ev = await post(owner, '/admin/events', {
        titleAr: 'تحدي',
        titleEn: 'Challenge',
        startsAt: start,
        permanent: true,
        metric: 'GIFT_COINS_RECEIVED',
        prizes: '1:5000,2:3000',
        reason: 'weekly',
      });
      expect(ev.status, JSON.stringify(ev.body)).toBe(201);
      expectContract(ev, 'createAdminEvent');
      await expectPanelAudit('event.create', ev.body.id, owner, 'weekly');
      expect(
        (
          await post(owner, '/admin/events', {
            titleAr: 'x',
            titleEn: 'x',
            startsAt: start,
            metric: 'GIFT_COINS_RECEIVED',
            reason: 'x',
          })
        ).status,
      ).toBe(409);
      const end = await post(owner, `/admin/events/${ev.body.id}/end`, { reason: 'early stop' });
      expect(end.body.changed).toBe(true);
      await expectPanelAudit('event.end', ev.body.id, owner, 'early stop');
      expect((await post(owner, `/admin/events/${ev.body.id}/hold`, { reason: 'review' })).status).toBe(200);
      expect((await post(owner, `/admin/events/${ev.body.id}/release`, { reason: 'ok' })).status).toBe(200);
      expect((await post(owner, `/admin/events/${ev.body.id}/explode`, { reason: 'x' })).status).toBe(404);
      const list = await get(support, '/admin/events');
      expectContract(list, 'listAdminEvents');
      expect((await get(support, '/admin/banners')).status).toBe(200);
    });
  });

  describe('money', () => {
    it("card orders, cases and the agents' top-ups; the team refund needs the code; closing a case is audited", async () => {
      await relogin(owner, moderator, support, finance);
      const orders = await get(finance, '/admin/finance/card-orders?status=PAID');
      expect(orders.status).toBe(200);
      expectContract(orders, 'listAdminCardOrders');
      const order = orders.body.data[0];
      expect(order.refundable).toBe(true);
      const missing = await post(finance, `/admin/finance/card-orders/${order.id}/refund`, {
        reason: 'goodwill',
      });
      expect(missing.status).toBe(400);
      const wrong = await post(finance, `/admin/finance/card-orders/${order.id}/refund`, {
        reason: 'goodwill',
        totpCode: '000000',
      });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
      // Right code, but Stripe is not configured here: 503, nothing recorded on the order.
      const off = await post(finance, `/admin/finance/card-orders/${order.id}/refund`, {
        reason: 'goodwill',
        totpCode: nextCode(finance.secret),
      });
      expect(off.status).toBe(503);
      expect(off.body.error.code).toBe('TOPUP_UNAVAILABLE');
      expect(
        (await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: order.id } })).teamRefundedMinor,
      ).toBe(0);
      const cases = await get(finance, '/admin/finance/cases?status=OPEN');
      expectContract(cases, 'listAdminTopupCases');
      const caseId = cases.body.data[0].id as string;
      const closed = await post(finance, `/admin/finance/cases/${caseId}/close`, { note: 'legit buyer' });
      expect(closed.status, JSON.stringify(closed.body)).toBe(200);
      const cm = await expectPanelAudit('topup.case.close', caseId, finance, 'legit buyer');
      expect(cm).toMatchObject({ before: 'OPEN', after: 'CLOSED' });
      const topups = await get(finance, '/admin/finance/recharge-topups');
      expectContract(topups, 'listAdminRechargeTopups');
      expect(topups.body.totals).toEqual({ coins: 100_000, paidMinor: 125, expectedMinor: 100 });
    });

    it('the financial report sums the seeded day exactly; its CSV is audited', async () => {
      const day = new Intl.DateTimeFormat('en-CA', { timeZone: ZONE }).format(new Date(clock));
      const res = await get(finance, `/admin/finance/report?granularity=day&from=${day}&to=${day}`);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getAdminFinanceReport');
      expect(res.body.rows).toHaveLength(1);
      expect(res.body.totals).toMatchObject({
        agentRevenueMinor: 125,
        agentExpectedMinor: 100,
        agentSalesCoins: 1000,
        cardCoins: 5000,
        cardRevenueMinor: 6250,
        hostPayoutsMinor: 0,
        estimatedMarginMinor: 6375,
      });
      const month = await get(
        finance,
        `/admin/finance/report?granularity=month&from=${day.slice(0, 8)}01&to=${day}`,
      );
      expect(month.body.rows).toHaveLength(1);
      expect(month.body.rows[0].period).toBe(day.slice(0, 7));
      expect((await get(finance, `/admin/finance/report?from=2020-01-01&to=2026-12-31`)).status).toBe(400);
      const csv = await get(finance, `/admin/finance/report?from=${day}&to=${day}&format=csv`);
      expect(csv.headers['content-type']).toMatch(/text\/csv/);
      expect(csv.text.split('\r\n')[0]).toContain('agent_revenue_minor');
      await expectPanelAudit('admin.export.csv', 'finance-report-day', finance);
      expect((await get(support, `/admin/finance/report?from=${day}&to=${day}`)).status).toBe(403);
    });
  });

  describe('audit and team', () => {
    it('the audit viewer filters by action prefix, actor and target; its CSV is audited', async () => {
      const res = await get(owner, `/admin/audit?action=gift.&actor=${owner.username}`);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listAdminAudit');
      expect(res.body.total).toBeGreaterThanOrEqual(4);
      expect(
        res.body.data.every(
          (r: { action: string; actor: { id: string } }) =>
            r.action.startsWith('gift.') && r.actor.id === owner.id,
        ),
      ).toBe(true);
      const upd = res.body.data.find((r: { action: string }) => r.action === 'gift.update');
      expect(upd.metadata.changes.priceCoins).toEqual({ from: 500, to: 750 });
      const target = await get(owner, `/admin/audit?targetType=user&targetId=${plain.id}`);
      expect(target.body.data.length).toBeGreaterThan(0);
      expect((await get(owner, '/admin/audit?actor=nobody_like_this')).body.total).toBe(0);
      const actions = await get(owner, '/admin/audit/actions');
      expectContract(actions, 'listAdminAuditActions');
      expect(actions.body.data).toContain('admin.export.csv');
      const csv = await get(owner, '/admin/audit?action=gift.&format=csv');
      expect(csv.status).toBe(200);
      await expectPanelAudit('admin.export.csv', 'audit', owner);
    });

    it("team: grant / revoke / reset-2fa need the code and a reason; never the last or one's own OWNER", async () => {
      const recruit = await signup();
      const noCode = await post(owner, '/admin/team/grant', {
        email: recruit.email,
        role: 'SUPPORT',
        reason: 'hired',
      });
      expect(noCode.status).toBe(400);
      const bad = await post(owner, '/admin/team/grant', {
        email: recruit.email,
        role: 'SUPPORT',
        reason: 'hired',
        totpCode: '000000',
      });
      expect(bad.status).toBe(403);
      const ok = await post(owner, '/admin/team/grant', {
        email: recruit.email,
        role: 'SUPPORT',
        reason: 'hired',
        totpCode: nextCode(owner.secret),
      });
      expect(ok.status, JSON.stringify(ok.body)).toBe(200);
      expectContract(ok, 'grantAdminTeamRole');
      expect(ok.body).toMatchObject({ userId: recruit.id, madeAdmin: true, already: false });
      await expectPanelAudit('admin.role.grant', recruit.id, owner, 'hired');
      const rows = await ctx.prisma.userAdminPermission.findMany({ where: { userId: recruit.id } });
      expect(rows.map((r) => r.permission)).toEqual(['SUPPORT']);
      expect(rows[0]!.grantedById).toBe(owner.id);
      const team = await get(owner, '/admin/team');
      expectContract(team, 'listAdminTeam');
      expect(team.body.data.find((m: { id: string }) => m.id === recruit.id).roles).toEqual(['SUPPORT']);
      // The CLI lists the same team.
      const { stdout } = await cli('admin-admin.ts', ['list']);
      expect(stdout).toContain(recruit.email);
      // Never one's own OWNER, never the last OWNER.
      const self = await post(owner, `/admin/team/${owner.id}/revoke`, {
        role: 'OWNER',
        reason: 'x',
        totpCode: nextCode(owner.secret),
      });
      expect(self.status).toBe(409);
      // Reset the moderator's authenticator: their sessions end.
      const reset = await post(owner, `/admin/team/${moderator.id}/reset-2fa`, {
        reason: 'lost phone',
        totpCode: nextCode(owner.secret),
      });
      expect(reset.status, JSON.stringify(reset.body)).toBe(200);
      await expectPanelAudit('admin.totp.reset', moderator.id, owner, 'lost phone');
      expect((await get(moderator, '/admin/auth/session')).status).toBe(401);
      expect(await ctx.prisma.adminCredential.count({ where: { userId: moderator.id } })).toBe(0);
      const revoke = await post(owner, `/admin/team/${recruit.id}/revoke`, {
        role: 'SUPPORT',
        reason: 'left',
        totpCode: nextCode(owner.secret),
      });
      expect(revoke.status, JSON.stringify(revoke.body)).toBe(200);
      expectContract(revoke, 'revokeAdminTeamRole');
      expect(revoke.body.left).toEqual([]);
      await expectPanelAudit('admin.role.revoke', recruit.id, owner, 'left');
      expect(await ctx.prisma.userAdminPermission.count({ where: { userId: recruit.id } })).toBe(0);
      // The runtime role still cannot write the roles table itself, nor grant a non-panel permission.
      await expect(
        ctx.prisma.userAdminPermission.create({ data: { userId: recruit.id, permission: 'OWNER' } }),
      ).rejects.toThrow();
      await expect(
        ctx.prisma.$queryRaw`SELECT kabso_admin_panel_role(${recruit.id}::uuid, 'LEVELS_EDIT', true, NULL)`,
      ).rejects.toThrow();
    });
  });

  describe('programs, special usernames, waitlist', () => {
    it('tasks and levels with USD; special usernames; the waitlist read is audited like the CLI', async () => {
      await ctx.prisma.taskDefinition.create({
        data: {
          code: 'D197_GIFT',
          period: 'DAILY',
          metric: 'GIFT_COINS_SENT',
          target: 1_000_000,
          rewardCherries: 1_000_000,
          nameAr: 'أرسل',
          nameEn: 'Send',
        },
      });
      const tasks = await get(support, '/admin/programs/tasks');
      expect(tasks.status, JSON.stringify(tasks.body)).toBe(200);
      expectContract(tasks, 'listAdminTasks');
      const t = tasks.body.data.find((x: { code: string }) => x.code === 'D197_GIFT');
      expect(t.targetUsd).toBe('$12.50');
      expect(t.rewardUsd).toMatch(/^\$/);
      const levels = await get(finance, '/admin/programs/levels');
      expectContract(levels, 'listAdminPanelLevels');
      const su = await get(support, '/admin/special-usernames?q=coin');
      expectContract(su, 'listAdminSpecialUsernames');
      await ctx.http.post('/api/v1/waitlist').send({ email: 'fan-d197@example.test', locale: 'ar' });
      const wl = await get(owner, '/admin/waitlist');
      expect(wl.status, JSON.stringify(wl.body)).toBe(200);
      expectContract(wl, 'listAdminWaitlist');
      expect(wl.body.counts.total).toBe(1);
      const wm = await expectPanelAudit('waitlist.view', undefined, owner);
      expect(wm).toMatchObject({ op: 'list', count: 1 });
      const csv = await get(owner, '/admin/waitlist?format=csv');
      expect(csv.text).toBe(
        'email,locale,created_at\r\nfan-d197@example.test,ar,' + wl.body.data[0].createdAt + '\r\n',
      );
      const reads = await ctx.prisma.auditLog.findMany({
        where: { action: 'waitlist.view', actorUserId: owner.id },
      });
      expect(reads.map((r) => (r.metadata as { op: string }).op)).toContain('export');
    });

    it("recent panel activity: the OWNER sees the team's, others their own", async () => {
      const mine = await get(support, '/admin/stats/activity');
      expectContract(mine, 'getAdminStatsActivity');
      expect(mine.body.data.length).toBeGreaterThan(0);
      expect(mine.body.data.every((r: { actor: { id: string } }) => r.actor.id === support.id)).toBe(true);
      const all = await get(owner, '/admin/stats/activity');
      const actors = new Set(all.body.data.map((r: { actor: { id: string } }) => r.actor.id));
      expect(actors.size).toBeGreaterThan(1);
    });
  });
});
