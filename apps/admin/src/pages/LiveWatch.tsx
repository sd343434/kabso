import { useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { Avatar, ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Key } from '../i18n';
import { useWatch, type WatchTrack } from '../live-media';
import { navigate } from '../router';
import type { PersonRef } from '../types';
import { Icon } from '../ui/icons';
import { onAir, type LiveRow } from './Lives';
import { ACTION_ICON, ACTION_LABEL, liveActions, ModerateDialog, type ModAction } from './LiveModeration';

/** `AdminLiveDetail` (D197 + D241 + D250). */
export interface LiveDetail extends Omit<LiveRow, 'score' | 'openReports'> {
  topic: string | null;
  status: string;
  endReason: string | null;
  peakViewers: number;
  endedAt: string | null;
  openReports: number;
  roomNumber: number | null;
}

export interface ChatLine {
  id: string;
  kind: string;
  text: string;
  createdAt: string;
  deleted: boolean;
  authorRole: string;
  author: PersonRef | null;
}

export interface LiveReport {
  id: string;
  targetType: 'LIVE_ROOM' | 'USER';
  reason: string;
  note: string | null;
  status: 'OPEN' | 'ACTIONED' | 'DISMISSED';
  createdAt: string;
  resolvedAt: string | null;
  resolutionNote: string | null;
  reporter: PersonRef | null;
  chatBefore: ChatLine[];
}

export interface LiveModerationRow {
  id: string;
  kind: ModAction | 'NO_LIVE' | 'SUSPEND';
  reason: string;
  endsAt: string | null;
  createdAt: string;
  actor: PersonRef | null;
}

/** A track drawn into a <video> (muted: the sound plays through the audio elements). */
function VideoTile({ t: track, label }: { t: WatchTrack; label: string }) {
  const ref = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.muted = true;
    track.track.attach(el);
    return () => {
      track.track.detach(el);
    };
  }, [track]);
  return (
    <figure className={`watch-tile${track.source === 'screen_share' ? ' screen' : ''}`} data-source={track.source}>
      <video ref={ref} autoPlay playsInline muted />
      <figcaption dir="auto">{label}</figcaption>
    </figure>
  );
}

/** Plays one audio track (hidden), unless the staff member muted the view. */
function AudioSink({ t: track, muted }: { t: WatchTrack; muted: boolean }) {
  const ref = useRef<HTMLAudioElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    track.track.attach(el);
    return () => {
      track.track.detach(el);
    };
  }, [track]);
  useEffect(() => {
    if (ref.current) ref.current.muted = muted;
  }, [muted]);
  return <audio ref={ref} autoPlay />;
}

/** Host first, then the rest; camera before screen share for the same person. */
export function orderTiles(tracks: readonly WatchTrack[], hostId: string): WatchTrack[] {
  const rank = (x: WatchTrack) => (x.participant === hostId ? 0 : 1) * 10 + (x.source === 'screen_share' ? 0 : 1);
  return tracks.filter((x) => x.kind === 'video').sort((a, b) => rank(a) - rank(b) || a.key.localeCompare(b.key));
}

