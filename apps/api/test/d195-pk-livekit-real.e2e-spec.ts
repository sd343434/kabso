/**
 * D195 (v1.43-live, CONVENTIONS §10.58 media design) against a REAL LiveKit server: two hosts each
 * publish a camera and a microphone track in their own live; a viewer of room A — and host A — get a
 * watch-only token for room B from `createLivePkMediaToken` and, over a second connection, receive
 * host B's video and audio (the hosts hear each other), while staying hidden in room B and unable to
 * publish there; room B's chat, gifts and seats are untouched. Runs only when LIVEKIT_TEST_URL is set
 * (as kl063-livekit-real), with `@livekit/rtc-node` as the clients and synthetic frames.
 */
import { RoomServiceClient } from 'livekit-server-sdk';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';

interface TestUser {
  readonly id: string;
  readonly token: string;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

describe.skipIf(!url)('D195 PK media on a real LiveKit server', { timeout: 120_000 }, () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
  };
  const host = async () => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: provider },
    ]);
  });
  afterAll(async () => {
    await ctx?.close();
    const rtc = await import('@livekit/rtc-node');
    await rtc.dispose();
  });

  it('each audience sees and hears both hosts; the watcher is hidden and watch-only in the other room', async () => {
    const rtc = await import('@livekit/rtc-node');
    const [a, b, viewer] = [await host(), await host(), await signup()];
    const live = async (u: TestUser) =>
      (await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'PK media' })).body.id as string;
    const roomA = await live(a);
    const roomB = await live(b);
    const inv = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/pk/invites`)
      .set(auth(a))
      .send({ toRoomId: roomB });
    expect(inv.status).toBe(201);
    const acc = await ctx.http
      .post(`/api/v1/live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`)
      .set(auth(b));
    expect(acc.status).toBe(200);

    const token = async (path: string, u: TestUser) => {
      const res = await ctx.http.post(path).set(auth(u)).send({});
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      return res.body as { url: string; token: string; identity: string; roomId?: string };
    };
    const connected: InstanceType<typeof rtc.Room>[] = [];
    const connect = async (access: { url: string; token: string }) => {
      const room = new rtc.Room();
      connected.push(room);
      await room.connect(access.url, access.token, { autoSubscribe: true, dynacast: false });
      return room;
    };
    /** Publishes a camera (32×32 RGBA frames) and a microphone (a 440 Hz tone) and keeps feeding them. */
    const publish = async (room: InstanceType<typeof rtc.Room>) => {
      const audio = new rtc.AudioSource(48000, 1);
      const video = new rtc.VideoSource(32, 32);
      const mic = rtc.LocalAudioTrack.createAudioTrack('mic', audio);
      const cam = rtc.LocalVideoTrack.createVideoTrack('cam', video);
      await room.localParticipant!.publishTrack(
        mic,
        new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_MICROPHONE }),
      );
      await room.localParticipant!.publishTrack(
        cam,
        new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_CAMERA }),
      );
      let t = 0;
      const timer = setInterval(() => {
        const samples = new Int16Array(480);
        for (let i = 0; i < samples.length; i += 1)
          samples[i] = Math.round(8000 * Math.sin((2 * Math.PI * 440 * (t + i)) / 48000));
        t += samples.length;
        void audio.captureFrame(new rtc.AudioFrame(samples, 48000, 1, 480)).catch(() => undefined);
        video.captureFrame(
          new rtc.VideoFrame(new Uint8Array(32 * 32 * 4).fill(t % 255), 32, 32, rtc.VideoBufferType.RGBA),
        );
      }, 10);
      return () => clearInterval(timer);
    };
    /** `${roomName}|${participant}|${kind}` of every track subscribed by [room]. */
    const subscriptions = (room: InstanceType<typeof rtc.Room>, label: string, into: Set<string>) =>
      room.on(rtc.RoomEvent.TrackSubscribed, (track, _pub, participant) => {
        into.add(
          `${label}|${participant.identity}|${track.kind === rtc.TrackKind.KIND_VIDEO ? 'video' : 'audio'}`,
        );
      });

    const hostA = await connect(await token(`/api/v1/live/rooms/${roomA}/media-token`, a));
    const hostB = await connect(await token(`/api/v1/live/rooms/${roomB}/media-token`, b));
    const stops = [await publish(hostA), await publish(hostB)];
    try {
      const got = new Set<string>();
      // The viewer of room A: room A as usual, room B through the PK token.
      const viewerA = await connect(await token(`/api/v1/live/rooms/${roomA}/media-token`, viewer));
      subscriptions(viewerA, 'A', got);
      const pkAccess = await token(`/api/v1/live/rooms/${roomA}/pk/media-token`, viewer);
      expect(pkAccess.roomId).toBe(roomB);
      const viewerB = new rtc.Room();
      connected.push(viewerB);
      subscriptions(viewerB, 'B', got);
      await viewerB.connect(pkAccess.url, pkAccess.token, { autoSubscribe: true, dynacast: false });
      // Host A hears host B through their own PK connection.
      const hostAPk = new rtc.Room();
      connected.push(hostAPk);
      subscriptions(hostAPk, 'hostA→B', got);
      const hostPk = await token(`/api/v1/live/rooms/${roomA}/pk/media-token`, a);
      await hostAPk.connect(hostPk.url, hostPk.token, { autoSubscribe: true, dynacast: false });
      const want = [
        `A|${a.id}|video`,
        `A|${a.id}|audio`,
        `B|${b.id}|video`,
        `B|${b.id}|audio`,
        `hostA→B|${b.id}|audio`,
        `hostA→B|${b.id}|video`,
      ];
      for (let i = 0; i < 150 && !want.every((w) => got.has(w)); i += 1) await sleep(100);
      expect([...got].sort()).toEqual(expect.arrayContaining(want));

      // Hidden in room B (host B's client never sees the watchers) but known to the server; and
      // it may not publish there.
      expect([...hostB.remoteParticipants.keys()].filter((id) => id.startsWith('pk:'))).toEqual([]);
      const inB = (await rooms.listParticipants(roomB)).map((p) => p.identity);
      expect(inB).toContain(pkAccess.identity);
      const watcher = (await rooms.listParticipants(roomB)).find((p) => p.identity === pkAccess.identity)!;
      expect(watcher.permission).toMatchObject({ canPublish: false, canSubscribe: true, hidden: true });
      // Never a viewer of room B in the API.
      expect(
        await ctx.prisma.liveRoomViewer.count({ where: { roomId: roomB, identity: pkAccess.identity } }),
      ).toBe(0);

      // Closing the PK removes the watchers from both media rooms.
      await ctx.http.post(`/api/v1/live/rooms/${roomA}/pk/end`).set(auth(a));
      await ctx.http.post(`/api/v1/live/rooms/${roomA}/pk/end`).set(auth(a));
      for (let i = 0; i < 50 && (await provider.listIdentities(roomB)).includes(pkAccess.identity); i += 1)
        await sleep(100);
      expect(await provider.listIdentities(roomB)).not.toContain(pkAccess.identity);
    } finally {
      for (const stop of stops) stop();
      for (const room of connected) await room.disconnect().catch(() => undefined);
      await ctx.http.post(`/api/v1/live/rooms/${roomA}/end`).set(auth(a));
      await ctx.http.post(`/api/v1/live/rooms/${roomB}/end`).set(auth(b));
    }
  });
});
