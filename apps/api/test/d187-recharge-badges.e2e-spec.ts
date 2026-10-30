/**
 * D187 (owner 2026-10-30; contract v1.56-social, CONVENTIONS §10.50, CP-030): the daily recharge badges — the
 * coins a buyer receives from recharge agents' sales in one calendar day (Asia/Riyadh) give a tier 1–5 shown for
 * 24 hours from the moment it was reached; a higher tier the same day replaces it; recharge agents never get
 * it; only sales count. End to end against PostgreSQL + Redis, with a clock that can be set.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { approveApplicationIn, topUpIn } from '../src/modules/recharge/recharge-core.js';
import { dayStart } from '../src/modules/recharge/recharge-rules.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time, or a set instant. */
class SettableClock extends Clock {
  private at: Date | null = null;
  now(): Date {
    return this.at ? new Date(this.at) : new Date();
  }
  set(at: Date | null): void {
    this.at = at;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Badge {
  tier: number;
  until: string;
}

const HOUR = 3_600_000;
const RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};

describe('D187 contract coverage', () => {
  it('openapi v1.56-social declares RechargeBadge on UserSummary and PublicProfile (optional)', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.RechargeBadge as { required: string[] }).required).toEqual(['tier', 'until']);
    for (const name of ['UserSummary', 'PublicProfile']) {
      const s = schemas[name] as { properties: object; required: string[] };
      expect(Object.keys(s.properties)).toContain('rechargeBadge');
      expect(s.required).not.toContain('rechargeBadge');
    }
  });
});

