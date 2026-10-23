/**
 * KL-063 / CP-010 (D93): live video L1 (openapi v1.6-live DRAFT, CONVENTIONS §10.8), end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role. The media server is the
 * in-memory fake behind the LiveMediaProvider port (signed webhooks included); the real LiveKit
 * server is exercised by kl063-livekit-real (gated) and the app check.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('CP-010 live video contract coverage', () => {
  it('openapi declares the five live video operations', () => {
    expect(
      operations()
        .filter((o) =>
          [
            'createLiveMediaToken',
            'updateLiveRoom',
            'listLiveRoomViewers',
            'grantLiveHost',
            'revokeLiveHost',
          ].includes(o.operationId),
        )
        .map((o) => `${o.method.toUpperCase()} ${o.path}`)
        .sort(),
    ).toEqual([
      'DELETE /api/v1/admin/live/hosts/{username}',
      'GET /api/v1/live/rooms/{roomId}/viewers',
      'PATCH /api/v1/live/rooms/{roomId}',
      'POST /api/v1/live/rooms/{roomId}/media-token',
      'PUT /api/v1/admin/live/hosts/{username}',
    ]);
  });
});

describe('CP-010 live video', () => {
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
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Live now', ...extra });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const token = (roomId: string, u?: TestUser, body: object = {}) => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`);
    if (u) void req.set(auth(u));
    return req.send(body);
  };
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
  const room = async (roomId: string, u?: TestUser) => {
    const req = ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    if (u) void req.set(auth(u));
    return req;
  };
  const admin = async (permission: 'LIVE_HOSTS' | 'MODERATION'): Promise<TestUser> => {
    const u = await signup();
    await withMigrationClient(async (c) => {
      await c.user.update({ where: { id: u.id }, data: { role: 'ADMIN' } });
      await c.userAdminPermission.create({ data: { userId: u.id, permission } });
    });
    return u;
  };

  beforeAll(async () => {
    media = new MemoryLiveMedia();
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  describe('hosting permission', () => {
    it('going live needs it (403); admins with LIVE_HOSTS grant and revoke it; revoking ends the live', async () => {
      const [u, plainAdmin, hostsAdmin] = [
        await signup(),
        await admin('MODERATION'),
        await admin('LIVE_HOSTS'),
      ];
      const me = await ctx.http.get('/api/v1/me').set(auth(u));
      expectContract(me, 'getMe');
      expect(me.body.canHost).toBe(false);
      const refused = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Hi' });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_HOSTING_NOT_ALLOWED');
      expectContract(refused, 'startLiveRoom');

      const denied = await ctx.http.put(`/api/v1/admin/live/hosts/${u.username}`).set(auth(plainAdmin));
      expect(denied.status).toBe(403);
      expectContract(denied, 'grantLiveHost');
      for (let i = 0; i < 2; i += 1) {
        const ok = await ctx.http.put(`/api/v1/admin/live/hosts/${u.username}`).set(auth(hostsAdmin));
        expect(ok.status).toBe(204);
      }
      expect(
        (await ctx.http.put('/api/v1/admin/live/hosts/nobody_here_x').set(auth(hostsAdmin))).status,
      ).toBe(404);
      expect((await ctx.http.get('/api/v1/me').set(auth(u))).body.canHost).toBe(true);
      const roomId = await goLive(u);

      const revoked = await ctx.http.delete(`/api/v1/admin/live/hosts/${u.username}`).set(auth(hostsAdmin));
      expect(revoked.status).toBe(204);
      expectContract(revoked, 'revokeLiveHost');
      const ended = await room(roomId, u);
      expect(ended.body).toMatchObject({ status: 'ENDED', endReason: 'ADMIN' });
      expect(media.closed).toContain(roomId);
      expect((await ctx.http.get('/api/v1/me').set(auth(u))).body.canHost).toBe(false);
      const audit = await ctx.prisma.auditLog.findMany({
        where: { targetId: u.id, action: { in: ['live.host.grant', 'live.host.revoke'] } },
        orderBy: { createdAt: 'asc' },
      });
      expect(audit.map((a) => a.action)).toEqual(['live.host.grant', 'live.host.revoke']);
    });
  });

  describe('media tokens', () => {
    it('host publishes, a viewer watches, a guest watches with a stable number; refusals', async () => {
      const [h, viewer] = [await host(), await signup()];
      const roomId = await goLive(h);

      const hostAccess = await token(roomId, h);
      expect(hostAccess.status).toBe(200);
      expectContract(hostAccess, 'createLiveMediaToken');
      expect(hostAccess.body).toMatchObject({
        url: media.url,
        role: 'HOST',
        identity: h.id,
        guestNumber: null,
      });
      expect(media.issued.at(-1)).toMatchObject({
        room: roomId,
        identity: h.id,
        publish: true,
        ttlSeconds: 600,
      });

      const viewerAccess = await token(roomId, viewer);
      expect(viewerAccess.body).toMatchObject({ role: 'VIEWER', identity: viewer.id });
      expect(media.issued.at(-1)).toMatchObject({ publish: false });

      const missing = await token(roomId);
      expect(missing.status).toBe(400);
      expect(missing.body.error.details).toEqual([{ field: 'guestId', issue: 'required' }]);
      const guestId = randomUUID();
      const g1 = await token(roomId, undefined, { guestId });
      const g2 = await token(roomId, undefined, { guestId: guestId.toUpperCase() });
      expect(g1.status).toBe(200);
      expectContract(g1, 'createLiveMediaToken');
      expect(g1.body).toMatchObject({ role: 'VIEWER', identity: `guest:${guestId}` });
      expect(g1.body.guestNumber).toBeGreaterThanOrEqual(1000);
      expect(g1.body.guestNumber).toBeLessThanOrEqual(9999);
      expect(g2.body.guestNumber).toBe(g1.body.guestNumber);
      expect(media.issued.at(-1)).toMatchObject({ name: `Guest ${g1.body.guestNumber}`, publish: false });

      expect((await token(randomUUID(), viewer)).status).toBe(404);
      expect((await token('nope', viewer)).status).toBe(404);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
      const ended = await token(roomId, viewer);
      expect(ended.status).toBe(409);
      expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
    });

    it('a block either way hides the room from lists, details and media', async () => {
      const [h, blocked] = [await host(), await signup()];
      const roomId = await goLive(h);
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(h)).expect(200);
      expect((await room(roomId, blocked)).status).toBe(404);
      expect((await token(roomId, blocked)).status).toBe(404);
      const list = await ctx.http.get('/api/v1/live/rooms?tab=new&limit=50').set(auth(blocked));
      expect(list.body.data.map((r: { id: string }) => r.id)).not.toContain(roomId);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    });
  });

  describe('guests', () => {
    it('read Popular, New and a room without a token, but not Following; a private host is public live (D93)', async () => {
      const h = await host();
      await withMigrationClient((c) =>
        c.userSettings.upsert({
          where: { userId: h.id },
          create: { userId: h.id, isPrivate: true },
          update: { isPrivate: true },
        }),
      );
      const roomId = await goLive(h);
      const config = await ctx.http.get('/api/v1/live/config');
      expect(config.status).toBe(200);
      expectContract(config, 'getLiveConfig');
      for (const tab of ['popular', 'new']) {
        const res = await ctx.http.get(`/api/v1/live/rooms?tab=${tab}&limit=50`);
        expect(res.status).toBe(200);
        expectContract(res, 'listLiveRooms');
        expect(res.body.data.map((r: { id: string }) => r.id)).toContain(roomId);
      }
      const following = await ctx.http.get('/api/v1/live/rooms?tab=following');
      expect(following.status).toBe(401);
      const detail = await room(roomId);
      expect(detail.status).toBe(200);
      expectContract(detail, 'getLiveRoom');
      expect(detail.body).toMatchObject({ id: roomId, allowGuests: true });
      const stranger = await signup();
      expect((await token(roomId, stranger)).status).toBe(200);
      expect((await token(roomId, undefined, { guestId: randomUUID() })).status).toBe(200);
      expect((await ctx.http.get('/api/v1/live/categories')).status).toBe(401);
      expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`)).status).toBe(401);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    });

    it('the host switches guests off (connected guests are removed) and on again', async () => {
      const [h, other] = [await host(), await signup()];
      const roomId = await goLive(h, { allowGuests: false });
      const guestId = randomUUID();
      const refused = await token(roomId, undefined, { guestId });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_GUESTS_NOT_ALLOWED');
      expectContract(refused, 'createLiveMediaToken');

      const on = await ctx.http
        .patch(`/api/v1/live/rooms/${roomId}`)
        .set(auth(h))
        .send({ allowGuests: true });
      expect(on.status).toBe(200);
      expectContract(on, 'updateLiveRoom');
      expect(on.body.allowGuests).toBe(true);
      expect((await token(roomId, undefined, { guestId })).status).toBe(200);
      await hook('participant_joined', roomId, `guest:${guestId}`).expect(200);
      await hook('participant_joined', roomId, other.id).expect(200);
      expect((await room(roomId)).body.viewerCount).toBe(2);

      expect(
        (await ctx.http.patch(`/api/v1/live/rooms/${roomId}`).set(auth(other)).send({ allowGuests: false }))
          .status,
      ).toBe(404);
      for (const body of [{}, { allowGuests: 'no' }, { allowGuests: false, title: 'x' }]) {
        const bad = await ctx.http.patch(`/api/v1/live/rooms/${roomId}`).set(auth(h)).send(body);
        expect(bad.status).toBe(400);
      }
      const off = await ctx.http
        .patch(`/api/v1/live/rooms/${roomId}`)
        .set(auth(h))
        .send({ allowGuests: false });
      expect(off.body.allowGuests).toBe(false);
      expect(media.removed).toContainEqual({ room: roomId, identity: `guest:${guestId}` });
      expect((await room(roomId)).body.viewerCount).toBe(1);
      expect((await token(roomId, undefined, { guestId })).status).toBe(403);
      // A guest who still joins is disconnected and not counted.
      await hook('participant_joined', roomId, `guest:${randomUUID()}`).expect(200);
      expect((await room(roomId)).body.viewerCount).toBe(1);
      const audit = await ctx.prisma.auditLog.count({
        where: { action: 'live.room.guests', targetId: roomId },
      });
      expect(audit).toBe(2);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
      const ended = await ctx.http
        .patch(`/api/v1/live/rooms/${roomId}`)
        .set(auth(h))
        .send({ allowGuests: true });
      expect(ended.status).toBe(409);
    });
  });

  describe('presence', () => {
    it('signed webhooks count viewers (not the host), list them for the host, and order Popular', async () => {
      const [h, h2, a, b] = [await host(), await host(), await signup(), await signup()];
      const roomId = await goLive(h);
      const quiet = await goLive(h2);
      expect(
        (
          await ctx.http
            .post('/internal/livekit/webhook')
            .set('Content-Type', 'application/webhook+json')
            .set('Authorization', 'Bearer nope')
            .send('{}')
        ).status,
      ).toBe(401);
      const guestId = randomUUID();
      await hook('participant_joined', roomId, h.id).expect(200);
      await hook('participant_joined', roomId, a.id).expect(200);
      await hook('participant_joined', roomId, a.id).expect(200);
      await hook('participant_joined', roomId, b.id).expect(200);
      await hook('participant_joined', roomId, `guest:${guestId}`).expect(200);
      await hook('track_published', roomId).expect(200);
      expect((await room(roomId)).body.viewerCount).toBe(3);
      const popularIds = async () =>
        (await ctx.http.get('/api/v1/live/rooms?tab=popular&limit=50')).body.data.map(
          (r: { id: string }) => r.id,
        ) as string[];
      // CP-012 (v1.8-live): Popular orders by the score, no longer by viewers: with both scores at
      // 0 the newer room comes first despite its 0 viewers; a viewer's taps lift the watched room.
      let ids = await popularIds();
      expect(ids.indexOf(quiet)).toBeLessThan(ids.indexOf(roomId));
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(a)).send({ count: 3 }).expect(200);
      ids = await popularIds();
      expect(ids.indexOf(roomId)).toBeLessThan(ids.indexOf(quiet));

      const page1 = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers?limit=2`).set(auth(h));
      expect(page1.status).toBe(200);
      expectContract(page1, 'listLiveRoomViewers');
      expect(page1.body.page.hasMore).toBe(true);
      const page2 = await ctx.http
        .get(
          `/api/v1/live/rooms/${roomId}/viewers?limit=2&cursor=${encodeURIComponent(page1.body.page.nextCursor)}`,
        )
        .set(auth(h));
      const all = [...page1.body.data, ...page2.body.data];
      expect(all).toHaveLength(3);
      expect(all.filter((v: { kind: string }) => v.kind === 'GUEST')).toEqual([
        expect.objectContaining({
          user: null,
          guestNumber: ctx.app.get(LiveMediaService).guestNumber(guestId),
        }),
      ]);
      expect(
        all
          .filter((v: { kind: string }) => v.kind === 'USER')
          .map((v: { user: { id: string } }) => v.user.id)
          .sort(),
      ).toEqual([a.id, b.id].sort());
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(a))).status).toBe(404);
      const stolen = await ctx.http
        .get(`/api/v1/live/rooms/${quiet}/viewers?cursor=${encodeURIComponent(page1.body.page.nextCursor)}`)
        .set(auth(h2));
      expect(stolen.status).toBe(400);

      await hook('participant_left', roomId, a.id).expect(200);
      expect((await room(roomId)).body.viewerCount).toBe(2);
      // A blocked viewer who joins anyway is disconnected and not counted.
      await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(h)).expect(200);
      await hook('participant_left', roomId, b.id).expect(200);
      await hook('participant_joined', roomId, b.id).expect(200);
      expect(media.removed).toContainEqual({ room: roomId, identity: b.id });
      expect((await room(roomId)).body.viewerCount).toBe(1);

      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
      expect(media.closed).toContain(roomId);
      expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId } })).toBe(0);
      // A late join to an ended room is disconnected.
      await hook('participant_joined', roomId, a.id).expect(200);
      expect(media.removed).toContainEqual({ room: roomId, identity: a.id });
      expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId } })).toBe(0);
      expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(h))).body.data).toEqual([]);
      await ctx.http.post(`/api/v1/live/rooms/${quiet}/end`).set(auth(h2)).expect(200);
    });

    it('reconciliation closes sessions of rooms that are no longer live and drops stale presence', async () => {
      const [h, a] = [await host(), await signup()];
      const roomId = await goLive(h);
      await hook('participant_joined', roomId, a.id).expect(200);
      // The media server lost a (no longer connected), and still holds an orphan session.
      media.rooms.get(roomId)?.delete(a.id);
      const orphan = randomUUID();
      media.rooms.set(orphan, new Set(['x']));
      // Earlier specs may leave sessions of ended rooms in the fake; those are closed too.
      expect(await ctx.app.get(LiveMediaService).reconcile()).toBeGreaterThanOrEqual(1);
      expect(media.closed).toContain(orphan);
      expect(media.closed).not.toContain(roomId);
      expect((await room(roomId)).body.viewerCount).toBe(0);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    });
  });

  describe('reports', () => {
    it('a live room can be reported (not your own); REMOVE_TARGET ends it with ADMIN', async () => {
      const [h, reporter, mod] = [await host(), await signup(), await admin('MODERATION')];
      const roomId = await goLive(h);
      const own = await ctx.http
        .post('/api/v1/reports')
        .set(auth(h))
        .send({ targetType: 'LIVE_ROOM', targetId: roomId, reason: 'SPAM' });
      expect(own.status).toBe(400);
      const rep: request.Response = await ctx.http
        .post('/api/v1/reports')
        .set(auth(reporter))
        .send({ targetType: 'LIVE_ROOM', targetId: roomId, reason: 'NUDITY' });
      expect(rep.status).toBe(201);
      expectContract(rep, 'createReport');
      expect(rep.body).toMatchObject({ targetType: 'LIVE_ROOM', targetId: roomId });
      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(act.status).toBe(200);
      expect((await room(roomId)).body).toMatchObject({ status: 'ENDED', endReason: 'ADMIN' });
      expect(media.closed).toContain(roomId);
    });
  });

  describe('hosting switched off', () => {
    let off: TestContext;
    beforeAll(async () => {
      off = await createTestApp({ LIVE_HOSTING_ENABLED: 'false' });
    });
    afterAll(async () => off?.close());

    it('media tokens answer 503 LIVE_HOSTING_UNAVAILABLE', async () => {
      const res = await off.http
        .post(`/api/v1/live/rooms/${randomUUID()}/media-token`)
        .send({ guestId: randomUUID() });
      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('LIVE_HOSTING_UNAVAILABLE');
      expectContract(res, 'createLiveMediaToken');
    });
  });
});
