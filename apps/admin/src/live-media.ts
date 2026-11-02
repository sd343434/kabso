import { useEffect, useState, useSyncExternalStore } from 'react';
import type { RemoteParticipant, RemoteTrack, RemoteTrackPublication, Room } from 'livekit-client';
import { api } from './api';

/**
 * v1.60-live (D250, CONVENTIONS §10.91.1): watching lives from the panel as a hidden observer. The tokens come from
 * `createAdminLiveWatchToken` (subscribe only, hidden, never a viewer, audited); `livekit-client` (2.22.4, the version of
 * apps/studio) is loaded only when a live is shown, so the panel's first load is unchanged.
 */

export interface StaffMediaAccess {
  roomId: string;
  url: string;
  token: string;
  identity: string;
  expiresAt: string;
}
export interface WatchAccess {
  purpose: 'PREVIEW' | 'WATCH';
  main: StaffMediaAccess;
  opponent: StaffMediaAccess | null;
}

/** At most this many card previews play at once (the rest show the cover with a play button). */
export const PREVIEW_MAX = 6;

/**
 * Which cards may play a preview now. A card on screen asks for a slot (`manual` false) and gets one while fewer than
 * {@link PREVIEW_MAX} play; pressing a card's play button (`manual` true) takes the oldest slot when all are used.
 * Leaving the screen gives the slot back. Pure (tested); one pool for the page.
 */
export class PreviewPool {
  private active: string[] = [];
  private readonly listeners = new Set<() => void>();
  constructor(readonly max: number = PREVIEW_MAX) {}

  has(id: string): boolean {
    return this.active.includes(id);
  }
  playing(): readonly string[] {
    return this.active;
  }
  /** Whether `id` plays now. */
  request(id: string, manual = false): boolean {
    if (this.active.includes(id)) return true;
    if (this.active.length >= this.max) {
      if (!manual) return false;
      this.active = this.active.slice(1);
    }
    this.active = [...this.active, id];
    this.emit();
    return true;
  }
  release(id: string): void {
    if (!this.active.includes(id)) return;
    this.active = this.active.filter((x) => x !== id);
    this.emit();
  }
  clear(): void {
    this.active = [];
    this.emit();
  }
  subscribe = (fn: () => void): (() => void) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };
  private emit(): void {
    for (const fn of this.listeners) fn();
  }
}

export const previewPool = new PreviewPool();

/** Whether the card `id` plays (re-renders when the pool changes). */
export function usePreviewSlot(pool: PreviewPool, id: string): boolean {
  return useSyncExternalStore(
    pool.subscribe,
    () => pool.has(id),
    () => pool.has(id),
  );
}

/**
 * Asks for a slot while `el` is on screen (IntersectionObserver), gives it back when it leaves or unmounts; a card on
 * screen without a slot takes one as soon as another card frees it.
 */
export function useOnScreenSlot(pool: PreviewPool, id: string, el: HTMLElement | null, enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !el || typeof IntersectionObserver === 'undefined') return;
    let visible = false;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          visible = e.isIntersecting && e.intersectionRatio >= 0.5;
          if (visible) pool.request(id);
          else pool.release(id);
        }
      },
      { threshold: [0, 0.5, 1] },
    );
    io.observe(el);
    const off = pool.subscribe(() => {
      if (visible && !pool.has(id) && pool.playing().length < pool.max) pool.request(id);
    });
    return () => {
      off();
      io.disconnect();
      pool.release(id);
    };
  }, [pool, id, el, enabled]);
}

export function watchToken(roomId: string, purpose: 'PREVIEW' | 'WATCH'): Promise<WatchAccess> {
  return api.post<WatchAccess>(`/admin/lives/${roomId}/watch-token`, { purpose });
}

type LiveKit = typeof import('livekit-client');
let lk: Promise<LiveKit> | null = null;
/** `livekit-client`, loaded once on first use (its own chunk). */
export function liveKit(): Promise<LiveKit> {
  lk ??= import('livekit-client');
  return lk;
}

/** One track the watch view shows or plays. */
export interface WatchTrack {
  key: string;
  room: 'main' | 'opponent';
  participant: string;
  name: string;
  kind: 'video' | 'audio';
  source: string;
  track: RemoteTrack;
}

/**
 * A muted, low-quality preview: subscribes to the first published video only (no audio), the lowest simulcast layer,
 * attached to `video`. Returns a stop function; `onState` reports 'video' | 'audio-only' | 'failed'.
 */
