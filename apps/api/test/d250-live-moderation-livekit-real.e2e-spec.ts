/**
 * D250 (v1.60-live, CONVENTIONS §10.91.1) against a REAL LiveKit server: a host publishes a camera and a microphone, a
 * viewer watches, and a MODERATION admin gets a hidden observer token from the panel (`createAdminLiveWatchToken`) and,
 * over its own connection, receives the host's video and audio — while it is not in the host's or the viewer's
 * participant list, is hidden and watch-only on the server (no publishing, no data), and the API's reconciliation
 * (which reads the server's participant list) never records or counts it as a viewer. Runs only when LIVEKIT_TEST_URL is
 * set (as kl063 / d195), with `@livekit/rtc-node` as the clients and synthetic frames.
 */
import { RoomServiceClient } from 'livekit-server-sdk';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';
const COOKIE = '__Host-kabso_admin';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

describe.skipIf(!url)('D250 the staff observer on a real LiveKit server', { timeout: 180_000 }, () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVEKIT_URL: url ?? '',
        LIVEKIT_API_KEY: key,
        LIVEKIT_API_SECRET: secret,
        LIVE_SWEEP_INTERVAL_SECONDS: '0',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: provider }],
    );
  });
  afterAll(async () => {
    await ctx?.close();
    const rtc = await import('@livekit/rtc-node');
    await rtc.dispose();
  });

  it('receives the host’s tracks, is in nobody’s participant list, cannot publish, and is never a viewer', async () => {
    const rtc = await import('@livekit/rtc-node');
    const signup = async () => {
      const { res, payload } = await registerVerified(ctx);
      return {
        id: res.body.user.id as string,
        token: res.body.tokens.accessToken as string,
        email: payload.email,
        password: payload.password,
      };
    };
    const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const viewer = await signup();
    const live = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Watched' });
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    const roomId = live.body.id as string;

    // A MODERATION admin signs in to the panel (enrols the authenticator once).
    const mod = await signup();
    await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, mod.email, 'MODERATION')));
    const cookieOf = (res: request.Response) =>
      ([] as string[])
        .concat(res.headers['set-cookie'] ?? [])
        .find((c) => c.startsWith(`${COOKIE}=`))!
        .split(';')[0]!;
    const login = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: mod.email, password: mod.password });
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', cookieOf(login))
      .set('X-CSRF-Token', login.body.csrfToken as string);
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', cookieOf(login))
      .set('X-CSRF-Token', login.body.csrfToken as string)
      .send({ code: totpCode(enrol.body.secret as string, Date.now()) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    const panelCookie = cookieOf(confirm);
    const csrf = confirm.body.session.csrfToken as string;

    const mediaToken = async (u: { token: string }) => {
      const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(u)).send({});
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      return res.body as { url: string; token: string };
    };
    const connected: InstanceType<typeof rtc.Room>[] = [];
    const connect = async (access: { url: string; token: string }) => {
      const room = new rtc.Room();
      connected.push(room);
      await room.connect(access.url, access.token, { autoSubscribe: true, dynacast: false });
      return room;
    };

    const hostRoom = await connect(await mediaToken(host));
    const audio = new rtc.AudioSource(48000, 1);
    const video = new rtc.VideoSource(32, 32);
    await hostRoom.localParticipant!.publishTrack(
      rtc.LocalAudioTrack.createAudioTrack('mic', audio),
      new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_MICROPHONE }),
    );
    await hostRoom.localParticipant!.publishTrack(
      rtc.LocalVideoTrack.createVideoTrack('cam', video),
      new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_CAMERA }),
    );
    let t = 0;
    const feed = setInterval(() => {
      const samples = new Int16Array(480);
      for (let i = 0; i < samples.length; i += 1)
        samples[i] = Math.round(8000 * Math.sin((2 * Math.PI * 440 * (t + i)) / 48000));
      t += samples.length;
      void audio.captureFrame(new rtc.AudioFrame(samples, 48000, 1, 480)).catch(() => undefined);
      video.captureFrame(
        new rtc.VideoFrame(new Uint8Array(32 * 32 * 4).fill(t % 255), 32, 32, rtc.VideoBufferType.RGBA),
      );
    }, 10);
    try {
      const viewerRoom = await connect(await mediaToken(viewer));

      const watch = await ctx.http
        .post(`/api/v1/admin/lives/${roomId}/watch-token`)
        .set('Cookie', panelCookie)
        .set('X-CSRF-Token', csrf)
        .send({ purpose: 'WATCH' });
      expect(watch.status, JSON.stringify(watch.body)).toBe(200);
      const access = watch.body.main as { url: string; token: string; identity: string };
      expect(access.identity.startsWith(`staff:${mod.id}:`)).toBe(true);

      const got = new Set<string>();
      const staff = new rtc.Room();
      connected.push(staff);
      staff.on(rtc.RoomEvent.TrackSubscribed, (track, _pub, participant) => {
        got.add(`${participant.identity}|${track.kind === rtc.TrackKind.KIND_VIDEO ? 'video' : 'audio'}`);
      });
      await staff.connect(access.url, access.token, { autoSubscribe: true, dynacast: false });
      const want = [`${host.id}|video`, `${host.id}|audio`];
      for (let i = 0; i < 100 && !want.every((w) => got.has(w)); i += 1) await sleep(100);
      expect([...got].sort()).toEqual(expect.arrayContaining(want));

      // Not in the host's or the viewer's participant list.
      await sleep(500);
      expect([...hostRoom.remoteParticipants.keys()]).not.toContain(access.identity);
      expect([...viewerRoom.remoteParticipants.keys()]).not.toContain(access.identity);
      // On the server: hidden, no publishing, no data.
      const info = (await rooms.listParticipants(roomId)).find((p) => p.identity === access.identity)!;
      expect(info).toBeDefined();
      expect(info.permission?.hidden).toBe(true);
      expect(info.permission?.canPublish).toBe(false);
      expect(info.permission?.canPublishData).toBe(false);
      expect(info.permission?.canSubscribe).toBe(true);
      // Publishing is refused.
      const own = new rtc.AudioSource(48000, 1);
      await expect(
        staff.localParticipant!.publishTrack(
          rtc.LocalAudioTrack.createAudioTrack('x', own),
          new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_MICROPHONE }),
        ),
      ).rejects.toBeDefined();

      // The reconciliation reads the server's participants (the observer included): only the viewer is recorded.
      await ctx.app.get(LiveMediaService).reconcile();
      const viewers = await ctx.prisma.liveRoomViewer.findMany({
        where: { roomId },
        select: { identity: true },
      });
      expect(viewers.map((v) => v.identity)).toEqual([viewer.id]);
      expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
      // Still connected (never kicked while the live is on air).
      expect((await rooms.listParticipants(roomId)).map((p) => p.identity)).toContain(access.identity);
      const audit = await ctx.prisma.auditLog.findMany({
        where: { action: 'admin.live.watch', targetId: roomId },
      });
      expect(audit).toHaveLength(1);
    } finally {
      clearInterval(feed);
      for (const r of connected) await r.disconnect().catch(() => undefined);
    }
  });
});
