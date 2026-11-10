/**
 * D293 (owner, contract v1.90-social, CONVENTIONS §10.105): automatic verification badges «شارة التوثيق», end to end
 * against PostgreSQL + Redis:
 *
 *  - each of the five badges granted (STAFF, RECHARGE_AGENT, HOST_AGENT, CREATOR, VERIFIED_HOST); D357 (owner
 *    2026-11-10: «ازيلها»): the app owner (OWNER) gets NO badge — not OWNER, not a lower one he also holds — and a
 *    stored OWNER row is removed at his next recompute (and by the D357 migration at deploy);
 *  - at once on a panel role, a creator approval and an identity-check approval (no sweep);
 *  - one badge per person, the highest by the owner's priority when several apply;
 *  - "more than": exactly 300 000 000 does not qualify, 300 000 001 does (coins sold, cherries bought, agency
 *    cherries); 30 active hosts do not, 31 do; hosts who left, reversed earnings, cancelled orders and declined
 *    cherry offers do not count; the agent's employees' work counts on the agent's account;
 *  - the rolling window drops old activity and the badge goes; a badge goes when its condition stops (a revoked role,
 *    a suspended agent, a banned account);
 *  - the OWNER's thresholds in the panel: view and edit permissions, the code again, the audit, the recompute;
 *  - the public responses carry only the badge type, never an amount; the panel's user page shows the badge;
 *  - the CLI's first-run backfill `verification-admin recompute`.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { approveCreatorApplicationIn } from '../src/modules/creator/creator-applications.js';
import {
  approveHostApplicationIn,
  rejectHostApplicationIn,
} from '../src/modules/host-applications/host-applications.core.js';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { KycService } from '../src/modules/kyc/kyc.service.js';
import { recomputeAllBadges } from '../src/modules/verification/verification-badges.js';
import { VerificationService } from '../src/modules/verification/verification.service.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const DAY = 86_400_000;
const M300 = 300_000_000n;

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

/** Runs `pnpm verification:admin …` as on the server (migration role, a child process). */
function verificationAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'verification:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('D293 contract coverage', () => {
  it('openapi v1.90-social declares the panel operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAdminVerificationSettings GET /api/v1/admin/verification-badges/settings',
        'updateAdminVerificationSettings PUT /api/v1/admin/verification-badges/settings',
      ]),
    );
  });
});

