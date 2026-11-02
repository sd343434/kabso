import { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { ApiError, type Api } from './api';
import { capabilityNote, currentCapabilities, displayMediaOptions } from './capabilities';
import { useT } from './context';
import {
  QUALITIES,
  cameraConstraints,
  defaultCamera,
  defaultMicrophone,
  deviceOptions,
  microphoneConstraints,
  type DeviceOption,
  type QualityId,
} from './devices';
import { errorKey } from './errors';
import {
  EMPTY_CHAT,
  chatFailed,
  chatLoaded,
  chatPending,
  chatReceived,
  chatSent,
  giftReceived,
  parseGift,
  type ChatState,
  type GiftLine,
} from './feed';
import { createTicker } from './heartbeat';
import type { Key } from './i18n';
import {
  CORNERS,
  DEFAULT_LAYOUT,
  layoutUpdate,
  missingForLive,
  orientationOf,
  startSetup,
  wireLayout,
  type OrientationChoice,
  type StudioLayout,
} from './layout';
import { ObsHelp } from './ObsHelp';
import { connLabel, nextConnState, retryableApiFailure, type ConnState, type EndReason } from './reconnect';
import { SidePanel } from './SidePanel';
import { Stage } from './Stage';
import { StudioLive } from './studio-live';
import type { GiftCatalogue, LiveChatMessage, LiveConfig, LiveMediaAccess, LiveRoom, LiveStreamer, Me, PublicProfile } from './types';

type Gate =
  | { kind: 'checking' }
  | { kind: 'ok' }
  | { kind: 'noPermission' }
  | { kind: 'hostingOff' }
  | { kind: 'error'; error: unknown }
  | { kind: 'active'; room: LiveRoom };

type Phase =
  | { kind: 'setup' }
  | { kind: 'starting' }
  | { kind: 'live'; room: LiveRoom; since: number }
  | { kind: 'ended'; reason: EndReason; seconds: number };

interface ScreenShare {
  video: MediaStreamTrack;
  audio: MediaStreamTrack | null;
  label: string;
}

function readPref(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}
function writePref(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* per-viewer convenience only */
  }
}

function stopTrack(t: MediaStreamTrack | null | undefined): void {
  try {
    t?.stop();
  } catch {
    /* already stopped */
  }
}