function ChatFeed({ roomId, onAirNow, initial }: { roomId: string; onAirNow: boolean; initial?: ChatLine[] }) {
  const { t, lang } = useApp();
  const [lines, setLines] = useState<ChatLine[]>(initial ?? []);
  const [error, setError] = useState<unknown>(null);
  const box = useRef<HTMLOListElement>(null);
  useEffect(() => {
    if (initial) return;
    let live = true;
    let after: string | undefined;
    const load = () =>
      api.get<{ data: ChatLine[] }>(`/admin/lives/${roomId}/chat`, after ? { after } : {}).then(
        (r) => {
          if (!live) return;
          setError(null);
          if (r.data.length > 0) {
            after = r.data[r.data.length - 1]!.createdAt;
            setLines((old) => [...old, ...r.data.filter((l) => !old.some((o) => o.id === l.id))].slice(-200));
          }
        },
        (e: unknown) => live && setError(e),
      );
    void load();
    const h = onAirNow ? window.setInterval(load, 4000) : undefined;
    return () => {
      live = false;
      if (h) window.clearInterval(h);
    };
  }, [roomId, onAirNow, initial]);
  useEffect(() => {
    const el = box.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [lines]);
  return (
    <section className="card watch-chat" aria-label={t('liveChat')}>
      <h3>{t('liveChat')}</h3>
      <ErrorAlert error={error} />
      {lines.length === 0 && <p className="muted small">{t('liveChatEmpty')}</p>}
      <ol ref={box} className="chat-lines">
        {lines.map((l) => (
          <li key={l.id} className={l.deleted ? 'deleted' : undefined}>
            <span className="who ltr">@{l.author?.username ?? '—'}</span>{' '}
            <span dir="auto">{l.kind === 'TEXT' ? l.text : t('liveChatMedia', { kind: l.kind })}</span>
            {l.deleted && <span className="muted small"> {t('liveChatDeleted')}</span>}
            <time className="muted small">{formatDate(l.createdAt, lang)}</time>
          </li>
        ))}
      </ol>
    </section>
  );
}

const REASON_KEY: Record<string, Key> = {
  SPAM: 'reasonSPAM' as Key,
  NUDITY: 'reasonNUDITY' as Key,
  VIOLENCE: 'reasonVIOLENCE' as Key,
  HATE: 'reasonHATE' as Key,
  HARASSMENT: 'reasonHARASSMENT' as Key,
  ILLEGAL: 'reasonILLEGAL' as Key,
  OTHER: 'reasonOTHER' as Key,
};

export function ReportsPanel({ reports, open }: { reports: LiveReport[]; open: number }) {
  const { t, lang } = useApp();
  return (
    <section className="card watch-reports" aria-label={t('liveReportsTitle')}>
      <h3>
        {t('liveReportsTitle')}
        {open > 0 && (
          <span className="count-badge" data-open-reports={open}>
            <span className="red-dot" aria-hidden="true" />
            {formatNumber(open, lang)}
          </span>
        )}
      </h3>
      {reports.length === 0 && <p className="muted small">{t('liveReportsEmpty')}</p>}
      <ul className="report-list">
        {reports.map((r) => (
          <li key={r.id} data-status={r.status}>
            <div className="row small">
              <b>{REASON_KEY[r.reason] ? t(REASON_KEY[r.reason]!) : r.reason}</b>
              <span className={`badge ${r.status === 'OPEN' ? 'bad' : ''}`}>{t(`liveReportStatus${r.status}`)}</span>
              <span className="spacer" />
              <time className="muted">{formatDate(r.createdAt, lang)}</time>
            </div>
            {r.targetType === 'USER' && <p className="muted small">{t('liveReportOnHost')}</p>}
            {r.note && (
              <p className="note" dir="auto">
                «{r.note}»
              </p>
            )}
            <p className="small">
              {t('liveReportBy')}: <span className="ltr">@{r.reporter?.username ?? '—'}</span>
            </p>
            {r.chatBefore.length > 0 && (
              <details>
                <summary className="small">{t('liveReportChatBefore')}</summary>
                <ol className="chat-lines small">
                  {r.chatBefore.map((l) => (
                    <li key={l.id} className={l.deleted ? 'deleted' : undefined}>
                      <span className="who ltr">@{l.author?.username ?? '—'}</span> <span dir="auto">{l.text}</span>
                    </li>
                  ))}
                </ol>
              </details>
            )}
            {r.resolutionNote && <p className="muted small">↳ {r.resolutionNote}</p>}
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * The watch view «مشاهدة البث» (D250): the live's every published track with sound (a PK's two sides), the chat
 * read-only, the room's facts, its reports and the actions. The staff member is a hidden observer.
 */
export function LiveWatch({ id }: { id: string }) {
  const { t, lang, can } = useApp();
  const [bump, setBump] = useState(0);
  const [dialog, setDialog] = useState<ModAction | null>(null);
  const [muted, setMuted] = useState(false);
  const detail = useAsync(() => api.get<LiveDetail>(`/admin/lives/${id}`), [id, bump]);
  const reports = useAsync(
    () =>
      can('lives.reports')
        ? api.get<{ open: number; data: LiveReport[] }>(`/admin/lives/${id}/reports`)
        : Promise.resolve({ open: 0, data: [] as LiveReport[] }),
    [id, bump],
  );
  const history = useAsync(
    () =>
      can('lives.reports')
        ? api.get<{ data: LiveModerationRow[] }>(`/admin/lives/${id}/moderations`)
        : Promise.resolve({ data: [] as LiveModerationRow[] }),
    [id, bump],
  );
  useEffect(() => {
    const h = window.setInterval(() => setBump((b) => b + 1), 15_000);
    return () => window.clearInterval(h);
  }, []);
  const d = detail.data;
  const onAirNow = d?.status === 'LIVE';
  const watch = useWatch(id, can('lives.watch') && onAirNow === true);
  const n = (v: number) => formatNumber(v, lang);
  if (!d) return detail.error ? <ErrorAlert error={detail.error} /> : <Loading />;
  const tiles = orderTiles(watch.tracks, d.host.id);
  const main = tiles.filter((x) => x.room === 'main');
  const opp = tiles.filter((x) => x.room === 'opponent');
  const actions = liveActions(can as never, onAirNow, reports.data?.open ?? 0);
  return (
    <div className="watch" data-live-watch={id}>
      <div className="page-head">
        <div>
          <a
            className="back small"
            href="/lives"
            onClick={(e) => {
              e.preventDefault();
              navigate('/lives');
            }}
          >
            <Icon name="chevron" size={16} /> {t('liveWatchBack')}
          </a>
          <h1 dir="auto">{d.title}</h1>
          <p className="muted small">
            <span className="ltr">@{d.host.username}</span> · {d.pk ? t('livePkBadge') : t(`liveMode${d.mode}` as Key)}
          </p>
        </div>
        {(reports.data?.open ?? 0) > 0 && (
          <span className="count-badge big" data-open-reports={reports.data!.open}>
            <span className="red-dot" aria-hidden="true" />
            {t('liveReportsBadge', { n: n(reports.data!.open) })}
          </span>
        )}
      </div>
      <div className="watch-grid">
        <div className="watch-stage">
          <div className={`watch-video${opp.length > 0 || d.pk ? ' pk' : ''}`}>
            {!onAirNow && <div className="watch-empty">{t('liveWatchEnded')}</div>}
            {onAirNow && watch.state === 'connecting' && <div className="watch-empty">{t('liveWatchConnecting')}</div>}
            {onAirNow && watch.state === 'failed' && (
              <div className="watch-empty">
                <ErrorAlert error={watch.error} />
              </div>
            )}
            {onAirNow && watch.state === 'live' && (
              <>
                <div className="watch-side" data-side="main">
                  {main.length === 0 && <div className="watch-empty">{t('liveWatchNoVideo')}</div>}
                  {main.map((x) => (
                    <VideoTile key={x.key} t={x} label={x.participant === d.host.id ? `@${d.host.username}` : x.name} />
                  ))}
                </div>
                {d.pk && (
                  <div className="watch-side" data-side="opponent">
                    <span className="side-label">
                      {t('liveWatchOpponent')} {d.pk.opponentUsername ? `@${d.pk.opponentUsername}` : ''}
                    </span>
                    {opp.map((x) => (
                      <VideoTile
                        key={x.key}
                        t={x}
                        label={
                          d.pk?.opponentUsername && new Set(opp.map((o) => o.participant)).size === 1 ? `@${d.pk.opponentUsername}` : x.name
                        }
                      />
                    ))}
                  </div>
                )}
              </>
            )}
            {watch.tracks
              .filter((x) => x.kind === 'audio')
              .map((x) => (
                <AudioSink key={x.key} t={x} muted={muted} />
              ))}
            <span className="live-badge">{onAirNow ? t('liveNow') : t('liveOver')}</span>
            {d.pk && <span className="live-badge pk-badge">{t('livePkBadge')}</span>}
          </div>
          <div className="watch-bar">
            <span className="muted small">
              <Icon name="eye" size={14} /> {t('liveWatchHidden')}
            </span>
            <span className="spacer" />
            {watch.audioBlocked && (
              <button className="btn small primary" onClick={() => void watch.startAudio()}>
                <Icon name="volume" size={16} />
                {t('liveWatchStartAudio')}
              </button>
            )}
            <button className="btn small" onClick={() => setMuted((m) => !m)} aria-pressed={muted}>
              <Icon name={muted ? 'mute' : 'volume'} size={16} />
              {muted ? t('liveWatchUnmute') : t('liveWatchMute')}
            </button>
          </div>
          {actions.length > 0 && (
            <section className="card watch-actions" aria-label={t('liveActions')}>
              <h3>{t('liveActions')}</h3>
              <div className="row wrap">
                {actions.map((a) => (
                  <button key={a} className={`btn ${a === 'DISMISS' ? '' : 'danger'}`} data-action={a} onClick={() => setDialog(a)}>
                    <Icon name={ACTION_ICON[a]} size={16} />
                    {t(ACTION_LABEL[a])}
                  </button>
                ))}
              </div>
            </section>
          )}
        </div>
        <aside className="watch-aside">
          <section className="card" aria-label={t('liveInfo')}>
            <h3>{t('liveInfo')}</h3>
            <div className="row">
              <Avatar url={d.host.avatarUrl ?? null} name={d.host.displayName || d.host.username} />
              <a
                href={`/users/${d.host.id}`}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(`/users/${d.host.id}`);
                }}
              >
                <span dir="auto">{d.host.displayName}</span> <span className="ltr muted small">@{d.host.username}</span>
              </a>
            </div>
            <dl className="kv">
              <dt>{t('colViewers')}</dt>
              <dd className="num">
                {n(d.viewers)} <span className="muted small">({t('livePeak', { n: n(d.peakViewers) })})</span>
              </dd>
              <dt>{t('liveStartedAt')}</dt>
              <dd>
                <span className="date small">{formatDate(d.startedAt, lang)}</span> · <span className="num">{onAir(d.startedAt)}</span>
              </dd>
              <dt>{t('colMode')}</dt>
              <dd>{t(`liveMode${d.mode}` as Key)}</dd>
              {d.pk && (
                <>
                  <dt>{t('livePkOpponent')}</dt>
                  <dd>{d.pk.opponentUsername ? <span className="ltr">@{d.pk.opponentUsername}</span> : t('livePkLegacy')}</dd>
                </>
              )}
              <dt>{t('liveRoomNumber')}</dt>
              <dd className="mono">{d.roomNumber ?? '—'}</dd>
            </dl>
          </section>
          {can('lives.watch') && <ChatFeed roomId={id} onAirNow={onAirNow} />}
          {can('lives.reports') && reports.data && <ReportsPanel reports={reports.data.data} open={reports.data.open} />}
          {(history.data?.data.length ?? 0) > 0 && (
            <section className="card">
              <h3>{t('liveHistory')}</h3>
              <ul className="report-list small">
                {history.data!.data.map((h) => (
                  <li key={h.id}>
                    <b>{h.kind}</b> · <span className="ltr">@{h.actor?.username ?? '—'}</span> ·{' '}
                    <time className="muted">{formatDate(h.createdAt, lang)}</time>
                    <p dir="auto">{h.reason}</p>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </aside>
      </div>
      {dialog && (
        <ModerateDialog
          roomId={id}
          host={`@${d.host.username}`}
          action={dialog}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            setBump((b) => b + 1);
          }}
        />
      )}
    </div>
  );
}