describe('D187 daily recharge badges', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  const media = new MemoryLiveMedia();
  const clock = new SettableClock();
  let ctx: TestContext;
  let png: Buffer;
  let seller: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  /** `user` applies and the team approves (an agent waiting for the first top-up). */
  const approvedAgent = async (user: TestUser): Promise<void> => {
    // The uploads first: a supertest request built before another one ran has a closed server.
    const body = {
      fullName: 'محمد أحمد علي حسن',
      phone: '+201001234567',
      whatsapp: true,
      photoUploadId: await upload(user, 'RECHARGE_AGENT_PHOTO'),
      selfieUploadId: await upload(user, 'RECHARGE_AGENT_SELFIE'),
      locations: [{ country: 'SA', cities: ['Riyadh'] }],
      paymentMethods: [{ country: 'SA', type: 'BANK_TRANSFER', details: 'IBAN' }],
    };
    const res = await ctx.http.post('/api/v1/me/recharge-agent/application').set(auth(user)).send(body);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const app = await ctx.prisma.rechargeAgentApplication.findFirstOrThrow({ where: { userId: user.id } });
    await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, app.id, new Date()));
  };
  /** An applicant approved and activated with `coins`. */
  const activeAgent = async (coins: bigint): Promise<TestUser> => {
    const user = await signup();
    await approvedAgent(user);
    await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, user.id, coins, (coins * 1200n) / 1_000_000n, null, RULES, new Date()),
    );
    return user;
  };
  /** A sale at `at` (the clock), checked against the contract; returns the buyer's summary. */
  const sell = async (buyer: TestUser, coins: number, at: Date | null = null, from = seller) => {
    clock.set(at);
    try {
      const res = await ctx.http
        .post('/api/v1/me/recharge-agent/sales')
        .set(auth(from))
        .set('Idempotency-Key', randomUUID())
        .send({ buyer: buyer.username, coins });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sellRechargeCoins');
      return res.body.buyer as { id: string; rechargeBadge?: Badge };
    } finally {
      clock.set(null);
    }
  };
  const profileBadge = async (u: TestUser): Promise<Badge | undefined> => {
    const viewer = seller;
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return (res.body as { rechargeBadge?: Badge }).rechargeBadge;
  };
  const row = (u: TestUser) => ctx.prisma.rechargeBadge.findUnique({ where: { userId: u.id } });
  const days = (u: TestUser) =>
    ctx.prisma.rechargeDailyTotal.findMany({ where: { userId: u.id }, orderBy: { day: 'asc' } });
  const iso = (d: Date) => d.toISOString().slice(0, 10);

  beforeAll(async () => {
    png = await sharp({ create: { width: 64, height: 64, channels: 3, background: '#c33' } })
      .png()
      .toBuffer();
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: clock },
      ],
    );
    expect(ctx.config.recharge.badges.timeZone).toBe('Asia/Riyadh');
    seller = await activeAgent(400_000_000n);
  });
  afterAll(async () => ctx?.close());

  it('tier boundaries: 999 999 none, 1 000 000 tier 1, 10 000 000 still 1, 10 000 001 tier 2 (upgrade restarts 24 h)', async () => {
    const a = await signup();
    // All on one Riyadh day: from 01:00 of today (its badge always ends after now).
    const base = new Date(dayStart(new Date(), 'Asia/Riyadh').getTime() + HOUR);
    expect((await sell(a, 999_999, base)).rechargeBadge).toBeUndefined();
    expect(await row(a)).toBeNull();
    expect(await profileBadge(a)).toBeUndefined();

    const t1 = new Date(base.getTime() + 60_000);
    const first = await sell(a, 1, t1);
    expect(first.rechargeBadge).toEqual({ tier: 1, until: new Date(t1.getTime() + 24 * HOUR).toISOString() });
    expect(await profileBadge(a)).toEqual(first.rechargeBadge);

    // Up to exactly 10 000 000: still tier 1, the 24 hours are not restarted.
    const same = await sell(a, 9_000_000, new Date(t1.getTime() + 60_000));
    expect(same.rechargeBadge).toEqual(first.rechargeBadge);
    expect((await days(a))[0]).toMatchObject({ coins: 10_000_000n, tier: 1 });

    // 10 000 001: tier 2, until = this moment + 24 h.
    const t2 = new Date(t1.getTime() + HOUR);
    const up = await sell(a, 1, t2);
    expect(up.rechargeBadge).toEqual({ tier: 2, until: new Date(t2.getTime() + 24 * HOUR).toISOString() });
    expect(await profileBadge(a)).toEqual(up.rechargeBadge);
    expect(await row(a)).toMatchObject({ tier: 2, reachedAt: t2 });
    expect((await days(a))[0]).toMatchObject({ coins: 10_000_001n, tier: 2 });

    // One sale crossing several tiers at once gives the highest.
    const b = await signup();
    expect((await sell(b, 70_000_001)).rechargeBadge?.tier).toBe(5);
  });

  it('the day is the calendar day in Asia/Riyadh: 23:59:59 and 00:00:00 are two days', async () => {
    const midnight = dayStart(new Date(), 'Asia/Riyadh');
    expect(midnight.getUTCHours()).toBe(21); // UTC+3
    const c = await signup();
    await sell(c, 600_000, new Date(midnight.getTime() - 1000));
    await sell(c, 600_000, midnight);
    const two = await days(c);
    expect(two.map((d) => [iso(d.day), d.coins, d.tier])).toEqual([
      [iso(new Date(midnight.getTime() - 3 * HOUR)), 600_000n, 0],
      [iso(new Date(midnight.getTime() + 3 * HOUR)), 600_000n, 0],
    ]);
    expect(await row(c)).toBeNull();
    // 400 000 more the same (new) day reaches 1 000 000.
    const t = new Date(midnight.getTime() + 1000);
    expect((await sell(c, 400_000, t)).rechargeBadge).toEqual({
      tier: 1,
      until: new Date(t.getTime() + 24 * HOUR).toISOString(),
    });
  });

  it('the badge shows for 24 hours from the moment it was reached, then disappears everywhere', async () => {
    const d = await signup();
    const old = new Date(Date.now() - 24 * HOUR - 5000);
    await sell(d, 1_000_000, old);
    expect(await row(d)).toMatchObject({ tier: 1, until: new Date(old.getTime() + 24 * HOUR) });
    expect(await profileBadge(d)).toBeUndefined();
    const sales = await ctx.http.get('/api/v1/me/recharge-agent/sales').set(auth(seller));
    expectContract(sales, 'listMyRechargeSales');
    const mine = (sales.body.data as { buyer: { id: string; rechargeBadge?: Badge } }[]).find(
      (s) => s.buyer.id === d.id,
    );
    expect(mine).toBeDefined();
    expect(mine!.buyer.rechargeBadge).toBeUndefined();

    const e = await signup();
    const recent = new Date(Date.now() - 24 * HOUR + 60_000);
    await sell(e, 1_000_000, recent);
    expect(await profileBadge(e)).toEqual({
      tier: 1,
      until: new Date(recent.getTime() + 24 * HOUR).toISOString(),
    });

    // The badge is on the room host's summary and on chat authors while it shows.
    await ctx.prisma.liveHost.create({ data: { userId: e.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(e)).send({ title: 'Badge live' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    expect(room.body.host.rechargeBadge).toEqual({ tier: 1, until: expect.any(String) });
    const msg = await ctx.http
      .post(`/api/v1/live/rooms/${room.body.id as string}/chat`)
      .set(auth(e))
      .send({ text: 'hi', clientId: randomUUID() });
    expect(msg.status, JSON.stringify(msg.body)).toBe(201);
    expectContract(msg, 'sendLiveChatMessage');
    expect(msg.body.author.rechargeBadge).toEqual({ tier: 1, until: expect.any(String) });
    // Expired (moved into the past): gone from the room and the chat too.
    await ctx.prisma.rechargeBadge.update({
      where: { userId: e.id },
      data: { until: new Date(Date.now() - 1000), reachedAt: new Date(Date.now() - 24 * HOUR - 1000) },
    });
    const roomNow = await ctx.http.get(`/api/v1/live/rooms/${room.body.id as string}`).set(auth(seller));
    expectContract(roomNow, 'getLiveRoom');
    expect(roomNow.body.host.rechargeBadge).toBeUndefined();
    const chat = await ctx.http.get(`/api/v1/live/rooms/${room.body.id as string}/chat`).set(auth(seller));
    expect(
      (chat.body.data as { author: { rechargeBadge?: unknown } }[])[0]!.author.rechargeBadge,
    ).toBeUndefined();
  });

  it('a higher tier from an earlier day still showing stays; an equal or higher one today replaces it', async () => {
    const f = await signup();
    const midnight = dayStart(new Date(), 'Asia/Riyadh');
    const yesterday = new Date(midnight.getTime() - HOUR);
    await sell(f, 20_000_001, yesterday);
    const kept = { tier: 3, until: new Date(yesterday.getTime() + 24 * HOUR).toISOString() };
    expect(await profileBadge(f)).toEqual(kept);
    // Today: tier 1 does not replace yesterday's tier 3.
    expect((await sell(f, 1_000_000, new Date(midnight.getTime() + 1000))).rechargeBadge).toEqual(kept);
    // Today: 40 000 001 in all → tier 4 replaces it.
    const t = new Date(midnight.getTime() + 2000);
    expect((await sell(f, 39_000_001, t)).rechargeBadge).toEqual({
      tier: 4,
      until: new Date(t.getTime() + 24 * HOUR).toISOString(),
    });
    expect((await days(f)).map((d) => d.tier)).toEqual([3, 4]);
  });

  it('only sales count: admin credits and other coin credits give nothing', async () => {
    const g = await signup();
    for (const reason of ['ADMIN_GRANT', 'TASK_REWARD', 'LUCKY_GIFT_WIN', 'CP_REFUND'] as const) {
      await ctx.prisma.$transaction((tx) => creditIn(tx, g.id, 50_000_000n, reason, randomUUID()));
    }
    expect(await row(g)).toBeNull();
    expect(await days(g)).toEqual([]);
    expect(await profileBadge(g)).toBeUndefined();
    // A sale below tier 1 after the credits: still nothing (the credits are not added).
    expect((await sell(g, 999_999)).rechargeBadge).toBeUndefined();
    expect((await days(g))[0]).toMatchObject({ coins: 999_999n, tier: 0 });
  });

  it('recharge agents never get it, as buyers or as sellers', async () => {
    const other = await activeAgent(30_000_000n);
    // An agent buying from another agent: nothing counted.
    const bought = await sell(other, 25_000_000);
    expect(bought.rechargeBadge).toBeUndefined();
    expect(await row(other)).toBeNull();
    expect(await days(other)).toEqual([]);
    // The selling agent: nothing either.
    expect(await row(seller)).toBeNull();
    expect(await profileBadge(other)).toBeUndefined();
    // A badge earned before becoming an agent is not shown once they are one.
    const h = await signup();
    await sell(h, 2_000_000);
    expect(await profileBadge(h)).toMatchObject({ tier: 1 });
    // Approved as an agent (not yet active): the badge is no longer shown.
    await approvedAgent(h);
    expect(await profileBadge(h)).toBeUndefined();
  });
});
