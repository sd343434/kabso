/**
 * D281 (v1.71-live / v1.86-social, CONVENTIONS §10.62.2, §10.41.4): «الأهداف الذكية» — the switch at the next day
 * boundary (today's D277 targets kept), three smart targets a day at three levels, the progress of every target kind
 * (gift counts included) from stored sends, the profit-share reward paid once in locked task cherries (never more
 * than the level's share of the ACTUAL profit counted), yesterday's reached targets settled, the Task Center's
 * generated tasks (a chosen gift, a window) and the OWNER's panel (knobs, catalogue, «لماذا هذا الهدف»).
 * Time is a FakeClock (UTC days in tests); lucky draws come from a scripted RNG (no wins).
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import type { LuckyRng } from '../src/modules/gifts/lucky-odds.js';
import { LUCKY_RNG } from '../src/modules/gifts/lucky-rng.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  NEW_HOST_DEFAULTS,
  expectedProfitUnits,
  platformProfitUnits,
  rewardCherriesFor,
  targetCode,
  trackOf,
  type TargetKind,
} from '../src/modules/programs/host-target-engine.js';
import { HostTargetsService } from '../src/modules/programs/host-targets.service.js';
import { seedDefaultTaskPoolIn, seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { smartTargetsEngineFrom } from './helpers/d281.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.parse('2027-01-13T07:00:00.000Z');
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D281 contract coverage', () => {
  it('openapi declares the panel operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getAdminHostTargetSettings GET /api/v1/admin/host-targets/settings');
    expect(ids).toContain('updateAdminHostTargetSettings PUT /api/v1/admin/host-targets/settings');
    expect(ids).toContain('getAdminTargetCatalogue GET /api/v1/admin/host-targets/catalogue');
    expect(ids).toContain('getAdminHostTargets GET /api/v1/admin/host-targets/hosts/{username}');
  });
});

describe('D281 smart host targets and tasks', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const rng: LuckyRng = { int: () => 999_999 };
  let ctx: TestContext;
  let seq = 0;
  let hostA: TestUser;
  let hostB: TestUser;
  let hostC: TestUser;
  let fan1: TestUser;
  let fan2: TestUser;
  const rooms = new Map<string, string>();
  let rose: string;
  let warrior: string;
  let lucky: string;
  let bigLucky: string;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const today = () => clock.now().toISOString().slice(0, 10);
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const gift = async (fields: Partial<GiftFields>): Promise<string> => {
    seq += 1;
    const code = `t${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: 100,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
    return code;
  };
  const join = async (roomId: string, u: TestUser) => {
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
  /** The host goes live (once) with both fans in the room. */
  const live = async (host: TestUser): Promise<string> => {
    const known = rooms.get(host.id);
    if (known) return known;
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Targets' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    rooms.set(host.id, id);
    for (const u of [fan1, fan2]) await join(id, u);
    return id;
  };
  const send = async (u: TestUser, host: TestUser, code: string, quantity = 1) => {
    const room = await live(host);
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${room}/gifts`)
      .set(auth(u))
      .set('CF-IPCountry', 'SA')
      .send({
        giftCode: code,
        quantity,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const targets = (host: TestUser, who: TestUser | null = null): request.Test => {
    const req = ctx.http.get(`/api/v1/live/hosts/${host.username}/targets`).set('Accept-Language', 'ar');
    if (who) void req.set(auth(who));
    return req;
  };
  /** The next day: the day's lives end (a heartbeat goes stale after an hour) and new ones start when needed. */
  const nextDay = async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endedAt: clock.now(), endReason: 'HOST_ENDED' },
    });
    rooms.clear();
    clock.advance(86_400);
  };
  const economy = () => ctx.app.get(HostTargetsService).economy();
  /** Stores a target for `host` today (before any read): its reward from the engine unless given. */
  const plant = async (
    host: TestUser,
    level: 'EASY' | 'MEDIUM' | 'HARD',
    kind: TargetKind,
    subject: string | null,
    amount: number,
    window = { from: 0, to: 1440 },
    opts: { expectedCoins?: number; rewardCherries?: number; shareBps?: number } = {},
  ) => {
    const bps = level === 'EASY' ? 150 : level === 'MEDIUM' ? 250 : 400;
    const track = trackOf(kind);
    const reward =
      opts.rewardCherries ??
      rewardCherriesFor(
        expectedProfitUnits(
          kind,
          amount,
          opts.expectedCoins ?? 0,
          economy(),
          track === 'LUCKY' ? { lucky: true } : { shareBps: opts.shareBps ?? 6_500 },
        ),
        bps,
        economy(),
      );
    await ctx.prisma.hostTargetAssignment.create({
      data: {
        userId: host.id,
        day: new Date(`${today()}T00:00:00.000Z`),
        track,
        level,
        code: targetCode({ kind, subject, amount, window }),
        kind,
        subject,
        amount: BigInt(amount),
        windowFrom: window.from,
        windowTo: window.to,
        expectedCoins: BigInt(opts.expectedCoins ?? 0),
        rewardBps: bps,
        rewardCherries: BigInt(reward),
        titleAr: `هدف ${kind}`,
        titleEn: `Target ${kind}`,
        reason: { planted: true },
        catalogueVersion: 'test',
      },
    });
    return reward;
  };
  const ledger = (u: TestUser) =>
    ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: u.id, reason: 'HOST_TARGET_REWARD' },
      orderBy: { referenceId: 'asc' },
      select: { delta: true, referenceId: true },
    });
  type Daily = {
    track: string;
    level: string;
    kind: string;
    progress: number;
    reached: boolean;
    rewardCherries: number;
    paidCherries: number | null;
  };
  /** D281b: the targets by `<track>:<level>` (GIFTS:EASY … LUCKY:HARD). */
  const byLevel = (body: { daily: Daily[] }) =>
    Object.fromEntries(body.daily.map((t) => [`${t.track}:${t.level}`, t]));

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        // v1.106-social (D341): this suite's arithmetic is the category share (65 %) of a host in no agency; the direct
        // share of D341 (70 % / a creator's 75 %) is covered by d341-direct-share.e2e-spec.ts.
        GIFT_DIRECT_HOST_SHARE_PERCENT: '65',
        GIFT_DIRECT_CREATOR_SHARE_PERCENT: '70',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_GIFT_QUANTITIES: '1,2,3,4,5',
        LUCKY_GIFTS_ENABLED: 'true',
        LUCKY_GIFTS_COUNTRY_HEADER: 'CF-IPCountry',
        LUCKY_PITY_AFTER: '0',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: LUCKY_RNG, value: rng },
      ],
    );
    await seedDefaultTasksIn(ctx.prisma);
    await seedDefaultTaskPoolIn(ctx.prisma);
    [hostA, hostB, hostC] = [await signup(), await signup(), await signup()];
    for (const h of [hostA, hostB, hostC])
      await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    [fan1, fan2] = [await signup(), await signup()];
    for (const u of [fan1, fan2]) {
      await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 10_000_000n, 'ADMIN_GRANT', randomUUID()));
      const age = await ctx.http
        .put('/api/v1/me/lucky-gifts/age-confirmation')
        .set(auth(u))
        .send({ adult: true });
      expect(age.status).toBe(200);
    }
    rose = await gift({ priceCoins: 100, nameAr: 'وردة', nameEn: 'Rose' });
    warrior = await gift({ category: 'FUN', priceCoins: 1_000, nameAr: 'المحارب', nameEn: 'Warrior' });
    lucky = await gift({ category: 'LUCKY', priceCoins: 10 });
    bigLucky = await gift({ category: 'LUCKY', priceCoins: 10_000, nameAr: 'كنز', nameEn: 'Treasure' });
  });
  afterAll(async () => ctx?.close());

  it("the switch: today keeps D277's two targets (in-flight progress), the next day has three smart targets", async () => {
    await send(fan1, hostA, rose, 2);
    const day0 = await targets(hostA);
    expect(day0.status, JSON.stringify(day0.body)).toBe(200);
    expectContract(day0, 'getLiveHostTargets');
    expect(day0.body.daily).toEqual([]);
    // 2 roses = 200 coins × 10 × 65 % = 1 300 cherries against D277's band-1 target.
    expect(day0.body.gifts).toEqual({ received: 1_300, target: 650_000, reached: false });
    const settings = await ctx.prisma.hostTargetSettings.findUniqueOrThrow({ where: { id: 1 } });
    expect(settings.engineFrom?.toISOString().slice(0, 10)).toBe('2027-01-14');
    // Nothing is assigned today.
    expect(await ctx.prisma.hostTargetAssignment.count()).toBe(0);

    await nextDay();
    const res = await targets(hostA);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLiveHostTargets');
    const daily = res.body.daily as (Daily & {
      rewardBps: number;
      locked: boolean;
      title: string;
      amount: number;
    })[];
    // D281b: three gift targets, then three lucky targets.
    expect(daily.map((t) => `${t.track}:${t.level}`)).toEqual([
      'GIFTS:EASY',
      'GIFTS:MEDIUM',
      'GIFTS:HARD',
      'LUCKY:EASY',
      'LUCKY:MEDIUM',
      'LUCKY:HARD',
    ]);
    expect(daily.map((t) => t.rewardBps)).toEqual([150, 250, 400, 150, 250, 400]);
    expect(new Set(daily.slice(0, 3).map((t) => t.kind)).size).toBe(3);
    // A new host on both tracks: the band defaults of each.
    expect(daily.map((t) => t.kind)).toEqual([
      'GIFT_SENDS',
      'SUPPORTERS',
      'GIFT_CHERRIES',
      'LUCKY_SENDS',
      'LUCKY_SUPPORTERS',
      'LUCKY_CHERRIES',
    ]);
    for (const t of daily) {
      expect(t.locked).toBe(true);
      expect(t.title.length).toBeGreaterThan(0);
      expect(t.rewardCherries).toBeGreaterThanOrEqual(0);
    }
    // Stable for the day; stored once.
    expect((await targets(hostA, fan1)).body.daily).toEqual(daily);
    const rows = await ctx.prisma.hostTargetAssignment.findMany({ where: { userId: hostA.id } });
    expect(rows).toHaveLength(6);
    for (const r of rows) expect((r.reason as { why: string }).why.length).toBeGreaterThan(0);
    // The fixed «هدف هدايا الحظ» task is no longer a Task Center task; the pool tasks are the smart ones.
    const tasks = await ctx.http.get('/api/v1/me/tasks').set(auth(hostA));
    expect(tasks.status).toBe(200);
    expectContract(tasks, 'getMyTasks');
    const codes = (tasks.body.tasks as { code: string }[]).map((t) => t.code);
    expect(codes).not.toContain('HOST_LUCKY_COINS');
    expect(codes).not.toContain('P_HOST_GIFTS');
    const assigned = await ctx.prisma.taskAssignment.findMany({ where: { userId: hostA.id } });
    expect(assigned.length).toBeGreaterThan(0);
    for (const a of assigned) expect(a.variant).toMatch(/^K\./);
  });

  it('progress of a gift count, a category count and a windowed cherries target; paid once, within the guard', async () => {
    // hostB, day 2027-01-14 (07:00): plant three targets before the first read.
    const huge = 1_000_000_000;
    await plant(hostB, 'EASY', 'GIFT_COUNT', rose, 3, undefined, {
      expectedCoins: 300,
      rewardCherries: huge,
    });
    const medium = await plant(hostB, 'MEDIUM', 'CATEGORY_COUNT', 'POPULAR', 5, undefined, {
      expectedCoins: 500,
    });
    const hard = await plant(hostB, 'HARD', 'GIFT_CHERRIES', null, 1_000, { from: 420, to: 480 });
    await send(fan1, hostB, rose, 3);
    await send(fan2, hostB, rose, 2);
    await send(fan2, hostB, warrior, 1);
    // Concurrent first reads: one payment per target.
    const reads = await Promise.all([targets(hostB), targets(hostB, fan1), targets(hostB, fan2)]);
    for (const r of reads) expect(r.status, JSON.stringify(r.body)).toBe(200);
    const res = await targets(hostB);
    expectContract(res, 'getLiveHostTargets');
    const t = byLevel(res.body);
    expect(t['GIFTS:EASY']).toMatchObject({ kind: 'GIFT_COUNT', progress: 3, reached: true });
    expect(res.body.daily[0].gift).toMatchObject({ code: rose, name: 'وردة' });
    expect(t['GIFTS:MEDIUM']).toMatchObject({ kind: 'CATEGORY_COUNT', progress: 5, reached: true });
    expect(res.body.daily[1].category).toEqual({ code: 'POPULAR', name: 'شائعة' });
    expect(t['GIFTS:HARD']).toMatchObject({ kind: 'GIFT_CHERRIES', progress: 1_000, reached: true });
    expect(res.body.daily[2].window).toEqual({ from: '07:00', to: '08:00' });
    // The guard: the EASY reward shown is huge, the payment is 1.5 % of the profit of the five roses only.
    const e = economy();
    const roses = platformProfitUnits(
      [{ lucky: false, coins: 500n, chargedCoins: 500n, hostCherries: 3_250n }],
      e,
    );
    expect(t['GIFTS:EASY']!.paidCherries).toBe(rewardCherriesFor(roses, 150, e));
    expect(t['GIFTS:EASY']!.paidCherries).toBeLessThan(huge);
    // The others reached their nominal: the reward shown.
    expect(t['GIFTS:MEDIUM']!.paidCherries).toBe(medium);
    expect(t['GIFTS:HARD']!.paidCherries).toBe(hard);
    const rows = await ledger(hostB);
    expect(rows.map((r) => r.referenceId)).toEqual([
      'HT:EASY@2027-01-14',
      'HT:HARD@2027-01-14',
      'HT:MEDIUM@2027-01-14',
    ]);
    const paid = rows.reduce((a, r) => a + Number(r.delta), 0);
    expect(paid).toBe(t['GIFTS:EASY']!.paidCherries! + medium + hard);
    // Locked like task cherries (the wallet shows them as locked; the unlock rule has not passed).
    const wallet = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(hostB));
    expect(wallet.status).toBe(200);
    expect(wallet.body.lockedTaskCherries).toBe(paid);
    // Audited.
    expect(await ctx.prisma.auditLog.count({ where: { action: 'host_targets.reward' } })).toBe(3);
    // A later read pays nothing again.
    await targets(hostB);
    expect(await ledger(hostB)).toHaveLength(3);
  });

  it("yesterday's reached target is settled on the next read; lucky, supporters and gifts received", async () => {
    // hostC (2027-01-14): a target reached but never read today.
    await plant(hostC, 'EASY', 'GIFT_SENDS', null, 1, undefined, { expectedCoins: 100 });
    await send(fan1, hostC, rose, 1);
    expect(await ledger(hostC)).toHaveLength(0);
    await nextDay();
    // 2027-01-15: hostB's gifts track (supporters, gifts received) and its LUCKY track (D281b).
    await plant(hostB, 'EASY', 'SUPPORTERS', null, 2, undefined, { expectedCoins: 200 });
    await plant(hostB, 'MEDIUM', 'GIFT_SENDS', null, 3, undefined, { expectedCoins: 300 });
    await plant(hostB, 'HARD', 'GIFT_CHERRIES', null, 100_000);
    const huge = 1_000_000_000;
    await plant(hostB, 'EASY', 'LUCKY_SENDS', null, 4, undefined, {
      expectedCoins: 40,
      rewardCherries: huge,
    });
    const luckyMedium = await plant(hostB, 'MEDIUM', 'LUCKY_SUPPORTERS', null, 1, undefined, {
      expectedCoins: 10,
    });
    await plant(hostB, 'HARD', 'LUCKY_CHERRIES', null, 50_000);
    await send(fan1, hostB, rose, 1);
    await send(fan2, hostB, rose, 2);
    for (let i = 0; i < 3; i++) await send(fan1, hostB, lucky, 1);
    await send(fan1, hostB, bigLucky, 1);
    const res = await targets(hostB);
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveHostTargets');
    const t = byLevel(res.body);
    expect(t['GIFTS:EASY']).toMatchObject({ kind: 'SUPPORTERS', progress: 2, reached: true });
    // «Gifts received» counts gifts outside the lucky category only (D281b): the 3 roses.
    expect(t['GIFTS:MEDIUM']).toMatchObject({ kind: 'GIFT_SENDS', progress: 3, reached: true });
    expect(t['GIFTS:HARD']).toMatchObject({ kind: 'GIFT_CHERRIES', progress: 1_950, reached: false });
    // The lucky track: 4 lucky gifts, one lucky supporter, 30 + 10 000 lucky cherries.
    expect(t['LUCKY:EASY']).toMatchObject({ kind: 'LUCKY_SENDS', progress: 4, reached: true });
    expect(t['LUCKY:MEDIUM']).toMatchObject({ kind: 'LUCKY_SUPPORTERS', progress: 1, reached: true });
    expect(t['LUCKY:HARD']).toMatchObject({
      kind: 'LUCKY_CHERRIES',
      progress: 10_030,
      reached: false,
      paidCherries: null,
    });
    // The guard on the LUCKY profit (after the expected payout): 1.5 % of what these four lucky sends left.
    const e = economy();
    const luckyProfit = platformProfitUnits(
      [{ lucky: true, coins: 10_030n, chargedCoins: 10_030n, hostCherries: 10_030n }],
      e,
    );
    expect(t['LUCKY:EASY']!.paidCherries).toBe(rewardCherriesFor(luckyProfit, 150, e));
    expect(t['LUCKY:EASY']!.paidCherries).toBeLessThan(huge);
    expect(t['LUCKY:MEDIUM']!.paidCherries).toBe(
      Math.min(luckyMedium, rewardCherriesFor(luckyProfit, 250, e)),
    );
    const refs = (await ledger(hostB)).map((r) => r.referenceId);
    expect(refs).toContain('HT:LUCKY:EASY@2027-01-15');
    // A payment of 0 (the nominal's reward rounds to nothing) writes no ledger row.
    expect(refs.includes('HT:LUCKY:MEDIUM@2027-01-15')).toBe(t['LUCKY:MEDIUM']!.paidCherries! > 0);
    expect(t['LUCKY:EASY']!.paidCherries).toBeGreaterThan(0);
    if (t['LUCKY:EASY']!.paidCherries! > 0) {
      // Locked like task cherries.
      const wallet = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(hostB));
      expect(wallet.body.lockedTaskCherries).toBeGreaterThan(0);
    }
    // hostC's read today settles yesterday's.
    const c = await targets(hostC);
    expect(c.status).toBe(200);
    expect((await ledger(hostC)).map((r) => r.referenceId)).toEqual(['HT:EASY@2027-01-14']);
  });

  it('combos and a window outside the sends', async () => {
    await nextDay();
    // 2027-01-16 07:00.
    await plant(hostB, 'EASY', 'COMBO', null, 3, undefined, { expectedCoins: 3_000 });
    await plant(hostB, 'MEDIUM', 'GIFT_COMBO', warrior, 2, undefined, { expectedCoins: 2_000 });
    await plant(hostB, 'HARD', 'GIFT_CHERRIES', null, 1_000, { from: 1200, to: 1260 });
    for (let i = 0; i < 3; i++) await send(fan1, hostB, warrior, 1);
    const t = byLevel((await targets(hostB)).body);
    expect(t['GIFTS:EASY']).toMatchObject({ kind: 'COMBO', progress: 3, reached: true });
    expect(t['GIFTS:MEDIUM']).toMatchObject({ kind: 'GIFT_COMBO', progress: 2, reached: true });
    expect(t['GIFTS:HARD']).toMatchObject({ progress: 0, reached: false, paidCherries: null });
  });

  it('Task Center: a chosen-gift task counts that gift (picture and name); a window outside now counts nothing', async () => {
    const fan = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, fan.id, 1_000_000n, 'ADMIN_GRANT', randomUUID()));
    const room = await live(hostB);
    await join(room, fan);
    const day = new Date(`${today()}T00:00:00.000Z`);
    await ctx.prisma.taskAssignment.createMany({
      data: [
        {
          userId: fan.id,
          day,
          taskCode: 'P_SEND_GIFT_OF',
          band: 1,
          target: 2,
          rewardCherries: 20,
          position: 0,
          variant: `K.P_SEND_GIFT_OF.${rose}.2.0-1440`,
          subject: rose,
          nameAr: 'أرسل 2 من وردة',
          nameEn: 'Send 2 × Rose',
        },
        {
          userId: fan.id,
          day,
          taskCode: 'P_SEND_CATEGORY',
          band: 1,
          target: 1,
          rewardCherries: 10,
          position: 1,
          variant: 'K.P_SEND_CATEGORY.POPULAR.1.1200-1260',
          subject: 'POPULAR',
          windowFrom: 1200,
          windowTo: 1260,
          nameAr: 'أرسل 1 هدية من فئة شائعة من 20:00 إلى 21:00',
          nameEn: 'Send 1 gifts from Popular between 20:00–21:00',
        },
      ],
    });
    await send(fan, hostB, rose, 2);
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(fan)).set('Accept-Language', 'ar');
    expect(res.status).toBe(200);
    expectContract(res, 'getMyTasks');
    const [chosen, windowed] = res.body.tasks as {
      code: string;
      name: string;
      progress: number;
      completed: boolean;
      gift: { code: string; name: string } | null;
      window: { from: string; to: string } | null;
    }[];
    expect(chosen).toMatchObject({
      code: 'P_SEND_GIFT_OF',
      name: 'أرسل 2 من وردة',
      progress: 2,
      completed: true,
    });
    expect(chosen!.gift).toMatchObject({ code: rose, name: 'وردة' });
    expect(windowed).toMatchObject({
      code: 'P_SEND_CATEGORY',
      progress: 0,
      completed: false,
      window: { from: '20:00', to: '21:00' },
    });
    const claim = await ctx.http.post('/api/v1/me/tasks/P_SEND_GIFT_OF/claim').set(auth(fan));
    expect(claim.status, JSON.stringify(claim.body)).toBe(201);
    expectContract(claim, 'claimMyTask');
    expect(claim.body.paidCherries).toBe(20);
    expect((await ctx.http.post('/api/v1/me/tasks/P_SEND_CATEGORY/claim').set(auth(fan))).status).toBe(409);
  });

  it('Task Center: a fresh person gets generated tasks, stored with their variants and reasons', async () => {
    const fresh = await signup();
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(fresh));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyTasks');
    const rows = await ctx.prisma.taskAssignment.findMany({ where: { userId: fresh.id } });
    expect(rows.length).toBe(6);
    for (const r of rows) {
      expect(r.variant).toMatch(new RegExp(`^K\\.${r.taskCode}\\.`));
      expect((r.reason as { why: string }).why.length).toBeGreaterThan(0);
    }
    // The same on reload.
    expect((await ctx.http.get('/api/v1/me/tasks').set(auth(fresh))).body.tasks).toEqual(res.body.tasks);
  });
});

describe('D281 the panel «الأهداف الذكية» (OWNER only)', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const P = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: P.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      LIVE_HOSTING_ENABLED: 'true',
    });
    await seedDefaultTasksIn(ctx.prisma);
    await seedDefaultTaskPoolIn(ctx.prisma);
    owner = await P.makeAdmin(['OWNER']);
    support = await P.makeAdmin(['SUPPORT']);
    finance = await P.makeAdmin(['FINANCE']);
    for (let i = 0; i < 20; i++) {
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, `cat_${String(i)}`, {
          category: i % 2 === 0 ? 'POPULAR' : 'FUN',
          nameAr: `هدية ${String(i)}`,
          nameEn: `Gift ${String(i)}`,
          priceCoins: 10 * (i + 1),
          assetKey: `gift_cat_${String(i)}`,
          animationKey: null,
          sortOrder: i,
          badge: 'NONE',
          tagCode: null,
          tagNameAr: null,
          tagNameEn: null,
        }),
      );
    }
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('knobs: OWNER reads and changes them (audited, with a reason); the order is kept; others get 403', async () => {
    const got = await P.send(owner, 'get', '/admin/host-targets/settings');
    expect(got.status, JSON.stringify(got.body)).toBe(200);
    expectContract(got, 'getAdminHostTargetSettings');
    expect(got.body).toMatchObject({
      easyPercentile: 50,
      mediumPercentile: 75,
      hardPercentile: 90,
      easyRewardBps: 150,
      mediumRewardBps: 250,
      hardRewardBps: 400,
      noRepeatDays: 7,
    });
    const put = await P.send(owner, 'put', '/admin/host-targets/settings', {
      hardRewardBps: 500,
      noRepeatDays: 10,
      reason: 'owner tuning',
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateAdminHostTargetSettings');
    expect(put.body).toMatchObject({ hardRewardBps: 500, noRepeatDays: 10, updatedById: owner.id });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'host_targets.settings.update' },
    });
    expect(audit.metadata).toMatchObject({
      before: { hardRewardBps: 400, noRepeatDays: 7 },
      after: { hardRewardBps: 500, noRepeatDays: 10 },
      reason: 'owner tuning',
    });
    // easy < medium < hard; easy ≤ medium ≤ hard shares; a reason and a change.
    expect(
      (await P.send(owner, 'put', '/admin/host-targets/settings', { easyPercentile: 80, reason: 'x' }))
        .status,
    ).toBe(400);
    expect(
      (await P.send(owner, 'put', '/admin/host-targets/settings', { easyRewardBps: 600, reason: 'x' }))
        .status,
    ).toBe(400);
    expect((await P.send(owner, 'put', '/admin/host-targets/settings', { reason: 'x' })).status).toBe(400);
    expect((await P.send(owner, 'put', '/admin/host-targets/settings', { easyRewardBps: 100 })).status).toBe(
      400,
    );
    // D281b (owner: today's gift prices are placeholders): the new-host defaults are OWNER-editable, audited;
    // descending levels are refused; null goes back to the code's values.
    expect(got.body.newHostDefaults).toEqual(NEW_HOST_DEFAULTS);
    const raised = {
      ...NEW_HOST_DEFAULTS,
      GIFT_CHERRIES: NEW_HOST_DEFAULTS.GIFT_CHERRIES.map(([x, y, z]) => [x * 10, y * 10, z * 10]),
    };
    const setDefaults = await P.send(owner, 'put', '/admin/host-targets/settings', {
      newHostDefaults: raised,
      reason: 'real prices',
    });
    expect(setDefaults.status, JSON.stringify(setDefaults.body)).toBe(200);
    expectContract(setDefaults, 'updateAdminHostTargetSettings');
    expect(setDefaults.body.newHostDefaults.GIFT_CHERRIES[0]).toEqual([200_000, 600_000, 1_500_000]);
    const bad = {
      ...raised,
      SUPPORTERS: [
        [3, 2, 1],
        [3, 5, 8],
        [5, 8, 12],
        [8, 12, 20],
      ],
    };
    expect(
      (await P.send(owner, 'put', '/admin/host-targets/settings', { newHostDefaults: bad, reason: 'x' }))
        .status,
    ).toBe(400);
    const reset = await P.send(owner, 'put', '/admin/host-targets/settings', {
      newHostDefaults: null,
      reason: 'x',
    });
    expect(reset.body.newHostDefaults).toEqual(NEW_HOST_DEFAULTS);
    for (const who of [support, finance]) {
      expect((await P.send(who, 'get', '/admin/host-targets/settings')).status).toBe(403);
      expect((await P.send(who, 'get', '/admin/host-targets/catalogue')).status).toBe(403);
      expect(
        (await P.send(who, 'put', '/admin/host-targets/settings', { noRepeatDays: 1, reason: 'x' })).status,
      ).toBe(403);
    }
  });

  it('the catalogue: more than 100 000 targets and more than 100 000 tasks; it follows the gift catalogue', async () => {
    const res = await P.send(owner, 'get', '/admin/host-targets/catalogue');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getAdminTargetCatalogue');
    expect(res.body.targets.total).toBeGreaterThan(100_000);
    expect(res.body.tasks.total).toBeGreaterThan(100_000);
    expect(res.body.targets.gifts).toBe(20);
    await ctx.prisma.gift.update({ where: { code: 'cat_0' }, data: { enabled: false } });
    const after = await P.send(owner, 'get', '/admin/host-targets/catalogue');
    expect(after.body.targets.gifts).toBe(19);
    expect(after.body.targets.total).toBeLessThan(res.body.targets.total);
    expect(after.body.targets.version).not.toBe(res.body.targets.version);
  });

  it('a host’s targets with «لماذا هذا الهدف» (audited read); 404 for an unknown name', async () => {
    const { res } = await registerVerified(ctx);
    const host = { id: res.body.user.id as string, username: res.body.user.username as string };
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    await smartTargetsEngineFrom(ctx.prisma, '2020-01-01');
    const read = await ctx.http.get(`/api/v1/live/hosts/${host.username}/targets`);
    expect(read.status, JSON.stringify(read.body)).toBe(200);
    expect(read.body.daily).toHaveLength(6);
    const view = await P.send(owner, 'get', `/admin/host-targets/hosts/${host.username}`);
    expect(view.status, JSON.stringify(view.body)).toBe(200);
    expectContract(view, 'getAdminHostTargets');
    expect(view.body.host.id).toBe(host.id);
    expect(view.body.targets.map((t: { track: string; level: string }) => `${t.track}:${t.level}`)).toEqual([
      'GIFTS:EASY',
      'GIFTS:MEDIUM',
      'GIFTS:HARD',
      'LUCKY:EASY',
      'LUCKY:MEDIUM',
      'LUCKY:HARD',
    ]);
    for (const t of view.body.targets as { reason: { newHost: boolean; whyAr: string } }[]) {
      // A new host: the band defaults, said so.
      expect(t.reason.newHost).toBe(true);
      expect(t.reason.whyAr).toContain('مضيف جديد');
    }
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'host_targets.view', targetId: host.id } }),
    ).toBe(1);
    expect((await P.send(owner, 'get', '/admin/host-targets/hosts/nobody_here_x')).status).toBe(404);
    expect((await P.send(support, 'get', `/admin/host-targets/hosts/${host.username}`)).status).toBe(403);
  });
});
