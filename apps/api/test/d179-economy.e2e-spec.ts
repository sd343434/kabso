/**
 * D179 (owner 2026-10-30, Kabso economy phase 1; contract v1.52-social, CONVENTIONS §10.43): the cherry
 * ledger credited in each gift send's transaction (normal, lucky, quips, direct-conversation gifts),
 * host agencies (join by code, the 14-day leave window, complaints resolved by the admin), commissions
 * paid on top of the host's share (15 %, 16 % in the month after a 1.5 billion month, the parent's 3 %),
 * the monthly rank evaluation (5 active hosts, the 200 million exception, agency admins), the reversal
 * mirror and withdrawal requests paid by hand — end to end against PostgreSQL + Redis, with the
 * `economy-admin` CLI as on the server.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { AgencyService } from '../src/modules/economy/agency.service.js';
import { addMonths, monthKey } from '../src/modules/economy/economy-math.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time moved by an offset. */
class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
  }
  advance(ms: number): void {
    this.offset += ms;
  }
  reset(): void {
    this.offset = 0;
  }
}

/** Runs `pnpm economy:admin …` as on the server (migration role, a child process). */
function economyAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'economy:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: { ...process.env, LIVE_RANKINGS_TIME_ZONE: 'UTC' },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

const DAY_MS = 86_400_000;

/** The parts of `MyAgency` the tests read (null checks are assertions). */
interface MyAgencyBody {
  membership: { canLeave: boolean; agency: { inviteCode: string } };
  ownAgency: {
    inviteCode: string;
    commissionRateBps: number;
    parent: { inviteCode: string };
    progress: { monthHostCherries: number };
    commission: Record<string, number>;
    parentCommission: Record<string, number>;
    subAgencies: unknown[];
  };
}

describe('D179 contract coverage', () => {
  it('openapi v1.52-social declares the cherry and agency operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyCherries GET /api/v1/wallet/me/cherries',
        'listMyCherryLedger GET /api/v1/wallet/me/cherries/ledger',
        'requestCherryWithdrawal POST /api/v1/wallet/me/cherries/withdrawals',
        'listMyCherryWithdrawals GET /api/v1/wallet/me/cherries/withdrawals',
        'getAgencyByCode GET /api/v1/agencies/{inviteCode}',
        'getMyAgency GET /api/v1/me/agency',
        'joinAgency POST /api/v1/me/agency/join',
        'leaveAgency POST /api/v1/me/agency/leave',
        'complainAboutAgency POST /api/v1/me/agency/complaints',
        'listMyAgencyHosts GET /api/v1/me/agency/hosts',
      ]),
    );
  });
});

