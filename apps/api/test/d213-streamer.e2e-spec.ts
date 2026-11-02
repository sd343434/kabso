/**
 * D213 (v1.56-live DRAFT, CONVENTIONS §10.86): the STREAMER live — the host's phone screen with a
 * round camera bubble. Start (setup, defaults, refusals), the host's media sources, listing by kind
 * (`streamer`, and inside `video` / `solo`), the layout update (`PUT /live/rooms/{id}/streamer`: the
 * `streamer` data message, the metadata's `streamerVersion`, idempotence, validation), who may change
 * it (host only; another mode 409), the host-away rule and the room read — end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role and the in-memory media server.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly token: string;
}

const STREAMER = { mode: 'STREAMER' };

describe('D213 contract coverage', () => {
  it('declares the new operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('updateLiveStreamer PUT /api/v1/live/rooms/{roomId}/streamer');
  });
});

describe('D213 streamer lives', () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, {});
    expect(res.status).toBe(201);
    return { id: res.body.user.id, token: res.body.tokens.accessToken };
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
      .send({ title: 'بث ببجي', ...body });
  const goLive = async (u: TestUser, body: object = STREAMER): Promise<string> => {
    const res = await start(u, body);
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const layout = (roomId: string, u: TestUser | null, body: unknown): request.Test => {
    const req = ctx.http.put(`/api/v1/live/rooms/${roomId}/streamer`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const expectError = (res: request.Response, status: number, code: string, operationId: string) => {
    expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
  };
  const streamerMessages = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'streamer')
      .map((b) => JSON.parse(b.payload) as { type: string; roomId: string; streamer: unknown });

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('starts a streamer: defaults, the chosen bubble, refusals, and the host publishes the screen', async () => {
    const h = await host();
    // `streamer` belongs to STREAMER; a STREAMER has no seats.
    expectError(
      await start(h, { mode: 'SOLO', streamer: { orientation: 'PORTRAIT' } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    expectError(await start(h, { ...STREAMER, seatCount: 4 }), 400, 'VALIDATION_FAILED', 'startLiveRoom');
    expectError(
      await start(h, { ...STREAMER, streamer: { cameraOverlay: { corner: 'MIDDLE' } } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    expectError(
      await start(h, { ...STREAMER, streamer: { orientation: 'SIDEWAYS' } }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );

    const plain = await start(h, STREAMER);
    expect(plain.status).toBe(201);
    expectContract(plain, 'startLiveRoom');
    expect(plain.body).toMatchObject({
      mode: 'STREAMER',
      seatCount: null,
      podcast: null,
      streamer: { orientation: 'PORTRAIT', cameraOverlay: { visible: true, corner: 'TOP_LEFT' }, version: 0 },
    });
    const token = await ctx.http
      .post(`/api/v1/live/rooms/${plain.body.id}/media-token`)
      .set(auth(h))
      .send({})
      .expect(200);
    expectContract(token, 'createLiveMediaToken');
    expect(token.body.role).toBe('HOST');
    expect(media.issued.at(-1)).toMatchObject({
      publish: true,
      sources: ['camera', 'microphone', 'screen_share', 'screen_share_audio'],
    });
    // A viewer watches only.
    const viewer = await signup();
    await ctx.http
      .post(`/api/v1/live/rooms/${plain.body.id}/media-token`)
      .set(auth(viewer))
      .send({})
      .expect(200);
    expect(media.issued.at(-1)).toMatchObject({ publish: false });
    await end(plain.body.id, h);

    const chosen = await start(h, {
      ...STREAMER,
      streamer: { orientation: 'LANDSCAPE', cameraOverlay: { visible: false, corner: 'BOTTOM_RIGHT' } },
    });
    expect(chosen.status).toBe(201);
    expect(chosen.body.streamer).toEqual({
      orientation: 'LANDSCAPE',
      cameraOverlay: { visible: false, corner: 'BOTTOM_RIGHT' },
      version: 0,
    });
    // A guest reads the room with the layout.
    const read = await ctx.http.get(`/api/v1/live/rooms/${chosen.body.id}`);
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.streamer.cameraOverlay.corner).toBe('BOTTOM_RIGHT');
    // Other modes carry no layout.
    await end(chosen.body.id, h);
    const solo = await goLive(h, { mode: 'SOLO' });
    expect((await ctx.http.get(`/api/v1/live/rooms/${solo}`)).body.streamer).toBeNull();
    await end(solo, h);
  });

  it('lists streamers under `streamer`, and inside `video` and `solo` (the main hub)', async () => {
    const [a, b, c, d] = [await host(), await host(), await host(), await host()];
    const streamer = await goLive(a);
    const solo = await goLive(b, { mode: 'SOLO' });
    const audio = await goLive(c, { mode: 'AUDIO', seatCount: 5 });
    const podcast = await goLive(d, { mode: 'PODCAST', podcast: { topic: 'tech' } });
    const ids = async (kind?: string) => {
      const res = await ctx.http.get(`/api/v1/live/rooms?tab=new&limit=50${kind ? `&kind=${kind}` : ''}`);
      expect(res.status).toBe(200);
      expectContract(res, 'listLiveRooms');
      return (res.body.data as { id: string }[]).map((r) => r.id);
    };
    expect(await ids('streamer')).toEqual([streamer]);
    expect(await ids('solo')).toEqual(expect.arrayContaining([streamer, solo]));
    expect(await ids('video')).toEqual(expect.arrayContaining([streamer, solo]));
    for (const kind of ['audio', 'podcast', 'multi', 'party']) {
      expect(await ids(kind)).not.toContain(streamer);
    }
    expect(await ids()).toEqual(expect.arrayContaining([streamer, solo, audio, podcast]));
    const card = (await ctx.http.get('/api/v1/live/rooms?tab=new&kind=streamer')).body.data[0];
    expect(card).toMatchObject({ mode: 'STREAMER', streamer: { orientation: 'PORTRAIT' } });
    // A cursor is bound to the kind (the D129 rule, here for `streamer`).
    await goLive(await host());
    const first = await ctx.http.get('/api/v1/live/rooms?tab=new&limit=1&kind=streamer');
    const cursor = first.body.page.nextCursor as string;
    expect(cursor).toEqual(expect.any(String));
    expectError(
      await ctx.http.get(`/api/v1/live/rooms?tab=new&limit=1&kind=solo&cursor=${encodeURIComponent(cursor)}`),
      400,
      'VALIDATION_FAILED',
      'listLiveRooms',
    );
    const next = await ctx.http.get(
      `/api/v1/live/rooms?tab=new&limit=1&kind=streamer&cursor=${encodeURIComponent(cursor)}`,
    );
    expect(next.status).toBe(200);
    expect(next.body.data).toHaveLength(1);
    for (const [id, u] of [
      [streamer, a],
      [solo, b],
      [audio, c],
      [podcast, d],
    ] as const)
      await end(id, u);
  });

  it('updates the layout: data message, metadata version, idempotent, validation', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const before = media.broadcasts.length;

    const rotated = await layout(roomId, h, { orientation: 'LANDSCAPE' });
    expect(rotated.status).toBe(200);
    expectContract(rotated, 'updateLiveStreamer');
    expect(rotated.body).toEqual({
      orientation: 'LANDSCAPE',
      cameraOverlay: { visible: true, corner: 'TOP_LEFT' },
      version: 1,
    });
    expect(streamerMessages(roomId)).toEqual([{ type: 'streamer', roomId, streamer: rotated.body }]);
    expect(JSON.parse(media.metadata.get(roomId) ?? '{}')).toMatchObject({ streamerVersion: 1 });

    // Only the keys sent change; both bubble keys at once are one change.
    const moved = await layout(roomId, h, { cameraOverlay: { corner: 'BOTTOM_RIGHT', visible: false } });
    expect(moved.status).toBe(200);
    expect(moved.body).toEqual({
      orientation: 'LANDSCAPE',
      cameraOverlay: { visible: false, corner: 'BOTTOM_RIGHT' },
      version: 2,
    });
    expect(streamerMessages(roomId).at(-1)?.streamer).toEqual(moved.body);
    expect(JSON.parse(media.metadata.get(roomId) ?? '{}')).toMatchObject({ streamerVersion: 2 });

    // The same values again: nothing changes, no message.
    const count = media.broadcasts.length;
    const same = await layout(roomId, h, { orientation: 'LANDSCAPE', cameraOverlay: { visible: false } });
    expect(same.status).toBe(200);
    expect(same.body.version).toBe(2);
    expect(media.broadcasts.length).toBe(count);
    expect(media.broadcasts.length - before).toBe(2);

    // The room read carries it.
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    expect(room.body.streamer).toEqual(moved.body);

    // Validation.
    for (const bad of [
      {},
      { cameraOverlay: {} },
      { orientation: 'UPSIDE_DOWN' },
      { cameraOverlay: { corner: 'CENTER' } },
      { cameraOverlay: { visible: 'yes' } },
      { orientation: 'PORTRAIT', extra: 1 },
    ]) {
      expectError(await layout(roomId, h, bad), 400, 'VALIDATION_FAILED', 'updateLiveStreamer');
    }
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body.streamer.version).toBe(2);
    await end(roomId, h);
  });

  it('only the host changes the layout; another mode 409, an ended live 409', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    const otherHost = await host();
    expectError(
      await layout(roomId, viewer, { orientation: 'LANDSCAPE' }),
      404,
      'NOT_FOUND',
      'updateLiveStreamer',
    );
    expectError(
      await layout(roomId, otherHost, { orientation: 'LANDSCAPE' }),
      404,
      'NOT_FOUND',
      'updateLiveStreamer',
    );
    expectError(
      await layout(roomId, null, { orientation: 'LANDSCAPE' }),
      401,
      'AUTH_UNAUTHENTICATED',
      'updateLiveStreamer',
    );
    expectError(
      await layout('not-a-uuid', h, { orientation: 'LANDSCAPE' }),
      404,
      'NOT_FOUND',
      'updateLiveStreamer',
    );
    expect(streamerMessages(roomId)).toEqual([]);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}`)).body.streamer.version).toBe(0);

    const solo = await goLive(otherHost, { mode: 'SOLO' });
    expectError(
      await layout(solo, otherHost, { orientation: 'LANDSCAPE' }),
      409,
      'LIVE_NOT_STREAMER',
      'updateLiveStreamer',
    );
    await end(solo, otherHost);

    await end(roomId, h);
    expectError(
      await layout(roomId, h, { orientation: 'LANDSCAPE' }),
      409,
      'LIVE_ROOM_ENDED',
      'updateLiveStreamer',
    );
  });

  it('a streamer host in another app is never «away» (the live goes on)', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/host-presence`)
      .set(auth(h))
      .send({ away: true })
      .expect(204);
    const row = await ctx.prisma.liveRoom.findUniqueOrThrow({
      where: { id: roomId },
      select: { hostAwaySince: true },
    });
    expect(row.hostAwaySince).toBeNull();
    await end(roomId, h);
  });

  it('the database refuses a streamer without its layout and a layout on another mode', async () => {
    const h = await host();
    const solo = await goLive(h, { mode: 'SOLO' });
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: solo }, data: { streamerOrientation: 'PORTRAIT' } }),
    ).rejects.toThrow();
    await end(solo, h);
    const roomId = await goLive(h);
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { streamerCameraCorner: 'MIDDLE' } }),
    ).rejects.toThrow();
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { seatCount: 4 } }),
    ).rejects.toThrow();
    await end(roomId, h);
  });
});
