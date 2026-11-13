/**
 * D391 (v1.118-live, CONVENTIONS §10.180, CP-041 §8) against a REAL LiveKit server: four hosts each publish a camera
 * and a microphone in their own live and start a 2 v 2 PK by invitation; a viewer of room 1 — and host 1 — get
 * watch-only tokens for the THREE other rooms from `createLivePk4MediaToken` and, over three more connections, receive
 * the other hosts' video and audio, while staying hidden there and unable to publish; no new media room is created and
 * the watchers are never viewers in the API; closing the match removes them from the four rooms. Runs only when
 * LIVEKIT_TEST_URL is set (as d195-pk-livekit-real), with `@livekit/rtc-node` as the clients and synthetic frames.
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

describe.skipIf(!url)('D391 4-way PK media on a real LiveKit server', { timeout: 180_000 }, () => {
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

  it('every audience sees and hears the four hosts; the watchers are hidden and watch-only', async () => {
    const rtc = await import('@livekit/rtc-node');
    const hosts = [await host(), await host(), await host(), await host()];
    const viewer = await signup();
    const live = async (u: TestUser) =>
      (await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'PK4 media' })).body.id as string;
    const roomIds: string[] = [];
    for (const h of hosts) roomIds.push(await live(h));
    const before = new Set(await provider.listRooms());
    const opened = await ctx.http
      .post(`/api/v1/live/rooms/${roomIds[0]!}/pk4/lobby`)
      .set(auth(hosts[0]!))
      .send({ format: 'TEAMS' });
    expect(opened.status, JSON.stringify(opened.body)).toBe(201);
    for (const seat of [2, 3, 4]) {
      const inv = await ctx.http
        .post(`/api/v1/live/rooms/${roomIds[0]!}/pk4/lobby/invites`)
        .set(auth(hosts[0]!))
        .send({ toRoomId: roomIds[seat - 1], seat });
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      const id = (inv.body.seats as { seat: number; invite: { id: string } }[]).find((s) => s.seat === seat)!
        .invite.id;
      const acc = await ctx.http
        .post(`/api/v1/live/rooms/${roomIds[seat - 1]!}/pk4/invites/${id}/accept`)
        .set(auth(hosts[seat - 1]!));
      expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    }

    const token = async (path: string, u: TestUser) => {
      const res = await ctx.http.post(path).set(auth(u)).send({});
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      return res.body as {
        url: string;
        token?: string;
        layer?: string;
        rooms?: { roomId: string; token: string; identity: string }[];
      };
    };
    const connected: InstanceType<typeof rtc.Room>[] = [];
    const connect = async (u: string, t: string) => {
      const room = new rtc.Room();
      connected.push(room);
      await room.connect(u, t, { autoSubscribe: true, dynacast: false });
      return room;
    };
    const publish = async (room: InstanceType<typeof rtc.Room>) => {
      const audio = new rtc.AudioSource(48000, 1);
      const video = new rtc.VideoSource(32, 32);
      await room.localParticipant!.publishTrack(
        rtc.LocalAudioTrack.createAudioTrack('mic', audio),
        new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_MICROPHONE }),
      );
      await room.localParticipant!.publishTrack(
        rtc.LocalVideoTrack.createVideoTrack('cam', video),
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
    const got = new Set<string>();
    const subscriptions = (room: InstanceType<typeof rtc.Room>, label: string) =>
      room.on(rtc.RoomEvent.TrackSubscribed, (track, _pub, participant) => {
        got.add(
          `${label}|${participant.identity}|${track.kind === rtc.TrackKind.KIND_VIDEO ? 'video' : 'audio'}`,
        );
      });

    const hostRooms: InstanceType<typeof rtc.Room>[] = [];
    const stops: (() => void)[] = [];
    try {
      for (const [i, h] of hosts.entries()) {
        const access = await token(`/api/v1/live/rooms/${roomIds[i]!}/media-token`, h);
        const room = await connect(access.url, access.token!);
        hostRooms.push(room);
        stops.push(await publish(room));
      }
      // The viewer of room 1: its own room as usual, the three others through the 4-way tokens (LOW layer).
      const own = await token(`/api/v1/live/rooms/${roomIds[0]!}/media-token`, viewer);
      subscriptions(await connect(own.url, own.token!), 'own');
      const access = await token(`/api/v1/live/rooms/${roomIds[0]!}/pk4/media-token`, viewer);
      expect(access.layer).toBe('LOW');
      expect(access.rooms!.map((r) => r.roomId).sort()).toEqual(roomIds.slice(1).sort());
      for (const r of access.rooms!) subscriptions(await connect(access.url, r.token), r.roomId);
      // Host 1 hears the three others (MEDIUM layer).
      const hostAccess = await token(`/api/v1/live/rooms/${roomIds[0]!}/pk4/media-token`, hosts[0]!);
      expect(hostAccess.layer).toBe('MEDIUM');
      for (const r of hostAccess.rooms!)
        subscriptions(await connect(hostAccess.url, r.token), `host1→${r.roomId}`);
      const want = [
        `own|${hosts[0]!.id}|video`,
        `own|${hosts[0]!.id}|audio`,
        ...[1, 2, 3].flatMap((i) => [
          `${roomIds[i]!}|${hosts[i]!.id}|video`,
          `${roomIds[i]!}|${hosts[i]!.id}|audio`,
          `host1→${roomIds[i]!}|${hosts[i]!.id}|audio`,
        ]),
      ];
      for (let i = 0; i < 200 && !want.every((w) => got.has(w)); i += 1) await sleep(100);
      expect([...got].sort()).toEqual(expect.arrayContaining(want));

      // No new media room; hidden and watch-only in the other rooms; never a viewer in the API.
      expect((await provider.listRooms()).filter((r) => !before.has(r))).toEqual([]);
      const identity = access.rooms![0]!.identity;
      for (const [i, room] of hostRooms.entries()) {
        expect([...room.remoteParticipants.keys()].filter((id) => id.startsWith('pk4:'))).toEqual([]);
        if (i === 0) continue;
        const watcher = (await rooms.listParticipants(roomIds[i]!)).find((p) => p.identity === identity)!;
        expect(watcher.permission).toMatchObject({ canPublish: false, canSubscribe: true, hidden: true });
        expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId: roomIds[i]!, identity } })).toBe(0);
      }

      // Closing the match removes the watchers from the four media rooms.
      await ctx.http.post(`/api/v1/live/rooms/${roomIds[0]!}/pk4/end`).set(auth(hosts[0]!));
      await ctx.http.post(`/api/v1/live/rooms/${roomIds[1]!}/pk4/end`).set(auth(hosts[1]!));
      await ctx.http.post(`/api/v1/live/rooms/${roomIds[1]!}/pk4/end`).set(auth(hosts[1]!));
      for (const r of roomIds.slice(1)) {
        for (let i = 0; i < 50 && (await provider.listIdentities(r)).includes(identity); i += 1)
          await sleep(100);
        expect(await provider.listIdentities(r)).not.toContain(identity);
      }
    } finally {
      for (const stop of stops) stop();
      for (const room of connected) await room.disconnect().catch(() => undefined);
      for (const [i, h] of hosts.entries())
        await ctx.http.post(`/api/v1/live/rooms/${roomIds[i]!}/end`).set(auth(h));
    }
  });
});
