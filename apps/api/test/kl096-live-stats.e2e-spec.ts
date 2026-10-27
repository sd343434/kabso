/**
 * D140 (v1.27.6-live DRAFT, CONVENTIONS §10.31): the host's statistics of one live —
 * `GET /live/rooms/{roomId}/stats` — end to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role. Presence comes from the signed media webhook (the in-memory media fake);
 * time from a FakeClock, so watch time and the duration are exact.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
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

const MISSING_ROOM = '0192f1d0-0000-7000-8000-000000000000';

describe('D140 contract coverage', () => {
  it('openapi declares getLiveRoomStats (GET /live/rooms/{roomId}/stats)', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/live/rooms/{roomId}/stats')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`),
    ).toEqual(['getLiveRoomStats GET']);
  });
});

describe('D140 live statistics', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (country: string | null = null): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const u = { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
    if (country !== null) {
      const set = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ country });
      expect(set.status, JSON.stringify(set.body)).toBe(200);
    }
    return u;
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Stats', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status).toBe(200);
  };
  const hook = async (event: string, roomId: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomId }, participant: { identity } });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const join = (roomId: string, identity: string) => hook('participant_joined', roomId, identity);
  const leave = (roomId: string, identity: string) => hook('participant_left', roomId, identity);
  const stats = (roomId: string, u: TestUser | null): request.Test => {
    const req = ctx.http.get(`/api/v1/live/rooms/${roomId}/stats`);
    if (u) void req.set(auth(u));
    return req;
  };
  const statsOk = async (roomId: string, u: TestUser) => {
    const res = await stats(roomId, u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLiveRoomStats');
    return res.body as Record<string, unknown> & {
      viewers: Record<string, number> | null;
      viewerCountries: unknown[];
      topSupporters: { user: { username: string }; points: number }[];
    };
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (): Promise<string> => {
    const code = `st_${randomUUID().slice(0, 8)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 4,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    return code;
  };
  const send = async (roomId: string, from: TestUser, to: TestUser, code: string, quantity: number) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  /** Follows through the API; the row takes the database's time, so it is moved to the fake clock. */
  const follow = async (u: TestUser, h: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(u));
    expect(res.status).toBeLessThan(300);
    await ctx.prisma.follow.update({
      where: { followerId_followeeId: { followerId: u.id, followeeId: h.id } },
      data: { createdAt: clock.now() },
    });
  };
  const tap = async (roomId: string, u: TestUser, count: number) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('access: host only (403 for anyone else, 401 without a token, 404 for a missing room)', async () => {
    const h = await host();
    const other = await signup();
    const roomId = await goLive(h);
    const forbidden = await stats(roomId, other);
    expect(forbidden.status).toBe(403);
    expect(forbidden.body.error.code).toBe('AUTH_FORBIDDEN');
    expectContract(forbidden, 'getLiveRoomStats');
    expect((await stats(roomId, null)).status).toBe(401);
    const missing = await stats(MISSING_ROOM, h);
    expect(missing.status).toBe(404);
    expectContract(missing, 'getLiveRoomStats');
    expect((await stats('nope', h)).status).toBe(404);
    await end(roomId, h);
  });

  it('a live nobody watched: zeros, empty countries, no supporters', async () => {
    const h = await host();
    const roomId = await goLive(h);
    clock.advance(65);
    const live = await statsOk(roomId, h);
    expect(live).toMatchObject({
      roomId,
      status: 'LIVE',
      endedAt: null,
      durationSeconds: 65,
      score: { total: 0, tapPoints: 0, supportPoints: 0 },
      hostOwnPoints: 0,
      supporters: 0,
      topSupporters: [],
      giftCount: 0,
      chatMessages: 0,
      newFollowers: 0,
      viewers: { unique: 0, guests: 0, peak: 0, atEnd: 0, averageWatchSeconds: 0 },
      viewerCountries: [],
    });
    clock.advance(10);
    await end(roomId, h);
    clock.advance(500); // reading later does not stretch the live
    const ended = await statsOk(roomId, h);
    expect(ended.status).toBe('ENDED');
    expect(ended.durationSeconds).toBe(75);
    expect(ended.endedAt).not.toBeNull();
  });

  it('audience: unique viewers, guests, peak, watch time and countries (top 5, OTHER, UNKNOWN)', async () => {
    const h = await host();
    const roomId = await goLive(h);
    // 9 signed-in viewers: SA ×3, EG ×2, JO, AE, KW, MA (6 countries → 5 named + OTHER)
    // + 1 without a country and 1 guest (UNKNOWN ×2).
    const countries = ['SA', 'SA', 'SA', 'EG', 'EG', 'JO', 'AE', 'KW', 'MA'];
    const people: TestUser[] = [];
    for (const c of countries) people.push(await signup(c));
    const noCountry = await signup();
    const guest = `guest:${randomUUID()}`;

    for (const p of people) await join(roomId, p.id);
    await join(roomId, noCountry.id);
    await join(roomId, guest);
    await join(roomId, h.id); // the host is never a viewer
    clock.advance(60);
    // Everyone but two leaves after 60 s; one comes back (still one unique viewer).
    for (const p of people.slice(0, 7)) await leave(roomId, p.id);
    await leave(roomId, noCountry.id);
    await join(roomId, people[0]!.id);
    await join(roomId, people[0]!.id); // a repeated webhook changes nothing
    clock.advance(30);

    const mid = await statsOk(roomId, h);
    expect(mid.viewers).toEqual({
      unique: 11,
      guests: 1,
      peak: 11,
      atEnd: 4, // people[0], people[7], people[8] and the guest
      // 11 × 60 s, + 30 s for the four still in = 780 s → 70.9 → 71 s
      averageWatchSeconds: 71,
    });
    expect(mid.viewerCountries).toEqual([
      { country: 'SA', viewers: 3, percent: 27.3 },
      { country: 'EG', viewers: 2, percent: 18.2 },
      { country: 'AE', viewers: 1, percent: 9.1 },
      { country: 'JO', viewers: 1, percent: 9.1 },
      { country: 'KW', viewers: 1, percent: 9.1 },
      { country: 'OTHER', viewers: 1, percent: 9.1 },
      { country: 'UNKNOWN', viewers: 2, percent: 18.2 },
    ]);

    // A kicked viewer stops counting watch time; the end closes everyone else's.
    const kicked = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/kicks`)
      .set(auth(h))
      .send({ username: people[8]!.username });
    expect(kicked.status, JSON.stringify(kicked.body)).toBe(201);
    clock.advance(10);
    await end(roomId, h);
    clock.advance(1000);
    const ended = await statsOk(roomId, h);
    // 780 + 10 s for the three still in after the kick = 810 s / 11 → 73.6 → 74 s.
    expect(ended.viewers).toMatchObject({ unique: 11, peak: 11, averageWatchSeconds: 74 });
    const open = await ctx.prisma.liveRoomAudience.count({ where: { roomId, openSince: { not: null } } });
    expect(open).toBe(0);
  });

  it('cherries, the host’s own share, supporters, top three, gifts, chat and new followers', async () => {
    const h = await host();
    const a = await signup('SA');
    const b = await signup('EG');
    const c = await signup('JO');
    const d = await signup();
    const before = await signup();
    await follow(before, h);
    clock.advance(5);
    const roomId = await goLive(h);
    for (const u of [a, b, c, d]) await join(roomId, u.id);
    const code = await gift();
    for (const u of [h, a, b]) await coins(u, 1_000);

    // The host gifts themself (D128) and taps (D120): counted in the score, not a supporter.
    await send(roomId, h, h, code, 1); // 4 coins → 400 points
    await send(roomId, h, h, code, 1); // and again: the host's own 800
    await tap(roomId, h, 1);
    await send(roomId, a, h, code, 1); // 400
    clock.advance(1);
    for (let i = 0; i < 3; i += 1) await send(roomId, b, h, code, 1); // 1 200 (quantities are the catalogue's)
    await tap(roomId, c, 5);
    clock.advance(1);
    await tap(roomId, d, 5); // same points as c, later → after c

    for (const [u, text] of [
      [a, 'hello'],
      [b, 'hi'],
      [h, 'welcome'],
    ] as const) {
      const sent = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/chat`)
        .set(auth(u))
        .send({ text, clientId: randomUUID() });
      expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    }
    for (const u of [a, b]) await follow(u, h);
    clock.advance(2);
    await end(roomId, h);
    clock.advance(5);
    const late = await signup();
    await follow(late, h); // after the end

    const s = await statsOk(roomId, h);
    expect(s.score).toEqual({ total: 2_411, tapPoints: 11, supportPoints: 2_400 });
    expect(s.hostOwnPoints).toBe(801);
    expect(s.supporters).toBe(4);
    expect(s.topSupporters.map((t) => [t.user.username, t.points])).toEqual([
      [b.username, 1_200],
      [a.username, 400],
      [c.username, 5],
    ]);
    expect(s.giftCount).toBe(6);
    expect(s.chatMessages).toBe(3);
    expect(s.newFollowers).toBe(2);
  });

  it('a live from before D140 (no audience record) has viewers null and no countries', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { peakViewerCount: null } });
    const s = await statsOk(roomId, h);
    expect(s.viewers).toBeNull();
    expect(s.viewerCountries).toEqual([]);
    await end(roomId, h);
  });
});
