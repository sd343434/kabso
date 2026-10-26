/**
 * KL-064 / CP-011 (D94): multi-guest video and audio rooms with seats (openapi v1.7-live DRAFT,
 * CONVENTIONS §10.9), end to end against PostgreSQL + Redis with the API as the DML-only runtime
 * role. The media server is the in-memory fake behind the LiveMediaProvider port, which records
 * permission changes, room metadata and data messages; kl063-livekit-real exercises the LiveKit
 * adapter against a real server.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { AccountLifecycleService } from '../src/modules/users/profiles/account-lifecycle.service.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const SEAT_OPERATIONS = [
  'getLiveRoomSeats',
  'requestLiveSeat',
  'listLiveSeatRequests',
  'cancelLiveSeatRequest',
  'acceptLiveSeatRequest',
  'declineLiveSeatRequest',
  'inviteToLiveSeat',
  'acceptLiveSeatInvite',
  'declineLiveSeatInvite',
  'leaveLiveSeat',
  'muteLiveSeat',
  'removeFromLiveSeat',
  'lockLiveSeat',
  'addLiveModerator',
  'removeLiveModerator',
];

describe('CP-011 seats contract coverage', () => {
  it('openapi declares exactly the fifteen seat operations', () => {
    expect(
      operations()
        .filter((o) =>
          /^\/api\/v1\/live\/rooms\/\{roomId\}\/(seats|seat-requests|seat-invites|moderators)(\/|$)/.test(
            o.path,
          ),
        )
        .map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`)
        .sort(),
    ).toEqual(
      [
        'getLiveRoomSeats GET /api/v1/live/rooms/{roomId}/seats',
        'requestLiveSeat POST /api/v1/live/rooms/{roomId}/seat-requests',
        'listLiveSeatRequests GET /api/v1/live/rooms/{roomId}/seat-requests',
        'cancelLiveSeatRequest DELETE /api/v1/live/rooms/{roomId}/seat-requests/me',
        'acceptLiveSeatRequest POST /api/v1/live/rooms/{roomId}/seat-requests/{requestId}/accept',
        'declineLiveSeatRequest POST /api/v1/live/rooms/{roomId}/seat-requests/{requestId}/decline',
        'inviteToLiveSeat POST /api/v1/live/rooms/{roomId}/seat-invites',
        'acceptLiveSeatInvite POST /api/v1/live/rooms/{roomId}/seat-invites/me/accept',
        'declineLiveSeatInvite POST /api/v1/live/rooms/{roomId}/seat-invites/me/decline',
        'leaveLiveSeat POST /api/v1/live/rooms/{roomId}/seats/me/leave',
        'muteLiveSeat POST /api/v1/live/rooms/{roomId}/seats/{seatIndex}/mute',
        'removeFromLiveSeat POST /api/v1/live/rooms/{roomId}/seats/{seatIndex}/remove',
        'lockLiveSeat POST /api/v1/live/rooms/{roomId}/seats/{seatIndex}/lock',
        'addLiveModerator PUT /api/v1/live/rooms/{roomId}/moderators/{username}',
        'removeLiveModerator DELETE /api/v1/live/rooms/{roomId}/moderators/{username}',
      ].sort(),
    );
    expect(
      operations()
        .filter((o) => SEAT_OPERATIONS.includes(o.operationId))
        .map((o) => o.operationId)
        .sort(),
    ).toEqual([...SEAT_OPERATIONS].sort());
  });
});

describe('CP-011 multi-guest and audio rooms', () => {
  let ctx: TestContext;
  let media: MemoryLiveMedia;
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
  const goLive = async (u: TestUser, extra: object = { mode: 'MULTI', seatCount: 4 }): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Seats', ...extra });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const hook = (event: string, room: string, identity?: string) => {
    const raw = JSON.stringify({
      event,
      room: { name: room },
      ...(identity ? { participant: { identity } } : {}),
    });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const watch = async (roomId: string, ...users: TestUser[]) => {
    for (const u of users) await hook('participant_joined', roomId, u.id).expect(200);
  };
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
  const seats = (roomId: string, u?: TestUser) => call('get', `${roomId}/seats`, u);
  const ask = (roomId: string, u: TestUser, body?: object) =>
    call('post', `${roomId}/seat-requests`, u, body);
  const accept = (roomId: string, requestId: string, u: TestUser, body?: object) =>
    call('post', `${roomId}/seat-requests/${requestId}/accept`, u, body);
  const invite = (roomId: string, u: TestUser, body: object) =>
    call('post', `${roomId}/seat-invites`, u, body);
  const seat = async (roomId: string, hostUser: TestUser, guest: TestUser, body?: object) => {
    const r = await ask(roomId, guest);
    expect([200, 201]).toContain(r.status);
    const a = await accept(roomId, r.body.id, hostUser, body);
    expect(a.status).toBe(200);
    return a;
  };
  const expectError = (res: request.Response, status: number, code: string, operationId: string) => {
    expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
  };
  const version = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).seatsVersion;

  beforeAll(async () => {
    media = new MemoryLiveMedia();
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  describe('going live in a mode', () => {
    it('config lists themes and seat counts; MULTI and AUDIO rooms carry seatCount, occupiedSeats, theme', async () => {
      const config = await ctx.http.get('/api/v1/live/config');
      expectContract(config, 'getLiveConfig');
      expect(config.body).toMatchObject({
        themes: [
          'classic',
          'ice-palace',
          'desert-night',
          'rose-garden',
          'sunset-sky',
          'moon-palace',
          'ocean-depths',
          'golden-hall',
          'game-arena',
          'heart-garden',
          'galaxy',
        ],
        seatCounts: { MULTI: [4, 6, 9, 12], AUDIO: [5, 10, 15, 20, 25] },
      });

      const [h1, h2, h3] = [await host(), await host(), await host()];
      const multi = await goLive(h1, { mode: 'MULTI', seatCount: 6, theme: 'ice-palace' });
      const audio = await goLive(h2, { mode: 'AUDIO', seatCount: 10 });
      const solo = await goLive(h3, {});
      const detail = await ctx.http.get(`/api/v1/live/rooms/${multi}`);
      expectContract(detail, 'getLiveRoom');
      expect(detail.body).toMatchObject({
        mode: 'MULTI',
        seatCount: 6,
        occupiedSeats: 0,
        theme: 'ice-palace',
      });
      expect((await ctx.http.get(`/api/v1/live/rooms/${audio}`)).body).toMatchObject({
        mode: 'AUDIO',
        seatCount: 10,
        theme: 'classic',
      });
      expect((await ctx.http.get(`/api/v1/live/rooms/${solo}`)).body).toMatchObject({
        mode: 'SOLO',
        seatCount: null,
        occupiedSeats: 0,
        theme: 'classic',
      });
      const list = await ctx.http.get('/api/v1/live/rooms?tab=new&limit=50');
      expectContract(list, 'listLiveRooms');
      expect(list.body.data.find((r: { id: string }) => r.id === audio)).toMatchObject({
        mode: 'AUDIO',
        seatCount: 10,
        occupiedSeats: 0,
      });

      // The AUDIO host publishes the microphone only; the MULTI host camera and microphone.
      const audioToken = await call('post', `${audio}/media-token`, h2, {});
      expectContract(audioToken, 'createLiveMediaToken');
      expect(audioToken.body.role).toBe('HOST');
      expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['microphone'] });
      await call('post', `${multi}/media-token`, h1, {}).expect(200);
      expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['camera', 'microphone'] });

      // A SOLO room has no seats.
      const soloSeats = await seats(solo, h3);
      expectError(soloSeats, 409, 'LIVE_SEAT_UNAVAILABLE', 'getLiveRoomSeats');
      for (const id of [multi, audio, solo]) {
        const owner = id === multi ? h1 : id === audio ? h2 : h3;
        await end(id, owner);
      }
    });

    it('validates mode, seatCount and theme (400)', async () => {
      const h = await host();
      const cases: [object, { field: string; issue: string }[]][] = [
        [{ mode: 'MULTI' }, [{ field: 'seatCount', issue: 'required' }]],
        [{ mode: 'AUDIO', seatCount: 4 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ mode: 'AUDIO', seatCount: 6 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ mode: 'AUDIO', seatCount: 9 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ mode: 'MULTI', seatCount: 5 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ mode: 'MULTI', seatCount: 13 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ seatCount: 4 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
        [{ mode: 'PK' }, [{ field: 'mode', issue: 'invalid_value' }]],
        [{ theme: 'no-such-theme' }, [{ field: 'theme', issue: 'invalid_value' }]],
        [{ theme: 'Bad!' }, [{ field: 'theme', issue: 'invalid_format' }]],
      ];
      for (const [extra, details] of cases) {
        const res = await ctx.http
          .post('/api/v1/live/rooms')
          .set(auth(h))
          .send({ title: 'x', ...extra });
        expectContract(res, 'startLiveRoom');
        expect({ extra, status: res.status, details: res.body.error?.details }).toEqual({
          extra,
          status: 400,
          details,
        });
      }
    });
  });

  describe('reading the seats', () => {
    it('everyone who may see the room reads them; mine and pendingRequests only for whom they concern', async () => {
      const [h, viewer] = [await host(), await signup()];
      const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
      const asHost = await seats(roomId, h);
      expectContract(asHost, 'getLiveRoomSeats');
      expect(asHost.body).toEqual({
        roomId,
        mode: 'AUDIO',
        version: 0,
        seatCount: 5,
        seats: [1, 2, 3, 4].map((index) => ({ index, state: 'EMPTY', user: null, mutedByHost: false })),
        moderators: [],
        pendingRequests: 0,
        mine: { role: 'HOST', seatIndex: null, request: null, invite: null },
      });
      const guest = await seats(roomId);
      expectContract(guest, 'getLiveRoomSeats');
      expect(guest.body.mine).toBeUndefined();
      expect(guest.body.pendingRequests).toBeUndefined();
      const asViewer = await seats(roomId, viewer);
      expect(asViewer.body.mine).toEqual({ role: 'VIEWER', seatIndex: null, request: null, invite: null });
      expect(asViewer.body.pendingRequests).toBeUndefined();

      expectError(await seats(randomUUID(), viewer), 404, 'NOT_FOUND', 'getLiveRoomSeats');
      expectError(await seats('nope'), 404, 'NOT_FOUND', 'getLiveRoomSeats');
      await ctx.http.put(`/api/v1/users/${viewer.username}/block`).set(auth(h)).expect(200);
      expectError(await seats(roomId, viewer), 404, 'NOT_FOUND', 'getLiveRoomSeats');
      await end(roomId, h);
      expectError(await seats(roomId, h), 409, 'LIVE_ROOM_ENDED', 'getLiveRoomSeats');
    });
  });

  describe('asking for a seat', () => {
    it('request, list, accept (permission, metadata, version), decline, cancel', async () => {
      const [h, a, b, c] = [await host(), await signup(), await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      await watch(roomId, a, b, c);

      const created = await ask(roomId, a, { seatIndex: 2 });
      expect(created.status).toBe(201);
      expectContract(created, 'requestLiveSeat');
      expect(created.body).toMatchObject({ user: { id: a.id }, seatIndex: 2 });
      const again = await ask(roomId, a);
      expect(again.status).toBe(200);
      expectContract(again, 'requestLiveSeat');
      expect(again.body.id).toBe(created.body.id);
      expect(await version(roomId)).toBe(1);
      expect(media.metadata.get(roomId)).toBe(JSON.stringify({ seatsVersion: 1, score: 0 }));
      expect((await seats(roomId, a)).body.mine.request).toMatchObject({ id: created.body.id, seatIndex: 2 });

      const bReq = await ask(roomId, b);
      const cReq = await ask(roomId, c);
      expect((await seats(roomId, h)).body.pendingRequests).toBe(3);

      // Host lists, oldest first, cursor-paged; a viewer may not.
      const page1 = await call('get', `${roomId}/seat-requests?limit=2`, h);
      expect(page1.status).toBe(200);
      expectContract(page1, 'listLiveSeatRequests');
      expect(page1.body.data.map((r: { id: string }) => r.id)).toEqual([created.body.id, bReq.body.id]);
      const page2 = await call(
        'get',
        `${roomId}/seat-requests?limit=2&cursor=${encodeURIComponent(page1.body.page.nextCursor)}`,
        h,
      );
      expect(page2.body.data.map((r: { id: string }) => r.id)).toEqual([cReq.body.id]);
      expect(page2.body.page).toEqual({ hasMore: false, nextCursor: null });
      expectError(
        await call('get', `${roomId}/seat-requests`, a),
        403,
        'AUTH_FORBIDDEN',
        'listLiveSeatRequests',
      );
      expectError(
        await call('get', `${roomId}/seat-requests?cursor=forged`, h),
        400,
        'VALIDATION_FAILED',
        'listLiveSeatRequests',
      );

      // A viewer cannot accept.
      expectError(await accept(roomId, bReq.body.id, a), 403, 'AUTH_FORBIDDEN', 'acceptLiveSeatRequest');

      const before = media.permissions.length;
      const accepted = await accept(roomId, created.body.id, h);
      expect(accepted.status).toBe(200);
      expectContract(accepted, 'acceptLiveSeatRequest');
      expect(accepted.body.seats[1]).toMatchObject({
        index: 2,
        state: 'TAKEN',
        user: { id: a.id },
        mutedByHost: false,
      });
      expect(accepted.body.version).toBe(4);
      expect(media.permissions.slice(before)).toEqual([
        { room: roomId, identity: a.id, permission: { visible: true, sources: ['camera', 'microphone'] } },
      ]);
      expect(media.metadata.get(roomId)).toBe(JSON.stringify({ seatsVersion: 4, score: 0 }));
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body.occupiedSeats).toBe(1);
      const mine = (await seats(roomId, a)).body.mine;
      expect(mine).toEqual({ role: 'SEATED', seatIndex: 2, request: null, invite: null });

      // A seated guest's media token is SPEAKER with the seat's sources.
      const speaker = await call('post', `${roomId}/media-token`, a, {});
      expectContract(speaker, 'createLiveMediaToken');
      expect(speaker.body.role).toBe('SPEAKER');
      expect(media.issued.at(-1)).toMatchObject({
        identity: a.id,
        publish: true,
        sources: ['camera', 'microphone'],
      });

      expectError(
        await accept(roomId, created.body.id, h),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatRequest',
      );
      expectError(await ask(roomId, a), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      expectError(await ask(roomId, h), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      expectError(await accept(roomId, randomUUID(), h), 404, 'NOT_FOUND', 'acceptLiveSeatRequest');
      expectError(await accept(roomId, 'nope', h), 404, 'NOT_FOUND', 'acceptLiveSeatRequest');
      // The seat asked for is taken: the host can still name a free one; a taken one is refused.
      expectError(
        await accept(roomId, bReq.body.id, h, { seatIndex: 2 }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'acceptLiveSeatRequest',
      );
      expectError(
        await accept(roomId, bReq.body.id, h, { seatIndex: 25 }),
        400,
        'VALIDATION_FAILED',
        'acceptLiveSeatRequest',
      );

      // Decline (idempotent), then accepting it is 409.
      const declined = await call('post', `${roomId}/seat-requests/${bReq.body.id}/decline`, h);
      expect(declined.status).toBe(204);
      expectContract(declined, 'declineLiveSeatRequest');
      await call('post', `${roomId}/seat-requests/${bReq.body.id}/decline`, h).expect(204);
      expectError(
        await accept(roomId, bReq.body.id, h),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatRequest',
      );
      expectError(
        await call('post', `${roomId}/seat-requests/${cReq.body.id}/decline`, b),
        403,
        'AUTH_FORBIDDEN',
        'declineLiveSeatRequest',
      );
      expectError(
        await call('post', `${roomId}/seat-requests/${randomUUID()}/decline`, h),
        404,
        'NOT_FOUND',
        'declineLiveSeatRequest',
      );

      // Cancel (idempotent).
      const cancelled = await call('delete', `${roomId}/seat-requests/me`, c);
      expect(cancelled.status).toBe(204);
      expectContract(cancelled, 'cancelLiveSeatRequest');
      await call('delete', `${roomId}/seat-requests/me`, c).expect(204);
      expectError(
        await accept(roomId, cReq.body.id, h),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatRequest',
      );
      expect((await seats(roomId, h)).body.pendingRequests).toBe(0);

      // Seats out of range, malformed bodies, guests.
      const free = await ask(roomId, b, { seatIndex: 3 });
      expect(free.status).toBe(201);
      expectContract(free, 'requestLiveSeat');
      await call('delete', `${roomId}/seat-requests/me`, b).expect(204);
      expectError(await ask(roomId, b, { seatIndex: 4 }), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      expectError(await ask(roomId, b, { seatIndex: 0 }), 400, 'VALIDATION_FAILED', 'requestLiveSeat');
      expectError(await ask(roomId, b, { seat: 1 }), 400, 'VALIDATION_FAILED', 'requestLiveSeat');
      const guestAsk = await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).send({});
      expectError(guestAsk, 401, 'AUTH_UNAUTHENTICATED', 'requestLiveSeat');
      expectError(await ask(randomUUID(), b), 404, 'NOT_FOUND', 'requestLiveSeat');
      await end(roomId, h);
      expectError(await ask(roomId, b), 409, 'LIVE_ROOM_ENDED', 'requestLiveSeat');
    });

    it('a SOLO room and a full room refuse requests (409 LIVE_SEAT_UNAVAILABLE)', async () => {
      const [h1, h2, a, b, c, d] = [
        await host(),
        await host(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const solo = await goLive(h1, {});
      expectError(await ask(solo, a), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      const roomId = await goLive(h2, { mode: 'MULTI', seatCount: 4 });
      await seat(roomId, h2, a);
      await seat(roomId, h2, b);
      await seat(roomId, h2, c);
      expectError(await ask(roomId, d), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body.occupiedSeats).toBe(3);
      await end(solo, h1);
      await end(roomId, h2);
    });

    it('two accepts racing for the last seat: exactly one wins', async () => {
      const [h, a, b, x, y] = [await host(), await signup(), await signup(), await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      await seat(roomId, h, a);
      await seat(roomId, h, b);
      const rx = await ask(roomId, x);
      const ry = await ask(roomId, y);
      const v = await version(roomId);
      const results = await Promise.all([accept(roomId, rx.body.id, h), accept(roomId, ry.body.id, h)]);
      expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
      const loser = results.find((r) => r.status === 409)!;
      expectError(loser, 409, 'LIVE_SEAT_UNAVAILABLE', 'acceptLiveSeatRequest');
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: { not: null } } })).toBe(3);
      expect(await version(roomId)).toBe(v + 1);
      await end(roomId, h);
    });
  });

  describe('invitations', () => {
    it('invite a watcher (data message), replace, accept, expire, decline, refusals', async () => {
      const [h, a, b, blocked, stranger] = [
        await host(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 5 });
      await watch(roomId, a, b, blocked);

      expectError(
        await invite(roomId, h, { username: stranger.username }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'inviteToLiveSeat',
      );
      const first = await invite(roomId, h, { username: a.username, seatIndex: 3 });
      expect(first.status).toBe(201);
      expectContract(first, 'inviteToLiveSeat');
      expect(first.body).toMatchObject({ user: { id: a.id }, seatIndex: 3, invitedBy: { id: h.id } });
      expect(new Date(first.body.expiresAt).getTime() - Date.now()).toBeLessThanOrEqual(60_000);
      expect(media.data.at(-1)).toEqual({
        room: roomId,
        identity: a.id,
        payload: JSON.stringify({ type: 'seat-invite', roomId }),
      });
      const second = await invite(roomId, h, { username: a.username });
      expect(second.body.id).not.toBe(first.body.id);
      expect(
        await ctx.prisma.liveSeatInvite.count({ where: { roomId, userId: a.id, status: 'PENDING' } }),
      ).toBe(1);
      expect((await seats(roomId, a)).body.mine.invite).toMatchObject({
        id: second.body.id,
        seatIndex: null,
      });

      const accepted = await call('post', `${roomId}/seat-invites/me/accept`, a);
      expect(accepted.status).toBe(200);
      expectContract(accepted, 'acceptLiveSeatInvite');
      expect(accepted.body.mine).toEqual({ role: 'SEATED', seatIndex: 1, request: null, invite: null });
      expect(media.lastPermission(roomId, a.id)).toEqual({ visible: true, sources: ['microphone'] });
      expectError(
        await call('post', `${roomId}/seat-invites/me/accept`, a),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatInvite',
      );
      expectError(
        await invite(roomId, h, { username: a.username }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'inviteToLiveSeat',
      );
      expectError(
        await invite(roomId, h, { username: h.username }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'inviteToLiveSeat',
      );

      // Expired after 60 seconds.
      await invite(roomId, h, { username: b.username }).then((r) => expect(r.status).toBe(201));
      await ctx.prisma.liveSeatInvite.updateMany({
        where: { roomId, userId: b.id, status: 'PENDING' },
        data: { createdAt: new Date(Date.now() - 120_000), expiresAt: new Date(Date.now() - 1000) },
      });
      expect((await seats(roomId, b)).body.mine.invite).toBeNull();
      expectError(
        await call('post', `${roomId}/seat-invites/me/accept`, b),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatInvite',
      );
      expect(
        (
          await ctx.prisma.liveSeatInvite.findFirst({
            where: { roomId, userId: b.id },
            orderBy: { createdAt: 'desc' },
          })
        )?.status,
      ).toBe('EXPIRED');

      // Decline (idempotent).
      await invite(roomId, h, { username: b.username }).then((r) => expect(r.status).toBe(201));
      const declined = await call('post', `${roomId}/seat-invites/me/decline`, b);
      expect(declined.status).toBe(204);
      expectContract(declined, 'declineLiveSeatInvite');
      await call('post', `${roomId}/seat-invites/me/decline`, b).expect(204);
      expectError(
        await call('post', `${roomId}/seat-invites/me/accept`, b),
        409,
        'LIVE_REQUEST_NOT_PENDING',
        'acceptLiveSeatInvite',
      );

      // Not privileged, unknown, blocked, malformed.
      expectError(
        await invite(roomId, b, { username: blocked.username }),
        403,
        'AUTH_FORBIDDEN',
        'inviteToLiveSeat',
      );
      expectError(
        await invite(roomId, h, { username: 'nobody_here_x' }),
        404,
        'NOT_FOUND',
        'inviteToLiveSeat',
      );
      await ctx.http.put(`/api/v1/users/${h.username}/block`).set(auth(blocked)).expect(200);
      expectError(
        await invite(roomId, h, { username: blocked.username }),
        404,
        'NOT_FOUND',
        'inviteToLiveSeat',
      );
      expectError(await invite(roomId, h, {}), 400, 'VALIDATION_FAILED', 'inviteToLiveSeat');
      expectError(
        await invite(roomId, h, { username: b.username, seatIndex: 4 + 1 }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'inviteToLiveSeat',
      );
      expectError(
        await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-invites/me/accept`),
        401,
        'AUTH_UNAUTHENTICATED',
        'acceptLiveSeatInvite',
      );
      await end(roomId, h);
    });
  });

  describe('host and moderator controls', () => {
    it('mute (MULTI: camera only; AUDIO: nothing), remove, lock, leave; refusals', async () => {
      const [h, ha, a, b, viewer] = [
        await host(),
        await host(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      await seat(roomId, h, a);

      const muted = await call('post', `${roomId}/seats/1/mute`, h, { muted: true });
      expect(muted.status).toBe(200);
      expectContract(muted, 'muteLiveSeat');
      expect(muted.body.seats[0]).toMatchObject({ state: 'TAKEN', mutedByHost: true });
      expect(media.lastPermission(roomId, a.id)).toEqual({ visible: true, sources: ['camera'] });
      const v = await version(roomId);
      await call('post', `${roomId}/seats/1/mute`, h, { muted: true }).expect(200);
      expect(await version(roomId)).toBe(v);
      // The token follows the mute.
      await call('post', `${roomId}/media-token`, a, {}).expect(200);
      expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: ['camera'] });
      await call('post', `${roomId}/seats/1/mute`, h, { muted: false }).expect(200);
      expect(media.lastPermission(roomId, a.id)).toEqual({
        visible: true,
        sources: ['camera', 'microphone'],
      });

      expectError(
        await call('post', `${roomId}/seats/2/mute`, h, { muted: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'muteLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/4/mute`, h, { muted: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'muteLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/abc/mute`, h, { muted: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'muteLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/x1/remove`, h),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'removeFromLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/0/lock`, h, { locked: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'lockLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/1/mute`, h, {}),
        400,
        'VALIDATION_FAILED',
        'muteLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/1/mute`, viewer, { muted: true }),
        403,
        'AUTH_FORBIDDEN',
        'muteLiveSeat',
      );

      // Lock: empty seats only; a locked seat cannot be asked for.
      const locked = await call('post', `${roomId}/seats/3/lock`, h, { locked: true });
      expect(locked.status).toBe(200);
      expectContract(locked, 'lockLiveSeat');
      expect(locked.body.seats[2]).toEqual({ index: 3, state: 'LOCKED', user: null, mutedByHost: false });
      expectError(await ask(roomId, b, { seatIndex: 3 }), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      expectError(
        await call('post', `${roomId}/seats/1/lock`, h, { locked: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'lockLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/2/lock`, viewer, { locked: true }),
        403,
        'AUTH_FORBIDDEN',
        'lockLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/9/lock`, h, { locked: true }),
        409,
        'LIVE_SEAT_UNAVAILABLE',
        'lockLiveSeat',
      );
      // With seat 3 locked and seat 1 taken, b gets seat 2; then nothing is free.
      await seat(roomId, h, b);
      expectError(await ask(roomId, viewer), 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
      await call('post', `${roomId}/seats/3/lock`, h, { locked: false }).expect(200);
      expect((await seats(roomId)).body.seats[2].state).toBe('EMPTY');

      // Remove: the guest keeps watching but stops publishing; an empty seat is unchanged.
      const removed = await call('post', `${roomId}/seats/2/remove`, h);
      expect(removed.status).toBe(200);
      expectContract(removed, 'removeFromLiveSeat');
      expect(removed.body.seats[1].state).toBe('EMPTY');
      expect(media.lastPermission(roomId, b.id)).toEqual({ visible: false, sources: [] });
      const v2 = await version(roomId);
      expect((await call('post', `${roomId}/seats/2/remove`, h)).status).toBe(200);
      expect(await version(roomId)).toBe(v2);
      expectError(
        await call('post', `${roomId}/seats/1/remove`, viewer),
        403,
        'AUTH_FORBIDDEN',
        'removeFromLiveSeat',
      );

      // Leave (idempotent).
      const left = await call('post', `${roomId}/seats/me/leave`, a);
      expect(left.status).toBe(204);
      expectContract(left, 'leaveLiveSeat');
      await call('post', `${roomId}/seats/me/leave`, a).expect(204);
      expect(media.lastPermission(roomId, a.id)).toEqual({ visible: false, sources: [] });
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body.occupiedSeats).toBe(0);
      await end(roomId, h);

      // AUDIO: muting withdraws the microphone, so nothing is published.
      const audio = await goLive(ha, { mode: 'AUDIO', seatCount: 5 });
      await seat(audio, ha, a);
      await call('post', `${audio}/seats/1/mute`, ha, { muted: true }).expect(200);
      expect(media.lastPermission(audio, a.id)).toEqual({ visible: true, sources: [] });
      await call('post', `${audio}/media-token`, a, {}).expect(200);
      expect(media.issued.at(-1)).toMatchObject({ publish: true, sources: [] });
      await end(audio, ha);
    });

    it('moderators: host appoints up to 5; they handle seats but never act on the host or another moderator', async () => {
      const h = await host();
      const mods = [await signup(), await signup(), await signup(), await signup(), await signup()];
      const [sixth, guest, blocked] = [await signup(), await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 6 });

      const added = await call('put', `${roomId}/moderators/${mods[0]!.username}`, h);
      expect(added.status).toBe(200);
      expectContract(added, 'addLiveModerator');
      expect(added.body.moderators).toEqual([expect.objectContaining({ id: mods[0]!.id })]);
      const v = await version(roomId);
      await call('put', `${roomId}/moderators/${mods[0]!.username}`, h).expect(200);
      expect(await version(roomId)).toBe(v);
      for (const m of mods.slice(1)) await call('put', `${roomId}/moderators/${m.username}`, h).expect(200);
      const limit = await call('put', `${roomId}/moderators/${sixth.username}`, h);
      expectError(limit, 422, 'VALIDATION_FAILED', 'addLiveModerator');
      expect(limit.body.error.details).toEqual([{ field: 'moderators', issue: 'too_many' }]);
      const self = await call('put', `${roomId}/moderators/${h.username}`, h);
      expectError(self, 422, 'VALIDATION_FAILED', 'addLiveModerator');
      expectError(
        await call('put', `${roomId}/moderators/nobody_here_x`, h),
        404,
        'NOT_FOUND',
        'addLiveModerator',
      );
      expectError(
        await call('put', `${roomId}/moderators/${sixth.username}`, mods[0]),
        403,
        'AUTH_FORBIDDEN',
        'addLiveModerator',
      );

      const [m1, m2] = [mods[0]!, mods[1]!];
      const mine = (await seats(roomId, m1)).body;
      expect(mine.mine.role).toBe('MODERATOR');
      expect(mine.pendingRequests).toBe(0);

      // A moderator accepts and invites; a moderator may sit (MODERATOR with a seatIndex).
      await watch(roomId, guest);
      const r = await ask(roomId, guest);
      expect((await seats(roomId, m1)).body.pendingRequests).toBe(1);
      expect((await call('get', `${roomId}/seat-requests`, m1)).status).toBe(200);
      await accept(roomId, r.body.id, m1).then((res) => expect(res.status).toBe(200));
      const m2Req = await ask(roomId, m2);
      // ... but never acts on another moderator.
      expectError(await accept(roomId, m2Req.body.id, m1), 403, 'AUTH_FORBIDDEN', 'acceptLiveSeatRequest');
      await accept(roomId, m2Req.body.id, h).then((res) => expect(res.status).toBe(200));
      expect((await seats(roomId, m2)).body.mine).toMatchObject({ role: 'MODERATOR', seatIndex: 2 });
      expectError(
        await call('post', `${roomId}/seats/2/mute`, m1, { muted: true }),
        403,
        'AUTH_FORBIDDEN',
        'muteLiveSeat',
      );
      expectError(
        await call('post', `${roomId}/seats/2/remove`, m1),
        403,
        'AUTH_FORBIDDEN',
        'removeFromLiveSeat',
      );
      await call('post', `${roomId}/seats/1/mute`, m1, { muted: true }).expect(200);
      await call('post', `${roomId}/seats/1/remove`, m1).expect(200);
      // Host-only controls.
      expectError(
        await call('post', `${roomId}/seats/3/lock`, m1, { locked: true }),
        403,
        'AUTH_FORBIDDEN',
        'lockLiveSeat',
      );
      expect((await call('patch', roomId, m1, { theme: 'rose-garden' })).status).toBe(404);

      // Removing (idempotent); a blocked user cannot be appointed.
      const removed = await call('delete', `${roomId}/moderators/${m1.username}`, h);
      expect(removed.status).toBe(200);
      expectContract(removed, 'removeLiveModerator');
      expect(removed.body.moderators.map((u: { id: string }) => u.id)).not.toContain(m1.id);
      await call('delete', `${roomId}/moderators/${m1.username}`, h).expect(200);
      expectError(
        await call('delete', `${roomId}/moderators/${m2.username}`, m1),
        403,
        'AUTH_FORBIDDEN',
        'removeLiveModerator',
      );
      expectError(
        await call('delete', `${roomId}/moderators/nobody_here_x`, h),
        404,
        'NOT_FOUND',
        'removeLiveModerator',
      );
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(h)).expect(200);
      expectError(
        await call('put', `${roomId}/moderators/${blocked.username}`, h),
        404,
        'NOT_FOUND',
        'addLiveModerator',
      );
      await end(roomId, h);
      expectError(
        await call('put', `${roomId}/moderators/${m1.username}`, h),
        409,
        'LIVE_ROOM_ENDED',
        'addLiveModerator',
      );
    });

    it('PATCH changes seatCount (not below an occupied seat) and theme', async () => {
      const [h, h2, a] = [await host(), await host(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 9 });
      await seat(roomId, h, a, { seatIndex: 5 });
      await call('post', `${roomId}/seats/7/lock`, h, { locked: true }).expect(200);

      const shrinkBad = await call('patch', roomId, h, { seatCount: 4 });
      expectError(shrinkBad, 409, 'LIVE_SEAT_UNAVAILABLE', 'updateLiveRoom');
      const wrongMode = await call('patch', roomId, h, { seatCount: 5 });
      expectError(wrongMode, 400, 'VALIDATION_FAILED', 'updateLiveRoom');
      expect(wrongMode.body.error.details).toEqual([{ field: 'seatCount', issue: 'invalid_value' }]);
      expectError(await call('patch', roomId, h, {}), 400, 'VALIDATION_FAILED', 'updateLiveRoom');
      expectError(
        await call('patch', roomId, h, { theme: 'nope-nope' }),
        400,
        'VALIDATION_FAILED',
        'updateLiveRoom',
      );

      await call('post', `${roomId}/seats/5/remove`, h).expect(200);
      await seat(roomId, h, a, { seatIndex: 2 });
      const v = await version(roomId);
      const resized = await call('patch', roomId, h, { seatCount: 4, theme: 'desert-night' });
      expect(resized.status).toBe(200);
      expectContract(resized, 'updateLiveRoom');
      expect(resized.body).toMatchObject({ seatCount: 4, theme: 'desert-night', occupiedSeats: 1 });
      expect(await version(roomId)).toBe(v + 1);
      // The lock on seat 7 went with the seats beyond the new count.
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, seatIndex: { gte: 4 } } })).toBe(0);
      const after = await seats(roomId);
      expect(after.body.seats.map((s: { state: string }) => s.state)).toEqual(['EMPTY', 'TAKEN', 'EMPTY']);
      expect(media.metadata.get(roomId)).toBe(JSON.stringify({ seatsVersion: v + 1, score: 0 }));
      const themeOnly = await call('patch', roomId, h, { theme: 'classic' });
      expect(themeOnly.body.theme).toBe('classic');

      const solo = await goLive(h2, {});
      const soloResize = await call('patch', solo, h2, { seatCount: 4 });
      expectError(soloResize, 400, 'VALIDATION_FAILED', 'updateLiveRoom');
      expect((await call('patch', solo, h2, { theme: 'rose-garden' })).body.theme).toBe('rose-garden');
      await end(roomId, h);
      await end(solo, h2);
    });
  });

  describe('losing a seat', () => {
    it('leaving the media session (webhook or reconciliation) ends the seat, the request and the invitation', async () => {
      const [h, a, b, c] = [await host(), await signup(), await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      await watch(roomId, a, b, c);
      await seat(roomId, h, a);
      const pending = await ask(roomId, b);
      await invite(roomId, h, { username: c.username }).then((r) => expect(r.status).toBe(201));
      const v = await version(roomId);

      await hook('participant_left', roomId, a.id).expect(200);
      await hook('participant_left', roomId, b.id).expect(200);
      expect((await seats(roomId, a)).body.mine).toEqual({
        role: 'VIEWER',
        seatIndex: null,
        request: null,
        invite: null,
      });
      expect(
        (await ctx.prisma.liveSeatRequest.findUniqueOrThrow({ where: { id: pending.body.id } })).status,
      ).toBe('EXPIRED');
      expect(await version(roomId)).toBe(v + 2);
      expect(media.lastPermission(roomId, a.id)).toEqual({ visible: false, sources: [] });
      // A seated guest who rejoins gets the seat's permission again at once.
      await seat(roomId, h, b);
      await hook('participant_left', roomId, b.id).expect(200);
      await seat(roomId, h, b);
      const writes = media.permissions.length;
      await hook('participant_joined', roomId, b.id).expect(200);
      expect(media.permissions.slice(writes)).toEqual([
        { room: roomId, identity: b.id, permission: { visible: true, sources: ['camera', 'microphone'] } },
      ]);
      await call('post', `${roomId}/seats/me/leave`, b).expect(204);
      // A viewer without seat or request leaving changes nothing.
      const v2 = await version(roomId);
      await hook('participant_joined', roomId, a.id).expect(200);
      await hook('participant_left', roomId, a.id).expect(200);
      expect(await version(roomId)).toBe(v2);

      // Reconciliation: c is no longer connected according to the media server.
      media.rooms.get(roomId)?.delete(c.id);
      await ctx.app.get(LiveMediaService).reconcile();
      expect((await seats(roomId, c)).body.mine.invite).toBeNull();
      expect(
        await ctx.prisma.liveSeatInvite.count({ where: { roomId, userId: c.id, status: 'PENDING' } }),
      ).toBe(0);
      await end(roomId, h);
    });

    it('a block with the host, a suspension and the room ending free seats and end requests', async () => {
      const [h, a, b, m, s] = [await host(), await signup(), await signup(), await signup(), await signup()];
      const roomId = await goLive(h, { mode: 'AUDIO', seatCount: 10 });
      await watch(roomId, a, b, m, s);
      await seat(roomId, h, a);
      await seat(roomId, h, s);
      await call('put', `${roomId}/moderators/${m.username}`, h).expect(200);
      await ask(roomId, b);

      // The guest blocks the host: they lose their seat (and stop publishing).
      await ctx.http.put(`/api/v1/users/${h.username}/block`).set(auth(a)).expect(200);
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: a.id } })).toBe(0);
      expect(media.lastPermission(roomId, a.id)).toEqual({ visible: false, sources: [] });
      // The host blocks a moderator: no longer a moderator.
      await ctx.http.put(`/api/v1/users/${m.username}/block`).set(auth(h)).expect(200);
      expect(await ctx.prisma.liveRoomModerator.count({ where: { roomId } })).toBe(0);

      // Suspension.
      await ctx.app.get(AccountLifecycleService).suspend(s.id);
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: s.id } })).toBe(0);

      // The room ends: requests expire, seats empty, the seats read 409.
      await end(roomId, h);
      expect(await ctx.prisma.liveSeatRequest.count({ where: { roomId, status: 'PENDING' } })).toBe(0);
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: { not: null } } })).toBe(0);
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(h))).body.occupiedSeats).toBe(0);
      expectError(await seats(roomId, h), 409, 'LIVE_ROOM_ENDED', 'getLiveRoomSeats');
      expectError(
        await call('post', `${roomId}/seats/1/mute`, h, { muted: true }),
        409,
        'LIVE_ROOM_ENDED',
        'muteLiveSeat',
      );
      expect((await call('get', `${roomId}/seat-requests`, h)).body.data).toEqual([]);
    });
  });

  describe('media server failures', () => {
    it('never undo a seat change; reconciliation repairs permission and metadata', async () => {
      const [h, a] = [await host(), await signup()];
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      await watch(roomId, a);
      const r = await ask(roomId, a);
      media.failing = true;
      try {
        const res = await accept(roomId, r.body.id, h);
        expect(res.status).toBe(200);
      } finally {
        media.failing = false;
      }
      expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: a.id } })).toBe(1);
      const v = await version(roomId);
      expect(media.metadata.get(roomId)).not.toBe(JSON.stringify({ seatsVersion: v, score: 0 }));
      await ctx.app.get(LiveMediaService).reconcile();
      expect(media.lastPermission(roomId, a.id)).toEqual({
        visible: true,
        sources: ['camera', 'microphone'],
      });
      expect(media.metadata.get(roomId)).toBe(JSON.stringify({ seatsVersion: v, score: 0 }));
      // Nothing more to repair.
      const writes = media.permissions.length;
      await ctx.app.get(LiveMediaService).reconcile();
      expect(media.permissions.length).toBe(writes);
      await end(roomId, h);
    });
  });

  describe('authentication', () => {
    it('every seat operation but reading needs a token (401); guests read the seats', async () => {
      const h = await host();
      const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
      const id = randomUUID();
      const calls: [string, () => Promise<request.Response>][] = [
        ['requestLiveSeat', () => call('post', `${roomId}/seat-requests`, undefined, {})],
        ['listLiveSeatRequests', () => call('get', `${roomId}/seat-requests`)],
        ['cancelLiveSeatRequest', () => call('delete', `${roomId}/seat-requests/me`)],
        ['acceptLiveSeatRequest', () => call('post', `${roomId}/seat-requests/${id}/accept`, undefined, {})],
        ['declineLiveSeatRequest', () => call('post', `${roomId}/seat-requests/${id}/decline`)],
        ['inviteToLiveSeat', () => call('post', `${roomId}/seat-invites`, undefined, { username: 'x' })],
        ['acceptLiveSeatInvite', () => call('post', `${roomId}/seat-invites/me/accept`)],
        ['declineLiveSeatInvite', () => call('post', `${roomId}/seat-invites/me/decline`)],
        ['leaveLiveSeat', () => call('post', `${roomId}/seats/me/leave`)],
        ['muteLiveSeat', () => call('post', `${roomId}/seats/1/mute`, undefined, { muted: true })],
        ['removeFromLiveSeat', () => call('post', `${roomId}/seats/1/remove`)],
        ['lockLiveSeat', () => call('post', `${roomId}/seats/1/lock`, undefined, { locked: true })],
        ['addLiveModerator', () => call('put', `${roomId}/moderators/someone`)],
        ['removeLiveModerator', () => call('delete', `${roomId}/moderators/someone`)],
      ];
      for (const [operationId, run] of calls) {
        const res = await run();
        expectContract(res, operationId);
        expect({ operationId, status: res.status, code: res.body.error?.code }).toEqual({
          operationId,
          status: 401,
          code: 'AUTH_UNAUTHENTICATED',
        });
      }
      const guest = await seats(roomId);
      expect(guest.status).toBe(200);
      expectContract(guest, 'getLiveRoomSeats');
      await end(roomId, h);
    });
  });

  describe('rate limits', () => {
    let limited: TestContext;
    beforeAll(async () => {
      limited = await createTestApp({
        LIVE_HOSTING_ENABLED: 'true',
        RATE_LIMIT_LIVE_SEAT_ASK_USER: '2/600',
        RATE_LIMIT_LIVE_SEAT_ACTION_USER: '2/3600',
        RATE_LIMIT_LIVE_SEATS_READ_USER: '2/900',
        RATE_LIMIT_LIVE_GUEST_READ_IP: '2/900',
      });
    });
    afterAll(async () => limited?.close());

    it('seat requests, host actions (incl. seatCount/theme in PATCH) and seat reads are limited (429)', async () => {
      const reg = async () => {
        const { res } = await registerVerified(limited);
        return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
      };
      const [h, a] = [await reg(), await reg()];
      await limited.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
      const bearer = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
      const room = await limited.http
        .post('/api/v1/live/rooms')
        .set(bearer(h))
        .send({ title: 'x', mode: 'MULTI', seatCount: 4 });
      const roomId = room.body.id as string;
      const base = `/api/v1/live/rooms/${roomId}`;

      for (let i = 0; i < 2; i += 1)
        await limited.http
          .post(`${base}/seat-requests`)
          .set(bearer(a))
          .send({})
          .expect((r) => expect(r.status).toBeLessThan(300));
      const asked = await limited.http.post(`${base}/seat-requests`).set(bearer(a)).send({});
      expectContract(asked, 'requestLiveSeat');
      expect(asked.status).toBe(429);
      expect(asked.headers['retry-after']).toBeDefined();

      await limited.http.patch(base).set(bearer(h)).send({ theme: 'classic' }).expect(200);
      await limited.http.post(`${base}/seats/1/lock`).set(bearer(h)).send({ locked: true }).expect(200);
      const action = await limited.http.patch(base).set(bearer(h)).send({ theme: 'rose-garden' });
      expect(action.status).toBe(429);
      expectContract(action, 'updateLiveRoom');
      // allowGuests alone is not a seat action.
      await limited.http.patch(base).set(bearer(h)).send({ allowGuests: true }).expect(200);

      for (let i = 0; i < 2; i += 1) await limited.http.get(`${base}/seats`).set(bearer(a)).expect(200);
      const read = await limited.http.get(`${base}/seats`).set(bearer(a));
      expect(read.status).toBe(429);
      expectContract(read, 'getLiveRoomSeats');
      for (let i = 0; i < 2; i += 1) await limited.http.get(`${base}/seats`).expect(200);
      expect((await limited.http.get(`${base}/seats`)).status).toBe(429);
    });
  });
});
