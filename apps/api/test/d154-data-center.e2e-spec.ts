/**
 * D154d (owner 2026-10-28, item 14; contract v1.35-live, CONVENTIONS §10.36): the host's data center
 * «مركز البيانات» — every ended live summarised once (`live_summaries`, any end path, older lives
 * too), the caller's DAY / WEEK / MONTH / YEAR totals, series and best hours, and the end-of-live
 * statistics' gift value and earnings — end to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LiveDataCenterService } from '../src/modules/live/live-data-center.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D154d contract coverage', () => {
  it('openapi v1.35-live declares the data center operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getMyLiveStats GET /api/v1/live/stats/me');
  });
});

describe('D154d data center', { timeout: 120_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

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
  const gift = (code: string, category: 'POPULAR' | 'QUIPS', price: number) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category,
        nameAr: code,
        nameEn: code,
        priceCoins: price,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...(category === 'QUIPS' ? { soundKey: 'kabi/ghazal_01', soundMs: 4362, quipText: 'x' } : {}),
      }),
    );
  const stats = (u: TestUser, period: string) =>
    ctx.http.get(`/api/v1/live/stats/me?period=${period}`).set(auth(u));

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    await gift('dc_rose', 'POPULAR', 10);
    await gift('dc_quip', 'QUIPS', 99);
  });
  afterAll(async () => ctx?.close());

  it('an ended live is summarised once; the periods add up its time, gifts, earnings and followers', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const fan = await signup();
    await creditIn(ctx.prisma, fan.id, 1_000n, 'ADMIN_GRANT', randomUUID());
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Stats' });
    expect(room.status).toBe(201);
    const roomId = room.body.id as string;
    await join(roomId, fan);
    for (const code of ['dc_rose', 'dc_quip']) {
      const sent = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/gifts`)
        .set(auth(fan))
        .send({
          giftCode: code,
          quantity: 1,
          recipients: [h.username],
          source: 'COINS',
          clientId: randomUUID(),
        });
      expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    }
    const followed = await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(fan));
    expect(followed.status).toBeLessThan(300);

    // While LIVE the room statistics already show the value and the host's share: 10 × 65 % + 99 × 50 %.
    const live = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stats`).set(auth(h));
    expect(live.status).toBe(200);
    expectContract(live, 'getLiveRoomStats');
    expect(live.body).toMatchObject({ giftCount: 2, giftCoins: 109, earningsCoins: 6 + 49 });
    // …and the live is not in the data center until it ends.
    expect((await stats(h, 'DAY')).body.totals.lives).toBe(0);

    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    // An exact hour-long live, so the arithmetic is checked.
    const ended = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
    await ctx.prisma.liveRoom.update({
      where: { id: roomId },
      data: { startedAt: new Date(ended.endedAt!.getTime() - 3_600_000) },
    });
    await ctx.prisma.follow.updateMany({
      where: { followeeId: h.id },
      data: { createdAt: new Date(ended.endedAt!.getTime() - 60_000) },
    });

    const res = await stats(h, 'YEAR');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyLiveStats');
    expect(res.body).toMatchObject({
      period: 'YEAR',
      timeZone: 'UTC',
      totals: {
        lives: 1,
        liveSeconds: 3600,
        giftCount: 2,
        giftCoins: 109,
        earningsCoins: 55,
        newFollowers: 1,
        uniqueViewers: 1,
      },
    });
    expect(res.body.series).toHaveLength(12);
    const thisMonth = (res.body.series as { liveSeconds: number; earningsCoins: number }[]).at(-1)!;
    expect(thisMonth).toMatchObject({ liveSeconds: 3600, earningsCoins: 55 });
    expect(res.body.heatmap).toHaveLength(1);
    expect(res.body.heatmap[0]).toMatchObject({ lives: 1, viewers: 1 });
    // Summarised once: the row stays and a second summariser run writes nothing for it.
    expect(await ctx.prisma.liveSummary.count({ where: { roomId } })).toBe(1);
    expect(await ctx.app.get(LiveDataCenterService).summarise(h.id)).toBe(0);
    const week = await stats(h, 'WEEK');
    expect(week.body.series).toHaveLength(7);
    expect(week.body.totals.lives).toBe(1);
    const month = await stats(h, 'MONTH');
    expect(month.body.series).toHaveLength(30);
    const day = await stats(h, 'DAY');
    expect(day.body.series.length).toBeGreaterThanOrEqual(1);
    expect(day.body.series.length).toBeLessThanOrEqual(24);

    // Someone else's data center is their own (no lives).
    const other = await stats(fan, 'YEAR');
    expect(other.body.totals).toMatchObject({ lives: 0, liveSeconds: 0, earningsCoins: 0 });
  });

  it('a live that ended by the heartbeat timeout (or before D154d) is summarised too', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Old' });
    const roomId = room.body.id as string;
    const endedAt = new Date();
    await ctx.prisma.liveRoom.update({
      where: { id: roomId },
      data: {
        status: 'ENDED',
        endReason: 'HEARTBEAT_TIMEOUT',
        endedAt,
        startedAt: new Date(endedAt.getTime() - 600_000),
      },
    });
    expect(await ctx.app.get(LiveDataCenterService).summarise()).toBeGreaterThanOrEqual(1);
    const s = await ctx.prisma.liveSummary.findUniqueOrThrow({ where: { roomId } });
    expect(s).toMatchObject({ durationSeconds: 600, giftCount: 0, newFollowers: 0 });
  });

  it('the period is required and one of DAY, WEEK, MONTH, YEAR', async () => {
    const u = await signup();
    for (const q of ['', '?period=HOUR', '?period=day&x=1']) {
      const res = await ctx.http.get(`/api/v1/live/stats/me${q}`).set(auth(u));
      expect(res.status, q).toBe(400);
      expectContract(res, 'getMyLiveStats');
    }
    const anonymous = await ctx.http.get('/api/v1/live/stats/me?period=DAY');
    expect(anonymous.status).toBe(401);
  });
});
