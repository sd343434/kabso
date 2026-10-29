/**
 * D164 (owner 2026-10-29: «اجعل الوكيل يعمل على أزرار قريباً في أنا»; contract v1.43-social, CONVENTIONS
 * §10.40): the Me hub's wallet history, gift earnings and creator center — only the caller's own stored
 * data, nothing estimated — end to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn, debitIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const DAY_MS = 86_400_000;

describe('D164 contract coverage', () => {
  it('openapi v1.43-social declares the Me hub operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'listMyWalletLedger GET /api/v1/wallet/me/ledger',
        'getMyEarnings GET /api/v1/wallet/me/earnings',
        'listMyEarnings GET /api/v1/wallet/me/earnings/history',
        'getMyCreatorStats GET /api/v1/me/creator-stats',
      ]),
    );
  });
});

describe('D164 Me hub', { timeout: 120_000 }, () => {
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
        nameAr: `هدية ${code}`,
        nameEn: `Gift ${code}`,
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
  const send = async (roomId: string, from: TestUser, to: TestUser, code: string, quantity = 1) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Hub' });
    expect(room.status).toBe(201);
    return room.body.id as string;
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    await gift('hub_rose', 'POPULAR', 10);
    await gift('hub_quip', 'QUIPS', 99);
  });
  afterAll(async () => ctx?.close());

  it('the coin history: own rows only, newest first, signed, paged, no reference', async () => {
    const me = await signup();
    const other = await signup();
    await creditIn(ctx.prisma, me.id, 100n, 'ADMIN_GRANT', randomUUID());
    await debitIn(ctx.prisma, me.id, 15n, 'BULLET_MESSAGE', randomUUID());
    await creditIn(ctx.prisma, me.id, 40n, 'ADMIN_GRANT', randomUUID());
    await creditIn(ctx.prisma, other.id, 999n, 'ADMIN_GRANT', randomUUID());
    // uuid v7 ids grow with each write, so equal times still keep the writing order.

    const first = await ctx.http.get('/api/v1/wallet/me/ledger?limit=2').set(auth(me));
    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expectContract(first, 'listMyWalletLedger');
    expect(first.body.data.map((e: { delta: number }) => e.delta)).toEqual([40, -15]);
    expect(first.body.data.map((e: { balanceAfter: number }) => e.balanceAfter)).toEqual([125, 85]);
    expect(first.body.data[1]).toMatchObject({ reason: 'BULLET_MESSAGE' });
    expect(first.body.data[0]).not.toHaveProperty('referenceId');
    expect(first.body.page.hasMore).toBe(true);

    const next = await ctx.http
      .get(
        `/api/v1/wallet/me/ledger?limit=2&cursor=${encodeURIComponent(first.body.page.nextCursor as string)}`,
      )
      .set(auth(me));
    expect(next.status).toBe(200);
    expect(next.body.data).toHaveLength(1);
    expect(next.body.data[0]).toMatchObject({ reason: 'ADMIN_GRANT', delta: 100, balanceAfter: 100 });
    expect(next.body.page).toEqual({ hasMore: false, nextCursor: null });

    // Another person's cursor and a forged one are refused; nobody else's rows appear.
    const foreign = await ctx.http
      .get(`/api/v1/wallet/me/ledger?cursor=${encodeURIComponent(first.body.page.nextCursor as string)}`)
      .set(auth(other));
    expect(foreign.status).toBe(400);
    expect(foreign.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    const forged = await ctx.http.get('/api/v1/wallet/me/ledger?cursor=abc.def').set(auth(me));
    expect(forged.status).toBe(400);
    const others = await ctx.http.get('/api/v1/wallet/me/ledger').set(auth(other));
    expect(others.body.data.map((e: { delta: number }) => e.delta)).toEqual([999]);
    expect((await ctx.http.get('/api/v1/wallet/me/ledger?limit=0').set(auth(me))).status).toBe(400);
    expect((await ctx.http.get('/api/v1/wallet/me/ledger')).status).toBe(401);

    // A new person: an empty page.
    const fresh = await signup();
    const empty = await ctx.http.get('/api/v1/wallet/me/ledger').set(auth(fresh));
    expect(empty.body).toEqual({ data: [], page: { hasMore: false, nextCursor: null } });
  });

  it('earnings: the stored share of each send received, rolling windows, history with the sender', async () => {
    const host = await signup();
    const fan = await signup();
    await creditIn(ctx.prisma, fan.id, 10_000n, 'ADMIN_GRANT', randomUUID());
    const roomId = await startLive(host);
    await join(roomId, fan);
    await send(roomId, fan, host, 'hub_rose', 10); // 100 coins × 65 % = 65
    await send(roomId, fan, host, 'hub_quip'); // 99 × 50 % = 49
    await send(roomId, fan, host, 'hub_rose'); // 10 × 65 % = 6, moved 10 days back
    await send(roomId, fan, host, 'hub_rose'); // share set to 0 below: left out

    const sends = await ctx.prisma.liveGift.findMany({ where: { senderId: fan.id }, orderBy: { id: 'asc' } });
    expect(sends).toHaveLength(4);
    const base = Date.now() - 60_000;
    for (const [i, s] of sends.entries()) {
      await ctx.prisma.liveGift.update({
        where: { id: s.id },
        data: { createdAt: new Date(base + i * 1000) },
      });
    }
    await ctx.prisma.liveGift.update({
      where: { id: sends[2]!.id },
      data: { createdAt: new Date(Date.now() - 10 * DAY_MS) },
    });
    await ctx.prisma.liveGift.update({ where: { id: sends[3]!.id }, data: { hostShareBps: 0 } });

    const totals = await ctx.http.get('/api/v1/wallet/me/earnings').set(auth(host));
    expect(totals.status, JSON.stringify(totals.body)).toBe(200);
    expectContract(totals, 'getMyEarnings');
    expect(totals.body).toEqual({
      totalCoins: 65 + 49 + 6,
      last7DaysCoins: 65 + 49,
      last30DaysCoins: 120,
      sendCount: 3,
    });
    // The sender earned nothing; their wallet is not "earnings".
    const fanTotals = await ctx.http.get('/api/v1/wallet/me/earnings').set(auth(fan));
    expect(fanTotals.body).toEqual({ totalCoins: 0, last7DaysCoins: 0, last30DaysCoins: 0, sendCount: 0 });

    const page1 = await ctx.http
      .get('/api/v1/wallet/me/earnings/history?limit=2')
      .set(auth(host))
      .set('Accept-Language', 'en');
    expect(page1.status, JSON.stringify(page1.body)).toBe(200);
    expectContract(page1, 'listMyEarnings');
    expect(page1.body.data).toHaveLength(2);
    expect(page1.body.data[0]).toMatchObject({
      id: sends[1]!.id,
      context: 'LIVE',
      giftCode: 'hub_quip',
      giftName: 'Gift hub_quip',
      quantity: 1,
      giftCoins: 99,
      shareBps: 5000,
      coins: 49,
      sender: { id: fan.id, username: fan.username },
    });
    expect(page1.body.data[1]).toMatchObject({
      id: sends[0]!.id,
      quantity: 10,
      giftCoins: 100,
      shareBps: 6500,
      coins: 65,
    });
    const page2 = await ctx.http
      .get(
        `/api/v1/wallet/me/earnings/history?limit=2&cursor=${encodeURIComponent(page1.body.page.nextCursor as string)}`,
      )
      .set(auth(host))
      .set('Accept-Language', 'ar');
    expect(page2.status).toBe(200);
    expect(page2.body.data.map((e: { id: string }) => e.id)).toEqual([sends[2]!.id]);
    expect(page2.body.data[0].giftName).toBe('هدية hub_rose');
    expect(page2.body.page).toEqual({ hasMore: false, nextCursor: null });

    // A block either way hides the sender (the earning stays).
    await ctx.http.put(`/api/v1/users/${fan.username}/block`).set(auth(host)).expect(200);
    const blocked = await ctx.http.get('/api/v1/wallet/me/earnings/history').set(auth(host));
    expect(blocked.body.data).toHaveLength(3);
    expect(blocked.body.data.every((e: { sender: unknown }) => e.sender === null)).toBe(true);
    // The fan's own history has nothing (they sent, they did not receive).
    expect((await ctx.http.get('/api/v1/wallet/me/earnings/history').set(auth(fan))).body.data).toEqual([]);
    expect((await ctx.http.get('/api/v1/wallet/me/earnings')).status).toBe(401);
  });

  it('the creator center: followers, posts and reels published in the period, ended lives', async () => {
    const me = await signup();
    const fans = [await signup(), await signup(), await signup()];
    for (const f of fans) {
      const res = await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(f));
      expect(res.status).toBeLessThan(300);
    }
    // One follow is old; one follower is suspended (not counted).
    await ctx.prisma.follow.update({
      where: { followerId_followeeId: { followerId: fans[0]!.id, followeeId: me.id } },
      data: { createdAt: new Date(Date.now() - 20 * DAY_MS) },
    });
    await ctx.prisma.user.update({ where: { id: fans[2]!.id }, data: { status: 'SUSPENDED' } });

    const post = async (text: string) => {
      const res = await ctx.http
        .post('/api/v1/posts')
        .set(auth(me))
        .set('Idempotency-Key', randomUUID())
        .send({ text });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body.id as string;
    };
    const recent = await post('recent');
    const old = await post('old');
    const removed = await post('removed');
    await ctx.prisma.post.update({
      where: { id: recent },
      data: { viewCount: 120, likeCount: 7, commentCount: 3, shareCount: 2 },
    });
    await ctx.prisma.post.update({
      where: { id: old },
      data: { publishedAt: new Date(Date.now() - 40 * DAY_MS), viewCount: 1000, likeCount: 50 },
    });
    await ctx.prisma.post.update({
      where: { id: removed },
      data: { moderation: 'REMOVED', viewCount: 5000 },
    });
    // A reel, written directly (its video pipeline is D162's): published 10 days ago.
    await ctx.prisma.post.create({
      data: {
        authorId: me.id,
        format: 'REEL',
        text: 'reel',
        publishedAt: new Date(Date.now() - 10 * DAY_MS),
        viewCount: 300,
        likeCount: 30,
        commentCount: 4,
        shareCount: 1,
      },
    });

    // One ended live: an hour, with a gift (10 × 65 % = 6).
    const fan = fans[1]!;
    await creditIn(ctx.prisma, fan.id, 1_000n, 'ADMIN_GRANT', randomUUID());
    const roomId = await startLive(me);
    await join(roomId, fan);
    await send(roomId, fan, me, 'hub_rose');
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(me)).expect(200);
    const ended = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
    await ctx.prisma.liveRoom.update({
      where: { id: roomId },
      data: { startedAt: new Date(ended.endedAt!.getTime() - 3_600_000) },
    });

    const week = await ctx.http.get('/api/v1/me/creator-stats?period=LAST_7_DAYS').set(auth(me));
    expect(week.status, JSON.stringify(week.body)).toBe(200);
    expectContract(week, 'getMyCreatorStats');
    expect(week.body).toMatchObject({
      period: 'LAST_7_DAYS',
      followers: { total: 2, newInPeriod: 1 },
      posts: { published: 1, views: 120, likes: 7, comments: 3, shares: 2 },
      reels: { published: 0, views: 0, likes: 0, comments: 0, shares: 0 },
      live: { lives: 1, liveSeconds: 3600, giftCount: 1, giftCoins: 10, earningsCoins: 6, peakViewers: 1 },
    });
    expect(Date.parse(week.body.to) - Date.parse(week.body.from)).toBe(7 * DAY_MS);

    const month = await ctx.http.get('/api/v1/me/creator-stats?period=LAST_30_DAYS').set(auth(me));
    expect(month.body).toMatchObject({
      followers: { total: 2, newInPeriod: 2 },
      posts: { published: 1, views: 120 },
      reels: { published: 1, views: 300, likes: 30, comments: 4, shares: 1 },
    });

    const all = await ctx.http.get('/api/v1/me/creator-stats?period=ALL_TIME').set(auth(me));
    expectContract(all, 'getMyCreatorStats');
    expect(all.body).toMatchObject({
      from: null,
      followers: { total: 2, newInPeriod: null },
      posts: { published: 2, views: 1120, likes: 57 },
      reels: { published: 1 },
      live: { lives: 1 },
    });

    // A new person: zeros, never an error.
    const fresh = await signup();
    const empty = await ctx.http.get('/api/v1/me/creator-stats?period=ALL_TIME').set(auth(fresh));
    expect(empty.body).toMatchObject({
      followers: { total: 0, newInPeriod: null },
      posts: { published: 0 },
      reels: { published: 0 },
      live: { lives: 0, liveSeconds: 0, earningsCoins: 0 },
    });

    for (const q of ['', '?period=7d', '?period=LAST_7_DAYS&x=1']) {
      const bad = await ctx.http.get(`/api/v1/me/creator-stats${q}`).set(auth(me));
      expect(bad.status).toBe(400);
      expectContract(bad, 'getMyCreatorStats');
    }
    expect((await ctx.http.get('/api/v1/me/creator-stats?period=ALL_TIME')).status).toBe(401);
  });
});
