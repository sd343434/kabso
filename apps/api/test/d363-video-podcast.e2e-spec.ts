/**
 * D363 (v1.114-live DRAFT, CONVENTIONS §10.157): the video podcast «بودكاست فيديو» — the flag on rooms and announced
 * episodes, camera grants for the host and speakers, the capacity weight, guest titles, question upvotes, the hot
 * seat «الكرسي الساخن» and the director relay — end to end against PostgreSQL + Redis with the API as the DML-only
 * runtime role and the in-memory media server. Audio podcasts are checked to stay exactly as D212 made them.
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

const VIDEO = { mode: 'PODCAST', podcast: { topic: 'tech', video: true } };
const AUDIO = { mode: 'PODCAST', podcast: { topic: 'tech' } };

describe('D363 contract coverage', () => {
  it('declares the new operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'voteLivePodcastQuestion PUT /api/v1/live/rooms/{roomId}/seat-requests/{requestId}/vote',
        'unvoteLivePodcastQuestion DELETE /api/v1/live/rooms/{roomId}/seat-requests/{requestId}/vote',
        'setLivePodcastDirector PUT /api/v1/live/rooms/{roomId}/podcast/director',
        // Scope extension (owner 2026-11-11): backstage, manual control, segments, the question on screen.
        'bringLiveSeatOnAir POST /api/v1/live/rooms/{roomId}/seats/{seatIndex}/on-air',
        'setLivePodcastControl PUT /api/v1/live/rooms/{roomId}/podcast/control',
        'setLivePodcastSegments PUT /api/v1/live/rooms/{roomId}/podcast/segments',
        'nextLivePodcastSegment POST /api/v1/live/rooms/{roomId}/podcast/segments/next',
        'showLivePodcastQuestion PUT /api/v1/live/rooms/{roomId}/podcast/on-screen',
        'hideLivePodcastQuestion DELETE /api/v1/live/rooms/{roomId}/podcast/on-screen',
      ]),
    );
  });
});

describe('D363 the video podcast', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, {});
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
  const goLive = async (u: TestUser, body: object = VIDEO): Promise<string> => {
    const res = await start(u, body);
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const call = (
    method: 'get' | 'post' | 'put' | 'delete',
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
  // A loose view of `LiveSeats` (checked against the contract by expectContract).
  type Seats = {
    version: number;
    handsUp?: string[];
    questions?: { requestId: string; votes: number; votedByMe: boolean }[];
    seats: {
      state?: string;
      user: { id: string } | null;
      hotSeat?: unknown;
      guestTitle?: string | null;
      backstage?: boolean;
    }[];
    studio?: Record<string, unknown>;
  };
  const seats = async (roomId: string, u?: TestUser): Promise<Seats> => {
    const res = await call('get', `${roomId}/seats`, u);
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoomSeats');
    return res.body as Seats;
  };
  const raise = async (roomId: string, u: TestUser, question?: string): Promise<string> => {
    const res = await call('post', `${roomId}/seat-requests`, u, question === undefined ? {} : { question });
    expect(res.status).toBe(201);
    expectContract(res, 'requestLiveSeat');
    return res.body.id as string;
  };
  const vote = (roomId: string, requestId: string, u: TestUser) =>
    call('put', `${roomId}/seat-requests/${requestId}/vote`, u);
  const unvote = (roomId: string, requestId: string, u: TestUser) =>
    call('delete', `${roomId}/seat-requests/${requestId}/vote`, u);
  const expectError = (res: request.Response, status: number, code: string, operationId: string) => {
    expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
  };
  const podcastData = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'podcast')
      .map((b) => JSON.parse(b.payload) as Record<string, unknown>);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  it('starts a video podcast: the flag, camera grants for the host and speakers, none for listeners', async () => {
    const h = await host();
    expectError(
      await start(h, { mode: 'PODCAST', podcast: { topic: 'tech', video: 'yes' } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    const res = await start(h, VIDEO);
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    expect(res.body.podcast).toMatchObject({ episodeNumber: 1, topic: 'tech', video: true, speakers: [] });
    const roomId = res.body.id as string;
    await call('post', `${roomId}/media-token`, h, {}).expect(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['camera', 'microphone'] });

    // A listener publishes nothing; once invited and seated a speaker gets the camera and the microphone.
    const g = await signup();
    await watch(roomId, g);
    const viewerToken = await call('post', `${roomId}/media-token`, g, {});
    expect(viewerToken.status).toBe(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: false });
    await call('post', `${roomId}/seat-invites`, h, { username: g.username }).expect(201);
    await call('post', `${roomId}/seat-invites/me/accept`, g).expect(200);
    expect(media.permissions.at(-1)).toMatchObject({
      identity: g.id,
      permission: { visible: true, sources: ['camera', 'microphone'] },
    });
    await call('post', `${roomId}/media-token`, g, {}).expect(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['camera', 'microphone'] });
    // Muted by the host: the camera stays.
    await call('post', `${roomId}/seats/1/mute`, h, { muted: true }).expect(200);
    expect(media.permissions.at(-1)).toMatchObject({ identity: g.id, permission: { sources: ['camera'] } });

    // Listed with the flag on hub cards.
    const card = (await ctx.http.get('/api/v1/live/rooms?tab=new&kind=podcast')).body.data.find(
      (r: { id: string }) => r.id === roomId,
    );
    expect(card.podcast.video).toBe(true);
    await end(roomId, h);
  });

  it('keeps an audio podcast exactly as D212 (voice only, no questions list, no video extras)', async () => {
    const h = await host();
    const roomId = await goLive(h, AUDIO);
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    expectContract(room, 'getLiveRoom');
    expect(room.body.podcast.video).toBe(false);
    await call('post', `${roomId}/media-token`, h, {}).expect(200);
    expect(media.issued.at(-1)).toMatchObject({ sources: ['microphone'] });
    const g = await signup();
    await watch(roomId, g);
    const requestId = await raise(roomId, g, 'سؤال');
    const read = await seats(roomId, h);
    expect(read.questions).toBeUndefined();
    expect(read.handsUp).toEqual([g.id]);
    // Video-only features are refused in an audio podcast.
    expectError(await vote(roomId, requestId, h), 404, 'NOT_FOUND', 'voteLivePodcastQuestion');
    expectError(
      await call('post', `${roomId}/seat-requests/${requestId}/accept`, h, { hotSeat: true }),
      400,
      'VALIDATION_FAILED',
      'acceptLiveSeatRequest',
    );
    expectError(
      await call('post', `${roomId}/seat-invites`, h, { username: g.username, guestTitle: 'ضيفة' }),
      400,
      'VALIDATION_FAILED',
      'inviteToLiveSeat',
    );
    expectError(
      await call('put', `${roomId}/podcast/director`, h, {
        shot: 'SPEAKER',
        userIds: [h.id],
        locked: false,
        seq: 1,
      }),
      404,
      'NOT_FOUND',
      'setLivePodcastDirector',
    );
    // An accepted hand still speaks for the room's question time (D212), as a voice-only speaker.
    const accepted = await call('post', `${roomId}/seat-requests/${requestId}/accept`, h, {});
    expect(accepted.status).toBe(200);
    expectContract(accepted, 'acceptLiveSeatRequest');
    expect(accepted.body.seats[0]).toMatchObject({ state: 'TAKEN', guestTitle: null, hotSeat: null });
    expect(accepted.body.seats[0].demoteAt).not.toBeNull();
    expect(media.permissions.at(-1)).toMatchObject({
      identity: g.id,
      permission: { sources: ['microphone'] },
    });
    await end(roomId, h);
  });

  it('guest titles: video podcasts only, the chat text rules, the host’s blocked words masked', async () => {
    const h = await host();
    await ctx.prisma.liveHost.update({ where: { userId: h.id }, data: { blockedWords: ['ممنوع'] } });
    const roomId = await goLive(h);
    const g = await signup();
    await watch(roomId, g);
    expectError(
      await call('post', `${roomId}/seat-invites`, h, { username: g.username, guestTitle: 'ب'.repeat(41) }),
      400,
      'VALIDATION_FAILED',
      'inviteToLiveSeat',
    );
    const invite = await call('post', `${roomId}/seat-invites`, h, {
      username: g.username,
      guestTitle: '  خبيرة ممنوع  ',
    });
    expect(invite.status).toBe(201);
    expectContract(invite, 'inviteToLiveSeat');
    expect(invite.body.guestTitle).toBe('خبيرة *****');
    const accepted = await call('post', `${roomId}/seat-invites/me/accept`, g);
    expect(accepted.status).toBe(200);
    expectContract(accepted, 'acceptLiveSeatInvite');
    expect(accepted.body.seats[0]).toMatchObject({
      user: { id: g.id },
      guestTitle: 'خبيرة *****',
      hotSeat: null,
    });
    // Everyone (guests too) reads the title.
    expect((await seats(roomId)).seats[0]?.guestTitle).toBe('خبيرة *****');
    await end(roomId, h);
  });

  it('upvotes: one per person, live counts, sorted questions, the asker and ended hands refused', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const [a, b, c, d] = [await signup(), await signup(), await signup(), await signup()];
    await watch(roomId, a, b, c, d);
    const qa = await raise(roomId, a, 'أول سؤال');
    const qb = await raise(roomId, b, 'ثاني سؤال');
    const plain = await raise(roomId, c); // a hand without a question

    const first = await vote(roomId, qb, c);
    expect(first.status).toBe(200);
    expectContract(first, 'voteLivePodcastQuestion');
    expect(first.body).toEqual({ requestId: qb, votes: 1, votedByMe: true });
    // Idempotent: the same vote again changes nothing and sends nothing.
    const sentBefore = podcastData(roomId).length;
    expect((await vote(roomId, qb, c)).body).toEqual({ requestId: qb, votes: 1, votedByMe: true });
    expect(podcastData(roomId)).toHaveLength(sentBefore);
    expect((await vote(roomId, qb, d)).body.votes).toBe(2);
    expect((await vote(roomId, qa, h)).body.votes).toBe(1); // the host may vote too
    expect(podcastData(roomId).at(-1)).toEqual({ type: 'question-votes', requestId: qa, votes: 1 });

    expectError(await vote(roomId, qa, a), 403, 'AUTH_FORBIDDEN', 'voteLivePodcastQuestion');
    expectError(await vote(roomId, plain, d), 404, 'NOT_FOUND', 'voteLivePodcastQuestion');
    expectError(await vote(roomId, 'not-a-uuid', d), 404, 'NOT_FOUND', 'voteLivePodcastQuestion');
    expect((await ctx.http.put(`/api/v1/live/rooms/${roomId}/seat-requests/${qa}/vote`)).status).toBe(401);

    // Everyone sees the questions, most votes first; votedByMe is per caller; a vote does not move the version.
    const before = await seats(roomId, c);
    expect(before.questions?.map((q: { requestId: string }) => q.requestId)).toEqual([qb, qa]);
    expect(before.questions?.[0]).toMatchObject({
      user: { id: b.id },
      question: 'ثاني سؤال',
      votes: 2,
      votedByMe: true,
    });
    expect(before.questions?.[1]).toMatchObject({ votes: 1, votedByMe: false, deferred: false });
    expect((await seats(roomId)).questions?.[0]?.votedByMe).toBe(false); // a guest
    await vote(roomId, qa, d);
    await vote(roomId, qa, b);
    const after = await seats(roomId, c);
    expect(after.version).toBe(before.version);
    expect(after.questions?.map((q: { requestId: string }) => q.requestId)).toEqual([qa, qb]);
    // The host's list carries the count.
    const list = await call('get', `${roomId}/seat-requests`, h);
    expectContract(list, 'listLiveSeatRequests');
    expect(list.body.data.find((r: { id: string }) => r.id === qa).votes).toBe(3);

    // Unvote: idempotent.
    const back = await unvote(roomId, qa, d);
    expect(back.status).toBe(200);
    expectContract(back, 'unvoteLivePodcastQuestion');
    expect(back.body).toEqual({ requestId: qa, votes: 2, votedByMe: false });
    expect((await unvote(roomId, qa, d)).body.votes).toBe(2);

    // A hand that was lowered can no longer be voted.
    await call('delete', `${roomId}/seat-requests/me`, b).expect(204);
    expectError(await vote(roomId, qb, h), 409, 'LIVE_REQUEST_NOT_PENDING', 'voteLivePodcastQuestion');
    expect((await seats(roomId, c)).questions?.map((q: { requestId: string }) => q.requestId)).toEqual([qa]);
    await end(roomId, h);
    expectError(await vote(roomId, qa, c), 409, 'LIVE_ROOM_ENDED', 'voteLivePodcastQuestion');
  });

  it('the hot seat: one at a time, its own time (default 60 s), the question card, back to the listeners', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const [a, b, c] = [await signup(), await signup(), await signup()];
    await watch(roomId, a, b, c);
    const qa = await raise(roomId, a, 'ما رأيك؟');
    const qb = await raise(roomId, b, 'وسؤالي؟');
    const plain = await raise(roomId, c);
    await vote(roomId, qa, c);

    expectError(
      await call('post', `${roomId}/seat-requests/${plain}/accept`, h, { hotSeat: true }),
      400,
      'VALIDATION_FAILED',
      'acceptLiveSeatRequest',
    );
    expectError(
      await call('post', `${roomId}/seat-requests/${qa}/accept`, h, { hotSeatSeconds: 60 }),
      400,
      'VALIDATION_FAILED',
      'acceptLiveSeatRequest',
    );
    const t0 = clock.now().getTime();
    const hot = await call('post', `${roomId}/seat-requests/${qa}/accept`, h, { hotSeat: true });
    expect(hot.status).toBe(200);
    expectContract(hot, 'acceptLiveSeatRequest');
    const seat = hot.body.seats.find((s: { user: { id: string } | null }) => s.user?.id === a.id);
    expect(seat.hotSeat).toEqual({ requestId: qa, question: 'ما رأيك؟', votes: 1 });
    const seconds = (new Date(seat.demoteAt).getTime() - t0) / 1000;
    expect(seconds).toBeGreaterThanOrEqual(59);
    expect(seconds).toBeLessThanOrEqual(61);
    // On camera allowed (a video podcast speaker); the app keeps it off by default.
    expect(media.permissions.at(-1)).toMatchObject({
      identity: a.id,
      permission: { sources: ['camera', 'microphone'] },
    });
    // The seated hand leaves the questions list; a second hot seat waits.
    expect((await seats(roomId)).questions?.map((q: { requestId: string }) => q.requestId)).toEqual([qb]);
    expectError(
      await call('post', `${roomId}/seat-requests/${qb}/accept`, h, { hotSeat: true, hotSeatSeconds: 120 }),
      409,
      'LIVE_SEAT_UNAVAILABLE',
      'acceptLiveSeatRequest',
    );
    // An ordinary accept still works next to the hot seat.
    await call('post', `${roomId}/seat-requests/${plain}/accept`, h, {}).expect(200);

    // When the time is over the sweeper sends the asker back to the listeners.
    clock.advance(61);
    const seatsService = ctx.app.get(LiveSeatsService);
    expect(await seatsService.demoteExpired()).toBeGreaterThanOrEqual(1);
    const now = await seats(roomId);
    expect(now.seats.some((s: { user: { id: string } | null }) => s.user?.id === a.id)).toBe(false);
    expect(now.seats.every((s: { hotSeat?: unknown }) => !s.hotSeat)).toBe(true);
    expect(media.permissions.at(-1)).toMatchObject({
      identity: a.id,
      permission: { visible: false, sources: [] },
    });

    // Now the next one may take the hot seat, with a chosen time.
    const t1 = clock.now().getTime();
    const next = await call('post', `${roomId}/seat-requests/${qb}/accept`, h, {
      hotSeat: true,
      hotSeatSeconds: 120,
    });
    expect(next.status).toBe(200);
    const nextSeat = next.body.seats.find((s: { user: { id: string } | null }) => s.user?.id === b.id);
    expect((new Date(nextSeat.demoteAt).getTime() - t1) / 1000).toBeGreaterThanOrEqual(119);
    await end(roomId, h);
  });

  // ---- Scope extension (owner 2026-11-11): backstage, manual control, segments, the question on screen ----------

  const studioOf = async (roomId: string, u?: TestUser) =>
    (await seats(roomId, u)).studio as Record<string, unknown>;
  const lastStudio = (roomId: string) =>
    podcastData(roomId)
      .filter((d) => d.type === 'studio')
      .at(-1)?.studio as Record<string, unknown> | undefined;
  const speakersOnCard = async (roomId: string): Promise<string[]> =>
    (
      (await ctx.http.get('/api/v1/live/rooms?tab=new&kind=podcast')).body.data.find(
        (r: { id: string }) => r.id === roomId,
      ).podcast.speakers as { id: string }[]
    ).map((p) => p.id);

  it('backstage: an accepted guest waits backstage, the host brings them on air; leaving is back to the audience', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const [g, g2] = [await signup(), await signup()];
    await watch(roomId, g, g2);
    await call('post', `${roomId}/seat-invites`, h, { username: g.username, guestTitle: 'باحثة' }).expect(
      201,
    );
    const accepted = await call('post', `${roomId}/seat-invites/me/accept`, g);
    expect(accepted.status).toBe(200);
    expectContract(accepted, 'acceptLiveSeatInvite');
    expect(accepted.body.seats[0]).toMatchObject({
      user: { id: g.id },
      backstage: true,
      guestTitle: 'باحثة',
    });
    // The self-check publishes (to the host only, the app restricts its subscribers): camera and microphone.
    expect(media.permissions.at(-1)).toMatchObject({
      identity: g.id,
      permission: { sources: ['camera', 'microphone'] },
    });
    // Not a speaker yet: not on the hub card, not on the director's shots.
    expect(await speakersOnCard(roomId)).toEqual([]);

    expectError(
      await call('post', `${roomId}/seats/1/on-air`, g),
      403,
      'AUTH_FORBIDDEN',
      'bringLiveSeatOnAir',
    );
    expectError(
      await call('post', `${roomId}/seats/2/on-air`, h),
      409,
      'LIVE_SEAT_UNAVAILABLE',
      'bringLiveSeatOnAir',
    );
    const before = (await seats(roomId)).version;
    const onAir = await call('post', `${roomId}/seats/1/on-air`, h);
    expect(onAir.status).toBe(200);
    expectContract(onAir, 'bringLiveSeatOnAir');
    expect(onAir.body.seats[0]).toMatchObject({ user: { id: g.id }, backstage: false });
    expect(onAir.body.version).toBeGreaterThan(before);
    expect(await speakersOnCard(roomId)).toEqual([g.id]);
    expectError(
      await call('post', `${roomId}/seats/1/on-air`, h),
      409,
      'LIVE_SEAT_UNAVAILABLE',
      'bringLiveSeatOnAir',
    );

    // Leaving backstage without going on air: back to the audience.
    await call('post', `${roomId}/seat-invites`, h, { username: g2.username }).expect(201);
    await call('post', `${roomId}/seat-invites/me/accept`, g2).expect(200);
    expect((await seats(roomId)).seats[1]).toMatchObject({ user: { id: g2.id }, backstage: true });
    await call('post', `${roomId}/seats/me/leave`, g2).expect(204);
    expect((await seats(roomId)).seats[1]).toMatchObject({ state: 'EMPTY', user: null });
    expect(media.permissions.at(-1)).toMatchObject({ identity: g2.id, permission: { sources: [] } });
    await end(roomId, h);

    // An audio podcast has no backstage.
    const audioRoom = await goLive(h, AUDIO);
    await watch(audioRoom, g);
    await call('post', `${audioRoom}/seat-invites`, h, { username: g.username }).expect(201);
    const audioSeats = await call('post', `${audioRoom}/seat-invites/me/accept`, g).expect(200);
    expect(audioSeats.body.seats[0]).toMatchObject({ user: { id: g.id }, backstage: false });
    expect(audioSeats.body.studio).toBeUndefined();
    expectError(await call('post', `${audioRoom}/seats/1/on-air`, h), 404, 'NOT_FOUND', 'bringLiveSeatOnAir');
    expectError(
      await call('put', `${audioRoom}/podcast/control`, h, {}),
      404,
      'NOT_FOUND',
      'setLivePodcastControl',
    );
    await end(audioRoom, h);
  });

  it('manual control: pin a person, lock a layout, «تلقائي»; sent as `studio`, read back by late joiners', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const [g, v] = [await signup(), await signup()];
    await watch(roomId, g, v);
    expect(await studioOf(roomId)).toEqual({
      seq: 0,
      pinUserId: null,
      layout: null,
      segments: [],
      segmentIndex: null,
      segmentStartedAt: null,
      closing: false,
      onScreen: null,
    });
    await call('post', `${roomId}/seat-invites`, h, { username: g.username }).expect(201);
    await call('post', `${roomId}/seat-invites/me/accept`, g).expect(200);
    // Backstage people cannot be pinned.
    const control = (u: TestUser, body: object) => call('put', `${roomId}/podcast/control`, u, body);
    expectError(await control(h, { pinUserId: g.id }), 400, 'VALIDATION_FAILED', 'setLivePodcastControl');
    await call('post', `${roomId}/seats/1/on-air`, h).expect(200);
    expectError(await control(g, { pinUserId: g.id }), 403, 'AUTH_FORBIDDEN', 'setLivePodcastControl');
    expectError(await control(h, { pinUserId: v.id }), 400, 'VALIDATION_FAILED', 'setLivePodcastControl');
    expectError(await control(h, { layout: 'HOT_SEAT' }), 400, 'VALIDATION_FAILED', 'setLivePodcastControl');
    expectError(await control(h, { layout: 'GRID' }), 400, 'VALIDATION_FAILED', 'setLivePodcastControl');

    const pinned = await control(h, { pinUserId: g.id, layout: 'SPLIT' });
    expect(pinned.status).toBe(200);
    expectContract(pinned, 'setLivePodcastControl');
    expect(pinned.body).toMatchObject({ seq: 1, pinUserId: g.id, layout: 'SPLIT' });
    expect(lastStudio(roomId)).toEqual(pinned.body);
    // The same again: nothing changes, nothing is sent.
    const sent = podcastData(roomId).length;
    expect((await control(h, { pinUserId: g.id, layout: 'SPLIT' })).body.seq).toBe(1);
    expect(podcastData(roomId)).toHaveLength(sent);
    // A late joiner (a guest too) reads the same state.
    expect(await studioOf(roomId)).toMatchObject({ seq: 1, pinUserId: g.id, layout: 'SPLIT' });

    // A pinned person who leaves the stage reads as null; «تلقائي» clears both.
    await call('post', `${roomId}/seats/me/leave`, g).expect(204);
    expect(await studioOf(roomId, v)).toMatchObject({ pinUserId: null, layout: 'SPLIT' });
    const auto = await control(h, {});
    expect(auto.body).toMatchObject({ seq: 2, pinUserId: null, layout: null });
    expect(lastStudio(roomId)).toMatchObject({ seq: 2, layout: null });
    await end(roomId, h);
    expectError(await control(h, {}), 409, 'LIVE_ROOM_ENDED', 'setLivePodcastControl');
  });

  it('segments: prepared at setup (video only), replaced live, «الفقرة التالية», then the closing card', async () => {
    const h = await host();
    const segments = [{ title: '  مقدمة  ' }, { title: 'نقاش الضيوف', minutes: 20 }];
    expectError(
      await start(h, { mode: 'PODCAST', podcast: { topic: 'tech', segments } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    const roomId = await goLive(h, { mode: 'PODCAST', podcast: { topic: 'tech', video: true, segments } });
    expect(await studioOf(roomId)).toMatchObject({
      segments: [
        { title: 'مقدمة', minutes: null },
        { title: 'نقاش الضيوف', minutes: 20 },
      ],
      segmentIndex: null,
      closing: false,
    });
    const next = () => call('post', `${roomId}/podcast/segments/next`, h);
    const t0 = clock.now().getTime();
    const first = await next();
    expect(first.status).toBe(200);
    expectContract(first, 'nextLivePodcastSegment');
    expect(first.body).toMatchObject({ segmentIndex: 0, closing: false });
    expect(Math.abs(new Date(first.body.segmentStartedAt).getTime() - t0)).toBeLessThan(5_000);
    expect((await next()).body).toMatchObject({ segmentIndex: 1, closing: false });
    const closing = await next();
    expect(closing.body).toMatchObject({ segmentIndex: 1, closing: true });
    expect(lastStudio(roomId)).toMatchObject({ closing: true });
    expect((await next()).body.seq).toBe(closing.body.seq);

    const put = (u: TestUser, body: object) => call('put', `${roomId}/podcast/segments`, u, body);
    const viewer = await signup();
    expectError(await put(viewer, { segments: [] }), 403, 'AUTH_FORBIDDEN', 'setLivePodcastSegments');
    const nine = Array.from({ length: 9 }, (_, i) => ({ title: `فقرة ${i + 1}` }));
    expectError(await put(h, { segments: nine }), 400, 'VALIDATION_FAILED', 'setLivePodcastSegments');
    expectError(
      await put(h, { segments: [{ title: 'ب'.repeat(41) }] }),
      400,
      'VALIDATION_FAILED',
      'setLivePodcastSegments',
    );
    expectError(
      await put(h, { segments: [{ title: 'أ', minutes: 0 }] }),
      400,
      'VALIDATION_FAILED',
      'setLivePodcastSegments',
    );
    const one = await put(h, { segments: [{ title: 'ختام' }] });
    expect(one.status).toBe(200);
    expectContract(one, 'setLivePodcastSegments');
    expect(one.body).toMatchObject({ segments: [{ title: 'ختام', minutes: null }], segmentIndex: 0 });
    const none = await put(h, { segments: [] });
    expect(none.body).toMatchObject({ segments: [], segmentIndex: null, closing: false });
    expectError(await next(), 400, 'VALIDATION_FAILED', 'nextLivePodcastSegment');
    await end(roomId, h);
  });

  it('the question on screen: a hand with a question, the answering person, dismissed by the host', async () => {
    const h = await host();
    await ctx.prisma.liveHost.update({ where: { userId: h.id }, data: { blockedWords: ['ممنوع'] } });
    const roomId = await goLive(h);
    const [a, b, c, v] = [await signup(), await signup(), await signup(), await signup()];
    await watch(roomId, a, b, c, v);
    const qa = await raise(roomId, a, 'سؤال ممنوع؟');
    const plain = await raise(roomId, c);
    const show = (u: TestUser, body: object) => call('put', `${roomId}/podcast/on-screen`, u, body);

    expectError(await show(a, { requestId: qa }), 403, 'AUTH_FORBIDDEN', 'showLivePodcastQuestion');
    expectError(await show(h, { requestId: plain }), 404, 'NOT_FOUND', 'showLivePodcastQuestion');
    expectError(await show(h, { requestId: 'nope' }), 400, 'VALIDATION_FAILED', 'showLivePodcastQuestion');
    expectError(
      await show(h, { requestId: qa, answerUserId: v.id }),
      400,
      'VALIDATION_FAILED',
      'showLivePodcastQuestion',
    );
    const shown = await show(h, { requestId: qa, answerUserId: h.id });
    expect(shown.status).toBe(200);
    expectContract(shown, 'showLivePodcastQuestion');
    expect(shown.body.onScreen).toMatchObject({
      requestId: qa,
      user: { id: a.id },
      question: 'سؤال *****؟',
      answerUserId: h.id,
    });
    expect(lastStudio(roomId)).toMatchObject({ onScreen: { requestId: qa, answerUserId: h.id } });
    expect((await studioOf(roomId)).onScreen).toMatchObject({ requestId: qa });

    const hide = () => call('delete', `${roomId}/podcast/on-screen`, h);
    const hidden = await hide();
    expect(hidden.status).toBe(200);
    expectContract(hidden, 'hideLivePodcastQuestion');
    expect(hidden.body.onScreen).toBeNull();
    expect((await hide()).body.seq).toBe(hidden.body.seq);

    // A lowered hand can no longer be shown.
    const qb = await raise(roomId, b, 'وسؤالي؟');
    await call('delete', `${roomId}/seat-requests/me`, b).expect(204);
    expectError(await show(h, { requestId: qb }), 409, 'LIVE_REQUEST_NOT_PENDING', 'showLivePodcastQuestion');
    await end(roomId, h);
  });

  it('the director relay: host only, the people on stage only, sent to the room on topic `podcast`', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const g = await signup();
    const v = await signup();
    await watch(roomId, g, v);
    await call('post', `${roomId}/seat-invites`, h, { username: g.username }).expect(201);
    await call('post', `${roomId}/seat-invites/me/accept`, g).expect(200);
    const shot = { shot: 'SPLIT', userIds: [g.id, h.id], locked: false, seq: 7 };
    // Scope extension: a guest waiting backstage is not on any shot until the host brings them on air.
    expectError(
      await call('put', `${roomId}/podcast/director`, h, shot),
      400,
      'VALIDATION_FAILED',
      'setLivePodcastDirector',
    );
    await call('post', `${roomId}/seats/1/on-air`, h).expect(200);

    expectError(
      await call('put', `${roomId}/podcast/director`, g, shot),
      403,
      'AUTH_FORBIDDEN',
      'setLivePodcastDirector',
    );
    expectError(
      await call('put', `${roomId}/podcast/director`, h, { ...shot, userIds: [v.id] }),
      400,
      'VALIDATION_FAILED',
      'setLivePodcastDirector',
    );
    expectError(
      await call('put', `${roomId}/podcast/director`, h, { ...shot, shot: 'WIDE' }),
      400,
      'VALIDATION_FAILED',
      'setLivePodcastDirector',
    );
    const ok = await call('put', `${roomId}/podcast/director`, h, shot);
    expect(ok.status).toBe(204);
    expectContract(ok, 'setLivePodcastDirector');
    const sent = podcastData(roomId).at(-1)!;
    expect(sent).toMatchObject({
      type: 'director',
      shot: 'SPLIT',
      userIds: [g.id, h.id],
      locked: false,
      seq: 7,
    });
    expect(typeof sent.at).toBe('string');
    await call('put', `${roomId}/podcast/director`, h, {
      shot: 'SPEAKER',
      userIds: [g.id],
      locked: true,
      seq: 8,
    }).expect(204);
    expect(podcastData(roomId).at(-1)).toMatchObject({ shot: 'SPEAKER', locked: true, seq: 8 });
    await end(roomId, h);
    expectError(
      await call('put', `${roomId}/podcast/director`, h, shot),
      409,
      'LIVE_ROOM_ENDED',
      'setLivePodcastDirector',
    );
  });

  it('announces video episodes: the flag with PODCAST only, listed with `video`', async () => {
    const h = await host();
    const slot = (body: object) => ctx.http.post('/api/v1/me/live-schedule').set(auth(h)).send(body);
    const startsAt = new Date(clock.now().getTime() + 3600_000).toISOString();
    expectError(
      await slot({ title: 'حلقة', startsAt, podcastVideo: true }),
      400,
      'VALIDATION_FAILED',
      'createLiveScheduleSlot',
    );
    const video = await slot({
      title: 'حلقة فيديو',
      startsAt,
      mode: 'PODCAST',
      podcastTopic: 'tech',
      podcastVideo: true,
    });
    expect(video.status).toBe(201);
    expectContract(video, 'createLiveScheduleSlot');
    expect(video.body).toMatchObject({ mode: 'PODCAST', podcastVideo: true });
    const audio = await slot({ title: 'حلقة صوت', startsAt, mode: 'PODCAST', podcastTopic: 'tech' });
    expect(audio.body.podcastVideo).toBe(false);
    const plain = await slot({ title: 'بث', startsAt });
    expect(plain.body.podcastVideo).toBe(false);
    const listed = await ctx.http.get('/api/v1/live/podcasts/scheduled');
    expectContract(listed, 'listScheduledPodcasts');
    const byId = new Map((listed.body.data as { id: string; video: boolean }[]).map((r) => [r.id, r.video]));
    expect(byId.get(video.body.id)).toBe(true);
    expect(byId.get(audio.body.id)).toBe(false);
  });

  it('the database keeps the flag on podcasts only', async () => {
    const h = await host();
    const roomId = await goLive(h, { mode: 'SOLO' });
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { podcastVideo: true } }),
    ).rejects.toThrow(/live_rooms_podcast_fields/);
    await expect(
      ctx.prisma.liveScheduleSlot.create({
        data: { hostUserId: h.id, title: 'x', startsAt: new Date(Date.now() + 3600_000), podcastVideo: true },
      }),
    ).rejects.toThrow(/live_schedule_slots_podcast_fields/);
    await end(roomId, h);
  });
});

describe('D363 the capacity guard weighs a video podcast as video', () => {
  let ctx: TestContext;
  const media = new MemoryLiveMedia();
  beforeAll(async () => {
    // 1 video room of room: an audio podcast (25) and another fit, a video podcast (100) does not.
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_CAPACITY_MAX_ROOMS: '1' },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
  });
  afterAll(async () => ctx?.close());

  it('counts and refuses video podcasts with the video weight', async () => {
    const hosts: TestUser[] = [];
    for (let i = 0; i < 3; i += 1) {
      const { res } = await registerVerified(ctx, {});
      const u = {
        id: res.body.user.id,
        username: res.body.user.username,
        token: res.body.tokens.accessToken,
      };
      await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
      hosts.push(u);
    }
    const go = (u: TestUser, body: object) =>
      ctx.http
        .post('/api/v1/live/rooms')
        .set({ Authorization: `Bearer ${u.token}` })
        .send({ title: 'حلقة', ...body });
    expect((await go(hosts[0]!, AUDIO)).status).toBe(201); // 25 of 100
    const refused = await go(hosts[1]!, VIDEO); // 25 + 100 > 100
    expect(refused.status).toBe(503);
    expectContract(refused, 'startLiveRoom');
    expect(refused.body.error.code).toBe('LIVE_CAPACITY_FULL');
    expect((await go(hosts[2]!, AUDIO)).status).toBe(201); // 50 of 100
  });
});
