/**
 * D247: a viewer for «استوديو البث»'s Playwright run (apps/studio/e2e/studio.spec.ts), on a REAL LiveKit server through
 * the API: it takes a viewer token (`POST …/media-token`), joins with @livekit/rtc-node, subscribes to everything and
 * counts the frames / samples of each source the studio publishes (`screen_share`, `camera`, `microphone`,
 * `screen_share_audio`), sends a chat line once the API counts it in the room (the media reconciliation) and one gift,
 * and records the `streamer` data messages. It rewrites STUDIO_VIEWER_OUT (JSON) after every change and leaves after
 * STUDIO_VIEWER_HOLD_MS. Run from apps/api: `pnpm exec tsx test/smoke/studio-viewer.ts` with the STUDIO_VIEWER_* variables.
 */
import { writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import * as rtc from '@livekit/rtc-node';

const env = (k: string, d = ''): string => process.env[k] ?? d;
const api = env('STUDIO_VIEWER_API', 'http://127.0.0.1:3000');
const roomId = env('STUDIO_VIEWER_ROOM');
const token = env('STUDIO_VIEWER_TOKEN');
const hostUsername = env('STUDIO_VIEWER_HOST');
const giftCode = env('STUDIO_VIEWER_GIFT', '');
const chatText = env('STUDIO_VIEWER_CHAT', '');
const out = env('STUDIO_VIEWER_OUT', 'studio-viewer.json');
const holdMs = Number(env('STUDIO_VIEWER_HOLD_MS', '45000'));

const SOURCES: Record<number, string> = {
  [rtc.TrackSource.SOURCE_CAMERA]: 'camera',
  [rtc.TrackSource.SOURCE_MICROPHONE]: 'microphone',
  [rtc.TrackSource.SOURCE_SCREENSHARE]: 'screen_share',
  [rtc.TrackSource.SOURCE_SCREENSHARE_AUDIO]: 'screen_share_audio',
};

interface TrackStats {
  frames: number;
  kind: 'video' | 'audio';
  muted: boolean;
  width?: number;
  height?: number;
  peak?: number;
}
const state: {
  connected: boolean;
  tracks: Record<string, TrackStats>;
  streamerMessages: unknown[];
  chat: { status: number; code: string | null } | null;
  gift: { status: number; code: string | null } | null;
  error: string | null;
} = {
  connected: false,
  tracks: {},
  streamerMessages: [],
  chat: null,
  gift: null,
  error: null,
};
const save = () => writeFileSync(out, JSON.stringify(state, null, 1));
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function call(
  method: string,
  path: string,
  body?: unknown,
): Promise<{ status: number; body: { error?: { code?: string } } & Record<string, unknown> }> {
  const res = await fetch(`${api}/api/v1${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = (await res.json().catch(() => ({}))) as { error?: { code?: string } } & Record<
    string,
    unknown
  >;
  return { status: res.status, body: json ?? {} };
}

async function countFrames(name: string, track: rtc.RemoteTrack): Promise<void> {
  const entry = state.tracks[name];
  if (!entry) return;
  if (track.kind === rtc.TrackKind.KIND_VIDEO) {
    const stream = new rtc.VideoStream(track);
    for await (const ev of stream) {
      entry.frames += 1;
      entry.width = ev.frame.width;
      entry.height = ev.frame.height;
      if (entry.frames % 15 === 1) save();
    }
  } else {
    const stream = new rtc.AudioStream(track, 48000, 1);
    for await (const frame of stream) {
      entry.frames += 1;
      let peak = 0;
      for (const s of frame.data) peak = Math.max(peak, Math.abs(s));
      entry.peak = Math.max(entry.peak ?? 0, peak);
      if (entry.frames % 50 === 1) save();
    }
  }
}

const room = new rtc.Room();
try {
  const access = await call('POST', `/live/rooms/${roomId}/media-token`, {});
  if (access.status !== 200) throw new Error(`media-token ${access.status} ${JSON.stringify(access.body)}`);
  room
    .on(rtc.RoomEvent.TrackSubscribed, (track, publication) => {
      const source = publication.source ?? -1;
      const name = SOURCES[source] ?? `source-${source}`;
      state.tracks[name] = {
        frames: 0,
        kind: track.kind === rtc.TrackKind.KIND_VIDEO ? 'video' : 'audio',
        muted: publication.muted ?? false,
      };
      save();
      void countFrames(name, track).catch(() => undefined);
    })
    .on(rtc.RoomEvent.TrackMuted, (publication: rtc.TrackPublication) => {
      const name = SOURCES[publication.source ?? -1];
      const entry = name ? state.tracks[name] : undefined;
      if (entry) entry.muted = true;
      save();
    })
    .on(rtc.RoomEvent.TrackUnmuted, (publication: rtc.TrackPublication) => {
      const name = SOURCES[publication.source ?? -1];
      const entry = name ? state.tracks[name] : undefined;
      if (entry) entry.muted = false;
      save();
    })
    .on(rtc.RoomEvent.DataReceived, (payload, _participant, _kind, topic) => {
      if (topic !== 'streamer') return;
      try {
        state.streamerMessages.push(JSON.parse(new TextDecoder().decode(payload)).streamer);
      } catch {
        /* not JSON */
      }
      save();
    });
  await room.connect(String(access.body.url), String(access.body.token), {
    autoSubscribe: true,
    dynacast: false,
  });
  state.connected = true;
  save();

  // The API counts the viewer in the room once the reconciliation saw it; then the chat line and the gift.
  if (chatText) {
    for (let i = 0; i < 30 && !(state.chat?.status === 201); i += 1) {
      const res = await call('POST', `/live/rooms/${roomId}/chat`, {
        text: chatText,
        clientId: randomUUID(),
      });
      state.chat = { status: res.status, code: res.body?.error?.code ?? null };
      save();
      if (res.status !== 201) await sleep(1000);
    }
  }
  if (giftCode) {
    const res = await call('POST', `/live/rooms/${roomId}/gifts`, {
      giftCode,
      quantity: 10,
      recipients: [hostUsername],
      source: 'COINS',
      clientId: randomUUID(),
    });
    state.gift = { status: res.status, code: res.body?.error?.code ?? null };
    save();
  }
  await sleep(holdMs);
} catch (err) {
  state.error = err instanceof Error ? err.message : String(err);
  save();
} finally {
  await room.disconnect().catch(() => undefined);
  save();
  await rtc.dispose();
}
