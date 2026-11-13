/**
 * D351 (v1.113-live, CONVENTIONS §10.148): the capacity guard «حد الامتلاء» on `startLiveRoom`.
 *
 * - Off by default (LIVE_CAPACITY_MAX_ROOMS 0): going live is unchanged, however many lives run.
 * - On: a go-live that does not fit → 503 LIVE_CAPACITY_FULL + `Retry-After` (as documented in openapi); nothing is
 *   created; a viewer's and a guest's media token, a seat, a PK invitation between the lives that run and the host's
 *   heartbeat are never refused; an ended (or stale) live frees its place; concurrent go-lives never overshoot;
 *   audio / podcast rooms are lighter; a caller already live still gets 409; a bypass user is never refused; the
 *   refusals are counted per UTC day in Redis.
 */
import { randomUUID } from 'node:crypto';
import { Redis } from 'ioredis';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { refusalsKey } from '../src/modules/live/live-capacity.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, resetDatabase, type TestContext } from './helpers/test-app.js';
import { startLegacyMulti } from './helpers/legacy-multi.js';

interface TestUser {
  readonly id: string;
  readonly token: string;
}

const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

function helpers(ctx: () => TestContext) {
  const signup = async (host = true): Promise<TestUser> => {
    const { res } = await registerVerified(ctx());
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const u = { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
    if (host) await ctx().prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const start = (u: TestUser, body: object = {}): request.Test =>
    ctx()
      .http.post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'D351 حد الامتلاء', ...body });
  const live = async (u: TestUser, body: object = {}): Promise<string> => {
    const res = await start(u, body);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const expectFull = (res: request.Response, retryAfter: string) => {
    expect({ status: res.status, code: res.body.error?.code }).toEqual({
      status: 503,
      code: 'LIVE_CAPACITY_FULL',
    });
    expect(res.headers['retry-after']).toBe(retryAfter);
    expect(res.body.error.message).toBe('Live is busy right now, please try again shortly.');
    expectContract(res, 'startLiveRoom');
  };
  const liveCount = () => ctx().prisma.liveRoom.count({ where: { status: 'LIVE' } });
  return { signup, start, live, expectFull, liveCount };
}

describe('D351 capacity guard — off by default', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const h = helpers(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('every host goes live as before, in every mode', async () => {
    expect(ctx.config.live.capacity.maxRooms).toBe(0);
    // v1.116-live (D369): MULTI is retired (400 `mode`, d239 / kl064 cover it); the video podcast (D363) instead.
    for (const body of [
      {},
      { mode: 'PODCAST', podcast: { topic: 'business', video: true } },
      { mode: 'AUDIO', seatCount: 5 },
      { mode: 'STREAMER' },
    ]) {
      await h.live(await h.signup(), body);
    }
    expect(await h.liveCount()).toBe(4);
  });
});

describe('D351 capacity guard — on', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  let redis: Redis;
  const h = helpers(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      LIVE_CAPACITY_MAX_ROOMS: '1',
      LIVE_CAPACITY_RETRY_AFTER_SECONDS: '45',
    });
    redis = new Redis(ctx.config.redis.url, { keyPrefix: ctx.config.redis.keyPrefix });
  });
  afterAll(async () => {
    redis?.disconnect();
    await ctx?.close();
  });

  it('refuses the go-live that does not fit, never touches the live that runs, and frees the place on end', async () => {
    const a = await h.signup();
    const b = await h.signup();
    const viewer = await h.signup(false);
    // A running (legacy) MULTI room — D369: no longer started, but one started before runs on.
    const roomA = await startLegacyMulti(ctx, a.token, { seatCount: 4 });

    const refused = await h.start(b);
    h.expectFull(refused, '45');
    expect(await ctx.prisma.liveRoom.count({ where: { hostUserId: b.id } })).toBe(0);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'live.room.start', actorUserId: b.id } })).toBe(
      0,
    );
    h.expectFull(await h.start(b, { mode: 'STREAMER' }), '45');

    // The live that runs: viewer and guest tokens, a seat, the heartbeat — never refused.
    const viewerToken = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/media-token`)
      .set(auth(viewer))
      .send({});
    expect(viewerToken.status, JSON.stringify(viewerToken.body)).toBe(200);
    const guestToken = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/media-token`)
      .send({ guestId: randomUUID() });
    expect(guestToken.status, JSON.stringify(guestToken.body)).toBe(200);
    const asked = await ctx.http.post(`/api/v1/live/rooms/${roomA}/seat-requests`).set(auth(viewer)).send({});
    expect([200, 201], JSON.stringify(asked.body)).toContain(asked.status);
    const seated = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/seat-requests/${asked.body.id as string}/accept`)
      .set(auth(a))
      .send({});
    expect(seated.status, JSON.stringify(seated.body)).toBe(200);
    const seatToken = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/media-token`)
      .set(auth(viewer))
      .send({});
    expect(seatToken.status).toBe(200);
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomA}/heartbeat`).set(auth(a)).send({})).status).toBe(
      204,
    );
    const hostToken = await ctx.http.post(`/api/v1/live/rooms/${roomA}/media-token`).set(auth(a)).send({});
    expect(hostToken.status).toBe(200);

    // A caller who is already live keeps the 409.
    const again = await h.start(a);
    expect({ status: again.status, code: again.body.error?.code }).toEqual({
      status: 409,
      code: 'LIVE_ROOM_ALREADY_ACTIVE',
    });

    // Ending the live frees its place.
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomA}/end`).set(auth(a)).send({})).status).toBe(200);
    await h.live(b);
    expect(await h.liveCount()).toBe(1);

    // Two refusals counted today (UTC).
    expect(await redis.get(refusalsKey(new Date()))).toBe('2');
  });

  it('a stale live (no heartbeat) stops counting', async () => {
    await resetDatabase();
    const a = await h.signup();
    const b = await h.signup();
    const roomA = await h.live(a);
    h.expectFull(await h.start(b), '45');
    const old = new Date(Date.now() - (ctx.config.live.heartbeatStaleSeconds + 60) * 1000);
    await ctx.prisma.liveRoom.update({
      where: { id: roomA },
      data: { startedAt: old, lastHeartbeatAt: old },
    });
    await h.live(b);
  });
});

