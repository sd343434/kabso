/**
 * D201 (v1.45-live, CONVENTIONS §10.63) against a REAL LiveKit server: the host publishes a camera and a
 * microphone whose track carries voice + music mixed under it (as the app's mixer sends it: a 440 Hz
 * "voice" and a quieter 1 kHz "music"); the host's second device redeems a pairing code and publishes a
 * second camera as `cam2:<hostUserId>`; a viewer receives both cameras and hears both tones in the one
 * microphone track. The second camera receives nothing, may publish only its camera and microphone and no
 * data; the main-feed and recording attributes reach the viewer; ending the second camera disconnects it.
 * Runs only when LIVEKIT_TEST_URL is set (as kl063 / d195), with `@livekit/rtc-node` and synthetic frames.
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

/** The power of `freq` in `samples` (Goertzel), normalised by the length. */
function tonePower(samples: Int16Array, rate: number, freq: number): number {
  const k = 2 * Math.cos((2 * Math.PI * freq) / rate);
  let s1 = 0;
  let s2 = 0;
  for (const x of samples) {
    const s0 = x + k * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  return (s1 * s1 + s2 * s2 - k * s1 * s2) / samples.length;
}

describe.skipIf(!url)('D201 second camera and music on a real LiveKit server', { timeout: 120_000 }, () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
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

  it('a viewer gets both cameras and voice + music; the second camera publishes only and receives nothing', async () => {
    const rtc = await import('@livekit/rtc-node');
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const viewer = await signup();
    const roomId = (await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Two cameras' }))
      .body.id as string;
    const connected: InstanceType<typeof rtc.Room>[] = [];
    const timers: NodeJS.Timeout[] = [];
    const connect = async (access: { url: string; token: string }) => {
      const room = new rtc.Room();
      connected.push(room);
      await room.connect(access.url, access.token, { autoSubscribe: true, dynacast: false });
      return room;
    };
    const camera = async (room: InstanceType<typeof rtc.Room>, fill: number) => {
      const source = new rtc.VideoSource(32, 32);
      await room.localParticipant!.publishTrack(
        rtc.LocalVideoTrack.createVideoTrack('cam', source),
        new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_CAMERA }),
      );
      timers.push(
        setInterval(() => {
          source.captureFrame(
            new rtc.VideoFrame(new Uint8Array(32 * 32 * 4).fill(fill), 32, 32, rtc.VideoBufferType.RGBA),
          );
        }, 33),
      );
    };
    try {
      const hostAccess = (
        await ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(h)).send({})
      ).body as { url: string; token: string };
      const host = await connect(hostAccess);
      await camera(host, 40);
      // The microphone track as the app's mixer sends it: voice at full level, music under it (×0.3).
      const mic = new rtc.AudioSource(48000, 1);
      await host.localParticipant!.publishTrack(
        rtc.LocalAudioTrack.createAudioTrack('mic', mic),
        new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_MICROPHONE }),
      );
      let t = 0;
      timers.push(
        setInterval(() => {
          const samples = new Int16Array(480);
          for (let i = 0; i < samples.length; i += 1) {
            const voice = 8000 * Math.sin((2 * Math.PI * 440 * (t + i)) / 48000);
            const music = 0.3 * 8000 * Math.sin((2 * Math.PI * 1000 * (t + i)) / 48000);
            samples[i] = Math.round(voice + music);
          }
          t += samples.length;
          void mic.captureFrame(new rtc.AudioFrame(samples, 48000, 1, 480)).catch(() => undefined);
        }, 10),
      );

      // The second device: the same account redeems the code.
      const code = (
        await ctx.http.post(`/api/v1/live/rooms/${roomId}/second-camera/codes`).set(auth(h)).send({})
      ).body.code as string;
      const redeemed = await ctx.http.post('/api/v1/live/second-camera/redeem').set(auth(h)).send({ code });
      expect(redeemed.status, JSON.stringify(redeemed.body)).toBe(200);
      const cam2Got: string[] = [];
      const cam2 = new rtc.Room();
      connected.push(cam2);
      cam2.on(rtc.RoomEvent.TrackSubscribed, (_t, _p, participant) => cam2Got.push(participant.identity));
      let cam2Gone = false;
      cam2.on(rtc.RoomEvent.Disconnected, () => {
        cam2Gone = true;
      });
      await cam2.connect(redeemed.body.url as string, redeemed.body.token as string, {
        autoSubscribe: true,
        dynacast: false,
      });
      await camera(cam2, 200);
      // The server holds it to camera and microphone: a screen share and data are refused.
      await expect(
        cam2.localParticipant!.publishTrack(
          rtc.LocalVideoTrack.createVideoTrack('screen', new rtc.VideoSource(32, 32)),
          new rtc.TrackPublishOptions({ source: rtc.TrackSource.SOURCE_SCREENSHARE }),
        ),
      ).rejects.toBeTruthy();
      const info = (await rooms.listParticipants(roomId)).find((p) => p.identity === `cam2:${h.id}`)!;
      expect(info.permission).toMatchObject({ canSubscribe: false, canPublish: true, canPublishData: false });
      expect(info.attributes).toEqual({ 'kabso.mainFeed': 'HOST' });

      // The viewer.
      const got = new Set<string>();
      const samples: number[] = [];
      const viewerAccess = (
        await ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(viewer)).send({})
      ).body as { url: string; token: string };
      const watcher = new rtc.Room();
      connected.push(watcher);
      watcher.on(rtc.RoomEvent.TrackSubscribed, (track, _pub, participant) => {
        got.add(`${participant.identity}|${track.kind === rtc.TrackKind.KIND_VIDEO ? 'video' : 'audio'}`);
        if (track.kind === rtc.TrackKind.KIND_AUDIO) {
          void (async () => {
            for await (const frame of new rtc.AudioStream(track, 48000, 1)) {
              for (const s of frame.data) samples.push(s);
              if (samples.length > 48000 * 2) break;
            }
          })();
        }
      });
      await watcher.connect(viewerAccess.url, viewerAccess.token, { autoSubscribe: true, dynacast: false });
      const want = [`${h.id}|video`, `${h.id}|audio`, `cam2:${h.id}|video`];
      for (let i = 0; i < 150 && !(want.every((w) => got.has(w)) && samples.length > 48000); i += 1)
        await sleep(100);
      expect([...got].sort()).toEqual(expect.arrayContaining(want));
      expect(cam2Got).toEqual([]);

      // Voice and music both reach the viewer in the one track.
      const heard = Int16Array.from(samples.slice(-24000));
      const voice = tonePower(heard, 48000, 440);
      const music = tonePower(heard, 48000, 1000);
      const silence = tonePower(heard, 48000, 2500);
      // Both tones are in the one track, well above an unrelated frequency (their exact ratio after Opus
      // over a real connection varies run to run, so it is not asserted).
      expect(voice).toBeGreaterThan(silence * 100);
      expect(music).toBeGreaterThan(silence * 10);

      // The main feed and the recording indicator reach the viewer as attributes.
      const cam2Seen = () => watcher.remoteParticipants.get(`cam2:${h.id}`);
      expect(cam2Seen()?.attributes['kabso.mainFeed']).toBe('HOST');
      expect(
        (
          await ctx.http
            .put(`/api/v1/live/rooms/${roomId}/second-camera/main`)
            .set(auth(h))
            .send({ main: 'SECOND' })
        ).status,
      ).toBe(200);
      const rec = await ctx.http
        .put(`/api/v1/live/rooms/${roomId}/recording`)
        .set(auth(h))
        .send({ active: true });
      expect(rec.status).toBe(200);
      const hostSeen = () => watcher.remoteParticipants.get(h.id);
      for (
        let i = 0;
        i < 50 &&
        !(
          cam2Seen()?.attributes['kabso.mainFeed'] === 'SECOND' &&
          hostSeen()?.attributes['kabso.recordingUntil'] === rec.body.until
        );
        i += 1
      )
        await sleep(100);
      expect(cam2Seen()?.attributes['kabso.mainFeed']).toBe('SECOND');
      expect(hostSeen()?.attributes['kabso.recordingUntil']).toBe(rec.body.until);
      await ctx.http.put(`/api/v1/live/rooms/${roomId}/recording`).set(auth(h)).send({ active: false });
      for (let i = 0; i < 50 && hostSeen()?.attributes['kabso.recordingUntil'] !== undefined; i += 1)
        await sleep(100);
      expect(hostSeen()?.attributes['kabso.recordingUntil']).toBeUndefined();

      // Ending the second camera disconnects the second device; the viewer's picture of it goes.
      expect((await ctx.http.delete(`/api/v1/live/rooms/${roomId}/second-camera`).set(auth(h))).status).toBe(
        204,
      );
      for (let i = 0; i < 50 && !(cam2Gone && cam2Seen() === undefined); i += 1) await sleep(100);
      expect(cam2Gone).toBe(true);
      expect(cam2Seen()).toBeUndefined();
      expect(await provider.listIdentities(roomId)).not.toContain(`cam2:${h.id}`);
    } finally {
      for (const timer of timers) clearInterval(timer);
      for (const room of connected) await room.disconnect().catch(() => undefined);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h));
    }
  });
});
