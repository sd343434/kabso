/**
 * KL-095 / owner D138 (openapi v1.27.5-live DRAFT, CONVENTIONS §10.30, §7): an emoji played once on
 * one's own seat, end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 * The media server is the in-memory fake behind the LiveMediaProvider port, which records the data
 * messages; the clock is fake, so the 2-second counting rule is tested without waiting.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
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

describe('v1.27.5-live contract coverage', () => {
  it('openapi declares sendLiveSeatEmoji', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('sendLiveSeatEmoji POST /api/v1/live/rooms/{roomId}/seat-emoji');
  });
});

describe('D138 an emoji on one’s own seat', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

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
  const goLive = async (u: TestUser, extra: object): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Seat emoji', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const join = async (roomId: string, u: TestUser) => {
    expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
  };
  /** `u` joins and sits on a seat (asked and accepted by the host). */
  const seat = async (roomId: string, h: TestUser, u: TestUser) => {
    await join(roomId, u);
    const asked = await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(u)).send({});
    expect(asked.status, JSON.stringify(asked.body)).toBe(201);
    const accepted = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/seat-requests/${asked.body.id}/accept`)
      .set(auth(h))
      .send({});
    expect(accepted.status).toBe(200);
    const seats = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seats`).set(auth(h));
    return (seats.body.seats as { index: number; user: { id: string } | null }[]).find(
      (s) => s.user?.id === u.id,
    )!.index;
  };
  const send = (roomId: string, by: TestUser | null, body: unknown): request.Test => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-emoji`);
    if (by) void req.set(auth(by));
    return req.send(body as object);
  };
  const sendOk = async (roomId: string, by: TestUser, token: string) => {
    const res = await send(roomId, by, { token });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'sendLiveSeatEmoji');
    return res.body as {
      id: string;
      seat: number;
      user: { id: string; username: string };
      token: string;
      createdAt: string;
    };
  };
  const expectCode = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, 'sendLiveSeatEmoji');
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('AUDIO: the host plays on tile 0, someone seated on their seat; the room gets `seat-emoji`', async () => {
    const h = await host();
    const v = await signup();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    const index = await seat(roomId, h, v);
    expect(index).toBeGreaterThan(0);

    const mine = await sendOk(roomId, h, ':kabi_love:');
    expect(mine).toEqual({
      id: expect.any(String),
      seat: 0,
      user: { id: h.id, username: h.username, displayName: expect.any(String), avatarUrl: null },
      token: ':kabi_love:',
      createdAt: clock.now().toISOString(),
    });
    const theirs = await sendOk(roomId, v, ':flags_ps:');
    expect(theirs.seat).toBe(index);
    expect(theirs.user.id).toBe(v.id);

    const data = media.broadcasts.filter((b) => b.room === roomId && b.topic === 'seat-emoji');
    expect(data.map((b) => JSON.parse(b.payload) as unknown)).toEqual([
      { type: 'seat-emoji', ...mine },
      { type: 'seat-emoji', ...theirs },
    ]);
  });

  it('one every 2 s per user (429 with Retry-After); others are not held back', async () => {
    const h = await host();
    const v = await signup();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    await seat(roomId, h, v);
    await sendOk(roomId, v, ':kiki_clap:');
    clock.advance(1);
    const again = await send(roomId, v, { token: ':kiki_clap:' });
    expectCode(again, 429, 'RATE_LIMITED');
    expect(Number(again.headers['retry-after'])).toBeGreaterThanOrEqual(1);
    await sendOk(roomId, h, ':dubi_hug:');
    clock.advance(1);
    await sendOk(roomId, v, ':neno_rose:');
    expect(media.broadcastsOf(roomId, 'seat-emoji')).toHaveLength(3);
  });

  it('400 for the token, 401 without an account, 404 for a room the caller cannot see', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    const before = media.broadcastsOf(roomId, 'seat-emoji').length;
    for (const [body, issue] of [
      [{}, 'required'],
      [{ token: ':kabi_nope:' }, 'invalid_value'],
      [{ token: '😀' }, 'invalid_value'],
      [{ token: 'hello :kabi_love:' }, 'invalid_value'],
    ] as const) {
      const res = await send(roomId, h, body);
      expectCode(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'token', issue }]);
    }
    const extra = await send(roomId, h, { token: ':kabi_love:', seat: 3 });
    expect(extra.status).toBe(400);
    expect((await send(roomId, null, { token: ':kabi_love:' })).status).toBe(401);
    expectCode(await send(MISSING_ROOM, h, { token: ':kabi_love:' }), 404, 'NOT_FOUND');
    expect(media.broadcastsOf(roomId, 'seat-emoji')).toHaveLength(before);
  });

  it('409 LIVE_SEAT_UNAVAILABLE: a viewer not seated, and a video live without seats', async () => {
    const h = await host();
    const viewer = await signup();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    await join(roomId, viewer);
    expectCode(await send(roomId, viewer, { token: ':kabi_hi:' }), 409, 'LIVE_SEAT_UNAVAILABLE');

    const soloHost = await host();
    const solo = await goLive(soloHost, {});
    expectCode(await send(solo, soloHost, { token: ':kabi_hi:' }), 409, 'LIVE_SEAT_UNAVAILABLE');
    expect(media.broadcastsOf(roomId, 'seat-emoji')).toHaveLength(0);
    expect(media.broadcastsOf(solo, 'seat-emoji')).toHaveLength(0);
  });

  it('MULTI: a seated guest plays on their seat', async () => {
    const h = await host();
    const g = await signup();
    const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
    const index = await seat(roomId, h, g);
    expect((await sendOk(roomId, g, ':gogo_roar:')).seat).toBe(index);
  });

  it('403 LIVE_KICKED for someone kicked out; 409 LIVE_ROOM_ENDED once the live ends', async () => {
    const h = await host();
    const v = await signup();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    await seat(roomId, h, v);
    const kicked = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/kicks`)
      .set(auth(h))
      .send({ username: v.username });
    expect(kicked.status).toBe(201);
    expectCode(await send(roomId, v, { token: ':kabi_hi:' }), 403, 'LIVE_KICKED');

    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h))).status).toBe(200);
    expectCode(await send(roomId, h, { token: ':kabi_hi:' }), 409, 'LIVE_ROOM_ENDED');
  });
});
