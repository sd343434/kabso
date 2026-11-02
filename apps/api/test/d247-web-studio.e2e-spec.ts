/**
 * D247 (v1.57-live DRAFT, CONVENTIONS §10.88): «استوديو البث», the browser studio at studio.<domain>. It is a
 * client of the existing API (no new server service): the user sign-in with a `web` device, the refresh rotation,
 * the hosting checks of the app's go-live, a STREAMER room, the host's media sources and the heartbeat. The one
 * contract addition is `LiveStreamer.main`: `SCREEN` (D213, the screen with the camera bubble) or `CAMERA` (the
 * camera track alone as the picture — OBS Virtual Camera holding the whole scene). End to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role and the in-memory media server.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly token: string;
  readonly email: string;
  readonly password: string;
}

const STUDIO_DEVICE = {
  name: 'Kabso Studio — Chrome on Windows',
  platform: 'web',
  appVersion: 'studio-0.1.0',
};

describe('D247 web studio', () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx, {});
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id,
      token: res.body.tokens.accessToken,
      email: String(payload.email),
      password: String(payload.password),
    };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const layout = (roomId: string, u: TestUser, body: unknown): request.Test =>
    ctx.http
      .put(`/api/v1/live/rooms/${roomId}/streamer`)
      .set(auth(u))
      .send(body as object);
  const end = async (roomId: string, u: { token: string }) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const streamerMessages = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'streamer')
      .map((b) => JSON.parse(b.payload) as { streamer: { main: string; version: number } });

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the studio signs in as a web device, refreshes single-flight and reads the hosting gate', async () => {
    const h = await host();
    const login = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: h.email, password: h.password, device: STUDIO_DEVICE });
    expect(login.status).toBe(200);
    expectContract(login, 'login');
    expect(login.body.user.canHost).toBe(true);
    const session = await ctx.prisma.session.findFirst({
      where: { userId: h.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(session).toMatchObject({
      platform: 'web',
      deviceName: STUDIO_DEVICE.name,
      appVersion: 'studio-0.1.0',
    });

    // The refresh rotates; the previous secret is reuse and revokes the session (why the studio keeps it single-flight).
    const first = login.body.tokens.refreshToken as string;
    const rotated = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: first });
    expect(rotated.status).toBe(200);
    expectContract(rotated, 'refresh');
    expect(rotated.body.refreshToken).not.toBe(first);
    const reuse = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: first });
    expect({ status: reuse.status, code: reuse.body.error?.code }).toEqual({
      status: 401,
      code: 'AUTH_REFRESH_INVALID',
    });

    // ...and with it the session: its access token is refused from now on (the studio then asks to sign in).
    const revoked = await ctx.http.get('/api/v1/me').set(auth({ token: rotated.body.accessToken }));
    expect(revoked.status).toBe(401);

    // The live config the studio reads before the go-live button.
    const config = await ctx.http.get('/api/v1/live/config').set(auth(h));
    expect(config.status).toBe(200);
    expect(config.body).toMatchObject({ hostingEnabled: true, heartbeatIntervalSeconds: expect.any(Number) });

    // Without the hosting permission the start is refused honestly (the studio shows the reason).
    const viewer = await signup();
    const me = await ctx.http.get('/api/v1/me').set(auth(viewer));
    expect(me.body.canHost).toBe(false);
    const refused = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(viewer))
      .send({ title: 'استوديو', mode: 'STREAMER' });
    expect({ status: refused.status, code: refused.body.error?.code }).toEqual({
      status: 403,
      code: 'LIVE_HOSTING_NOT_ALLOWED',
    });
  });

  it('screen + bubble: the start body the studio sends, the host token and the heartbeat', async () => {
    const h = await host();
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({
        title: 'بث من المتصفح',
        mode: 'STREAMER',
        streamer: {
          orientation: 'LANDSCAPE',
          main: 'SCREEN',
          cameraOverlay: { visible: true, corner: 'BOTTOM_RIGHT' },
        },
      });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    expect(res.body.streamer).toEqual({
      orientation: 'LANDSCAPE',
      cameraOverlay: { visible: true, corner: 'BOTTOM_RIGHT' },
      main: 'SCREEN',
      version: 0,
    });
    const roomId = res.body.id as string;
    const token = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/media-token`)
      .set(auth(h))
      .send({})
      .expect(200);
    expectContract(token, 'createLiveMediaToken');
    expect(media.issued.at(-1)).toMatchObject({
      publish: true,
      sources: ['camera', 'microphone', 'screen_share', 'screen_share_audio'],
    });
    // The tab keeps the heartbeat; «away» stores nothing for a streamer (a browser tab in the background).
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(h)).expect(204);
    await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/host-presence`)
      .set(auth(h))
      .send({ away: true })
      .expect(204);
    const row = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
    expect(row.hostAwaySince).toBeNull();
    // A second start while this one is fresh → 409: the studio resumes the room instead.
    const again = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'x', mode: 'STREAMER' });
    expect({ status: again.status, code: again.body.error?.code }).toEqual({
      status: 409,
      code: 'LIVE_ROOM_ALREADY_ACTIVE',
    });
    await end(roomId, h);
    const after = await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(h));
    expect({ status: after.status, code: after.body.error?.code }).toEqual({
      status: 409,
      code: 'LIVE_ROOM_ENDED',
    });
  });

  it('camera as the main picture (OBS): start, switch, idempotent, validation, read by a guest', async () => {
    const h = await host();
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({
        title: 'OBS',
        mode: 'STREAMER',
        streamer: { orientation: 'LANDSCAPE', main: 'CAMERA', cameraOverlay: { visible: false } },
      });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    expect(res.body.streamer).toMatchObject({ main: 'CAMERA', orientation: 'LANDSCAPE', version: 0 });
    const roomId = res.body.id as string;

    // The host shares a screen after all: the screen becomes the picture, the camera the bubble.
    const toScreen = await layout(roomId, h, { main: 'SCREEN', cameraOverlay: { visible: true } });
    expect(toScreen.status).toBe(200);
    expectContract(toScreen, 'updateLiveStreamer');
    expect(toScreen.body).toMatchObject({ main: 'SCREEN', cameraOverlay: { visible: true }, version: 1 });
    expect(streamerMessages(roomId).at(-1)?.streamer).toEqual(toScreen.body);
    expect(JSON.parse(media.metadata.get(roomId) ?? '{}')).toMatchObject({ streamerVersion: 1 });

    // Back to the camera; sending the current value again changes nothing (no message).
    const back = await layout(roomId, h, { main: 'CAMERA' });
    expect(back.body).toMatchObject({ main: 'CAMERA', version: 2 });
    const count = streamerMessages(roomId).length;
    const same = await layout(roomId, h, { main: 'CAMERA' });
    expect(same.status).toBe(200);
    expect(same.body.version).toBe(2);
    expect(streamerMessages(roomId)).toHaveLength(count);

    for (const bad of [{ main: 'OBS' }, { main: null }, { main: 'camera' }]) {
      const r = await layout(roomId, h, bad);
      expectContract(r, 'updateLiveStreamer');
      expect({ status: r.status, code: r.body.error?.code }).toEqual({
        status: 400,
        code: 'VALIDATION_FAILED',
      });
    }
    const other = await host();
    const badStart = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(other))
      .send({ title: 'x', mode: 'STREAMER', streamer: { main: 'WINDOW' } });
    expect(badStart.status).toBe(400);

    // Everyone reads it (a guest too) — what the app's viewer lays out.
    const read = await ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.streamer).toMatchObject({ main: 'CAMERA', orientation: 'LANDSCAPE' });
    const list = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new', kind: 'streamer' });
    expectContract(list, 'listLiveRooms');
    const card = (list.body.data as { id: string; streamer: { main: string } }[]).find(
      (r) => r.id === roomId,
    );
    expect(card?.streamer.main).toBe('CAMERA');
    await end(roomId, h);
  });

  it('the database keeps `main` with STREAMER only, and only SCREEN / CAMERA', async () => {
    const h = await host();
    const roomId = (
      await ctx.http
        .post('/api/v1/live/rooms')
        .set(auth(h))
        .send({ title: 'x', mode: 'STREAMER' })
        .expect(201)
    ).body.id as string;
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).streamerMain).toBe(
      'SCREEN',
    );
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { streamerMain: 'WINDOW' } }),
    ).rejects.toThrow();
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { streamerMain: null } }),
    ).rejects.toThrow();
    // D213's fields too: a NULL is refused now (the re-created CHECK says IS NOT NULL; `NULL IN (…)` passed before).
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { streamerOrientation: null } }),
    ).rejects.toThrow();
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { streamerCameraCorner: null } }),
    ).rejects.toThrow();
    await end(roomId, h);
    const solo = (await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'x' }).expect(201))
      .body.id as string;
    await expect(
      ctx.prisma.liveRoom.update({ where: { id: solo }, data: { streamerMain: 'SCREEN' } }),
    ).rejects.toThrow();
    await end(solo, h);
  });
});
