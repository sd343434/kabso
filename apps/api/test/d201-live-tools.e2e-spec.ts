/**
 * D201 (v1.45-live, CONVENTIONS §10.63): the host's live tools — the second camera's pairing codes (expiry,
 * single use, the same account only, replaced codes, rate limit, audit without the code), its publish-only
 * token, the webhook that never counts `cam2:` as a viewer, one camera at a time, none during a PK (refused,
 * and ended by the reconciliation), ending the camera and the live; the recording indicator; the one-time
 * music-rights notice. The media server is the in-memory fake; time is a FakeClock.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
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
  readonly token: string;
}

describe('D201 contract', () => {
  it('lists the live tools operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getLiveSecondCamera GET /api/v1/live/rooms/{roomId}/second-camera',
      'endLiveSecondCamera DELETE /api/v1/live/rooms/{roomId}/second-camera',
      'createLiveSecondCameraCode POST /api/v1/live/rooms/{roomId}/second-camera/codes',
      'setLiveSecondCameraMain PUT /api/v1/live/rooms/{roomId}/second-camera/main',
      'redeemLiveSecondCameraCode POST /api/v1/live/second-camera/redeem',
      'setLiveRecording PUT /api/v1/live/rooms/{roomId}/recording',
      'getMyLiveMusicRights GET /api/v1/me/live-music-rights',
      'acceptMyLiveMusicRights PUT /api/v1/me/live-music-rights',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D201 live tools', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  /** A second session of the same account (the second device). */
  const secondDevice = async (u: TestUser): Promise<TestUser> => u;
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Tools', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const webhook = async (event: string, roomId: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomId }, participant: { identity } });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const code = async (u: TestUser, roomId: string): Promise<request.Response> =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/second-camera/codes`).set(auth(u)).send({});
  const newCode = async (u: TestUser, roomId: string): Promise<string> => {
    const res = await code(u, roomId);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.code as string;
  };
  const redeem = (u: TestUser, value: string) =>
    ctx.http.post('/api/v1/live/second-camera/redeem').set(auth(u)).send({ code: value });
  const state = async (u: TestUser, roomId: string) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveSecondCamera');
    return res.body as {
      status: string;
      main: string;
      available: boolean;
      unavailableReason: string | null;
      codeExpiresAt: string | null;
    };
  };
  const audits = (action: string, actorUserId: string) =>
    ctx.prisma.auditLog.findMany({ where: { action, actorUserId }, orderBy: { createdAt: 'asc' } });
  const viewerCount = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount;
  const cameraRows = (roomId: string) =>
    ctx.prisma.liveSecondCamera.findMany({ where: { roomId }, orderBy: { createdAt: 'asc' } });
  /** Pairs and connects a second camera; returns its identity. */
  const pair = async (u: TestUser, roomId: string): Promise<string> => {
    const res = await redeem(await secondDevice(u), await newCode(u, roomId));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    await webhook('participant_joined', roomId, `cam2:${u.id}`);
    return `cam2:${u.id}`;
  };
  const startPk = async (a: TestUser, roomA: string, b: TestUser, roomB: string) => {
    const inv = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/pk/invites`)
      .set(auth(a))
      .send({ toRoomId: roomB });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await ctx.http
      .post(`/api/v1/live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`)
      .set(auth(b));
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('pairs the same account: a 6-digit code for 120 s, a publish-only cam2 token, never a viewer', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await webhook('participant_joined', roomId, h.id);
    expect(await state(h, roomId)).toMatchObject({
      status: 'NONE',
      available: true,
      unavailableReason: null,
    });

    const created = await code(h, roomId);
    expect(created.status).toBe(201);
    expectContract(created, 'createLiveSecondCameraCode');
    expect(created.body.code).toMatch(/^[0-9]{6}$/);
    expect(created.body.ttlSeconds).toBe(120);
    expect(new Date(created.body.expiresAt as string).getTime() - clock.now().getTime()).toBe(120_000);
    expect(await state(h, roomId)).toMatchObject({ status: 'CODE', codeExpiresAt: created.body.expiresAt });
    const row = (await cameraRows(roomId))[0]!;
    expect(row.codeHash).toMatch(/^[0-9a-f]{64}$/);
    expect(row.codeHash).not.toContain(created.body.code as string);

    const res = await redeem(await secondDevice(h), created.body.code as string);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'redeemLiveSecondCameraCode');
    expect(res.body).toMatchObject({ roomId, hostUserId: h.id, identity: `cam2:${h.id}`, main: 'HOST' });
    const issued = media.issued.at(-1)!;
    expect(issued).toMatchObject({
      room: roomId,
      identity: `cam2:${h.id}`,
      publish: true,
      sources: ['camera', 'microphone'],
      subscribe: false,
      attributes: { 'kabso.mainFeed': 'HOST' },
      ttlSeconds: 600,
    });
    expect(await state(h, roomId)).toMatchObject({ status: 'PAIRED' });

    await webhook('participant_joined', roomId, `cam2:${h.id}`);
    expect(await state(h, roomId)).toMatchObject({ status: 'CONNECTED' });
    expect(media.removed.filter((r) => r.room === roomId)).toEqual([]);
    expect(await viewerCount(roomId)).toBe(0);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId } })).toBe(0);
    expect(media.broadcastsOf(roomId, 'join')).toEqual([]);
    // A real viewer still counts.
    const v = await signup();
    await webhook('participant_joined', roomId, v.id);
    expect(await viewerCount(roomId)).toBe(1);
    // The reconciliation sees cam2 connected and keeps it (no viewer row, no kick).
    await ctx.app.get(LiveMediaService).reconcile();
    expect(await viewerCount(roomId)).toBe(1);
    expect(media.removed.filter((r) => r.room === roomId)).toEqual([]);
    expect(await state(h, roomId)).toMatchObject({ status: 'CONNECTED' });

    const [codeAudit] = await audits('live.second_camera.code', h.id);
    expect(codeAudit).toMatchObject({ targetType: 'live_room', targetId: roomId });
    const [redeemAudit] = await audits('live.second_camera.redeem', h.id);
    expect(redeemAudit).toMatchObject({ targetType: 'live_room', targetId: roomId });
    expect(JSON.stringify([codeAudit, redeemAudit])).not.toContain(created.body.code as string);
  });

  it('a code works once', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const value = await newCode(h, roomId);
    expect((await redeem(h, value)).status).toBe(200);
    await webhook('participant_left', roomId, `cam2:${h.id}`);
    const again = await redeem(h, value);
    expect(again.status).toBe(422);
    expect(again.body.error.code).toBe('SECOND_CAMERA_CODE_INVALID');
    expect((await audits('live.second_camera.refused', h.id)).map((a) => a.metadata)).toEqual([
      { reason: 'used' },
    ]);
  });

  it('a code expires after 120 s', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const value = await newCode(h, roomId);
    clock.advance(121);
    const res = await redeem(h, value);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SECOND_CAMERA_CODE_INVALID');
    expect((await cameraRows(roomId))[0]).toMatchObject({ endReason: 'EXPIRED', redeemedAt: null });
    expect((await audits('live.second_camera.refused', h.id)).map((a) => a.metadata)).toEqual([
      { reason: 'expired' },
    ]);
    expect(await state(h, roomId)).toMatchObject({ status: 'NONE' });
  });

  it('another account is refused with the same answer, and the code still works for its account', async () => {
    const h = await host();
    const other = await host();
    const roomId = await goLive(h);
    const value = await newCode(h, roomId);
    const wrong = await redeem(other, value);
    expect(wrong.status).toBe(422);
    expect(wrong.body.error.code).toBe('SECOND_CAMERA_CODE_INVALID');
    const unknown = await redeem(other, value === '000000' ? '000001' : '000000');
    expect(unknown.body).toEqual({
      ...wrong.body,
      error: { ...wrong.body.error, requestId: unknown.body.error.requestId },
    });
    expect((await audits('live.second_camera.refused', other.id)).map((a) => a.metadata)).toEqual([
      { reason: 'unknown' },
      { reason: 'unknown' },
    ]);
    expect(media.issued.filter((t) => t.identity === `cam2:${other.id}`)).toEqual([]);
    expect((await redeem(h, value)).status).toBe(200);
  });

  it('a new code replaces the open one; a second camera at a time; viewers and other hosts get 404', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const first = await newCode(h, roomId);
    const second = await newCode(h, roomId);
    expect((await redeem(h, first)).status).toBe(422);
    expect((await redeem(h, second)).status).toBe(200);
    const busy = await code(h, roomId);
    expect(busy.status).toBe(409);
    expect(busy.body.error.code).toBe('SECOND_CAMERA_BUSY');
    const v = await signup();
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(v))).status).toBe(404);
    expect((await code(v, roomId)).status).toBe(404);
    expect((await ctx.http.delete(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(v))).status).toBe(
      404,
    );
  });

  it('only a SOLO video live; not during a PK, and a PK starting ends the camera', async () => {
    const audio = await host();
    const audioRoom = await goLive(audio, { mode: 'AUDIO', seatCount: 10 });
    const notSolo = await code(audio, audioRoom);
    expect(notSolo.status).toBe(409);
    expect(notSolo.body.error.code).toBe('SECOND_CAMERA_UNAVAILABLE');
    expect(await state(audio, audioRoom)).toMatchObject({ available: false, unavailableReason: 'NOT_SOLO' });

    const [a, b] = [await host(), await host()];
    const [roomA, roomB] = [await goLive(a), await goLive(b)];
    for (const [u, r] of [
      [a, roomA],
      [b, roomB],
    ] as const)
      await webhook('participant_joined', r, u.id);
    const identity = await pair(a, roomA);
    const pending = await newCode(b, roomB);
    await startPk(a, roomA, b, roomB);
    expect(await state(b, roomB)).toMatchObject({ available: false, unavailableReason: 'PK' });
    const inPk = await code(b, roomB);
    expect(inPk.status).toBe(409);
    expect(inPk.body.error.code).toBe('SECOND_CAMERA_UNAVAILABLE');
    const lateRedeem = await redeem(b, pending);
    expect(lateRedeem.status).toBe(409);
    expect(lateRedeem.body.error.code).toBe('SECOND_CAMERA_UNAVAILABLE');
    // A's camera was on before the PK: the reconciliation ends it and removes the second device.
    media.rooms.get(roomA)?.add(identity);
    await ctx.app.get(LiveMediaService).reconcile();
    expect(media.removed).toContainEqual({ room: roomA, identity });
    expect((await cameraRows(roomA)).at(-1)).toMatchObject({ endReason: 'PK' });
    expect(await state(a, roomA)).toMatchObject({ status: 'NONE', unavailableReason: 'PK' });
    // A cam2 joining during the PK is removed.
    const removedBefore = media.removed.filter((r) => r.identity === identity).length;
    await webhook('participant_joined', roomA, identity);
    expect(media.removed.filter((r) => r.identity === identity).length).toBe(removedBefore + 1);
  });

  it('the webhook removes a cam2 that is not this live’s paired camera, and its leaving ends the camera', async () => {
    const h = await host();
    const other = await host();
    const roomId = await goLive(h);
    await webhook('participant_joined', roomId, `cam2:${other.id}`); // someone else's identity
    await webhook('participant_joined', roomId, `cam2:${h.id}`); // not paired
    await webhook('participant_joined', roomId, 'cam2:nobody');
    expect(media.removed.filter((r) => r.room === roomId).map((r) => r.identity)).toEqual([
      `cam2:${other.id}`,
      `cam2:${h.id}`,
      'cam2:nobody',
    ]);
    expect(await viewerCount(roomId)).toBe(0);
    await pair(h, roomId);
    await webhook('participant_left', roomId, `cam2:${h.id}`);
    expect((await cameraRows(roomId)).at(-1)).toMatchObject({ endReason: 'LEFT' });
    expect(await state(h, roomId)).toMatchObject({ status: 'NONE' });
    expect(await viewerCount(roomId)).toBe(0);
    // A new code pairs again.
    await pair(h, roomId);
    expect(await state(h, roomId)).toMatchObject({ status: 'CONNECTED' });
  });

  it('the host ends the second camera (either device); the main feed is the host’s to choose', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const noCamera = await ctx.http
      .put(`/api/v1/live/rooms/${roomId}/second-camera/main`)
      .set(auth(h))
      .send({ main: 'SECOND' });
    expect(noCamera.status).toBe(409);
    const identity = await pair(h, roomId);
    const main = await ctx.http
      .put(`/api/v1/live/rooms/${roomId}/second-camera/main`)
      .set(auth(h))
      .send({ main: 'SECOND' });
    expect(main.status).toBe(200);
    expectContract(main, 'setLiveSecondCameraMain');
    expect(main.body.main).toBe('SECOND');
    expect(media.attributes.get(roomId)?.get(identity)).toEqual({ 'kabso.mainFeed': 'SECOND' });
    expect(
      (await ctx.http.put(`/api/v1/live/rooms/${roomId}/second-camera/main`).set(auth(h)).send({ main: 'X' }))
        .status,
    ).toBe(400);
    expect((await audits('live.second_camera.main', h.id)).map((a) => a.metadata)).toEqual([
      { main: 'SECOND' },
    ]);

    const pending = await (async () => {
      const end = await ctx.http.delete(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(h));
      expect(end.status).toBe(204);
      return newCode(h, roomId);
    })();
    expect(media.removed).toContainEqual({ room: roomId, identity });
    expect((await cameraRows(roomId)).at(-2)).toMatchObject({ endReason: 'REVOKED' });
    const end = await ctx.http.delete(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(h));
    expect(end.status).toBe(204);
    expect((await redeem(h, pending)).status).toBe(422);
    expect((await audits('live.second_camera.end', h.id)).length).toBe(2);
  });

  it('ending the live ends the second camera and its open code', async () => {
    const h = await host();
    const roomId = await goLive(h);
    await pair(h, roomId);
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h))).status).toBe(200);
    expect(media.closed).toContain(roomId);
    expect((await cameraRows(roomId)).every((r) => r.endReason === 'ROOM_ENDED')).toBe(true);
    expect(await state(h, roomId)).toMatchObject({
      status: 'NONE',
      available: false,
      unavailableReason: 'NOT_LIVE',
    });
    expect((await code(h, roomId)).status).toBe(409);

    const h2 = await host();
    const room2 = await goLive(h2);
    const pending = await newCode(h2, room2);
    expect((await ctx.http.post(`/api/v1/live/rooms/${room2}/end`).set(auth(h2))).status).toBe(200);
    const res = await redeem(h2, pending);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SECOND_CAMERA_CODE_INVALID');
    expect(media.issued.filter((t) => t.identity === `cam2:${h2.id}`)).toEqual([]);
  });

  it('redeeming is limited to 10 per 10 minutes per user, wrong codes included', async () => {
    const u = await signup();
    for (let i = 0; i < 10; i += 1) expect((await redeem(u, '123456')).status).toBe(422);
    const limited = await redeem(u, '123456');
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect((await audits('live.second_camera.refused', u.id)).length).toBe(10);
    // Malformed codes never reach the lookup.
    const fresh = await signup();
    expect((await redeem(fresh, '12345')).status).toBe(400);
  });

  it('creating codes is limited to 10 per 10 minutes per user', async () => {
    const h = await host();
    const roomId = await goLive(h);
    for (let i = 0; i < 10; i += 1) expect((await code(h, roomId)).status).toBe(201);
    expect((await code(h, roomId)).status).toBe(429);
  });

  it('the recording indicator: the host’s attribute, cleared after 61 s or on stop; audited', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const start = await ctx.http
      .put(`/api/v1/live/rooms/${roomId}/recording`)
      .set(auth(h))
      .send({ active: true });
    expect(start.status).toBe(200);
    expectContract(start, 'setLiveRecording');
    expect(start.body).toMatchObject({ active: true, maxSeconds: 60 });
    expect(new Date(start.body.until as string).getTime() - clock.now().getTime()).toBe(61_000);
    expect(media.attributes.get(roomId)?.get(h.id)).toEqual({ 'kabso.recordingUntil': start.body.until });
    const stop = await ctx.http
      .put(`/api/v1/live/rooms/${roomId}/recording`)
      .set(auth(h))
      .send({ active: false });
    expect(stop.body).toMatchObject({ active: false, until: null });
    expect(media.attributes.get(roomId)?.get(h.id)).toEqual({});
    expect((await audits('live.recording.start', h.id)).length).toBe(1);
    expect((await audits('live.recording.stop', h.id)).length).toBe(1);
    const v = await signup();
    expect(
      (await ctx.http.put(`/api/v1/live/rooms/${roomId}/recording`).set(auth(v)).send({ active: true }))
        .status,
    ).toBe(404);
    const audio = await host();
    const audioRoom = await goLive(audio, { mode: 'AUDIO', seatCount: 10 });
    expect(
      (
        await ctx.http
          .put(`/api/v1/live/rooms/${audioRoom}/recording`)
          .set(auth(audio))
          .send({ active: true })
      ).status,
    ).toBe(400);
  });

  it('the music-rights notice is accepted once and kept', async () => {
    const u = await signup();
    const before = await ctx.http.get('/api/v1/me/live-music-rights').set(auth(u));
    expect(before.status).toBe(200);
    expectContract(before, 'getMyLiveMusicRights');
    expect(before.body).toEqual({ accepted: false, acceptedAt: null, noticeVersion: 1 });
    expect(
      (await ctx.http.put('/api/v1/me/live-music-rights').set(auth(u)).send({ noticeVersion: 2 })).status,
    ).toBe(400);
    const accept = await ctx.http.put('/api/v1/me/live-music-rights').set(auth(u)).send({ noticeVersion: 1 });
    expect(accept.status).toBe(200);
    expectContract(accept, 'acceptMyLiveMusicRights');
    expect(accept.body.accepted).toBe(true);
    clock.advance(5);
    const again = await ctx.http.put('/api/v1/me/live-music-rights').set(auth(u)).send({ noticeVersion: 1 });
    expect(again.body.acceptedAt).toBe(accept.body.acceptedAt);
    expect((await audits('live.music.rights_accept', u.id)).length).toBe(1);
    expect((await ctx.http.get('/api/v1/me/live-music-rights')).status).toBe(401);
  });
});
