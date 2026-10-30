/**
 * D170 (v1.41-live DRAFT, CONVENTIONS §10.40): a live goes on in the background; a VIDEO live whose
 * host stays away (the app in the background, the camera off) for LIVE_HOST_AWAY_TIMEOUT_SECONDS
 * (default 300 s) is ended by the sweeper with HOST_AWAY_TIMEOUT. End to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role; time from a FakeClock, the sweeper run by hand.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveRoomsService } from '../src/modules/live/live-rooms.service.js';
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

describe('D170 contract coverage', () => {
  it('openapi declares setLiveHostPresence (POST /live/rooms/{roomId}/host-presence)', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/live/rooms/{roomId}/host-presence')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`),
    ).toEqual(['setLiveHostPresence POST']);
  });
});

describe('D170 host away', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  let rooms: LiveRoomsService;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
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
      .send({ title: 'Away', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const presence = (roomId: string, u: TestUser | null, body: unknown) => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/host-presence`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const away = async (roomId: string, u: TestUser, value: boolean) => {
    const res = await presence(roomId, u, { away: value });
    expect(res.status, JSON.stringify(res.body)).toBe(204);
  };
  const room = async (roomId: string) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoom');
    return res.body as { status: string; endReason: string | null; endedAt: string | null };
  };
  const awaySince = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId }, select: { hostAwaySince: true } }))
      .hostAwaySince;

  beforeAll(async () => {
    // A long stale window: the clock moves minutes without heartbeats, and only the away rule is
    // under test (the stale case below moves past it on purpose).
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
    ]);
    rooms = ctx.app.get(LiveRoomsService);
  });
  afterAll(async () => ctx?.close());

  it('defaults to 5 minutes (LIVE_HOST_AWAY_TIMEOUT_SECONDS = 300)', () => {
    expect(ctx.config.live.hostAwayTimeoutSeconds).toBe(300);
  });

  it('a video (SOLO) live away for 5 minutes is ended with HOST_AWAY_TIMEOUT', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const since = clock.now();
    const res = await presence(roomId, h, { away: true });
    expect(res.status).toBe(204);
    expectContract(res, 'setLiveHostPresence');
    expect((await awaySince(roomId))?.toISOString()).toBe(since.toISOString());

    clock.advance(299);
    expect(await rooms.sweepHostAway()).toBe(0);
    expect((await room(roomId)).status).toBe('LIVE');

    clock.advance(1);
    expect(await rooms.sweepHostAway()).toBe(1);
    const ended = await room(roomId);
    expect(ended).toMatchObject({ status: 'ENDED', endReason: 'HOST_AWAY_TIMEOUT' });
    // endedAt: when the limit was reached.
    expect(ended.endedAt).toBe(new Date(since.getTime() + 300_000).toISOString());
    expect(
      await ctx.prisma.auditLog.count({
        where: {
          action: 'live.room.end',
          targetId: roomId,
          metadata: { path: ['reason'], equals: 'HOST_AWAY_TIMEOUT' },
        },
      }),
    ).toBe(1);

    // The same end flow as any other end: the host's heartbeat and presence say it ended, a new
    // live can start, and a second sweep ends nothing more.
    const beat = await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(h));
    expect(beat.status).toBe(409);
    expect(beat.body.error.code).toBe('LIVE_ROOM_ENDED');
    const late = await presence(roomId, h, { away: false });
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('LIVE_ROOM_ENDED');
    expectContract(late, 'setLiveHostPresence');
    expect(await rooms.sweepHostAway()).toBe(0);
    const again = await goLive(h);
    expect(again).not.toBe(roomId);
  });

  it('back before 5 minutes: not ended; a new away period starts from zero', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await away(roomId, h, true);
    clock.advance(240);
    await away(roomId, h, false);
    expect(await awaySince(roomId)).toBeNull();
    clock.advance(600);
    expect(await rooms.sweepHostAway()).toBe(0);
    expect((await room(roomId)).status).toBe('LIVE');

    // Away again: 4 min 59 s of this period (8 min away in total) does not end it.
    await away(roomId, h, true);
    clock.advance(299);
    expect(await rooms.sweepHostAway()).toBe(0);
    expect((await room(roomId)).status).toBe('LIVE');
    await away(roomId, h, false);
    clock.advance(3);
    expect(await rooms.sweepHostAway()).toBe(0);
    expect((await room(roomId)).status).toBe('LIVE');

    const end = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h));
    expect(end.status).toBe(200);
    expect(end.body.endReason).toBe('HOST_ENDED');
  });

  it('a repeated away keeps the first time (the 5 minutes are continuous)', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const since = clock.now();
    await away(roomId, h, true);
    clock.advance(200);
    await away(roomId, h, true);
    expect((await awaySince(roomId))?.toISOString()).toBe(since.toISOString());
    clock.advance(100);
    expect(await rooms.sweepHostAway()).toBe(1);
    expect(await room(roomId)).toMatchObject({ status: 'ENDED', endReason: 'HOST_AWAY_TIMEOUT' });
  });

  it('a MULTI (video with guests) live is a video live too', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'MULTI', seatCount: 6 });
    await away(roomId, h, true);
    clock.advance(300);
    expect(await rooms.sweepHostAway()).toBe(1);
    expect(await room(roomId)).toMatchObject({ status: 'ENDED', endReason: 'HOST_AWAY_TIMEOUT' });
  });

  it('an AUDIO live is never ended by this rule (nothing is stored)', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 10 });
    const res = await presence(roomId, h, { away: true });
    expect(res.status).toBe(204);
    expect(await awaySince(roomId)).toBeNull();
    clock.advance(1800);
    expect(await rooms.sweepHostAway()).toBe(0);
    expect((await room(roomId)).status).toBe('LIVE');
    // The heartbeat rule still applies to it as before.
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(h)).expect(204);
    const end = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h));
    expect(end.body.endReason).toBe('HOST_ENDED');
  });

  it('a stale room is left to the heartbeat rule (HEARTBEAT_TIMEOUT), not the away rule', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await away(roomId, h, true);
    clock.advance(3601);
    expect(await rooms.sweepHostAway()).toBe(0);
    await rooms.runSweep();
    expect(await room(roomId)).toMatchObject({ status: 'ENDED', endReason: 'HEARTBEAT_TIMEOUT' });
  });

  it('only the host may set it: others and missing rooms → 404, no token → 401, bad bodies → 400', async () => {
    const h = await host();
    const other = await signup();
    const roomId = await goLive(h);

    const stranger = await presence(roomId, other, { away: true });
    expect(stranger.status).toBe(404);
    expect(stranger.body.error.code).toBe('NOT_FOUND');
    expectContract(stranger, 'setLiveHostPresence');
    expect(await awaySince(roomId)).toBeNull();
    // Another host cannot set it on someone else's room either.
    const otherHost = await host();
    expect((await presence(roomId, otherHost, { away: true })).status).toBe(404);
    expect(await awaySince(roomId)).toBeNull();

    const anonymous = await presence(roomId, null, { away: true });
    expect(anonymous.status).toBe(401);
    expectContract(anonymous, 'setLiveHostPresence');
    expect((await presence(MISSING_ROOM, h, { away: true })).status).toBe(404);
    expect((await presence('nope', h, { away: true })).status).toBe(404);

    for (const body of [{}, { away: 'yes' }, { away: true, extra: 1 }]) {
      const bad = await presence(roomId, h, body);
      expect(bad.status, JSON.stringify(body)).toBe(400);
      expectContract(bad, 'setLiveHostPresence');
    }
    expect(await awaySince(roomId)).toBeNull();
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
  });
});