describe('D351 capacity guard — PK between lives that run', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const h = helpers(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_CAPACITY_MAX_ROOMS: '2' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('a PK invitation and its acceptance are never refused while full', async () => {
    const a = await h.signup();
    const b = await h.signup();
    const c = await h.signup();
    const roomA = await h.live(a);
    const roomB = await h.live(b);
    h.expectFull(await h.start(c), '60');
    const inv = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/pk/invites`)
      .set(auth(a))
      .send({ toRoomId: roomB });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await ctx.http
      .post(`/api/v1/live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`)
      .set(auth(b))
      .send({});
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    expect(await h.liveCount()).toBe(2);
  });
});

describe('D351 capacity guard — weights, bypass and concurrency', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const h = helpers(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      LIVE_CAPACITY_MAX_ROOMS: '3',
      LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT: '50',
    });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('audio and podcast rooms weigh the audio weight; a video room needs a whole place', async () => {
    await h.live(await h.signup()); // 100 of 300
    await h.live(await h.signup(), { mode: 'AUDIO', seatCount: 5 }); // 150
    await h.live(await h.signup(), { mode: 'PODCAST', podcast: { topic: 'business' } }); // 200
    await h.live(await h.signup(), { mode: 'AUDIO', seatCount: 5 }); // 250
    h.expectFull(await h.start(await h.signup()), '60'); // 350 > 300
    await h.live(await h.signup(), { mode: 'AUDIO', seatCount: 5 }); // 300
    h.expectFull(await h.start(await h.signup(), { mode: 'AUDIO', seatCount: 5 }), '60'); // 350 > 300
    expect(await h.liveCount()).toBe(5);
  });

  it('never refuses a bypass user, whose live still counts', async () => {
    const vip = await h.signup();
    const other = await h.signup();
    // LIVE_CAPACITY_BYPASS_USER_IDS is read on every go-live; the account ids are random, so the test sets it here
    // (the parsing is covered by live-capacity.spec.ts).
    const capacity = ctx.config.live.capacity as { bypassUserIds: readonly string[] };
    capacity.bypassUserIds = [vip.id];
    try {
      // Still full (300 of 300 from the test above): the bypass user goes live, nobody else does.
      await h.live(vip);
      h.expectFull(await h.start(other), '60');
      expect(await h.liveCount()).toBe(6);
    } finally {
      capacity.bypassUserIds = [];
    }
  });

  it('concurrent go-lives never overshoot the ceiling', async () => {
    await resetDatabase();
    const hosts = await Promise.all(Array.from({ length: 9 }, () => h.signup()));
    const answers = await Promise.all(hosts.map((u) => h.start(u)));
    const statuses = answers.map((r) => r.status).sort();
    expect(statuses.filter((s) => s === 201)).toHaveLength(3);
    expect(statuses.filter((s) => s === 503)).toHaveLength(6);
    for (const r of answers.filter((x) => x.status === 503))
      expect(r.body.error.code).toBe('LIVE_CAPACITY_FULL');
    expect(await h.liveCount()).toBe(3);
  });
});
