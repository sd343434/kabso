/**
 * KL-065 / CP-012 (D95): live taps and the room score (openapi v1.8-live DRAFT, CONVENTIONS §10.10,
 * §10.4, §7), end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 *
 * Time: the counting rules read "now" from the injectable Clock; these tests move a FakeClock
 * instead of sleeping. The media server is the in-memory fake behind the LiveMediaProvider port,
 * which records the room metadata; kl063-livekit-real checks the score in a real LiveKit room.
 */
import { createHmac, hkdfSync } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveRoomMetadataService } from '../src/modules/live/live-metadata.service.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
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

describe('CP-012 contract coverage', () => {
  it('openapi declares tapLiveRoom (POST /live/rooms/{roomId}/taps)', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/live/rooms/{roomId}/taps')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`),
    ).toEqual(['tapLiveRoom POST']);
  });
});

describe('CP-012 live taps and the room score', () => {
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
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Taps', ...extra });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    expect(res.body.score).toBe(0);
    expect(res.body.scoreParts).toEqual({ total: 0, tapPoints: 0, supportPoints: 0 });
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'endLiveRoom');
    return res;
  };
  const tap = (roomId: string, u: TestUser | null, body: unknown = { count: 10 }): request.Test => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const tapOk = async (roomId: string, u: TestUser, count: number) => {
    const res = await tap(roomId, u, { count });
    expectContract(res, 'tapLiveRoom');
    expect(res.status).toBe(200);
    return res.body as {
      accepted: number;
      score: { total: number; tapPoints: number; supportPoints: number };
    };
  };
  const room = async (roomId: string, u?: TestUser) => {
    const req = ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'getLiveRoom');
    return res;
  };
  const tapper = (roomId: string, userId: string) =>
    ctx.prisma.liveRoomTapper.findUnique({ where: { roomId_userId: { roomId, userId } } });
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  describe('counting and the score', () => {
    it('counts each tap as 1 point; the room and the hub show the score', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);

      expect(await tapOk(roomId, v, 7)).toEqual({
        accepted: 7,
        score: { total: 7, tapPoints: 7, supportPoints: 0 },
      });
      clock.advance(1);
      expect(await tapOk(roomId, v, 4)).toEqual({
        accepted: 4,
        score: { total: 11, tapPoints: 11, supportPoints: 0 },
      });

      const detail = await room(roomId, v);
      expect(detail.status).toBe(200);
      expect(detail.body).toMatchObject({
        score: 11,
        scoreParts: { total: 11, tapPoints: 11, supportPoints: 0 },
      });
      // Guests read the score too (the room allows guests by default).
      expect((await room(roomId)).body.score).toBe(11);

      const list = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(auth(v));
      expectContract(list, 'listLiveRooms');
      expect(list.body.data.find((r: { id: string }) => r.id === roomId)).toMatchObject({ score: 11 });

      expect(await tapper(roomId, v.id)).toMatchObject({ counted: 11, lastBatchAt: clock.now() });
      expect(await ctx.prisma.liveRoomScore.findUnique({ where: { roomId } })).toMatchObject({
        tapPoints: BigInt(11),
        supportPoints: BigInt(0),
      });
      await end(roomId, h);
    });

    it('10 a second: at most floor(10 × seconds since the last counted batch); first batch at most 10', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);

      expect((await tapOk(roomId, v, 50)).accepted).toBe(10); // first batch in the room
      expect((await tapOk(roomId, v, 5)).accepted).toBe(0); // no time passed
      clock.advance(0.099);
      expect((await tapOk(roomId, v, 5)).accepted).toBe(0); // dropped batches do not move the time
      clock.advance(0.251); // 350 ms since the last counted batch
      expect((await tapOk(roomId, v, 50)).accepted).toBe(3);
      clock.advance(1.5);
      expect((await tapOk(roomId, v, 50)).accepted).toBe(15);
      clock.advance(1);
      expect((await tapOk(roomId, v, 4)).accepted).toBe(4); // never more than the batch
      clock.advance(30);
      const res = await tapOk(roomId, v, 50);
      expect(res).toEqual({ accepted: 50, score: { total: 82, tapPoints: 82, supportPoints: 0 } });
      expect((await tapper(roomId, v.id))?.counted).toBe(82);

      // Another viewer has their own allowance.
      const w = await signup();
      expect((await tapOk(roomId, w, 12)).accepted).toBe(10);
      await end(roomId, h);
    });

    it('concurrent batches of one caller never pass the limit (one transaction with row locks)', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);
      const results = await Promise.all(Array.from({ length: 6 }, () => tapOk(roomId, v, 10)));
      expect(results.reduce((sum, r) => sum + r.accepted, 0)).toBe(10);
      expect((await room(roomId)).body.scoreParts).toEqual({ total: 10, tapPoints: 10, supportPoints: 0 });
      // Several callers at once: each is counted, and the score is their sum.
      const others = [await signup(), await signup(), await signup()];
      clock.advance(1);
      await Promise.all(others.map((u) => tapOk(roomId, u, 8)));
      expect((await room(roomId)).body.score).toBe(34);
      await end(roomId, h);
    });

    it('10 000 a live: a caller never counts more in one room', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);
      expect((await tapOk(roomId, v, 10)).accepted).toBe(10);
      // Fixture: as if the caller had already tapped 9 995 times (counted taps and points agree).
      await ctx.prisma.liveRoomTapper.update({
        where: { roomId_userId: { roomId, userId: v.id } },
        data: { counted: 9_995, points: 9_995 },
      });
      await ctx.prisma.liveRoomScore.update({ where: { roomId }, data: { tapPoints: BigInt(9_995) } });
      await ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { score: BigInt(9_995) } });
      clock.advance(10);
      expect(await tapOk(roomId, v, 50)).toEqual({
        accepted: 5,
        score: { total: 10_000, tapPoints: 10_000, supportPoints: 0 },
      });
      clock.advance(10);
      expect((await tapOk(roomId, v, 50)).accepted).toBe(0);
      expect((await tapper(roomId, v.id))?.counted).toBe(10_000);
      // Another viewer still counts.
      expect((await tapOk(roomId, await signup(), 3)).accepted).toBe(3);
      await end(roomId, h);
    });

    it("the host's own taps count 0 (200)", async () => {
      const h = await host();
      const roomId = await goLive(h);
      expect(await tapOk(roomId, h, 10)).toEqual({
        accepted: 0,
        score: { total: 0, tapPoints: 0, supportPoints: 0 },
      });
      expect(await tapper(roomId, h.id)).toBeNull();
      expect(media.metadataWrites.filter((w) => w.room === roomId)).toEqual([]);
      await end(roomId, h);
    });

    it('seated guests and moderators count like any viewer', async () => {
      const h = await host();
      const [guest, mod] = [await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      const asked = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/seat-requests`)
        .set(auth(guest))
        .send({});
      expect(asked.status).toBe(201);
      await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/seat-requests/${asked.body.id}/accept`)
        .set(auth(h))
        .send({})
        .expect(200);
      await ctx.http.put(`/api/v1/live/rooms/${roomId}/moderators/${mod.username}`).set(auth(h)).expect(200);

      expect((await tapOk(roomId, guest, 6)).accepted).toBe(6);
      expect((await tapOk(roomId, mod, 4)).accepted).toBe(4);
      expect((await tapOk(roomId, h, 9)).accepted).toBe(0);
      expect((await room(roomId)).body.scoreParts).toEqual({ total: 10, tapPoints: 10, supportPoints: 0 });
      await end(roomId, h);
    });
  });

  describe('errors', () => {
    it('a guest without an account → 401', async () => {
      const h = await host();
      const roomId = await goLive(h);
      const res = await tap(roomId, null);
      expectContract(res, 'tapLiveRoom');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('AUTH_UNAUTHENTICATED');
      await end(roomId, h);
    });

    it('an ended room → 409 LIVE_ROOM_ENDED, and it keeps its final score', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);
      expect((await tapOk(roomId, v, 9)).accepted).toBe(9);
      const ended = await end(roomId, h);
      expect(ended.body).toMatchObject({
        status: 'ENDED',
        score: 9,
        scoreParts: { total: 9, tapPoints: 9, supportPoints: 0 },
      });
      clock.advance(5);
      const res = await tap(roomId, v, { count: 5 });
      expectContract(res, 'tapLiveRoom');
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('LIVE_ROOM_ENDED');
      expect((await room(roomId, v)).body).toMatchObject({ status: 'ENDED', score: 9 });
      // A new live starts at 0.
      const next = await goLive(h);
      expect((await room(next)).body.scoreParts).toEqual({ total: 0, tapPoints: 0, supportPoints: 0 });
      await end(next, h);
    });

    it('an unknown, malformed or blocked room → 404', async () => {
      const h = await host();
      const [v, blocked] = [await signup(), await signup()];
      const roomId = await goLive(h);
      for (const id of [MISSING_ROOM, 'not-a-uuid']) {
        const res = await tap(id, v);
        expectContract(res, 'tapLiveRoom');
        expect({ id, status: res.status, code: res.body.error?.code }).toEqual({
          id,
          status: 404,
          code: 'NOT_FOUND',
        });
      }
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(h)).expect(200);
      expect((await tap(roomId, blocked)).status).toBe(404);
      expect(await ctx.prisma.liveRoomTapper.count({ where: { roomId } })).toBe(0);
      await end(roomId, h);
    });

    it('validates the body: count 1–50, an integer, required, no other fields → 400', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);
      const cases: [unknown, string][] = [
        [{ count: 0 }, 'too_small'],
        [{ count: 51 }, 'too_big'],
        [{}, 'required'],
        [{ count: 1.5 }, ''],
        [{ count: '5' }, 'invalid_type'],
        [{ count: 5, extra: 1 }, 'unknown_field'],
      ];
      for (const [body, issue] of cases) {
        const res = await tap(roomId, v, body);
        expectContract(res, 'tapLiveRoom');
        expect({ body, status: res.status, code: res.body.error?.code }).toEqual({
          body,
          status: 400,
          code: 'VALIDATION_FAILED',
        });
        const detail = res.body.error.details[0] as { field: string; issue: string };
        if (issue === 'unknown_field') expect(detail).toEqual({ field: 'extra', issue });
        else expect(detail.field).toBe('count');
        if (issue && issue !== 'unknown_field') expect(detail.issue).toBe(issue);
      }
      // No body at all is a missing count.
      const empty = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(v));
      expect(empty.status).toBe(400);
      // Validation comes first: a bad body on an unknown room is still 400.
      expect((await tap(MISSING_ROOM, v, { count: 0 })).status).toBe(400);
      expect(await tapper(roomId, v.id)).toBeNull();
      await end(roomId, h);
    });
  });

  describe('popular order and paging (§10.4)', () => {
    const forge = (payload: unknown): string => {
      const key = Buffer.from(hkdfSync('sha256', ctx.config.live.cursorKey, 'kabso', 'live-cursor/v1', 32));
      const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
      const tag = createHmac('sha256', key).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
      return `${body}.${tag.toString('base64url')}`;
    };

    it('orders by score desc, then startedAt desc, then id desc; pages with the v2 cursor', async () => {
      // Only this test's rooms are live.
      await ctx.prisma.liveRoom.updateMany({
        where: { status: 'LIVE' },
        data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
      });
      const viewer = await signup();
      const tappers = [await signup(), await signup(), await signup()];
      const hosts = [await host(), await host(), await host(), await host(), await host()];
      const ids: string[] = [];
      for (const h of hosts) {
        ids.push(await goLive(h));
        clock.advance(1);
      }
      const [r0, r1, r2, r3, r4] = ids as [string, string, string, string, string];
      // Scores: r1 = 20 (two tappers), r3 = 10, r0 = 10 (r3 started later), r2 = r4 = 0.
      await tapOk(r1, tappers[0]!, 10);
      await tapOk(r1, tappers[1]!, 10);
      await tapOk(r3, tappers[0]!, 10);
      await tapOk(r0, tappers[2]!, 10);
      // A high viewer count no longer moves a room up (v1.8-live).
      await ctx.prisma.liveRoom.update({ where: { id: r2 }, data: { viewerCount: 500 } });
      const expected = [r1, r3, r0, r4, r2];

      const pages: string[][] = [];
      let cursor: string | undefined;
      do {
        const res = await ctx.http
          .get('/api/v1/live/rooms')
          .query({ tab: 'popular', limit: 2, ...(cursor ? { cursor } : {}) })
          .set(auth(viewer));
        expectContract(res, 'listLiveRooms');
        expect(res.status).toBe(200);
        pages.push(res.body.data.map((r: { id: string }) => r.id));
        cursor = res.body.page.nextCursor ?? undefined;
        if (cursor) {
          const payload = JSON.parse(Buffer.from(cursor.split('.')[0]!, 'base64url').toString()) as {
            v: number;
            n: number;
          };
          const last = res.body.data.at(-1) as { score: number };
          expect(payload).toMatchObject({ v: 2, n: last.score });
        }
      } while (cursor);
      expect(pages).toEqual([[r1, r3], [r0, r4], [r2]]);
      expect(pages.flat()).toEqual(expected);

      // `new` keeps its order (startedAt desc).
      const fresh = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(auth(viewer));
      expect(fresh.body.data.map((r: { id: string }) => r.id)).toEqual([r4, r3, r2, r1, r0]);
      // Every card carries the score.
      expect(
        Object.fromEntries(fresh.body.data.map((r: { id: string; score: number }) => [r.id, r.score])),
      ).toEqual({ [r0]: 10, [r1]: 20, [r2]: 0, [r3]: 10, [r4]: 0 });

      // A popular cursor of the v1 format (viewerCount) is rejected: 400 cursor / invalid_value.
      for (const tab of ['popular', 'new'] as const) {
        const v1 = forge({ v: 1, t: tab, c: null, u: null, n: 0, s: clock.now().getTime(), i: r1 });
        const res = await ctx.http.get('/api/v1/live/rooms').query({ tab, cursor: v1 }).set(auth(viewer));
        expectContract(res, 'listLiveRooms');
        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_FAILED');
        expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      // A forged v2 cursor at a big score still binds (int8).
      const big = forge({ v: 2, t: 'popular', c: null, u: null, n: 2 ** 40, s: 0, i: r1 });
      const bigRes = await ctx.http
        .get('/api/v1/live/rooms')
        .query({ tab: 'popular', cursor: big })
        .set(auth(viewer));
      expect(bigRes.status).toBe(200);

      // Ties on score and startedAt fall back to id desc.
      await ctx.prisma.liveRoom.updateMany({
        where: { id: { in: [r2, r4] } },
        data: { startedAt: new Date(clock.now().getTime() - 60_000) },
      });
      const tie = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'popular' }).set(auth(viewer));
      const tail = tie.body.data.slice(3).map((r: { id: string }) => r.id);
      expect(tail).toEqual([r2, r4].sort().reverse());
      for (const [i, h] of hosts.entries()) await end(ids[i]!, h);
    });
  });

  describe('live updates: the score in the media room metadata (§10.10)', () => {
    const meta = (roomId: string) => JSON.parse(media.metadata.get(roomId) ?? 'null') as unknown;
    const writes = (roomId: string) => media.metadataWrites.filter((w) => w.room === roomId);

    it('writes {"seatsVersion","score"} at once, then at most every 2 s with a trailing write', async () => {
      const h = await host();
      const [a, b] = [await signup(), await signup()];
      const roomId = await goLive(h);
      expect(writes(roomId)).toEqual([]);

      await tapOk(roomId, a, 10);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 10 });
      expect(writes(roomId)).toHaveLength(1);

      // Inside the 2 s window: no write yet, one trailing write pending.
      clock.advance(1.9);
      await tapOk(roomId, b, 5);
      await tapOk(roomId, a, 10);
      expect(writes(roomId)).toHaveLength(1);
      const metadata = ctx.app.get(LiveRoomMetadataService);
      expect(metadata.pendingScoreWrites()).toContain(roomId);
      // The trailing write lands ~100 ms later (real timer) with the last value.
      for (let i = 0; i < 40 && writes(roomId).length < 2; i += 1)
        await new Promise((r) => setTimeout(r, 50));
      expect(writes(roomId)).toHaveLength(2);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 25 });

      // 2 s later on the clock: immediate again.
      clock.advance(2);
      await tapOk(roomId, b, 5);
      expect(writes(roomId)).toHaveLength(3);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 30 });
      // A batch that counts nothing writes nothing.
      await tapOk(roomId, h, 5);
      expect(writes(roomId)).toHaveLength(3);
      await end(roomId, h);
    });

    it('seat changes keep the score and taps keep the seat version (one merged metadata)', async () => {
      const h = await host();
      const [guest, v] = [await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
      await tapOk(roomId, v, 8);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 8 });

      const asked = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/seat-requests`)
        .set(auth(guest))
        .send({});
      expect(asked.status).toBe(201);
      expect(meta(roomId)).toEqual({ seatsVersion: 1, score: 8 });

      clock.advance(3);
      await tapOk(roomId, guest, 2);
      expect(meta(roomId)).toEqual({ seatsVersion: 1, score: 10 });
      expect(media.metadata.get(roomId)).toBe('{"seatsVersion":1,"score":10}');
      await end(roomId, h);
    });

    it('reconciliation repairs metadata that lost the score', async () => {
      const h = await host();
      const v = await signup();
      const roomId = await goLive(h);
      await hook('participant_joined', roomId, v.id).expect(200); // the room is open on the server
      clock.advance(3);
      await tapOk(roomId, v, 6);
      media.metadata.set(roomId, JSON.stringify({ seatsVersion: 0 }));
      await ctx.app.get(LiveMediaService).reconcile();
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 6 });
      // A room nobody tapped and without seats gets no metadata.
      const quietHost = await host();
      const quiet = await goLive(quietHost);
      await hook('participant_joined', quiet, v.id).expect(200);
      await ctx.app.get(LiveMediaService).reconcile();
      expect(writes(quiet)).toEqual([]);
      await end(roomId, h);
      await end(quiet, quietHost);
    });
  });
});

describe('CP-012 rate limit (§7): 120 / min per user, replacing the default bucket', () => {
  let limited: TestContext;
  beforeAll(async () => {
    limited = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_LIVE_TAPS_USER: '3/60',
      // The taps bucket replaces the default per-user bucket, so this one is never reached.
      RATE_LIMIT_AUTHENTICATED_USER: '1/900',
    });
  });
  afterAll(async () => limited?.close());

  it('the 4th batch in the window → 429', async () => {
    const reg = async () => {
      const { res } = await registerVerified(limited);
      return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
    };
    const [h, v] = [await reg(), await reg()];
    await limited.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const bearer = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
    const created = await limited.http.post('/api/v1/live/rooms').set(bearer(h)).send({ title: 'Limited' });
    expect(created.status).toBe(201);
    const path = `/api/v1/live/rooms/${created.body.id}/taps`;
    for (let i = 0; i < 3; i += 1) {
      const ok = await limited.http.post(path).set(bearer(v)).send({ count: 1 });
      expect(ok.status).toBe(200);
    }
    const limitedRes = await limited.http.post(path).set(bearer(v)).send({ count: 1 });
    expectContract(limitedRes, 'tapLiveRoom');
    expect(limitedRes.status).toBe(429);
    expect(limitedRes.body.error.code).toBe('RATE_LIMITED');
  });
});
