/**
 * The studio's media session (D247, CONVENTIONS §10.86 / §10.88): joins the STREAMER room on the media server with
 * the host token from `POST …/media-token` and publishes what the host chose —
 *
 * - the screen as `screen_share` (720p30 ≈ 2.5 Mbps or 1080p30 ≈ 4 Mbps, no simulcast: viewers get the picture the
 *   host picked, as the Android app sends it), its sound as `screen_share_audio` (music quality, no DTX);
 * - the camera as `camera` (the bubble, or the whole picture with `main: CAMERA`); the microphone as `microphone`.
 *
 * Apps never publish data (§10.11): the studio only receives the `chat`, `gift` and `streamer` topics. Viewers are hidden
 * participants on the media server (§10.8), so the viewer count is the API's (`LiveRoom.viewerCount`). livekit-client
 * resumes short blips itself; when it disconnects for good the owner rejoins with a new token (see reconnect.ts).
 */
import {
  AudioPresets,
  ConnectionQuality,
  DisconnectReason,
  LocalTrack,
  Room,
  RoomEvent,
  Track,
  type LocalTrackPublication,
} from 'livekit-client';
import type { QualityId } from './devices';
import { QUALITIES } from './devices';
import type { LiveMediaAccess } from './types';

export type SourceKind = 'screen' | 'screenAudio' | 'camera' | 'microphone';

const SOURCE: Record<SourceKind, Track.Source> = {
  screen: Track.Source.ScreenShare,
  screenAudio: Track.Source.ScreenShareAudio,
  camera: Track.Source.Camera,
  microphone: Track.Source.Microphone,
};

export interface LiveCallbacks {
  onData(topic: string | undefined, payload: unknown): void;
  onResuming(): void;
  onResumed(): void;
  /** The session is gone and was not ended by the host (`clientInitiated` false). */
  onLost(reason: string): void;
  onQuality(quality: 'excellent' | 'good' | 'poor' | 'lost' | 'unknown'): void;
}

export class StudioLive {
  private room: Room | null = null;
  private readonly tracks = new Map<SourceKind, MediaStreamTrack>();
  private readonly muted = new Set<SourceKind>();
  private leaving = false;
  quality: QualityId = '720p';
  /** `main: CAMERA` (OBS): the camera is the whole picture, sent at the chosen quality instead of a bubble's. */
  cameraIsMain = false;

  constructor(private readonly callbacks: LiveCallbacks) {}

  get connected(): boolean {
    return this.room?.state === 'connected';
  }

  /** The tracks to send (set before or while connected; `null` removes one). */
  async setTrack(kind: SourceKind, track: MediaStreamTrack | null): Promise<void> {
    const before = this.tracks.get(kind);
    if (track) this.tracks.set(kind, track);
    else this.tracks.delete(kind);
    const room = this.room;
    if (!room || room.state !== 'connected') return;
    const pub = this.publication(kind);
    if (!track) {
      if (pub?.track) await room.localParticipant.unpublishTrack(pub.track, false);
      return;
    }
    if (pub?.track && before !== track) {
      // Same publication, new picture (a re-shared screen, another camera): viewers never see it disappear.
      await (pub.track as LocalTrack).replaceTrack(track, { userProvidedTrack: true, stopProcessor: true });
      if (this.muted.has(kind)) await (pub.track as LocalTrack).mute();
      else if (pub.isMuted) await (pub.track as LocalTrack).unmute();
      return;
    }
    if (!pub) await this.publish(room, kind, track);
  }

  /** Mutes or unmutes one source (a muted screen = «الشاشة متوقفة مؤقتاً» for viewers). */
  async setMuted(kind: SourceKind, muted: boolean): Promise<void> {
    if (muted) this.muted.add(kind);
    else this.muted.delete(kind);
    const pub = this.publication(kind);
    if (!pub?.track) return;
    if (muted) await (pub.track as LocalTrack).mute();
    else await (pub.track as LocalTrack).unmute();
  }

  isMuted(kind: SourceKind): boolean {
    return this.muted.has(kind);
  }