export async function startPreview(
  roomId: string,
  video: HTMLVideoElement,
  onState: (s: 'video' | 'audio-only' | 'failed') => void,
): Promise<() => void> {
  let room: Room | null = null;
  let stopped = false;
  const stop = () => {
    stopped = true;
    void room?.disconnect();
  };
  try {
    const [{ Room, RoomEvent, Track, VideoQuality }, access] = await Promise.all([liveKit(), watchToken(roomId, 'PREVIEW')]);
    if (stopped) return stop;
    room = new Room({ adaptiveStream: true, dynacast: false });
    let attached = false;
    const take = (pub: RemoteTrackPublication) => {
      if (attached || pub.kind !== Track.Kind.Video) return;
      pub.setSubscribed(true);
      pub.setVideoQuality(VideoQuality.LOW);
    };
    room.on(RoomEvent.TrackPublished, (pub) => take(pub));
    room.on(RoomEvent.TrackSubscribed, (track) => {
      if (attached || track.kind !== Track.Kind.Video) return;
      attached = true;
      video.muted = true;
      track.attach(video);
      onState('video');
    });
    await room.connect(access.main.url, access.main.token, { autoSubscribe: false });
    if (stopped) {
      void room.disconnect();
      return stop;
    }
    room.remoteParticipants.forEach((p: RemoteParticipant) => p.trackPublications.forEach((pub) => take(pub)));
    window.setTimeout(() => {
      if (!attached && !stopped) onState('audio-only');
    }, 4000);
  } catch {
    if (!stopped) onState('failed');
  }
  return stop;
}

/** The watch view's connection(s): every published track of the live (and of its PK opponent), with audio. */
export function useWatch(roomId: string, enabled: boolean) {
  const [tracks, setTracks] = useState<WatchTrack[]>([]);
  const [state, setState] = useState<'idle' | 'connecting' | 'live' | 'ended' | 'failed'>('idle');
  const [error, setError] = useState<unknown>(null);
  const [audioBlocked, setAudioBlocked] = useState(false);
  const [rooms, setRooms] = useState<Room[]>([]);
  useEffect(() => {
    if (!enabled) return;
    let stopped = false;
    const opened: Room[] = [];
    setState('connecting');
    void (async () => {
      try {
        const [{ Room, RoomEvent, Track }, access] = await Promise.all([liveKit(), watchToken(roomId, 'WATCH')]);
        if (stopped) return;
        const refresh = () => {
          const list: WatchTrack[] = [];
          opened.forEach((room, i) => {
            const side = i === 0 ? 'main' : 'opponent';
            room.remoteParticipants.forEach((p) =>
              p.trackPublications.forEach((pub) => {
                if (!pub.track || !pub.isSubscribed) return;
                list.push({
                  key: `${side}|${p.identity}|${pub.trackSid}`,
                  room: side,
                  participant: p.identity,
                  name: p.name || p.identity,
                  kind: pub.kind === Track.Kind.Video ? 'video' : 'audio',
                  source: pub.source,
                  track: pub.track,
                });
              }),
            );
          });
          setTracks(list);
        };
        for (const a of [access.main, access.opponent]) {
          if (!a) continue;
          const room = new Room({ adaptiveStream: true, dynacast: false });
          opened.push(room);
          room
            .on(RoomEvent.TrackSubscribed, refresh)
            .on(RoomEvent.TrackUnsubscribed, refresh)
            .on(RoomEvent.ParticipantDisconnected, refresh)
            .on(RoomEvent.AudioPlaybackStatusChanged, () => setAudioBlocked(!room.canPlaybackAudio))
            .on(RoomEvent.Disconnected, () => {
              if (!stopped && room === opened[0]) setState('ended');
            });
          await room.connect(a.url, a.token, { autoSubscribe: true });
          if (stopped) return;
          setAudioBlocked(!room.canPlaybackAudio);
        }
        setRooms([...opened]);
        refresh();
        setState('live');
      } catch (e) {
        if (!stopped) {
          setError(e);
          setState('failed');
        }
      }
    })();
    return () => {
      stopped = true;
      for (const r of opened) void r.disconnect();
      setTracks([]);
      setRooms([]);
    };
  }, [roomId, enabled]);
  const startAudio = async () => {
    for (const r of rooms) await r.startAudio().catch(() => undefined);
    setAudioBlocked(rooms.some((r) => !r.canPlaybackAudio));
  };
  return { tracks, state, error, audioBlocked, startAudio };
}
