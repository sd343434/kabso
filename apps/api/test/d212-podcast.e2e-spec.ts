/**
 * D212 (v1.47-live DRAFT, CONVENTIONS §10.69): the five live categories (the `kind` filter), the
 * PODCAST live (episode numbers, 4 speakers, raised hands as a queue with «لاحقاً», timed questions,
 * voice-only permissions), announced podcast episodes and the chat `join` gender — end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role and the in-memory media server.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveSeatsService } from '../src/modules/live/live-seats.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
  }
  advance(seconds: number): void {
    this.offset += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const PODCAST = { mode: 'PODCAST', podcast: { topic: 'business' } };

describe('D212 contract coverage', () => {
  it('declares the new operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain(
      'deferLiveSeatRequest POST /api/v1/live/rooms/{roomId}/seat-requests/{requestId}/defer',
    );
    expect(ids).toContain('listScheduledPodcasts GET /api/v1/live/podcasts/scheduled');
  });
});

describe('D212 live categories and podcasts', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (body: Record<string, unknown> = {}): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, body);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const start = (u: TestUser, body: object) =>
    ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'حلقة', ...body });
  const goLive = async (u: TestUser, body: object = PODCAST): Promise<string> => {
    const res = await start(u, body);
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const call = (
    method: 'get' | 'post' | 'put' | 'delete' | 'patch',
    path: string,
    u?: TestUser,
    body?: object,
  ): request.Test => {
    const req = ctx.http[method](`/api/v1/live/rooms/${path}`);
    if (u) void req.set(auth(u));
    return body === undefined ? req : req.send(body);
  };
  const hook = (event: string, room: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: room }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const watch = async (roomId: string, ...users: TestUser[]) => {
    for (const u of users) await hook('participant_joined', roomId, u.id).expect(200);
  };
  const seats = (roomId: string, u?: TestUser) => call('get', `${roomId}/seats`, u);
  const raise = (roomId: string, u: TestUser, body?: object) =>
    call('post', `${roomId}/seat-requests`, u, body);
  const queue = async (roomId: string, u: TestUser) => {
    const res = await call('get', `${roomId}/seat-requests`, u);
    expect(res.status).toBe(200);
    expectContract(res, 'listLiveSeatRequests');
    return res.body.data as {
      id: string;
      user: { id: string };
      question: string | null;
      deferred: boolean;
    }[];
  };
  const expectError = (res: request.Response, status: number, code: string, operationId: string) => {
    expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  it('starts a podcast: required setup, 4 speakers, per-host episode numbers, voice-only host', async () => {
    const h = await host();
    expectError(await start(h, { mode: 'PODCAST' }), 400, 'VALIDATION_FAILED', 'startLiveRoom');
    expectError(await start(h, { ...PODCAST, seatCount: 4 }), 400, 'VALIDATION_FAILED', 'startLiveRoom');
    expectError(
      await start(h, { mode: 'AUDIO', seatCount: 5, podcast: { topic: 'tech' } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    expectError(
      await start(h, { mode: 'PODCAST', podcast: { topic: 'tech', questionSeconds: 90 } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );

    const first = await start(h, PODCAST);
    expect(first.status).toBe(201);
    expectContract(first, 'startLiveRoom');
    expect(first.body).toMatchObject({
      mode: 'PODCAST',
      seatCount: 4,
      theme: 'podcast-studio',
      podcast: {
        episodeNumber: 1,
        topic: 'business',
        questionsOpen: true,
        questionSeconds: 120,
        speakers: [],
      },
    });
    const token = await call('post', `${first.body.id}/media-token`, h, {});
    expect(token.status).toBe(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['microphone'] });
    await end(first.body.id, h);

    // A video live in between does not take a number; the next episode is 2.
    await end(await goLive(h, { mode: 'SOLO' }), h);
    const second = await start(h, {
      mode: 'PODCAST',
      podcast: { topic: 'tech', questionsOpen: false, questionSeconds: null },
    });
    expect(second.status).toBe(201);
    expect(second.body.podcast).toMatchObject({
      episodeNumber: 2,
      topic: 'tech',
      questionsOpen: false,
      questionSeconds: null,
    });
    // Another host starts at 1.
    const other = await host();
    const third = await goLive(other);
    expect((await ctx.http.get(`/api/v1/live/rooms/${third}`)).body.podcast.episodeNumber).toBe(1);
    await end(second.body.id, h);
    await end(third, other);
  });

  it('filters the hub by category (kind), podcasts only under `podcast`', async () => {
    const [a, b, c, d] = [await host(), await host(), await host(), await host()];
    const podcast = await goLive(a);
    const audio = await goLive(b, { mode: 'AUDIO', seatCount: 5 });
    const solo = await goLive(c, { mode: 'SOLO' });
    const multi = await goLive(d, { mode: 'MULTI', seatCount: 4 });
    const ids = async (kind?: string) => {
      const res = await ctx.http.get(`/api/v1/live/rooms?tab=new&limit=50${kind ? `&kind=${kind}` : ''}`);
      expect(res.status).toBe(200);
      expectContract(res, 'listLiveRooms');
      return (res.body.data as { id: string }[]).map((r) => r.id);
    };
    expect(await ids('podcast')).toEqual([podcast]);
    const audioIds = await ids('audio');
    expect(audioIds).toContain(audio);
    expect(audioIds).not.toContain(podcast);
    expect(await ids('solo')).toContain(solo);
    expect(await ids('solo')).not.toContain(podcast);
    expect(await ids('multi')).toEqual(expect.arrayContaining([multi]));
    expect(await ids()).toEqual(expect.arrayContaining([podcast, audio, solo, multi]));
    const card = (await ctx.http.get('/api/v1/live/rooms?tab=new&kind=podcast')).body.data[0];
    expect(card.podcast).toMatchObject({ episodeNumber: 1, topic: 'business', speakers: [] });
    const page = await ctx.http.get('/api/v1/live/rooms?tab=new&kind=nope');
    expectError(page, 400, 'VALIDATION_FAILED', 'listLiveRooms');
    for (const [id, u] of [
      [podcast, a],
      [audio, b],
      [solo, c],
      [multi, d],
    ] as const)
      await end(id, u);
  });

  it('hands: questions, queue order, «لاحقاً», closed hands, the 3-speaker limit and permissions', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const [l1, l2, l3, l4, l5] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await watch(roomId, l1, l2, l3, l4, l5);

    // A listener publishes nothing until accepted.
    await call('post', `${roomId}/media-token`, l1, {}).expect(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: false });

    const r1 = await raise(roomId, l1, { question: '  كيف أختار الشريك المناسب؟  ' });
    expect(r1.status).toBe(201);
    expectContract(r1, 'requestLiveSeat');
    expect(r1.body).toMatchObject({ question: 'كيف أختار الشريك المناسب؟', deferred: false });
    expectError(
      await raise(roomId, l2, { question: 'x'.repeat(81) }),
      400,
      'VALIDATION_FAILED',
      'requestLiveSeat',
    );
    const r2 = await raise(roomId, l2);
    const r3 = await raise(roomId, l3);
    expect(r2.body.question).toBeNull();

    // Everyone (a guest too) sees the raised hands in queue order.
    const asGuest = await seats(roomId);
    expectContract(asGuest, 'getLiveRoomSeats');
    expect(asGuest.body).toMatchObject({ mode: 'PODCAST', seatCount: 4, handsUp: [l1.id, l2.id, l3.id] });

    // «لاحقاً» sends the first hand to the end; host only; outside a podcast → 409.
    expectError(
      await call('post', `${roomId}/seat-requests/${r1.body.id}/defer`, l4),
      403,
      'AUTH_FORBIDDEN',
      'deferLiveSeatRequest',
    );
    const deferred = await call('post', `${roomId}/seat-requests/${r1.body.id}/defer`, h);
    expect(deferred.status).toBe(200);
    expectContract(deferred, 'deferLiveSeatRequest');
    expect(deferred.body.handsUp).toEqual([l2.id, l3.id, l1.id]);
    const q = await queue(roomId, h);
    expect(q.map((r) => [r.user.id, r.deferred])).toEqual([
      [l2.id, false],
      [l3.id, false],
      [l1.id, true],
    ]);
    // Paging keeps the queue order.
    const p1 = await call('get', `${roomId}/seat-requests?limit=2`, h);
    const p2 = await call(
      'get',
      `${roomId}/seat-requests?limit=2&cursor=${encodeURIComponent(p1.body.page.nextCursor)}`,
      h,
    );
    expect([...p1.body.data, ...p2.body.data].map((r: { user: { id: string } }) => r.user.id)).toEqual([
      l2.id,
      l3.id,
      l1.id,
    ]);

    // «اصعد»: microphone only, a question time on the seat.
    const up = await call('post', `${roomId}/seat-requests/${r2.body.id}/accept`, h, {});
    expect(up.status).toBe(200);
    expectContract(up, 'acceptLiveSeatRequest');
    const seat1 = up.body.seats.find((s: { user: { id: string } | null }) => s.user?.id === l2.id);
    expect(new Date(seat1.demoteAt).getTime() - clock.now().getTime()).toBeGreaterThan(119_000);
    expect(media.lastPermission(roomId, l2.id)).toEqual({ visible: true, sources: ['microphone'] });
    expect(up.body.handsUp).toEqual([l3.id, l1.id]);

    // The host fills the other two seats with invitations (guests: no limit).
    for (const g of [l4, l5]) {
      await call('post', `${roomId}/seat-invites`, h, { username: g.username }).expect(201);
      await call('post', `${roomId}/seat-invites/me/accept`, g).expect(200);
    }
    const full = await seats(roomId, h);
    expect(
      full.body.seats.map((s: { state: string; demoteAt: string | null }) => [s.state, s.demoteAt === null]),
    ).toEqual([
      ['TAKEN', false],
      ['TAKEN', true],
      ['TAKEN', true],
    ]);
    // 4 speakers: a fourth accept finds no seat, yet hands still queue.
    expectError(
      await call('post', `${roomId}/seat-requests/${r3.body.id}/accept`, h, {}),
      409,
      'LIVE_SEAT_UNAVAILABLE',
      'acceptLiveSeatRequest',
    );
    expect((await queue(roomId, h)).map((r) => r.user.id)).toEqual([l3.id, l1.id]);

    // Closed hands: new hands refused, hands up stay; the switch is a podcast's only.
    const closed = await call('patch', roomId, h, { questionsOpen: false, questionSeconds: 60 });
    expect(closed.status).toBe(200);
    expect(closed.body.podcast).toMatchObject({ questionsOpen: false, questionSeconds: 60 });
    await call('delete', `${roomId}/seat-requests/me`, l3).expect(204);
    expectError(await raise(roomId, l3), 409, 'LIVE_QUESTIONS_CLOSED', 'requestLiveSeat');
    expect((await seats(roomId)).body.handsUp).toEqual([l1.id]);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'live.room.podcast', targetId: roomId } }),
    ).toBe(1);

    // A question goes with a podcast hand only.
    const audioHost = await host();
    const audio = await goLive(audioHost, { mode: 'AUDIO', seatCount: 5 });
    expectError(await raise(audio, l3, { question: 'سؤال' }), 400, 'VALIDATION_FAILED', 'requestLiveSeat');
    await end(audio, audioHost);
    await end(roomId, h);
  });

  it('a question ends: the speaker goes back to the listeners; no limit keeps them', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'PODCAST', podcast: { topic: 'society', questionSeconds: 60 } });
    const [a, b] = [await signup(), await signup()];
    await watch(roomId, a, b);
    const ra = await raise(roomId, a);
    await call('post', `${roomId}/seat-requests/${ra.body.id}/accept`, h, {}).expect(200);
    const sweeper = ctx.app.get(LiveSeatsService);
    expect(await sweeper.demoteExpired()).toBe(0);
    clock.advance(61);
    expect(await sweeper.demoteExpired()).toBe(1);
    const after = await seats(roomId, a);
    expect(after.body.mine).toMatchObject({ role: 'VIEWER', seatIndex: null });
    expect(media.lastPermission(roomId, a.id)).toEqual({ visible: false, sources: [] });

    // «بدون حد»: an accepted hand has no end.
    await call('patch', roomId, h, { questionSeconds: null }).expect(200);
    const rb = await raise(roomId, b);
    const up = await call('post', `${roomId}/seat-requests/${rb.body.id}/accept`, h, {});
    expect(up.body.seats[0]).toMatchObject({ state: 'TAKEN', demoteAt: null });
    clock.advance(1800); // well past any question time (the room stays fresh: stale after 3600 s)
    expect(await sweeper.demoteExpired()).toBe(0);
    expect((await seats(roomId, b)).body.mine.role).toBe('SEATED');

    // A podcast card in the hub shows its speakers.
    const card = (await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body;
    expect(card.podcast.speakers).toEqual([expect.objectContaining({ id: b.id, username: b.username })]);
    await end(roomId, h);
  });

  it('PATCH questionsOpen on a non-podcast → 400', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    expectError(
      await call('patch', roomId, h, { questionsOpen: true }),
      400,
      'VALIDATION_FAILED',
      'updateLiveRoom',
    );
    const r = await call(
      'post',
      `${roomId}/seat-requests`,
      await (async () => {
        const u = await signup();
        await watch(roomId, u);
        return u;
      })(),
    );
    expect(r.status).toBe(201);
    expectError(
      await call('post', `${roomId}/seat-requests/${r.body.id}/defer`, h),
      409,
      'LIVE_SEAT_UNAVAILABLE',
      'deferLiveSeatRequest',
    );
    await end(roomId, h);
  });

  it('announced episodes: topic rules, the hub list, the follower reminder, blocks', async () => {
    const h = await host();
    const fan = await signup();
    const at = new Date(clock.now().getTime() + 2 * 3600_000).toISOString();
    const slot = (body: object) => ctx.http.post('/api/v1/me/live-schedule').set(auth(h)).send(body);
    expectContract(await slot({ title: 'ep', startsAt: at, mode: 'PODCAST' }), 'createLiveScheduleSlot');
    expect((await slot({ title: 'ep', startsAt: at, mode: 'PODCAST' })).status).toBe(400);
    expect((await slot({ title: 'ep', startsAt: at, podcastTopic: 'tech' })).status).toBe(400);
    const plain = await slot({ title: 'عادي', startsAt: at });
    expect(plain.status).toBe(201);
    expect(plain.body).toMatchObject({ mode: null, podcastTopic: null });
    const ep = await slot({ title: 'الحلقة القادمة', startsAt: at, mode: 'PODCAST', podcastTopic: 'tech' });
    expect(ep.status).toBe(201);
    expectContract(ep, 'createLiveScheduleSlot');
    expect(ep.body).toMatchObject({ mode: 'PODCAST', podcastTopic: 'tech' });

    const listed = async (u?: TestUser) => {
      const req = ctx.http.get('/api/v1/live/podcasts/scheduled');
      const res = await (u ? req.set(auth(u)) : req);
      expect(res.status).toBe(200);
      expectContract(res, 'listScheduledPodcasts');
      return res.body.data as { id: string; reminder: boolean; host: { id: string } }[];
    };
    const mine = <T extends { id: string }>(rows: T[]) => rows.filter((r) => r.id === ep.body.id);
    expect(mine(await listed())).toEqual([
      expect.objectContaining({ title: 'الحلقة القادمة', reminder: false }),
    ]);
    expect((await listed()).some((r) => r.id === plain.body.id)).toBe(false);
    expect(mine(await listed(fan))[0]?.reminder).toBe(false);
    expect([200, 201, 204]).toContain(
      (await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(fan))).status,
    );
    expect(mine(await listed(fan))[0]?.reminder).toBe(true);
    // A block hides it.
    await ctx.prisma.userBlock.create({ data: { blockerId: h.id, blockedId: fan.id } });
    expect(mine(await listed(fan))).toEqual([]);
    // Past its start it is gone.
    clock.advance(3 * 3600);
    expect(mine(await listed())).toEqual([]);
  });

  it('announced episodes, security review (int7b): guests and callers see only ACTIVE hosting hosts, no block either way, no private fields, 7 days, at most 20', async () => {
    const now = clock.now().getTime();
    const episode = (hostUserId: string, inMs: number, title = 'ep') =>
      ctx.prisma.liveScheduleSlot.create({
        data: { hostUserId, title, startsAt: new Date(now + inMs), mode: 'PODCAST', podcastTopic: 'tech' },
      });
    const list = async (u?: TestUser) => {
      const req = ctx.http.get('/api/v1/live/podcasts/scheduled');
      const res = await (u ? req.set(auth(u)) : req);
      expect(res.status).toBe(200);
      expectContract(res, 'listScheduledPodcasts');
      return res.body.data as { id: string; startsAt: string; host: Record<string, unknown> }[];
    };
    const [open, suspended, pending, revoked, blockedByFan] = [
      await host(),
      await host(),
      await host(),
      await host(),
      await host(),
    ];
    const fan = await signup();
    const shown = await episode(open.id, 3600_000, 'shown');
    const late = await episode(open.id, 8 * 24 * 3600_000, 'next week');
    const hidden = [
      await episode(suspended.id, 3600_000),
      await episode(pending.id, 3600_000),
      await episode(revoked.id, 3600_000),
    ];
    const fanBlocked = await episode(blockedByFan.id, 3600_000);
    await ctx.prisma.user.update({ where: { id: suspended.id }, data: { status: 'SUSPENDED' } });
    await ctx.prisma.user.update({ where: { id: pending.id }, data: { status: 'PENDING_DELETION' } });
    await ctx.prisma.liveHost.delete({ where: { userId: revoked.id } });
    await ctx.prisma.userBlock.create({ data: { blockerId: fan.id, blockedId: blockedByFan.id } });

    const guest = await list();
    const ids = new Set(guest.map((r) => r.id));
    expect(ids.has(shown.id)).toBe(true);
    expect(ids.has(late.id)).toBe(false);
    for (const h of hidden) expect(ids.has(h.id)).toBe(false);
    // Guests have no blocks; the caller who blocked the host does not see the episode.
    expect(ids.has(fanBlocked.id)).toBe(true);
    expect((await list(fan)).some((r) => r.id === fanBlocked.id)).toBe(false);
    // Only UserSummary fields: no email or other private field anywhere in the answer.
    const raw = JSON.stringify(guest);
    expect(raw).not.toMatch(/email|dateOfBirth|phone|isPrivate/i);
    expect(Object.keys(guest.find((r) => r.id === shown.id)!).sort()).toEqual([
      'host',
      'id',
      'podcastTopic',
      'reminder',
      'startsAt',
      'title',
    ]);

    // At most 20, soonest first (two more hosts, 10 each: 22 listable episodes in the window).
    const [more1, more2] = [await host(), await host()];
    for (let i = 0; i < 20; i += 1) await episode(i % 2 === 0 ? more1.id : more2.id, (2 + i) * 3600_000);
    const capped = await list();
    expect(capped).toHaveLength(20);
    const starts = capped.map((r) => Date.parse(r.startsAt));
    expect(starts).toEqual([...starts].sort((a, b) => a - b));
    expect(starts.every((t) => t > clock.now().getTime() && t <= now + 7 * 24 * 3600_000)).toBe(true);
  });

  it('chat: each join is a line with the gender the joiner shows (else null)', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
    const [shown, hidden, none] = [await signup(), await signup(), await signup()];
    await ctx.prisma.userProfile.update({
      where: { userId: shown.id },
      data: { gender: 'FEMALE', showGender: true },
    });
    await ctx.prisma.userProfile.update({
      where: { userId: hidden.id },
      data: { gender: 'MALE', showGender: false },
    });
    for (const u of [shown, hidden, none]) {
      clock.advance(0.25); // D212: up to 5 a second per room
      await hook('participant_joined', roomId, u.id).expect(200);
    }
    const joins = media.broadcastsOf(roomId, 'join') as { user: { id: string }; gender: string | null }[];
    expect(joins.map((j) => [j.user.id, j.gender])).toEqual([
      [shown.id, 'FEMALE'],
      [hidden.id, null],
      [none.id, null],
    ]);
    await end(roomId, h);
  });
});