  /** Joins with a host token and publishes every track held. */
  async connect(access: LiveMediaAccess): Promise<void> {
    await this.disconnect();
    this.leaving = false;
    const room = new Room({
      adaptiveStream: false,
      dynacast: true,
      // A closed tab leaves the session at once (the heartbeat rule ends the live, as an app that was killed).
      disconnectOnPageLeave: true,
      // The host's MediaStreamTracks belong to the studio: a session that drops (and the rejoin after it) never stops
      // the capture — the screen-share consent cannot be asked again without a click.
      stopLocalTrackOnUnpublish: false,
      publishDefaults: { videoCodec: 'vp8', red: true, dtx: false },
    });
    this.room = room;
    room
      .on(RoomEvent.DataReceived, (payload: Uint8Array, _p?: unknown, _k?: unknown, topic?: string) => {
        let parsed: unknown;
        try {
          parsed = JSON.parse(new TextDecoder().decode(payload));
        } catch {
          return;
        }
        this.callbacks.onData(topic, parsed);
      })
      .on(RoomEvent.Reconnecting, () => this.callbacks.onResuming())
      .on(RoomEvent.SignalReconnecting, () => this.callbacks.onResuming())
      .on(RoomEvent.Reconnected, () => this.callbacks.onResumed())
      .on(RoomEvent.ConnectionQualityChanged, (q: ConnectionQuality, p) => {
        if (p.identity !== room.localParticipant.identity) return;
        this.callbacks.onQuality(
          q === ConnectionQuality.Excellent
            ? 'excellent'
            : q === ConnectionQuality.Good
              ? 'good'
              : q === ConnectionQuality.Poor
                ? 'poor'
                : q === ConnectionQuality.Lost
                  ? 'lost'
                  : 'unknown',
        );
      })
      .on(RoomEvent.Disconnected, (reason?: DisconnectReason) => {
        if (this.room !== room || this.leaving) return;
        this.room = null;
        this.callbacks.onLost(reason === undefined ? 'unknown' : String(DisconnectReason[reason] ?? reason));
      });
    await room.connect(access.url, access.token, { autoSubscribe: false });
    // One source failing (an ended camera) never keeps the others off the air.
    for (const [kind, track] of this.tracks) {
      if (track.readyState === 'ended' && kind !== 'screen' && kind !== 'screenAudio') continue;
      try {
        await this.publish(room, kind, track);
      } catch {
        /* the next setTrack of this source publishes it */
      }
    }
  }

  async disconnect(): Promise<void> {
    const room = this.room;
    this.room = null;
    if (!room) return;
    this.leaving = true;
    try {
      // The host's own MediaStreamTracks stay theirs (the preview keeps showing them).
      for (const pub of room.localParticipant.trackPublications.values()) {
        if (pub.track) await room.localParticipant.unpublishTrack(pub.track, false);
      }
    } catch {
      /* leaving anyway */
    }
    await room.disconnect(false);
  }

  /** The bitrate actually sent for the screen (bits / s), for the status line; null when unknown. */
  screenBitrate(): number | null {
    const pub = this.publication('screen');
    const track = pub?.track as (LocalTrack & { currentBitrate?: number }) | undefined;
    return track?.currentBitrate ?? null;
  }

  private publication(kind: SourceKind): LocalTrackPublication | undefined {
    return this.room?.localParticipant.getTrackPublication(SOURCE[kind]);
  }

  private async publish(room: Room, kind: SourceKind, track: MediaStreamTrack): Promise<void> {
    const q = QUALITIES[this.quality];
    let pub: LocalTrackPublication;
    switch (kind) {
      case 'screen':
        if ('contentHint' in track) track.contentHint = 'motion';
        pub = await room.localParticipant.publishTrack(track, {
          source: Track.Source.ScreenShare,
          name: 'screen',
          simulcast: false,
          videoEncoding: { maxBitrate: q.maxBitrate, maxFramerate: q.frameRate },
          degradationPreference: 'maintain-framerate',
        });
        break;
      case 'screenAudio':
        pub = await room.localParticipant.publishTrack(track, {
          source: Track.Source.ScreenShareAudio,
          name: 'screen-audio',
          audioPreset: AudioPresets.musicHighQuality,
          dtx: false,
          red: false,
        });
        break;
      case 'camera':
        pub = await room.localParticipant.publishTrack(track, {
          source: Track.Source.Camera,
          name: 'camera',
          simulcast: true,
          ...(this.cameraIsMain ? { videoEncoding: { maxBitrate: q.maxBitrate, maxFramerate: q.frameRate } } : {}),
        });
        break;
      case 'microphone':
        pub = await room.localParticipant.publishTrack(track, {
          source: Track.Source.Microphone,
          name: 'microphone',
          audioPreset: AudioPresets.speech,
        });
        break;
    }
    if (this.muted.has(kind)) await (pub.track as LocalTrack | undefined)?.mute();
  }
}