describe('D293 verification badges', { timeout: 600_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: TestUser;
  let seq = 0;
  const next = () => ++seq;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  /** Plain accounts without a profile (buyers, hosts): fast, enough for the counts. */
  const bulkUsers = async (n: number): Promise<string[]> => {
    const ids = Array.from({ length: n }, () => randomUUID());
    await ctx.prisma.user.createMany({
      data: ids.map((id) => ({ id, email: `${id}@bulk.test`, passwordHash: 'x' })),
    });
    return ids;
  };
  const ago = (days: number) => new Date(Date.now() - days * DAY);
  const badgeOf = async (userId: string) =>
    (await ctx.prisma.userVerificationBadge.findUnique({ where: { userId } }))?.badge ?? null;
  const sweep = (at: Date = new Date()) => recomputeAllBadges(ctx.prisma, 'sweep', at);
  const publicBadge = async (u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body.verification as string | null;
  };
  const meBadge = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body.verification as string | null;
  };
  const audits = async (userId: string) =>
    (
      await ctx.prisma.auditLog.findMany({
        where: { action: 'verification.badge.change', targetId: userId },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      })
    ).map(
      (a) => a.metadata as { before: string | null; after: string | null; change: string; cause: string },
    );

  // ---- recharge agents ---------------------------------------------------------------------------------------------
  const makeAgent = async (userId?: string): Promise<string> => {
    const id = userId ?? (await bulkUsers(1))[0]!;
    const n = 1000 + next();
    const appId = randomUUID();
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id: appId,
        userId: id,
        status: 'APPROVED',
        fullName: 'محمد أحمد علي حسن',
        phone: '+201001234567',
        photoKey: `private/recharge-agents/${appId}/photo.webp`,
        selfieKey: `private/recharge-agents/${appId}/selfie.webp`,
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'x' }],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: id,
        applicationId: appId,
        status: 'ACTIVE',
        code: `coin${String(n)}`,
        codeNumber: n,
        activatedAt: new Date(),
        countries: ['EG'],
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentTypes: { EG: ['MOBILE_WALLET'] },
      },
    });
    return id;
  };
  const sale = async (agent: string, coins: bigint, daysAgo = 1, seller = agent) => {
    const [buyer] = await bulkUsers(1);
    await ctx.prisma.rechargeSale.create({
      data: {
        agentUserId: agent,
        sellerUserId: seller,
        buyerUserId: buyer!,
        clientId: randomUUID(),
        coins,
        createdAt: ago(daysAgo),
      },
    });
  };
  const order = async (
    agent: string,
    coins: bigint,
    status: 'COMPLETED' | 'CANCELLED' | 'COMPLETED_BY_ADMIN' = 'COMPLETED',
    daysAgo = 1,
    claimedBy: string | null = null,
  ) => {
    const [buyer] = await bulkUsers(1);
    const at = ago(daysAgo);
    await ctx.prisma.rechargeOrder.create({
      data: {
        buyerUserId: buyer!,
        agentUserId: agent,
        clientId: randomUUID(),
        country: 'EG',
        coins,
        usdMinor: 0n,
        paymentType: 'MOBILE_WALLET',
        status,
        detailsAt: status === 'CANCELLED' ? null : at,
        paidAt: status === 'CANCELLED' ? null : at,
        disputedAt: status === 'COMPLETED_BY_ADMIN' ? at : null,
        closedAt: at,
        claimedBy,
        claimedAt: claimedBy ? at : null,
        createdAt: at,
      },
    });
  };
  const cherryBuy = async (
    agent: string,
    cherries: bigint,
    status: 'CONFIRMED' | 'DECLINED' = 'CONFIRMED',
    daysAgo = 1,
    actedBy: string | null = null,
  ) => {
    const [host] = await bulkUsers(1);
    await ctx.prisma.rechargeCherryRequest.create({
      data: {
        agentUserId: agent,
        hostUserId: host!,
        createdBy: actedBy ?? agent,
        actedBy,
        decidedBy: actedBy ?? host!,
        clientId: randomUUID(),
        cherries,
        coins: 0n,
        payoutMinor: 0n,
        currency: 'USD',
        status,
        expiresAt: ago(daysAgo - 1),
        decidedAt: ago(daysAgo),
        createdAt: ago(daysAgo),
      },
    });
  };
  const employeeOf = async (agent: string): Promise<string> => {
    const [e] = await bulkUsers(1);
    await ctx.prisma.rechargeEmployee.create({
      data: { agentUserId: agent, employeeUserId: e!, timeZone: 'UTC', schedule: [] },
    });
    return e!;
  };

  // ---- host agencies -----------------------------------------------------------------------------------------------
  const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const inviteCode = () =>
    Array.from({ length: 8 }, () => ALPHABET[Math.floor(Math.random() * ALPHABET.length)]).join('');
  const makeAgency = async (ownerId: string, active: number, left = 0) => {
    const n = 10 + next();
    const agency = await ctx.prisma.agency.create({
      data: {
        ownerUserId: ownerId,
        inviteCode: inviteCode(),
        evaluateFrom: new Date('2099-01-01T00:00:00Z'),
        hostCode: `host${String(n)}`,
        hostCodeNumber: n,
        hostCodeAt: new Date(),
      },
    });
    const links: { id: string; hostUserId: string }[] = [];
    const addHosts = async (count: number, status: 'ACTIVE' | 'LEFT') => {
      const hosts = await bulkUsers(count);
      const rows = hosts.map((hostUserId) => ({
        id: randomUUID(),
        agencyId: agency.id,
        hostUserId,
        status,
        commissionEligible: true,
        endedAt: status === 'ACTIVE' ? null : new Date(),
      }));
      await ctx.prisma.agencyHost.createMany({ data: rows });
      if (status === 'ACTIVE') links.push(...rows.map((r) => ({ id: r.id, hostUserId: r.hostUserId })));
      return rows;
    };
    await addHosts(active, 'ACTIVE');
    if (left > 0) await addHosts(left, 'LEFT');
    const earn = async (cherries: bigint, daysAgo = 1, reversed = false) => {
      const at = ago(daysAgo);
      const link = links[0]!;
      await ctx.prisma.agencyEarning.create({
        data: {
          giftId: randomUUID(),
          agencyId: agency.id,
          agencyHostId: link.id,
          hostUserId: link.hostUserId,
          hostCherries: cherries,
          rateBps: 0,
          commission: 0n,
          parentRateBps: 0,
          parentCommission: 0n,
          month: new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), 1)),
          createdAt: at,
          reversedAt: reversed ? new Date() : null,
        },
      });
    };
    return { id: agency.id, links, addHosts, earn };
  };

  // ---- creators and identity checks --------------------------------------------------------------------------------
  const approveCreator = async (userId: string) => {
    const app = await ctx.prisma.creatorApplication.create({
      data: { userId, country: 'EG', category: 'VIDEO', links: ['https://example.com/me'] },
    });
    await ctx.prisma.$transaction((tx) =>
      approveCreatorApplicationIn(tx, app.id, new Date(), { via: 'cli', actorUserId: null }),
    );
  };
  const kycCheck = (userId: string, status: 'APPROVED' | 'IN_PROGRESS') =>
    ctx.prisma.kycCheck.create({
      data: {
        userId,
        purpose: 'HOST_APPLICATION',
        status,
        sessionId: randomUUID(),
        workflowId: randomUUID(),
        providerStatus: status === 'APPROVED' ? 'Approved' : 'In Progress',
        dateOfBirth: new Date('1990-01-01T00:00:00Z'),
        decidedAt: status === 'APPROVED' ? new Date() : null,
      },
    });
  const grant = (email: string, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, email, role as never)));
  const revoke = (email: string, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, email, role as never)));

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      LIVE_HEARTBEAT_STALE_SECONDS: '3600',
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
    });
    owner = await p.makeAdmin(['OWNER']);
    viewer = await signup();
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the settings start with the owner defaults; the window is 30 days', async () => {
    const res = await p.send(owner, 'get', '/admin/verification-badges/settings');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getAdminVerificationSettings');
    const owner300 = {
      rechargeMinSalesCoins: 300_000_000,
      rechargeMinCherries: 300_000_000,
      hostAgentMinHosts: 30,
      hostAgentMinCherries: 300_000_000,
    };
    expect(res.body.settings).toEqual(owner300);
    expect(res.body.defaults).toEqual(owner300);
    expect(res.body.windowDays).toBe(30);
  });

  it('STAFF is granted at once with the role and removed with it; the OWNER gets no badge (D293, D357)', async () => {
    // D357: the OWNER's grant (makeAdmin) gives no badge — not in /me, not on his public profile, nothing stored.
    const ownerUser = {
      ...owner,
      username: (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: owner.id } })).username,
    };
    expect(await meBadge(ownerUser)).toBeNull();
    expect(await publicBadge(ownerUser)).toBeNull();
    expect(await badgeOf(owner.id)).toBeNull();
    expect(await audits(owner.id)).toEqual([]);

    // Every Kabso Team role is STAFF (red).
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE', 'BD']) {
      const u = await signup();
      expect(await meBadge(u)).toBeNull();
      await grant(u.email, role);
      expect(await meBadge(u), role).toBe('STAFF');
      expect(await publicBadge(u), role).toBe('STAFF');
      if (role === 'SUPPORT') {
        // Revoked → gone at once (audited, cause role).
        await revoke(u.email, role);
        expect(await meBadge(u)).toBeNull();
        expect(await badgeOf(u.id)).toBeNull();
        expect((await audits(u.id)).map((a) => `${a.change}:${a.cause}`)).toEqual([
          'granted:role',
          'removed:role',
        ]);
      }
    }

    // OWNER + STAFF on one account: D357 — no badge at all while OWNER is held (the STAFF seal goes, audited).
    const both = await signup();
    await grant(both.email, 'SUPPORT');
    expect(await meBadge(both)).toBe('STAFF');
    await grant(both.email, 'OWNER');
    expect(await meBadge(both)).toBeNull();
    expect(await publicBadge(both)).toBeNull();
    expect((await audits(both.id)).at(-1)).toEqual({
      before: 'STAFF',
      after: null,
      change: 'removed',
      cause: 'role',
    });
    // The OWNER role taken back: STAFF again at once.
    await revoke(both.email, 'OWNER');
    expect(await meBadge(both)).toBe('STAFF');
  });

  it('RECHARGE_AGENT: more than 300 000 000 coins sold AND cherries bought, employees on the agent (D293)', async () => {
    // A: sales exactly 300 000 000 (200 M direct + 100 M completed order), cherries 300 000 001 → not yet.
    const aUser = await signup();
    const a = await makeAgent(aUser.id);
    await sale(a, 200_000_000n, 3);
    await order(a, 100_000_000n, 'COMPLETED', 2);
    await cherryBuy(a, M300 + 1n, 'CONFIRMED', 2);
    await sweep();
    expect(await badgeOf(a)).toBeNull();
    expect(await publicBadge(aUser)).toBeNull();
    // One coin more, sold by the agent's employee (D287: on the agent's account) → gold.
    const employee = await employeeOf(a);
    await sale(a, 1n, 1, employee);
    await sweep();
    expect(await badgeOf(a)).toBe('RECHARGE_AGENT');
    expect(await publicBadge(aUser)).toBe('RECHARGE_AGENT');
    expect(await meBadge(aUser)).toBe('RECHARGE_AGENT');

    // B: sales 300 000 001 (an employee-owned completed order), cherries exactly 300 000 000 → not yet; one more
    // cherry bought by an employee for the agent → gold.
    const b = await makeAgent();
    const bEmployee = await employeeOf(b);
    await order(b, M300 + 1n, 'COMPLETED', 5, bEmployee);
    await cherryBuy(b, M300, 'CONFIRMED', 4);
    await sweep();
    expect(await badgeOf(b)).toBeNull();
    await cherryBuy(b, 1n, 'CONFIRMED', 1, bEmployee);
    await sweep();
    expect(await badgeOf(b)).toBe('RECHARGE_AGENT');

    // C: what does not count — a cancelled order, a declined offer, activity older than 30 days.
    const c = await makeAgent();
    await order(c, 900_000_000n, 'CANCELLED', 1);
    await sale(c, 900_000_000n, 31);
    await sale(c, 200_000_000n, 1);
    await cherryBuy(c, 900_000_000n, 'DECLINED', 1);
    await cherryBuy(c, 900_000_000n, 'CONFIRMED', 31);
    await cherryBuy(c, 200_000_000n, 'CONFIRMED', 1);
    await sweep();
    expect(await badgeOf(c)).toBeNull();
    // A COMPLETED_BY_ADMIN order counts as sold (the buyer was credited from the agent's frozen coins).
    await order(c, 100_000_001n, 'COMPLETED_BY_ADMIN', 1);
    await cherryBuy(c, 100_000_001n, 'CONFIRMED', 1);
    await sweep();
    expect(await badgeOf(c)).toBe('RECHARGE_AGENT');

    // The rolling window: A's activity is 1–3 days old; 28 days later (30 days after the oldest sale) the 200 M sale
    // and the order are out → removed (audited, cause sweep).
    await sweep(new Date(Date.now() + 28 * DAY));
    expect(await badgeOf(a)).toBeNull();
    expect((await audits(a)).at(-1)).toMatchObject({
      before: 'RECHARGE_AGENT',
      after: null,
      change: 'removed',
    });
    // Back to now: granted again.
    await sweep();
    expect(await badgeOf(a)).toBe('RECHARGE_AGENT');

    // A suspended agent loses it.
    await ctx.prisma.rechargeAgent.update({
      where: { userId: b },
      data: { status: 'SUSPENDED', suspendedAt: new Date(), suspendReason: 'test' },
    });
    await sweep();
    expect(await badgeOf(b)).toBeNull();
  });

  it('HOST_AGENT: more than 30 active hosts AND 300 000 000 cherries received in 30 days (D293)', async () => {
    // X: 31 active hosts, exactly 300 000 000 → not yet; one cherry more → green.
    const xUser = await signup();
    const x = await makeAgency(xUser.id, 31);
    await x.earn(200_000_000n, 10);
    await x.earn(100_000_000n, 2);
    await sweep();
    expect(await badgeOf(xUser.id)).toBeNull();
    await x.earn(1n, 1);
    await sweep();
    expect(await badgeOf(xUser.id)).toBe('HOST_AGENT');
    expect(await publicBadge(xUser)).toBe('HOST_AGENT');

    // Y: 30 active + 1 who left, plenty of cherries → not yet (30 is not more than 30); a 31st active host → green.
    const y = await makeAgency((await bulkUsers(1))[0]!, 30, 1);
    const yOwner = (await ctx.prisma.agency.findUniqueOrThrow({ where: { id: y.id } })).ownerUserId;
    await y.earn(400_000_000n, 3);
    await sweep();
    expect(await badgeOf(yOwner)).toBeNull();
    await y.addHosts(1, 'ACTIVE');
    await sweep();
    expect(await badgeOf(yOwner)).toBe('HOST_AGENT');
    // A host whose account is banned is not an active host: back to 30 → removed.
    await ctx.prisma.user.update({ where: { id: y.links[0]!.hostUserId }, data: { status: 'SUSPENDED' } });
    await sweep();
    expect(await badgeOf(yOwner)).toBeNull();

    // Z: reversed earnings and earnings older than 30 days do not count.
    const zOwner = (await bulkUsers(1))[0]!;
    const z = await makeAgency(zOwner, 35);
    await z.earn(250_000_000n, 1);
    await z.earn(100_000_000n, 1, true);
    await z.earn(900_000_000n, 31);
    await sweep();
    expect(await badgeOf(zOwner)).toBeNull();
    await z.earn(50_000_001n, 1);
    await sweep();
    expect(await badgeOf(zOwner)).toBe('HOST_AGENT');
    // The window moves on: 2 days later the 1-day-old cherries are still in, 30 days later they are out.
    await sweep(new Date(Date.now() + 2 * DAY));
    expect(await badgeOf(zOwner)).toBe('HOST_AGENT');
    await sweep(new Date(Date.now() + 30 * DAY));
    expect(await badgeOf(zOwner)).toBeNull();
    await sweep();
    // A suspended agency loses it.
    await ctx.prisma.agency.update({
      where: { id: z.id },
      data: { suspendedAt: new Date(), suspendReason: 'test' },
    });
    await sweep();
    expect(await badgeOf(zOwner)).toBeNull();
  });

  it('CREATOR at once on approval; VERIFIED_HOST at once on the identity check; a host is required (D293)', async () => {
    const creator = await signup();
    await approveCreator(creator.id);
    expect(await meBadge(creator)).toBe('CREATOR');
    expect(await publicBadge(creator)).toBe('CREATOR');
    expect(await audits(creator.id)).toEqual([
      { before: null, after: 'CREATOR', change: 'granted', cause: 'creator' },
    ]);

    // A direct host (live_hosts) whose Didit check becomes APPROVED → blue at once.
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'IDENTITY' } });
    const check = await kycCheck(host.id, 'IN_PROGRESS');
    expect(await meBadge(host)).toBeNull();
    expect(await ctx.app.get(KycService).apply(check.sessionId, 'Approved', null, new Date(), 'sync')).toBe(
      'applied',
    );
    expect(await meBadge(host)).toBe('VERIFIED_HOST');
    expect(await publicBadge(host)).toBe('VERIFIED_HOST');
    expect((await audits(host.id)).at(-1)).toMatchObject({ after: 'VERIFIED_HOST', cause: 'kyc' });
    // The check declined afterwards (Didit's later decision) → gone at once.
    expect(
      await ctx.app
        .get(KycService)
        .apply(check.sessionId, 'Declined', null, new Date(Date.now() + 1000), 'sync'),
    ).toBe('applied');
    expect(await meBadge(host)).toBeNull();

    // An agency host (no live_hosts row) with an approved check → blue at the sweep.
    const member = await signup();
    const agency = await makeAgency((await bulkUsers(1))[0]!, 0);
    await ctx.prisma.agencyHost.create({
      data: { agencyId: agency.id, hostUserId: member.id, status: 'ACTIVE', commissionEligible: true },
    });
    await kycCheck(member.id, 'APPROVED');
    await sweep();
    expect(await badgeOf(member.id)).toBe('VERIFIED_HOST');

    // An approved check without being a host → nothing; a check not approved → nothing.
    const notHost = await signup();
    await kycCheck(notHost.id, 'APPROVED');
    const unapproved = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: unapproved.id, source: 'ADMIN' } });
    await kycCheck(unapproved.id, 'IN_PROGRESS');
    await sweep();
    expect(await badgeOf(notHost.id)).toBeNull();
    expect(await badgeOf(unapproved.id)).toBeNull();

    // A banned account loses its badge at the next recompute.
    await ctx.prisma.user.update({ where: { id: member.id }, data: { status: 'SUSPENDED' } });
    await sweep();
    expect(await badgeOf(member.id)).toBeNull();
  });

  it("VERIFIED_HOST also from the team's manual ID + selfie review (owner «نعم»); pending / rejected do not count (D293)", async () => {
    const application = (userId: string) =>
      ctx.prisma.hostApplication.create({
        data: {
          userId,
          clientKey: randomUUID(),
          requestHash: 'a'.repeat(64),
          displayName: 'Host',
          country: 'EG',
          contactType: 'WHATSAPP',
          contactValue: '+201001234567',
          photoKey: `private/host-applications/${userId}/photo.webp`,
          selfieKey: `private/host-applications/${userId}/selfie.webp`,
          rulesAcceptedAt: new Date(),
        },
      });
    // Approved by the team (Didit off: the pictures are the check) → host + blue at once, no sweep.
    const approved = await signup();
    const app = await application(approved.id);
    await ctx.prisma.$transaction((tx) =>
      approveHostApplicationIn(tx, app.id, new Date(), { via: 'cli', actorUserId: null }),
    );
    expect(await meBadge(approved)).toBe('VERIFIED_HOST');
    expect((await audits(approved.id)).at(-1)).toMatchObject({ after: 'VERIFIED_HOST', cause: 'host' });
    // Pending (with a hosting permission from elsewhere) → nothing; rejected → nothing.
    const pending = await signup();
    await application(pending.id);
    await ctx.prisma.liveHost.create({ data: { userId: pending.id, source: 'ADMIN' } });
    const rejected = await signup();
    const rejectedApp = await application(rejected.id);
    await ctx.prisma.$transaction((tx) =>
      rejectHostApplicationIn(tx, rejectedApp.id, 'no', new Date(), { via: 'cli', actorUserId: null }),
    );
    await ctx.prisma.liveHost.create({ data: { userId: rejected.id, source: 'ADMIN' } });
    await sweep();
    expect(await badgeOf(pending.id)).toBeNull();
    expect(await badgeOf(rejected.id)).toBeNull();
    // The hosting permission revoked by the team → no longer a host → gone at once.
    const revoked = await p.send(owner, 'post', '/admin/live-hosts/revoke', {
      username: approved.username,
      reason: 'D293 test',
    });
    expect(revoked.status, JSON.stringify(revoked.body)).toBe(200);
    expect(await badgeOf(approved.id)).toBeNull();
  });

  it('one badge per person: the highest by the owner priority (D293)', async () => {
    // STAFF + VERIFIED_HOST → STAFF.
    const staffHost = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: staffHost.id, source: 'ADMIN' } });
    await kycCheck(staffHost.id, 'APPROVED');
    await sweep();
    expect(await badgeOf(staffHost.id)).toBe('VERIFIED_HOST');
    await grant(staffHost.email, 'MODERATION');
    expect(await badgeOf(staffHost.id)).toBe('STAFF');

    // OWNER + CREATOR → none (D357: the app owner shows no seal at all).
    const ownerCreator = await signup();
    await approveCreator(ownerCreator.id);
    expect(await badgeOf(ownerCreator.id)).toBe('CREATOR');
    await grant(ownerCreator.email, 'OWNER');
    expect(await badgeOf(ownerCreator.id)).toBeNull();

    // A stored OWNER row from before D357 (an older server wrote it) is removed at the next sweep and never sent.
    await ctx.prisma.userVerificationBadge.create({
      data: { userId: ownerCreator.id, badge: 'OWNER', since: new Date(), computedAt: new Date() },
    });
    await sweep();
    expect(await badgeOf(ownerCreator.id)).toBeNull();

    // RECHARGE_AGENT + CREATOR → RECHARGE_AGENT; when the sales stop → CREATOR (the next one). Since D295 a creator
    // cannot also be a host (the trigger refuses another hosting source) and the membership's own permission (source
    // CREATOR) is not a host's: the approved check gives no VERIFIED_HOST.
    const multi = await signup();
    await approveCreator(multi.id);
    expect(await ctx.prisma.liveHost.findUnique({ where: { userId: multi.id } })).toMatchObject({
      source: 'CREATOR',
    });
    await kycCheck(multi.id, 'APPROVED');
    await makeAgent(multi.id);
    await sale(multi.id, M300 + 1n, 1);
    await cherryBuy(multi.id, M300 + 1n, 'CONFIRMED', 1);
    await sweep();
    expect(await badgeOf(multi.id)).toBe('RECHARGE_AGENT');
    await sweep(new Date(Date.now() + 31 * DAY));
    expect(await badgeOf(multi.id)).toBe('CREATOR');
    expect((await audits(multi.id)).at(-1)).toMatchObject({
      before: 'RECHARGE_AGENT',
      after: 'CREATOR',
      change: 'changed',
      cause: 'sweep',
    });
    await sweep();

    // HOST_AGENT + VERIFIED_HOST → HOST_AGENT.
    const agent = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: agent.id, source: 'ADMIN' } });
    await kycCheck(agent.id, 'APPROVED');
    const ag = await makeAgency(agent.id, 31);
    await ag.earn(M300 + 1n, 1);
    await sweep();
    expect(await badgeOf(agent.id)).toBe('HOST_AGENT');
    expect(await publicBadge(agent)).toBe('HOST_AGENT');
  });

  it('the panel: view and edit permissions, the code again, audited, everyone recomputed; public-safe (D293)', async () => {
    const moderator = await p.makeAdmin(['MODERATION']);
    const support = await p.makeAdmin(['SUPPORT']);
    const finance = await p.makeAdmin(['FINANCE']);
    const bd = await p.makeAdmin(['BD']);
    for (const a of [moderator, support, finance]) {
      expect((await p.send(a, 'get', '/admin/verification-badges/settings')).status).toBe(200);
    }
    expect((await p.send(bd, 'get', '/admin/verification-badges/settings')).status).toBe(403);
    const change = (a: Admin, fields: object) =>
      p.send(a, 'put', '/admin/verification-badges/settings', {
        ...fields,
        reason: 'owner D293',
        totpCode: p.nextCode(a.secret),
      });
    expect((await change(support, { hostAgentMinHosts: 5 })).status).toBe(403);
    expect((await change(moderator, { hostAgentMinHosts: 5 })).status).toBe(403);

    const nothing = await change(owner, {});
    expect(nothing.status).toBe(400);
    expectContract(nothing, 'updateAdminVerificationSettings');
    expect(nothing.body.error.details).toEqual([{ field: 'rechargeMinSalesCoins', issue: 'required' }]);
    expect((await change(owner, { hostAgentMinHosts: -1 })).status).toBe(400);
    expect((await change(owner, { rechargeMinCherries: 1.5 })).status).toBe(400);
    expect((await change(owner, { rechargeMinCherries: 10 ** 16 })).status).toBe(400);
    const badCode = await p.send(owner, 'put', '/admin/verification-badges/settings', {
      hostAgentMinHosts: 5,
      reason: 'x',
      totpCode: '000000',
    });
    expect(badCode.status).not.toBe(200);
    expect(
      (await ctx.prisma.verificationBadgeSettings.findUniqueOrThrow({ where: { id: 1 } })).hostAgentMinHosts,
    ).toBe(30);

    // An agency with 10 hosts and 50 M: no badge with the owner's values; the OWNER lowers both → granted at once.
    const small = await signup();
    const ag = await makeAgency(small.id, 10);
    await ag.earn(50_000_000n, 1);
    await sweep();
    expect(await badgeOf(small.id)).toBeNull();
    const ok = await change(owner, { hostAgentMinHosts: 9, hostAgentMinCherries: 49_999_999 });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'updateAdminVerificationSettings');
    expect(ok.body.settings).toMatchObject({ hostAgentMinHosts: 9, hostAgentMinCherries: 49_999_999 });
    expect(ok.body.defaults.hostAgentMinHosts).toBe(30);
    expect(ok.body.holders.HOST_AGENT).toBeGreaterThanOrEqual(1);
    expect(ok.body.lastRunAt).not.toBeNull();
    expect(await badgeOf(small.id)).toBe('HOST_AGENT');
    expect((await audits(small.id)).at(-1)).toMatchObject({ after: 'HOST_AGENT', cause: 'settings' });
    const row = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'verification.settings.update' },
      orderBy: { createdAt: 'desc' },
    });
    expect(row.actorUserId).toBe(owner.id);
    expect(row.metadata).toMatchObject({
      before: { hostAgentMinHosts: 30, hostAgentMinCherries: 300_000_000 },
      after: { hostAgentMinHosts: 9, hostAgentMinCherries: 49_999_999 },
      reason: 'owner D293',
      via: 'panel',
    });

    // Public-safe: only the badge type, never the amounts or the thresholds.
    const res = await ctx.http.get(`/api/v1/users/${small.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expect(res.body.verification).toBe('HOST_AGENT');
    const text = JSON.stringify(res.body);
    for (const leak of ['50000000', '49999999', 'hostAgentMin', 'rechargeMin', 'computedAt', 'since']) {
      expect(text, leak).not.toContain(leak);
    }
    // The panel's user page shows the badge with its times.
    const detail = await p.send(moderator, 'get', `/admin/users/${small.id}`);
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminUser');
    expect(detail.body.verification).toMatchObject({ badge: 'HOST_AGENT' });
    expect(typeof detail.body.verification.computedAt).toBe('string');
    const plain = await p.send(moderator, 'get', `/admin/users/${viewer.id}`);
    expect(plain.body.verification).toBeNull();

    // Back to the owner's values: the badge goes again.
    const back = await change(owner, { hostAgentMinHosts: 30, hostAgentMinCherries: 300_000_000 });
    expect(back.status).toBe(200);
    expect(await badgeOf(small.id)).toBeNull();
  });

  it('the badge beside the name everywhere: lists, search, posts, comments, chat, DMs, live cards (D293)', async () => {
    // A creator (purple, at once) who goes live: since D295 the membership itself gives the hosting permission
    // (source CREATOR; another source is refused for a creator).
    const star = await signup();
    await approveCreator(star.id);
    expect(await ctx.prisma.liveHost.findUnique({ where: { userId: star.id } })).toMatchObject({
      source: 'CREATOR',
    });
    const plain = await signup();
    const leak = (body: unknown) => {
      const text = JSON.stringify(body);
      for (const k of ['computedAt', 'since', 'rechargeMin', 'hostAgentMin'])
        expect(text, k).not.toContain(k);
    };
    // Follow lists (UserSummary).
    for (const u of [star, plain]) {
      expect((await ctx.http.put(`/api/v1/users/${viewer.username}/follow`).set(auth(u))).status).toBe(200);
    }
    const followers = await ctx.http.get(`/api/v1/users/${viewer.username}/followers`).set(auth(viewer));
    expect(followers.status).toBe(200);
    expectContract(followers, 'listUserFollowers');
    const row = (list: { id: string; verification?: string }[], id: string) => list.find((u) => u.id === id)!;
    expect(row(followers.body.data, star.id).verification).toBe('CREATOR');
    expect(row(followers.body.data, plain.id)).not.toHaveProperty('verification');
    leak(followers.body);
    // Search.
    const found = await ctx.http.get(`/api/v1/search?type=users&q=${star.username}`).set(auth(viewer));
    expect(found.status, JSON.stringify(found.body)).toBe(200);
    expectContract(found, 'search');
    expect(row(found.body.data, star.id).verification).toBe('CREATOR');
    // A post's author and a comment's author.
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(star))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'D293' });
    expect(post.status, JSON.stringify(post.body)).toBe(201);
    expectContract(post, 'createPost');
    expect(post.body.author.verification).toBe('CREATOR');
    const comment = await ctx.http
      .post(`/api/v1/posts/${post.body.id as string}/comments`)
      .set(auth(star))
      .send({ text: 'hi' });
    expect(comment.status, JSON.stringify(comment.body)).toBe(201);
    expect(comment.body.author.verification).toBe('CREATOR');
    const comments = await ctx.http.get(`/api/v1/posts/${post.body.id as string}/comments`).set(auth(viewer));
    expect(comments.status).toBe(200);
    expectContract(comments, 'listComments');
    expect(comments.body.data[0].author.verification).toBe('CREATOR');
    // A live: the room card's host, and a chat line's author.
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(star)).send({ title: 'D293' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    const card = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(card.status).toBe(200);
    expect(card.body.host.verification).toBe('CREATOR');
    const line = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(star))
      .send({ text: 'مرحبا', clientId: randomUUID() });
    expect(line.status, JSON.stringify(line.body)).toBe(201);
    expectContract(line, 'sendLiveChatMessage');
    expect(line.body.author.verification).toBe('CREATOR');
    const chat = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(viewer));
    expect(chat.status).toBe(200);
    expectContract(chat, 'listLiveChatMessages');
    expect(
      (chat.body.data as { author: { id: string; verification?: string } }[]).find(
        (m) => m.author.id === star.id,
      )!.author.verification,
    ).toBe('CREATOR');
    leak(chat.body);
    // DMs: the conversation list's peer.
    const dm = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(viewer))
      .send({ to: star.username, clientId: randomUUID(), kind: 'TEXT', text: 'hello' });
    expect(dm.status, JSON.stringify(dm.body)).toBe(201);
    const inbox = await ctx.http.get('/api/v1/dm/conversations').set(auth(viewer));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listDmConversations');
    const conv = (inbox.body.data as { peer: { id: string; verification?: string } }[]).find(
      (c) => c.peer.id === star.id,
    )!;
    expect(conv.peer.verification).toBe('CREATOR');
    leak(inbox.body);
    // A banned account loses it everywhere at the next recompute.
    await ctx.prisma.user.update({ where: { id: star.id }, data: { status: 'SUSPENDED' } });
    await sweep();
    expect(await badgeOf(star.id)).toBeNull();
  });

  it('the sweeper service and the CLI backfill recompute everyone (D293)', async () => {
    // A badge written by nobody yet (rows made behind the API's back): the sweeper picks it up.
    const late = await signup();
    await ctx.prisma.creatorApplication.create({
      data: {
        userId: late.id,
        country: 'EG',
        category: 'MUSIC',
        links: ['https://example.com/x'],
        status: 'APPROVED',
        decidedAt: new Date(),
      },
    });
    const app = await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: late.id } });
    await ctx.prisma.creatorMember.create({
      data: { userId: late.id, applicationId: app.id, activatedAt: new Date() },
    });
    expect(await badgeOf(late.id)).toBeNull();
    const result = await ctx.app.get(VerificationService).sweep();
    expect(result.granted).toBeGreaterThanOrEqual(1);
    expect(await badgeOf(late.id)).toBe('CREATOR');

    // The CLI (migration role): idempotent — run twice, the second changes nothing.
    const late2 = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: late2.id, source: 'ADMIN' } });
    await kycCheck(late2.id, 'APPROVED');
    const first = verificationAdmin('recompute');
    expect(first.status, first.out).toBe(0);
    expect(first.out).toMatch(/1 granted, 0 changed, 0 removed, \d+ kept\./);
    const second = verificationAdmin('recompute');
    expect(second.out).toMatch(/0 granted, 0 changed, 0 removed, \d+ kept\./);
    expect(verificationAdmin('nope').status).not.toBe(0);
    expect(await badgeOf(late2.id)).toBe('VERIFIED_HOST');
    expect(await ctx.prisma.auditLog.count({ where: { action: 'verification.recompute' } })).toBe(2);
    expect((await audits(late2.id)).at(-1)).toMatchObject({ after: 'VERIFIED_HOST', cause: 'backfill' });
  });
});