describe('D179 cherry economy', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new FakeClock();
  let ctx: TestContext;
  const month = () => monthKey(clock.now(), 'UTC');

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = (code: string, fields: Partial<GiftFields>) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 100,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Economy' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  const enter = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const followed = new Set<string>();
  const liveGift = async (
    roomId: string,
    from: TestUser,
    to: TestUser,
    giftCode: string,
    clientId = randomUUID(),
  ) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity: 1, recipients: [to.username], source: 'COINS', clientId });
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    const row = await ctx.prisma.liveGift.findFirst({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return { res, id: row!.id };
  };
  const dmGift = async (from: TestUser, to: TestUser, giftCode = 'eco_rose') => {
    // The recipient follows the sender: a conversation, not a message request (3 messages at most).
    if (!followed.has(`${to.id}>${from.id}`)) {
      const f = await ctx.http.put(`/api/v1/users/${from.username}/follow`).set(auth(to));
      expect(f.status).toBe(200);
      followed.add(`${to.id}>${from.id}`);
    }
    const clientId = randomUUID();
    const res = await ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(from))
      .send({ to: to.username, giftCode, quantity: 1, source: 'COINS', clientId });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const row = await ctx.prisma.liveGift.findFirst({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return row!.id;
  };
  const cherries = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyCherries');
    return res.body as {
      cherries: number;
      heldCherries: number;
      earnedTotal: number;
      commissionTotal: number;
      valueMinor: number;
      pendingWithdrawal: { id: string; status: string } | null;
      payout: { minAmountMinor: number; rateCherries: number; rateMinor: number };
    };
  };
  const balance = async (u: TestUser) =>
    Number((await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n);
  const ledgerOf = (u: TestUser, referenceId: string) =>
    ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: u.id, referenceId },
      orderBy: { reason: 'asc' },
    });
  const myAgency = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/agency').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyAgency');
    return res.body as MyAgencyBody;
  };
  const createAgency = (owner: TestUser, parent?: string): string => {
    const r = economyAdmin('agency-create', owner.email, ...(parent ? ['--parent', parent] : []));
    expect(r.status, r.out).toBe(0);
    return /invite code ([A-Z0-9]{8})/.exec(r.out)![1]!;
  };
  const join = (u: TestUser, inviteCode: string) =>
    ctx.http.post('/api/v1/me/agency/join').set(auth(u)).send({ inviteCode });
  const setRank = (code: string, rank: 'NEW' | 'AGENT' | 'ADMIN' | 'LAPSED') =>
    ctx.prisma.agency.update({ where: { inviteCode: code }, data: { rank } });

  let viewer: TestUser;
  let agent: TestUser;
  let parent: TestUser;
  let host: TestUser;
  let agencyCode = '';
  let parentCode = '';
  let reversible = '';

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        LUCKY_GIFTS_ENABLED: 'true',
        // Small payout units so a test balance reaches the $10 minimum: 1 000 cherries = $1.10.
        CHERRY_PAYOUT_RATE: '1000:110',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: clock },
      ],
    );
    await gift('eco_rose', {});
    await gift('eco_big', { priceCoins: 1000 });
    await gift('eco_lucky', { category: 'LUCKY', nameEn: 'Lucky' });
    await gift('eco_quip', {
      category: 'QUIPS',
      nameEn: 'Quip',
      soundKey: 'room/clap',
      soundMs: 500,
      quipText: null,
    });
    viewer = await signup();
    await coins(viewer, 1_000_000);
    const confirm = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(viewer))
      .send({ adult: true });
    expect(confirm.status).toBe(200);
    [agent, parent, host] = [await signup(), await signup(), await signup()];
  });
  afterAll(async () => ctx?.close());

  it('credits the recipient instantly: coins × share × 10 for each gift kind, idempotent with the send', async () => {
    const h = await signup();
    const room = await startLive(h);
    await enter(room, viewer);
    const normal = await liveGift(room, viewer, h, 'eco_rose');
    expect(await balance(h)).toBe(650); // 100 coins × 65 % × 10
    // A retry of the same send (same clientId) → 200, nothing credited twice.
    const clientId = randomUUID();
    await liveGift(room, viewer, h, 'eco_rose', clientId);
    const again = await liveGift(room, viewer, h, 'eco_rose', clientId);
    expect(again.res.status).toBe(200);
    expect(await balance(h)).toBe(1300);
    await liveGift(room, viewer, h, 'eco_lucky');
    expect(await balance(h)).toBe(1400); // lucky 10 % → 100
    await liveGift(room, viewer, h, 'eco_quip');
    expect(await balance(h)).toBe(1900); // quips 50 % → 500
    await dmGift(viewer, h, 'eco_rose');
    expect(await balance(h)).toBe(2400); // a direct-conversation gift: 50 % → 500
    await dmGift(viewer, h, 'eco_lucky');
    expect(await balance(h)).toBe(2500); // a lucky gift in a conversation: 10 % → 100

    const w = await cherries(h);
    expect(w).toMatchObject({ cherries: 2500, heldCherries: 0, earnedTotal: 2500, commissionTotal: 0 });
    expect(w.valueMinor).toBe(275); // 2 500 cherries at 1 000 = 110 → $2.75
    const ledger = await ctx.http
      .get('/api/v1/wallet/me/cherries/ledger?limit=10')
      .set(auth(h))
      .set('Accept-Language', 'en');
    expect(ledger.status).toBe(200);
    expectContract(ledger, 'listMyCherryLedger');
    expect(ledger.body.data).toHaveLength(6);
    expect(ledger.body.data.map((e: { delta: number }) => e.delta)).toEqual([100, 500, 500, 100, 650, 650]);
    const first = ledger.body.data[5];
    expect(first).toMatchObject({ reason: 'GIFT_RECEIVED', balanceAfter: 650 });
    expect(first.gift).toMatchObject({
      giftCode: 'eco_rose',
      giftName: 'Gift',
      giftCoins: 100,
      shareBps: 6500,
      context: 'LIVE',
    });
    expect(first.gift.sender.username).toBe(viewer.username);
    expect((await ledgerOf(h, normal.id)).map((r) => [r.reason, Number(r.delta)])).toEqual([
      ['GIFT_RECEIVED', 650],
    ]);
    // The sender earns nothing; the coin ledger is untouched by cherries.
    expect(await balance(viewer)).toBe(0);
  });

  it('agency invite codes: preview, join and accept, one agency at a time, owners never join', async () => {
    parentCode = createAgency(parent);
    agencyCode = createAgency(agent, parentCode);
    expect(agencyCode).not.toBe(parentCode);
    const unauth = await ctx.http.get(`/api/v1/agencies/${agencyCode}`);
    expect(unauth.status).toBe(401);
    const preview = await ctx.http.get(`/api/v1/agencies/${agencyCode.toLowerCase()}`).set(auth(host));
    expect(preview.status).toBe(200);
    expectContract(preview, 'getAgencyByCode');
    expect(preview.body).toMatchObject({ inviteCode: agencyCode, rank: 'NEW', hostCount: 0 });
    expect(preview.body.owner.username).toBe(agent.username);
    expect((await ctx.http.get('/api/v1/agencies/ZZZZ2222').set(auth(host))).status).toBe(404);

    const joined = await join(host, ` ${agencyCode.toLowerCase()} `);
    expect(joined.status, JSON.stringify(joined.body)).toBe(201);
    expectContract(joined, 'joinAgency');
    expect(joined.body.membership).toMatchObject({ canLeave: true, complaint: null });
    expect(joined.body.membership.agency.inviteCode).toBe(agencyCode);
    expect((await join(host, agencyCode)).status).toBe(200);
    const other = await join(host, parentCode);
    expect([other.status, other.body.error.code]).toEqual([409, 'AGENCY_ALREADY_MEMBER']);
    const owner = await join(agent, parentCode);
    expect([owner.status, owner.body.error.code]).toEqual([409, 'AGENCY_JOIN_NOT_ALLOWED']);
    expect((await join(agent, agencyCode)).body.error.code).toBe('AGENCY_JOIN_NOT_ALLOWED');
    expect((await join(host, 'nope')).status).toBe(404);
    expect((await ctx.http.post('/api/v1/me/agency/join').set(auth(host)).send({})).status).toBe(400);
    // Only the agent sees the hosts list.
    expect((await ctx.http.get('/api/v1/me/agency/hosts').set(auth(host))).status).toBe(404);
    const mine = await myAgency(agent);
    expect(mine.membership).toBeNull();
    expect(mine.ownAgency).toMatchObject({ inviteCode: agencyCode, rank: 'NEW', commissionRateBps: 1500 });
    expect(mine.ownAgency.parent.inviteCode).toBe(parentCode);
    expect(mine.ownAgency.progress).toMatchObject({
      hostCount: 1,
      requiredActiveHosts: 5,
      exceptionCherries: 200_000_000,
    });
    expect((await myAgency(parent)).ownAgency.subAgencies).toEqual([
      expect.objectContaining({ inviteCode: agencyCode, qualifies: false }),
    ]);
  });

  it('leaving: within 14 days of joining; after that only a complaint the admin resolves', async () => {
    const early = await signup();
    expect((await join(early, agencyCode)).status).toBe(201);
    const left = await ctx.http.post('/api/v1/me/agency/leave').set(auth(early));
    expect(left.status).toBe(200);
    expectContract(left, 'leaveAgency');
    expect(left.body.membership).toBeNull();
    expect((await ctx.http.post('/api/v1/me/agency/leave').set(auth(early))).status).toBe(404);

    const late = await signup();
    expect((await join(late, agencyCode)).status).toBe(201);
    clock.advance(14 * DAY_MS + 60_000);
    try {
      const closed = await ctx.http.post('/api/v1/me/agency/leave').set(auth(late));
      expect([closed.status, closed.body.error.code]).toEqual([409, 'AGENCY_LEAVE_WINDOW_CLOSED']);
      expect((await myAgency(late)).membership.canLeave).toBe(false);
      const empty = await ctx.http.post('/api/v1/me/agency/complaints').set(auth(late)).send({ text: '  ' });
      expect(empty.status).toBe(400);
      const complaint = await ctx.http
        .post('/api/v1/me/agency/complaints')
        .set(auth(late))
        .send({ text: 'The agent does not answer.' });
      expect(complaint.status).toBe(201);
      expectContract(complaint, 'complainAboutAgency');
      const twice = await ctx.http
        .post('/api/v1/me/agency/complaints')
        .set(auth(late))
        .send({ text: 'again' });
      expect([twice.status, twice.body.id]).toEqual([200, complaint.body.id]);
      expect(economyAdmin('complaints').out).toContain(complaint.body.id);
      // The admin moves the host to the parent's agency.
      const moved = economyAdmin(
        'complaint-resolve',
        complaint.body.id,
        'move',
        '--to',
        parentCode,
        '--note',
        'ok',
      );
      expect(moved.status, moved.out).toBe(0);
      expect(economyAdmin('complaint-resolve', complaint.body.id, 'release').status).toBe(1);
      expect((await myAgency(late)).membership.agency.inviteCode).toBe(parentCode);
      const links = await ctx.prisma.agencyHost.findMany({
        where: { hostUserId: late.id },
        orderBy: { activatedAt: 'asc' },
      });
      expect(links.map((l) => l.status)).toEqual(['MOVED', 'ACTIVE']);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'agency.complaint.resolve' } })).toBe(1);
    } finally {
      clock.reset();
    }
    // The move starts a new leave window (the CLI ran now): the host may leave the new agency.
    expect((await myAgency(late)).membership.canLeave).toBe(true);
    expect((await ctx.http.post('/api/v1/me/agency/leave').set(auth(late))).status).toBe(200);
  });

  it('commissions are credited with each gift on top of the host share: agency 15 %, parent 3 % (admin only)', async () => {
    await setRank(parentCode, 'AGENT');
    const g1 = await dmGift(viewer, host); // 500 cherries
    expect((await ledgerOf(host, g1)).map((r) => Number(r.delta))).toEqual([500]);
    expect((await ledgerOf(agent, g1)).map((r) => [r.reason, Number(r.delta)])).toEqual([
      ['AGENCY_COMMISSION', 75],
    ]);
    expect(await ledgerOf(parent, g1)).toEqual([]); // the parent is not an agency admin
    await setRank(parentCode, 'ADMIN');
    reversible = await dmGift(viewer, host);
    expect((await ledgerOf(agent, reversible)).map((r) => Number(r.delta))).toEqual([75]);
    expect((await ledgerOf(parent, reversible)).map((r) => [r.reason, Number(r.delta)])).toEqual([
      ['PARENT_COMMISSION', 15],
    ]);
    expect(await balance(host)).toBe(1000); // the host's own share is never reduced
    const mine = await myAgency(agent);
    expect(mine.ownAgency.commission).toMatchObject({ thisMonth: 150, total: 150 });
    expect(mine.ownAgency.progress.monthHostCherries).toBe(1000);
    expect((await myAgency(parent)).ownAgency.parentCommission).toMatchObject({ thisMonth: 15 });
    expect(await cherries(agent)).toMatchObject({ cherries: 150, commissionTotal: 150, earnedTotal: 0 });
    const hosts = await ctx.http.get('/api/v1/me/agency/hosts').set(auth(agent));
    expect(hosts.status).toBe(200);
    expectContract(hosts, 'listMyAgencyHosts');
    expect(hosts.body.data).toEqual([
      expect.objectContaining({ monthCherries: 1000, active: false, liveDays: 0, commissionEligible: true }),
    ]);
    expect(hosts.body.data[0].user.username).toBe(host.username);
  });

  it('16 % in the month after a month in which the hosts earned ≥ 1.5 billion cherries', async () => {
    const agency = await ctx.prisma.agency.findUniqueOrThrow({ where: { inviteCode: agencyCode } });
    const previous = addMonths(month(), -1);
    await ctx.prisma.agencyMonth.create({
      data: { agencyId: agency.id, month: new Date(`${previous}T00:00:00Z`), hostCherries: 1_499_999_999n },
    });
    expect((await ledgerOf(agent, await dmGift(viewer, host))).map((r) => Number(r.delta))).toEqual([75]);
    await ctx.prisma.agencyMonth.update({
      where: { agencyId_month: { agencyId: agency.id, month: new Date(`${previous}T00:00:00Z`) } },
      data: { hostCherries: 1_500_000_000n },
    });
    expect((await ledgerOf(agent, await dmGift(viewer, host))).map((r) => Number(r.delta))).toEqual([80]);
    expect((await myAgency(agent)).ownAgency.commissionRateBps).toBe(1600);
    // This month reaches the tier too → next month (the clock moved to it) pays 16 %, and the one after 15 %.
    await ctx.prisma.agencyMonth.update({
      where: { agencyId_month: { agencyId: agency.id, month: new Date(`${month()}T00:00:00Z`) } },
      data: { hostCherries: { increment: 1_500_000_000n } },
    });
    const now = clock.now();
    const nextStart = new Date(`${addMonths(month(), 1)}T00:00:00Z`).getTime();
    clock.advance(nextStart - now.getTime() + DAY_MS);
    try {
      expect((await ledgerOf(agent, await dmGift(viewer, host))).map((r) => Number(r.delta))).toEqual([80]);
      clock.advance(32 * DAY_MS);
      expect((await ledgerOf(agent, await dmGift(viewer, host))).map((r) => Number(r.delta))).toEqual([75]);
    } finally {
      clock.reset();
      await ctx.prisma.agencyMonth.delete({
        where: { agencyId_month: { agencyId: agency.id, month: new Date(`${previous}T00:00:00Z`) } },
      });
    }
  });

  it('a lapsed agency earns nothing on hosts who join while lapsed; hosts from before still pay', async () => {
    await setRank(agencyCode, 'LAPSED');
    const newcomer = await signup();
    expect((await join(newcomer, agencyCode)).status).toBe(201);
    const g = await dmGift(viewer, newcomer);
    expect(await ledgerOf(agent, g)).toEqual([]);
    expect((await ledgerOf(newcomer, g)).map((r) => Number(r.delta))).toEqual([500]);
    const row = await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { giftId: g } });
    expect(row).toMatchObject({ hostCherries: 500n, commission: 0n, rateBps: 0 });
    const old = await dmGift(viewer, host);
    expect((await ledgerOf(agent, old)).map((r) => Number(r.delta))).toEqual([75]);
    // Qualified again: the newcomer pays too.
    await setRank(agencyCode, 'AGENT');
    expect((await ledgerOf(agent, await dmGift(viewer, newcomer))).map((r) => Number(r.delta))).toEqual([75]);
  });

  it('a reversal mirrors the host cherries and both commissions, once', async () => {
    const agency = await ctx.prisma.agency.findUniqueOrThrow({ where: { inviteCode: agencyCode } });
    const before = await ctx.prisma.agencyMonth.findUniqueOrThrow({
      where: { agencyId_month: { agencyId: agency.id, month: new Date(`${month()}T00:00:00Z`) } },
    });
    const balances = [await balance(host), await balance(agent), await balance(parent)];
    const r = economyAdmin('reverse-gift', reversible, '--note', 'chargeback');
    expect(r.status, r.out).toBe(0);
    expect(r.out).toContain('3 credits reversed');
    expect((await ledgerOf(host, reversible)).map((e) => [e.reason, Number(e.delta)])).toEqual([
      ['GIFT_RECEIVED', 500],
      ['GIFT_REVERSAL', -500],
    ]);
    expect((await ledgerOf(agent, reversible)).map((e) => [e.reason, Number(e.delta)])).toEqual([
      ['AGENCY_COMMISSION', 75],
      ['AGENCY_COMMISSION_REVERSAL', -75],
    ]);
    expect((await ledgerOf(parent, reversible)).map((e) => [e.reason, Number(e.delta)])).toEqual([
      ['PARENT_COMMISSION', 15],
      ['PARENT_COMMISSION_REVERSAL', -15],
    ]);
    expect([await balance(host), await balance(agent), await balance(parent)]).toEqual([
      balances[0]! - 500,
      balances[1]! - 75,
      balances[2]! - 15,
    ]);
    const after = await ctx.prisma.agencyMonth.findUniqueOrThrow({
      where: { agencyId_month: { agencyId: agency.id, month: new Date(`${month()}T00:00:00Z`) } },
    });
    expect(before.hostCherries - after.hostCherries).toBe(500n);
    expect(before.commission - after.commission).toBe(75n);
    expect(
      (await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { giftId: reversible } })).reversedAt,
    ).not.toBeNull();
    const again = economyAdmin('reverse-gift', reversible);
    expect([again.status, again.out]).toEqual([0, expect.stringContaining('nothing to reverse')]);
    expect(await balance(host)).toBe(balances[0]! - 500);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'cherry.gift.reverse', targetId: reversible } }),
    ).toBe(1);
  });

  it('withdrawals: ≥ $10, cherries held, one pending, idempotent, paid or rejected (refund) by the admin', async () => {
    const h = await signup();
    await dmGift(viewer, h, 'eco_big'); // 1 000 coins × 50 % × 10 = 5 000
    await dmGift(viewer, h, 'eco_big'); // 10 000 cherries ≈ $11
    const body = { amountMinor: 1000, payoutDetails: 'Bank: IBAN SA00 0000' };
    const post = (key: string | null, b: unknown) => {
      const req = ctx.http.post('/api/v1/wallet/me/cherries/withdrawals').set(auth(h));
      return (key === null ? req : req.set('Idempotency-Key', key)).send(b as object);
    };
    expect((await post(null, body)).status).toBe(400);
    const small = await post(randomUUID(), { ...body, amountMinor: 999 });
    expect([small.status, small.body.error.details]).toEqual([
      400,
      [{ field: 'amountMinor', issue: 'too_small' }],
    ]);
    expect((await post(randomUUID(), { amountMinor: 1000 })).status).toBe(400);
    const big = await post(randomUUID(), { ...body, amountMinor: 1100 }); // 10 000 cherries + 1? ceil → 10 000
    expect(big.status).toBe(201);
    expect(big.body).toMatchObject({ status: 'PENDING', cherries: 10_000, amountMinor: 1100 });
    // Reject → the cherries come back.
    const rejectNoNote = economyAdmin('withdrawal-reject', big.body.id);
    expect(rejectNoNote.status).toBe(1);
    expect(economyAdmin('withdrawal-reject', big.body.id, '--note', 'wrong IBAN').status).toBe(0);
    expect(await balance(h)).toBe(10_000);

    const key = randomUUID();
    const [a, b] = await Promise.all([post(key, body), post(randomUUID(), body)]);
    expect([a.status, b.status].sort()).toEqual([201, 409]);
    const created = a.status === 201 ? a : b;
    expect(created.body).toMatchObject({
      status: 'PENDING',
      cherries: 9091,
      amountMinor: 1000,
      currency: 'USD',
    });
    expectContract(created, 'requestCherryWithdrawal');
    const retry = await post(key, body);
    if (a.status === 201) {
      expect([retry.status, retry.body.id]).toEqual([200, a.body.id]);
      expect((await post(key, { ...body, payoutDetails: 'other' })).body.error.code).toBe(
        'IDEMPOTENCY_CONFLICT',
      );
    }
    expect((await post(randomUUID(), body)).body.error.code).toBe('WITHDRAWAL_PENDING');
    const w = await cherries(h);
    expect(w).toMatchObject({ cherries: 909, heldCherries: 9091 });
    expect(w.pendingWithdrawal?.id).toBe(created.body.id);
    expect(economyAdmin('withdrawals').out).toContain(created.body.id);
    const paid = economyAdmin('withdrawal-pay', created.body.id, '--note', 'transfer 123');
    expect(paid.status, paid.out).toBe(0);
    expect(economyAdmin('withdrawal-pay', created.body.id).status).toBe(1);
    expect(economyAdmin('withdrawal-reject', created.body.id, '--note', 'x').status).toBe(1);
    expect(await cherries(h)).toMatchObject({ cherries: 909, heldCherries: 0, pendingWithdrawal: null });
    const list = await ctx.http.get('/api/v1/wallet/me/cherries/withdrawals').set(auth(h));
    expect(list.status).toBe(200);
    expectContract(list, 'listMyCherryWithdrawals');
    expect(list.body.data.map((x: { status: string }) => x.status)).toEqual(['PAID', 'REJECTED']);
    expect(list.body.data[0].decisionNote).toBe('transfer 123');
    const short = await post(randomUUID(), body);
    expect([short.status, short.body.error.code]).toEqual([409, 'INSUFFICIENT_CHERRIES']);
    expect(
      (
        await ctx.prisma.cherryLedgerEntry.findMany({
          where: { userId: h.id },
          orderBy: { createdAt: 'asc' },
        })
      ).map((e) => e.reason),
    ).toEqual(['GIFT_RECEIVED', 'GIFT_RECEIVED', 'WITHDRAWAL_HOLD', 'WITHDRAWAL_REFUND', 'WITHDRAWAL_HOLD']);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'cherry.withdrawal.pay', targetId: created.body.id },
      }),
    ).toBe(1);
    expect((await ctx.http.get('/api/v1/wallet/me/cherries')).status).toBe(401);
  });

  it('ranks: 5 active hosts or 200 million cherries; admins with 3 qualified subs; demoted only at a month start', async () => {
    // Fresh agencies made directly, evaluated from this month.
    const now = clock.now();
    const make = async (parentId: string | null) => {
      const owner = await signup();
      return ctx.prisma.agency.create({
        data: {
          ownerUserId: owner.id,
          inviteCode: `R${randomUUID()
            .replace(/[^2-9]/g, '')
            .padEnd(7, '2')
            .slice(0, 7)}`,
          parentAgencyId: parentId,
          evaluateFrom: new Date(`${month()}T00:00:00Z`),
        },
      });
    };
    /** `n` hosts of `agencyId`, each live `days` days × `hours` hours in the last 30 days. */
    const hosts = async (agencyId: string, n: number, days: number, hoursPerDay: number) => {
      for (let i = 0; i < n; i++) {
        const u = await signup();
        await ctx.prisma.agencyHost.create({
          data: {
            agencyId,
            hostUserId: u.id,
            commissionEligible: true,
            activatedAt: new Date(now.getTime() - 40 * DAY_MS),
          },
        });
        // One live a day at 01:00 UTC (≤ 3 hours: never across midnight) on the `days` days before today.
        const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
        for (let d = 1; d <= days; d++) {
          const start = new Date(today - d * DAY_MS + 3_600_000);
          await ctx.prisma.liveRoom.create({
            data: {
              hostUserId: u.id,
              title: 'past live',
              status: 'ENDED',
              endReason: 'HOST_ENDED',
              startedAt: start,
              lastHeartbeatAt: new Date(start.getTime() + hoursPerDay * 3_600_000),
              endedAt: new Date(start.getTime() + hoursPerDay * 3_600_000),
            },
          });
        }
      }
    };
    const admin = await make(null);
    const five = await make(admin.id);
    const rich = await make(admin.id);
    const poor = await make(admin.id);
    const third = await make(admin.id);
    await hosts(five.id, 5, 7, 1.5); // 7 days, 10.5 hours → 5 active hosts
    await hosts(rich.id, 4, 7, 1.5);
    await hosts(poor.id, 4, 7, 1.5);
    await hosts(poor.id, 1, 6, 3); // 6 days only → not active
    await hosts(third.id, 5, 7, 1.5);
    const cur = new Date(`${month()}T00:00:00Z`);
    await ctx.prisma.agencyMonth.createMany({
      data: [
        { agencyId: rich.id, month: cur, hostCherries: 200_000_000n },
        { agencyId: poor.id, month: cur, hostCherries: 199_999_999n },
        { agencyId: admin.id, month: cur, hostCherries: 250_000_000n },
      ],
    });
    const service = ctx.app.get(AgencyService);
    await service.evaluateRanks();
    const rank = async (id: string) => (await ctx.prisma.agency.findUniqueOrThrow({ where: { id } })).rank;
    expect(await rank(five.id)).toBe('AGENT');
    expect(await rank(rich.id)).toBe('AGENT'); // 4 active hosts, the 200M exception
    expect(await rank(poor.id)).toBe('LAPSED'); // 4 active hosts and 199 999 999 cherries
    expect(await rank(third.id)).toBe('AGENT');
    expect(await rank(admin.id)).toBe('ADMIN'); // qualifies itself (exception) + 3 qualified subs
    expect(
      (await ctx.prisma.agency.findUniqueOrThrow({ where: { id: five.id } })).rankMonth?.toISOString(),
    ).toBe(cur.toISOString());
    // During the month a rank is kept even when the agency no longer qualifies; promotions happen at once.
    await ctx.prisma.liveRoom.deleteMany({
      where: { host: { agencyLinks: { some: { agencyId: five.id } } } },
    });
    await ctx.prisma.agencyMonth.update({
      where: { agencyId_month: { agencyId: poor.id, month: cur } },
      data: { hostCherries: 200_000_000n },
    });
    const changes = await service.evaluateRanks();
    expect(await rank(five.id)).toBe('AGENT');
    expect(await rank(poor.id)).toBe('AGENT');
    expect(changes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ agencyId: poor.id, to: 'AGENT', monthStart: false }),
      ]),
    );
    // The next month start: re-evaluated up or down (`five` and `third` have no live time any more; last
    // month's cherries keep the exception for `rich` and `poor`).
    await ctx.prisma.liveRoom.deleteMany({
      where: { host: { agencyLinks: { some: { agencyId: third.id } } } },
    });
    const nextStart = new Date(`${addMonths(month(), 1)}T00:00:00Z`).getTime();
    clock.advance(nextStart - clock.now().getTime() + 3_600_000);
    try {
      await service.evaluateRanks();
      expect(await rank(five.id)).toBe('LAPSED');
      expect(await rank(third.id)).toBe('LAPSED');
      expect(await rank(rich.id)).toBe('AGENT');
      expect(await rank(poor.id)).toBe('AGENT');
      expect(await rank(admin.id)).toBe('AGENT'); // only 2 qualified subs now
      // Idempotent within the month.
      expect(await service.evaluateRanks()).toEqual([]);
    } finally {
      clock.reset();
    }
  });
});