function clock(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const mm = String(m).padStart(2, '0');
  const ss = String(s).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

/**
 * The studio (D247): the hosting gate, the sources (screen, camera incl. OBS Virtual Camera, microphone), the layout
 * and its preview, then the live itself — media, the layout kept in sync with `PUT …/streamer`, the heartbeat, the
 * chat and the gifts, reconnection, and the end.
 */
export function Studio({ api, me }: { api: Api; me: Me }) {
  const { t, lang } = useT();
  const caps = useMemo(() => currentCapabilities(), []);
  const [config, setConfig] = useState<LiveConfig | null>(null);
  const [gate, setGate] = useState<Gate>({ kind: 'checking' });
  const [resumeRoom, setResumeRoom] = useState<LiveRoom | null>(null);

  // ---- sources -----------------------------------------------------------------------------------------------
  const [cameras, setCameras] = useState<DeviceOption[]>([]);
  const [mics, setMics] = useState<DeviceOption[]>([]);
  const [labelled, setLabelled] = useState(false);
  const [denied, setDenied] = useState(false);
  const [cameraId, setCameraId] = useState<string | null>(() => readPref('kabso.studio.camera'));
  const [micId, setMicId] = useState<string | null>(() => readPref('kabso.studio.mic'));
  const [cameraOff, setCameraOff] = useState(false);
  const [micOff, setMicOff] = useState(false);
  const [cameraTrack, setCameraTrack] = useState<MediaStreamTrack | null>(null);
  const [micTrack, setMicTrack] = useState<MediaStreamTrack | null>(null);
  const [cameraLost, setCameraLost] = useState(false);
  const [cameraEpoch, setCameraEpoch] = useState(0);
  const [screen, setScreen] = useState<ScreenShare | null>(null);
  const [screenStopped, setScreenStopped] = useState(false);
  const [wantScreenAudio, setWantScreenAudio] = useState(true);
  const [quality, setQuality] = useState<QualityId>(() => (readPref('kabso.studio.quality') === '1080p' ? '1080p' : '720p'));
  const [layout, setLayout] = useState<StudioLayout>(() => ({
    ...DEFAULT_LAYOUT,
    mode: readPref('kabso.studio.mode') === 'camera' ? 'camera' : 'screen',
  }));
  const [mainSize, setMainSize] = useState<{ w: number; h: number } | null>(null);
  const [title, setTitle] = useState('');
  const [error, setError] = useState<unknown>(null);

  // ---- live ----------------------------------------------------------------------------------------------------
  const [phase, setPhase] = useState<Phase>({ kind: 'setup' });
  const [conn, dispatch] = useReducer(nextConnState, { kind: 'idle' } as ConnState);
  const [serverLayout, setServerLayout] = useState<LiveStreamer | null>(null);
  const [chat, setChat] = useState<ChatState>(EMPTY_CHAT);
  const [gifts, setGifts] = useState<GiftLine[]>([]);
  const [giftNames, setGiftNames] = useState<Map<string, { name: string; imageUrl: string | null }>>(new Map());
  const [viewers, setViewers] = useState(0);
  const [netQuality, setNetQuality] = useState<string>('unknown');
  const [mutedMic, setMutedMic] = useState(false);
  const [mutedScreenAudio, setMutedScreenAudio] = useState(false);
  const [pausedScreen, setPausedScreen] = useState(false);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [ending, setEnding] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const [heartbeatFailures, setHeartbeatFailures] = useState(0);
  const joinSeq = useRef(0);

  const liveRef = useRef<StudioLive | null>(null);
  const live = useMemo(() => {
    const session = new StudioLive({
      onData: (topic, payload) => {
        if (topic === 'chat') {
          joinSeq.current += 1;
          const seq = joinSeq.current;
          setChat((c) => chatReceived(c, payload, seq));
        } else if (topic === 'gift') {
          const gift = parseGift(payload);
          if (gift) setGifts((g) => giftReceived(g, gift));
        } else if (topic === 'streamer') {
          const s = (payload as { streamer?: LiveStreamer } | null)?.streamer;
          if (s && typeof s.version === 'number') setServerLayout((cur) => (cur && cur.version >= s.version ? cur : s));
        }
      },
      onResuming: () => dispatch({ type: 'resuming' }),
      onResumed: () => dispatch({ type: 'resumed' }),
      onLost: () => dispatch({ type: 'lost' }),
      onQuality: setNetQuality,
    });
    liveRef.current = session;
    return session;
  }, []);

  const isLive = phase.kind === 'live';
  const isLiveRef = useRef(false);
  isLiveRef.current = isLive;
  const roomId = phase.kind === 'live' ? phase.room.id : null;

  // ---- gate: the same checks as the app's go-live ----------------------------------------------------------
  const checkGate = useCallback(async () => {
    setGate({ kind: 'checking' });
    try {
      const cfg = await api.get<LiveConfig>('/live/config');
      setConfig(cfg);
      if (!cfg.hostingEnabled) return setGate({ kind: 'hostingOff' });
      const fresh = await api.get<Me>('/me');
      if (!fresh.canHost) return setGate({ kind: 'noPermission' });
      const profile = await api.get<PublicProfile>(`/users/${encodeURIComponent(fresh.username)}`);
      if (profile.liveRoomId) {
        const room = await api.get<LiveRoom>(`/live/rooms/${profile.liveRoomId}`);
        if (room.status !== 'ENDED') return setGate({ kind: 'active', room });
      }
      setGate({ kind: 'ok' });
    } catch (err) {
      setGate({ kind: 'error', error: err });
    }
  }, [api]);
  useEffect(() => {
    void checkGate();
  }, [checkGate]);

  // ---- devices -------------------------------------------------------------------------------------------------
  const listDevices = useCallback(async () => {
    if (!navigator.mediaDevices?.enumerateDevices) return;
    const list = deviceOptions(await navigator.mediaDevices.enumerateDevices());
    setCameras(list.cameras);
    setMics(list.microphones);
    setLabelled(list.labelled);
  }, []);
  useEffect(() => {
    void listDevices();
    const md = navigator.mediaDevices;
    if (!md?.addEventListener) return;
    const onChange = () => void listDevices();
    md.addEventListener('devicechange', onChange);
    return () => md.removeEventListener('devicechange', onChange);
  }, [listDevices]);

  const allowDevices = async () => {
    setDenied(false);
    try {
      const s = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }).catch(async (e: unknown) => {
        if ((e as DOMException).name === 'NotFoundError') return navigator.mediaDevices.getUserMedia({ audio: true });
        throw e;
      });
      s.getTracks().forEach(stopTrack);
    } catch (e) {
      if ((e as DOMException).name === 'NotAllowedError' || (e as DOMException).name === 'SecurityError') setDenied(true);
    }
    await listDevices();
  };

  // The chosen camera / microphone ids, falling back to OBS (camera-only layout) or the first device.
  const effectiveCamera = cameraOff ? null : defaultCamera(cameras, cameraId, layout.mode === 'camera');
  const effectiveMic = micOff ? null : defaultMicrophone(mics, micId);
  const cameraAsMain = layout.mode === 'camera';

  useEffect(() => {
    if (!labelled || !effectiveCamera) {
      setCameraTrack((old) => {
        stopTrack(old);
        return null;
      });
      return;
    }
    let cancelled = false;
    navigator.mediaDevices
      .getUserMedia({ video: cameraConstraints(effectiveCamera, cameraAsMain, quality) })
      .then((s) => {
        const track = s.getVideoTracks()[0] ?? null;
        if (cancelled) return stopTrack(track);
        track?.addEventListener('ended', () => setCameraLost(true));
        setCameraLost(false);
        setCameraTrack((old) => {
          stopTrack(old);
          return track;
        });
      })
      .catch(() => {
        if (!cancelled) setCameraLost(true);
      });
    return () => {
      cancelled = true;
    };
  }, [labelled, effectiveCamera, cameraAsMain, quality, cameraEpoch]);

  useEffect(() => {
    if (!labelled || !effectiveMic) {
      setMicTrack((old) => {
        stopTrack(old);
        return null;
      });
      return;
    }
    let cancelled = false;
    navigator.mediaDevices
      .getUserMedia({ audio: microphoneConstraints(effectiveMic) })
      .then((s) => {
        const track = s.getAudioTracks()[0] ?? null;
        if (cancelled) return stopTrack(track);
        setMicTrack((old) => {
          stopTrack(old);
          return track;
        });
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [labelled, effectiveMic]);

  // ---- the screen ------------------------------------------------------------------------------------------------
  const pickScreen = async () => {
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getDisplayMedia(displayMediaOptions(caps, QUALITIES[quality], wantScreenAudio));
      const video = stream.getVideoTracks()[0];
      if (!video) return;
      const audio = stream.getAudioTracks()[0] ?? null;
      const share: ScreenShare = { video, audio, label: video.label };
      // The browser's «Stop sharing» bar (or the shared window closed). Live: the publication stays and is muted, so
      // viewers see «الشاشة متوقفة مؤقتاً» until the host shares again into the same publication. These listeners
      // are added before livekit-client's own (it subscribes when the track is published) and stop the event there:
      // livekit-client would otherwise unpublish an ended screen share (viewers would see «بانتظار شاشة المضيف»).
      // Before the live, the choice is simply gone.
      video.addEventListener('ended', (ev) => {
        if (isLiveRef.current) {
          ev.stopImmediatePropagation();
          setScreenStopped(true);
        } else {
          setScreen((cur) => (cur?.video === video ? null : cur));
        }
      });
      audio?.addEventListener('ended', (ev) => {
        if (isLiveRef.current) ev.stopImmediatePropagation();
      });
      setScreen((old) => {
        if (old && old.video !== video) {
          stopTrack(old.video);
          stopTrack(old.audio);
        }
        return share;
      });
      setScreenStopped(false);
      setMainSize(null);
    } catch (e) {
      if ((e as DOMException).name !== 'NotAllowedError' && (e as DOMException).name !== 'AbortError') setError(e);
    }
  };
  const stopScreen = () => {
    setScreen((old) => {
      stopTrack(old?.video);
      stopTrack(old?.audio);
      return null;
    });
    setScreenStopped(false);
  };

  // ---- the layout ------------------------------------------------------------------------------------------------
  const detected = mainSize ? orientationOf(mainSize.w, mainSize.h) : null;
  const hasCamera = cameraTrack !== null && !cameraLost;
  const wire = wireLayout(layout, detected, hasCamera);
  const setLayoutKey = <K extends keyof StudioLayout>(key: K, value: StudioLayout[K]) => {
    setLayout((l) => ({ ...l, [key]: value }));
    if (key === 'mode') {
      writePref('kabso.studio.mode', String(value));
      setMainSize(null);
    }
  };
  const onMainSize = useCallback((w: number, h: number) => setMainSize((cur) => (cur && cur.w === w && cur.h === h ? cur : { w, h })), []);

  // ---- going live ------------------------------------------------------------------------------------------------
  const sources = { screen: screen !== null && !screenStopped, camera: hasCamera, microphone: micTrack !== null };
  const missing = missingForLive(layout, sources, title);

  const joinMedia = useCallback(
    async (id: string) => {
      const access = await api.post<LiveMediaAccess>(`/live/rooms/${id}/media-token`, {});
      await live.connect(access);
    },
    [api, live],
  );

  const goLive = async () => {
    if (missing.length > 0 || phase.kind === 'starting') return;
    setError(null);
    setPhase({ kind: 'starting' });
    try {
      let room: LiveRoom;
      if (resumeRoom) {
        room = resumeRoom;
      } else {
        room = await api.post<LiveRoom>('/live/rooms', { title: title.trim(), mode: 'STREAMER', streamer: startSetup(wire) });
      }
      let current = room.streamer;
      const body = layoutUpdate(current ? { ...current } : null, wire);
      if (resumeRoom && body) current = await api.put<LiveStreamer>(`/live/rooms/${room.id}/streamer`, body);
      setServerLayout(current);
      setChat(EMPTY_CHAT);
      setGifts([]);
      live.quality = quality;
      live.cameraIsMain = layout.mode === 'camera';
      await live.setTrack('screen', layout.mode === 'screen' ? (screen?.video ?? null) : null);
      await live.setTrack('screenAudio', layout.mode === 'screen' ? (screen?.audio ?? null) : null);
      await live.setTrack('camera', cameraTrack);
      await live.setTrack('microphone', micTrack);
      setPhase({ kind: 'live', room, since: Date.parse(room.startedAt) || Date.now() });
      setResumeRoom(null);
      dispatch({ type: 'connect' });
      try {
        await joinMedia(room.id);
        dispatch({ type: 'connected' });
      } catch {
        dispatch({ type: 'lost' });
      }
      void api
        .get<{ data: LiveChatMessage[] }>(`/live/rooms/${room.id}/chat`)
        .then((r) => setChat((c) => chatLoaded(c, r.data)))
        .catch(() => undefined);
    } catch (err) {
      setPhase({ kind: 'setup' });
      if (err instanceof ApiError && err.code === 'LIVE_ROOM_ALREADY_ACTIVE') {
        void checkGate();
        return;
      }
      if (err instanceof ApiError && (err.code === 'LIVE_HOSTING_NOT_ALLOWED' || err.code === 'LIVE_HOSTING_UNAVAILABLE')) {
        setGate({ kind: err.code === 'LIVE_HOSTING_NOT_ALLOWED' ? 'noPermission' : 'hostingOff' });
        return;
      }
      setError(err);
    }
  };

  const finish = useCallback(
    async (reason: EndReason) => {
      await live.disconnect();
      setPhase((p) => (p.kind === 'live' ? { kind: 'ended', reason, seconds: Math.max(0, Math.round((Date.now() - p.since) / 1000)) } : p));
      // The capture ends with the live: the browser's sharing bar and the camera light go off.
      setScreen((old) => {
        stopTrack(old?.video);
        stopTrack(old?.audio);
        return null;
      });
      setScreenStopped(false);
      setPausedScreen(false);
      setMutedMic(false);
      setMutedScreenAudio(false);
      for (const k of ['screen', 'screenAudio', 'microphone', 'camera'] as const) await live.setMuted(k, false);
    },
    [live],
  );

  // The connection state machine's side effects.
  useEffect(() => {
    if (conn.kind === 'ended' && phase.kind === 'live') void finish(conn.reason);
    if (conn.kind !== 'rejoining' || !roomId) return;
    const timer = setTimeout(() => {
      joinMedia(roomId)
        .then(() => dispatch({ type: 'connected' }))
        .catch((err: unknown) => {
          if (err instanceof ApiError) {
            if (err.code === 'LIVE_ROOM_ENDED' || err.status === 404) return dispatch({ type: 'room-ended' });
            if (err.status === 401) return dispatch({ type: 'signed-out' });
            if (err.code === 'LIVE_HOSTING_UNAVAILABLE') return dispatch({ type: 'hosting-off' });
            return dispatch({ type: 'rejoin-failed', retryable: retryableApiFailure(err.status, err.code) });
          }
          // A media server error (network): try again.
          dispatch({ type: 'rejoin-failed', retryable: true });
        });
    }, conn.delayMs);
    return () => clearTimeout(timer);
  }, [conn, roomId, joinMedia, finish, phase.kind]);

  // The heartbeat (a worker's clock), every heartbeatIntervalSeconds while live.
  useEffect(() => {
    if (!roomId || !config) return;
    const ticker = createTicker();
    const beat = () => {
      api
        .post<void>(`/live/rooms/${roomId}/heartbeat`)
        .then(() => setHeartbeatFailures(0))
        .catch((err: unknown) => {
          if (err instanceof ApiError && err.code === 'LIVE_ROOM_ENDED') dispatch({ type: 'room-ended' });
          else if (err instanceof ApiError && err.code === 'LIVE_HOSTING_UNAVAILABLE') dispatch({ type: 'hosting-off' });
          else if (err instanceof ApiError && err.status === 401) dispatch({ type: 'signed-out' });
          else setHeartbeatFailures((n) => n + 1);
        });
    };
    beat();
    ticker.start(Math.max(5, config.heartbeatIntervalSeconds) * 1000, beat);
    return () => ticker.stop();
  }, [roomId, config, api]);

  // The room read every 10 s: the viewer count (viewers are hidden on the media server, so the API counts them), an
  // end by the team, the chat switch.
  useEffect(() => {
    if (!roomId) return;
    const read = () =>
      api
        .get<LiveRoom>(`/live/rooms/${roomId}`)
        .then((r) => {
          setViewers(r.viewerCount);
          if (r.status === 'ENDED') dispatch({ type: 'room-ended' });
          if (typeof r.chatEnabled === 'boolean') setChat((c) => ({ ...c, enabled: r.chatEnabled as boolean }));
          if (r.streamer) setServerLayout((cur) => (cur && cur.version >= (r.streamer as LiveStreamer).version ? cur : r.streamer));
        })
        .catch(() => undefined);
    void read();
    const timer = setInterval(() => void read(), 10_000);
    return () => clearInterval(timer);
  }, [roomId, api]);

  // The gift names (the catalogue in the page's language).
  useEffect(() => {
    if (!roomId) return;
    api.lang = lang;
    api
      .get<GiftCatalogue>('/gifts/catalogue')
      .then((c) => setGiftNames(new Map(c.data.map((g) => [g.code, { name: g.name, imageUrl: g.imageUrl }]))))
      .catch(() => undefined);
  }, [roomId, api, lang]);

  // Tracks follow the host's choices while live.
  useEffect(() => {
    if (!isLive) return;
    live.cameraIsMain = layout.mode === 'camera';
    void (async () => {
      await live.setTrack('screen', layout.mode === 'screen' ? (screen?.video ?? null) : null);
      await live.setTrack('screenAudio', layout.mode === 'screen' ? (screen?.audio ?? null) : null);
      await live.setTrack('camera', cameraTrack);
      await live.setTrack('microphone', micTrack);
    })().catch(() => undefined);
  }, [isLive, live, layout.mode, screen, cameraTrack, micTrack]);

  // Mutes: the host's toggles, a stopped screen (browser bar) and a lost camera.
  useEffect(() => {
    if (!isLive) return;
    void live.setMuted('screen', pausedScreen || screenStopped);
    void live.setMuted('screenAudio', mutedScreenAudio || pausedScreen || screenStopped);
    void live.setMuted('microphone', mutedMic);
    void live.setMuted('camera', cameraLost || (layout.mode === 'camera' ? false : !layout.bubbleVisible));
  }, [isLive, live, pausedScreen, screenStopped, mutedScreenAudio, mutedMic, cameraLost, layout.mode, layout.bubbleVisible]);

  // The layout viewers get, sent when it changes (debounced; idempotent server side).
  const wireKey = JSON.stringify(wire);
  useEffect(() => {
    if (!roomId || !serverLayout) return;
    const body = layoutUpdate(serverLayout, JSON.parse(wireKey) as typeof wire);
    if (!body) return;
    const timer = setTimeout(() => {
      api
        .put<LiveStreamer>(`/live/rooms/${roomId}/streamer`, body)
        .then((s) => setServerLayout((cur) => (cur && cur.version > s.version ? cur : s)))
        .catch((err: unknown) => {
          if (err instanceof ApiError && err.code === 'LIVE_ROOM_ENDED') dispatch({ type: 'room-ended' });
        });
    }, 500);
    return () => clearTimeout(timer);
  }, [roomId, serverLayout, wireKey, api]);

  // Leaving the page while live: the browser's own warning.
  useEffect(() => {
    if (!isLive) return;
    const warn = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = t('leaveWarning');
      return t('leaveWarning');
    };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [isLive, t]);

  useEffect(() => {
    if (!isLive) return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [isLive]);

  useEffect(
    () => () => {
      void liveRef.current?.disconnect();
    },
    [],
  );

  const sendChat = (text: string) => {
    if (!roomId) return;
    const clientId = crypto.randomUUID();
    const pending: LiveChatMessage = {
      id: clientId,
      roomId,
      author: { id: me.id, username: me.username, displayName: me.displayName, avatarUrl: me.avatarUrl },
      authorRole: 'HOST',
      kind: 'TEXT',
      text,
      expiresAt: null,
      createdAt: new Date().toISOString(),
    };
    setChat((c) => chatPending(c, clientId, pending));
    api
      .post<LiveChatMessage>(`/live/rooms/${roomId}/chat`, { text, clientId })
      .then((m) => setChat((c) => chatSent(c, clientId, m)))
      .catch(() => setChat((c) => chatFailed(c, clientId)));
  };

  const endLive = async () => {
    if (!roomId) return;
    setEnding(true);
    try {
      await api.post<LiveRoom>(`/live/rooms/${roomId}/end`);
    } catch (err) {
      if (!(err instanceof ApiError && (err.code === 'LIVE_ROOM_ENDED' || err.status === 404))) {
        setEnding(false);
        setError(err);
        return;
      }
    }
    setEnding(false);
    setConfirmEnd(false);
    dispatch({ type: 'host-ended' });
  };

  const endOldLive = async (room: LiveRoom) => {
    try {
      await api.post<LiveRoom>(`/live/rooms/${room.id}/end`);
    } catch {
      /* already ended */
    }
    setResumeRoom(null);
    void checkGate();
  };

  const newLive = () => {
    setPhase({ kind: 'setup' });
    dispatch({ type: 'reset' });
    setChat(EMPTY_CHAT);
    setGifts([]);
    setViewers(0);
    setServerLayout(null);
    void checkGate();
  };

  // ---- render ----------------------------------------------------------------------------------------------------
  if (gate.kind === 'checking') {
    return (
      <main className="center">
        <div className="spinner" aria-label="…" />
      </main>
    );
  }
  if (gate.kind !== 'ok' && gate.kind !== 'active' && phase.kind !== 'live') {
    const key: Key = gate.kind === 'noPermission' ? 'gateNoPermission' : gate.kind === 'hostingOff' ? 'gateHostingOff' : errorKey(gate.kind === 'error' ? gate.error : null).key;
    return (
      <main className="center">
        <div className="card gate" data-testid="gate" data-gate={gate.kind}>
          <h1>{t(key)}</h1>
          {gate.kind === 'noPermission' && <p className="muted">{t('gateNoPermissionHint')}</p>}
          <button className="btn" onClick={() => void checkGate()}>
            ↻
          </button>
        </div>
      </main>
    );
  }

  if (phase.kind === 'ended') {
    const reasonKey: Key =
      phase.reason === 'host' ? 'endedByHost' : phase.reason === 'auth' ? 'endedAuth' : phase.reason === 'hosting-off' ? 'endedHostingOff' : 'endedByServer';
    return (
      <main className="center">
        <div className="card gate" data-testid="ended">
          <h1>{t('endedTitle')}</h1>
          <p>{t(reasonKey)}</p>
          <p className="muted">
            {t('elapsed')}: <bdi className="ltr">{clock(phase.seconds)}</bdi>
          </p>
          <button className="btn primary" onClick={newLive}>
            {t('newLive')}
          </button>
        </div>
      </main>
    );
  }

  const live_ = phase.kind === 'live';
  const label = connLabel(conn);
  const pausedNote = layout.mode === 'screen' && live_ && (screenStopped || pausedScreen) ? t(screenStopped ? 'screenStopped' : 'pauseScreen') : null;
  const obsCameras = cameras.filter((c) => c.obs);
  const errMsg = error ? errorKey(error) : null;

  const stage = (
    <Stage
      mode={layout.mode}
      orientation={wire.orientation}
      screen={screen?.video ?? null}
      camera={hasCamera ? cameraTrack : null}
      bubbleVisible={wire.cameraOverlay.visible}
      corner={layout.corner}
      onCorner={(c) => setLayoutKey('corner', c)}
      onMainSize={onMainSize}
      paused={pausedNote}
      testId={live_ ? 'live-stage' : 'stage'}
    />
  );

  return (
    <main className={`studio ${live_ ? 'is-live' : ''}`}>
      {gate.kind === 'active' && !live_ && !resumeRoom && (
        <div className="alert warn row-between" data-testid="active-live">
          <div>
            <strong>{t('gateActive')}</strong> <span className="muted">{t('gateActiveHint')}</span>
          </div>
          <div className="row">
            {gate.room.mode === 'STREAMER' && (
              <button
                className="btn primary small"
                onClick={() => {
                  setResumeRoom(gate.room);
                  setTitle(gate.room.title);
                }}
              >
                {t('resumeLive')}
              </button>
            )}
            <button className="btn danger small" onClick={() => void endOldLive(gate.room)}>
              {t('endOldLive')}
            </button>
          </div>
        </div>
      )}
      {errMsg && (
        <div className="alert error" role="alert">
          {t(errMsg.key, errMsg.vars)}
        </div>
      )}

      {live_ && (
        <header className="live-bar card" data-testid="live-bar">
          <span className={`pill ${conn.kind === 'connected' ? 'live' : 'warn'}`} data-testid="conn" data-state={conn.kind}>
            {conn.kind === 'connected' && <i className="dot" aria-hidden="true" />}
            {t(label, conn.kind === 'rejoining' ? { n: conn.attempt } : {})}
          </span>
          <span className="stat" title={t('elapsed')}>
            ⏱ <bdi className="ltr">{clock(Math.max(0, Math.round((now - phase.since) / 1000)))}</bdi>
          </span>
          <span className="stat" data-testid="viewers" data-count={viewers} title={t('viewersLabel', { n: viewers })}>
            👁 <bdi>{viewers.toLocaleString(lang === 'ar' ? 'ar' : 'en')}</bdi> {t('viewers')}
          </span>
          {(netQuality === 'poor' || netQuality === 'lost' || heartbeatFailures >= 2) && <span className="pill warn">{t('statusUnstable')}</span>}
          <bdi className="live-title">{phase.room.title}</bdi>
          <span className="grow" />
          <button className="btn danger" onClick={() => setConfirmEnd(true)} data-testid="end-live">
            {t('endLive')}
          </button>
        </header>
      )}

      <div className={live_ ? 'live-grid' : 'setup-grid'}>
        {!live_ && (
          <section className="controls card" aria-label={t('stepSources')}>
            <h2>{t('stepLayout')}</h2>
            <div className="choice" role="radiogroup" aria-label={t('stepLayout')}>
              {(['screen', 'camera'] as const).map((m) => (
                <button
                  key={m}
                  role="radio"
                  aria-checked={layout.mode === m}
                  className={`choice-item ${layout.mode === m ? 'on' : ''}`}
                  onClick={() => setLayoutKey('mode', m)}
                  data-testid={`mode-${m}`}
                >
                  <strong>{t(m === 'screen' ? 'layoutScreen' : 'layoutCamera')}</strong>
                  <small>{t(m === 'screen' ? 'layoutScreenHint' : 'layoutCameraHint')}</small>
                </button>
              ))}
            </div>

            {layout.mode === 'screen' && (
              <div className="group">
                <h3>{t('screenTitle')}</h3>
                <p className="note small" data-testid="cap-note" data-note={capabilityNote(caps)}>
                  {t(capabilityNote(caps))}
                </p>
                {caps.screen && (
                  <>
                    {screen ? (
                      <div className="row-between">
                        <span className="small">
                          {t('screenSharing', { label: screen.label || '—' })} · {t(screen.audio ? 'screenAudioOn' : 'screenAudioOff')}
                        </span>
                        <span className="row">
                          <button className="btn small" onClick={() => void pickScreen()}>
                            {t('changeScreen')}
                          </button>
                          <button className="btn ghost small" onClick={stopScreen}>
                            {t('stopScreen')}
                          </button>
                        </span>
                      </div>
                    ) : (
                      <button className="btn primary block" onClick={() => void pickScreen()} data-testid="pick-screen">
                        {t('shareScreen')}
                      </button>
                    )}
                    {caps.audio !== 'none' && (
                      <label className="check">
                        <input type="checkbox" checked={wantScreenAudio} onChange={(e) => setWantScreenAudio(e.target.checked)} />
                        {t('screenAudioWant')}
                      </label>
                    )}
                  </>
                )}
              </div>
            )}

            <div className="group">
              <h3>{t('cameraTitle')}</h3>
              {!labelled ? (
                <>
                  <button className="btn block" onClick={() => void allowDevices()} data-testid="allow-devices">
                    {t('allowDevices')}
                  </button>
                  <p className="muted small">{denied ? t('devicesDenied') : t('allowDevicesHint')}</p>
                </>
              ) : (
                <>
                  <select
                    aria-label={t('cameraTitle')}
                    value={cameraOff ? '' : (effectiveCamera ?? '')}
                    onChange={(e) => {
                      const v = e.target.value;
                      setCameraOff(v === '');
                      if (v) {
                        setCameraId(v);
                        writePref('kabso.studio.camera', v);
                      }
                    }}
                    data-testid="camera-select"
                  >
                    {layout.mode === 'screen' && <option value="">{t('noCamera')}</option>}
                    {cameras.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.obs ? `★ ${c.label}` : c.label}
                      </option>
                    ))}
                  </select>
                  {cameras.length === 0 && <p className="muted small">{t('noCameras')}</p>}
                  {cameraLost && (
                    <p className="alert warn small">
                      {t('cameraLost')}{' '}
                      <button className="btn small" onClick={() => setCameraEpoch((n) => n + 1)}>
                        {t('reconnectCamera')}
                      </button>
                    </p>
                  )}
                </>
              )}
              <ObsHelp found={obsCameras.length > 0} prominent={layout.mode === 'camera'} />
            </div>

            <div className="group">
              <h3>{t('micTitle')}</h3>
              {labelled && (
                <select
                  aria-label={t('micTitle')}
                  value={micOff ? '' : (effectiveMic ?? '')}
                  onChange={(e) => {
                    const v = e.target.value;
                    setMicOff(v === '');
                    if (v) {
                      setMicId(v);
                      writePref('kabso.studio.mic', v);
                    }
                  }}
                  data-testid="mic-select"
                >
                  <option value="">{t('noMicrophone')}</option>
                  {mics.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.label}
                    </option>
                  ))}
                </select>
              )}
            </div>

            {layout.mode === 'screen' && (
              <div className="group">
                <h3>{t('bubbleTitle')}</h3>
                <label className="check">
                  <input type="checkbox" checked={layout.bubbleVisible} onChange={(e) => setLayoutKey('bubbleVisible', e.target.checked)} />
                  {t('bubbleShow')}
                </label>
                <div className="corners" role="radiogroup" aria-label={t('bubbleCorner')} dir="ltr">
                  {CORNERS.map((c) => (
                    <button
                      key={c}
                      role="radio"
                      aria-checked={layout.corner === c}
                      aria-label={t(`corner${c}`)}
                      title={t(`corner${c}`)}
                      className={`corner c-${c} ${layout.corner === c ? 'on' : ''}`}
                      onClick={() => setLayoutKey('corner', c)}
                    >
                      <i />
                    </button>
                  ))}
                </div>
                <p className="muted small">{t('bubbleDragHint')}</p>
              </div>
            )}

            <div className="group two">
              <label className="field">
                <span>{t('orientationTitle')}</span>
                <select value={layout.orientation} onChange={(e) => setLayoutKey('orientation', e.target.value as OrientationChoice)} data-testid="orientation">
                  <option value="auto">{t('orientationAuto', { detected: detected ? t(`orientation${detected}`) : t('orientationUnknown') })}</option>
                  <option value="LANDSCAPE">{t('orientationLANDSCAPE')}</option>
                  <option value="PORTRAIT">{t('orientationPORTRAIT')}</option>
                </select>
              </label>
              <label className="field">
                <span>{t('qualityTitle')}</span>
                <select
                  value={quality}
                  onChange={(e) => {
                    const q = e.target.value as QualityId;
                    setQuality(q);
                    writePref('kabso.studio.quality', q);
                  }}
                >
                  <option value="720p">{t('quality720p')}</option>
                  <option value="1080p">{t('quality1080p')}</option>
                </select>
              </label>
            </div>
            <p className="muted small">{t('qualityHint')}</p>
          </section>
        )}

        <section className="preview">
          {!live_ && <h2>{t('previewTitle')}</h2>}
          {stage}
          {!live_ && <p className="muted small">{t('previewNote')}</p>}
          {live_ && (
            <div className="toolbar card" role="toolbar">
              <button className={`tool ${mutedMic ? 'off' : ''}`} aria-pressed={mutedMic} onClick={() => setMutedMic((v) => !v)} disabled={!micTrack} data-testid="toggle-mic">
                {mutedMic ? '🔇' : '🎙️'} {t(mutedMic ? 'unmuteMic' : 'muteMic')}
              </button>
              {layout.mode === 'screen' && (
                <button
                  className={`tool ${mutedScreenAudio ? 'off' : ''}`}
                  aria-pressed={mutedScreenAudio}
                  onClick={() => setMutedScreenAudio((v) => !v)}
                  disabled={!screen?.audio}
                  data-testid="toggle-screen-audio"
                >
                  {mutedScreenAudio ? '🔈' : '🔊'} {t(mutedScreenAudio ? 'unmuteScreenAudio' : 'muteScreenAudio')}
                </button>
              )}
              {layout.mode === 'screen' && (
                <button
                  className={`tool ${!layout.bubbleVisible ? 'off' : ''}`}
                  aria-pressed={!layout.bubbleVisible}
                  onClick={() => setLayoutKey('bubbleVisible', !layout.bubbleVisible)}
                  disabled={!hasCamera}
                  data-testid="toggle-camera"
                >
                  📷 {t(layout.bubbleVisible ? 'hideCamera' : 'showCamera')}
                </button>
              )}
              {layout.mode === 'screen' && !screenStopped && (
                <button className={`tool ${pausedScreen ? 'off' : ''}`} aria-pressed={pausedScreen} onClick={() => setPausedScreen((v) => !v)} data-testid="toggle-screen">
                  {pausedScreen ? '▶️' : '⏸️'} {t(pausedScreen ? 'resumeScreen' : 'pauseScreen')}
                </button>
              )}
              {layout.mode === 'screen' && (
                <span className="corners inline" role="radiogroup" aria-label={t('bubbleCorner')} dir="ltr">
                  {CORNERS.map((c) => (
                    <button
                      key={c}
                      role="radio"
                      aria-checked={layout.corner === c}
                      aria-label={t(`corner${c}`)}
                      title={t(`corner${c}`)}
                      className={`corner small c-${c} ${layout.corner === c ? 'on' : ''}`}
                      onClick={() => setLayoutKey('corner', c)}
                    >
                      <i />
                    </button>
                  ))}
                </span>
              )}
            </div>
          )}
          {live_ && screenStopped && layout.mode === 'screen' && (
            <div className="alert warn row-between" data-testid="screen-stopped">
              <div>
                <strong>{t('screenStopped')}</strong> <span className="muted">{t('screenStoppedHint')}</span>
              </div>
              <button className="btn primary" onClick={() => void pickScreen()}>
                {t('reshare')}
              </button>
            </div>
          )}
          {live_ && cameraLost && (
            <div className="alert warn row-between small">
              <span>{t('cameraLost')}</span>
              <button className="btn small" onClick={() => setCameraEpoch((n) => n + 1)}>
                {t('reconnectCamera')}
              </button>
            </div>
          )}
          {!live_ && (
            <div className="golive card">
              <label className="field">
                <span>{t('titleLabel')}</span>
                <input value={title} maxLength={60} placeholder={t('titlePlaceholder')} onChange={(e) => setTitle(e.target.value)} data-testid="title" disabled={resumeRoom !== null} />
              </label>
              {missing.length > 0 && (
                <ul className="missing small">
                  {missing.map((m) => (
                    <li key={m}>{t(m)}</li>
                  ))}
                </ul>
              )}
              <button className="btn primary big" disabled={missing.length > 0 || phase.kind === 'starting'} onClick={() => void goLive()} data-testid="go-live">
                {phase.kind === 'starting' ? t('goingLive') : resumeRoom ? t('resumeLive') : t('goLive')}
              </button>
            </div>
          )}
        </section>

        {live_ && <SidePanel chat={chat} gifts={gifts} giftNames={giftNames} onSend={sendChat} />}
      </div>

      {confirmEnd && (
        <div className="modal-scrim" role="presentation" onClick={() => !ending && setConfirmEnd(false)}>
          <div className="card modal" role="alertdialog" aria-modal="true" aria-labelledby="end-title" onClick={(e) => e.stopPropagation()}>
            <h2 id="end-title">{t('endConfirmTitle')}</h2>
            <p>{t('endConfirmBody')}</p>
            <div className="row end">
              <button className="btn" onClick={() => setConfirmEnd(false)} disabled={ending}>
                {t('cancel')}
              </button>
              <button className="btn danger" onClick={() => void endLive()} disabled={ending} data-testid="confirm-end">
                {ending ? t('ending') : t('endConfirm')}
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
