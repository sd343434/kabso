import { useEffect, useRef, useState, type ReactNode } from 'react';
import { api } from '../api';
import { Avatar, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { PersonRef } from '../types';
import { DataTable, type TablePage } from '../ui/DataTable';
import { Icon } from '../ui/icons';
import { previewPool, startPreview, useOnScreenSlot, usePreviewSlot, type PreviewPool } from '../live-media';
import { ACTION_ICON, ACTION_LABEL, liveActions, ModerateDialog, useLiveReportsSummary, type ModAction } from './LiveModeration';
import './live-moderation.css';

/** D241: the other side of the live's open PK (the opponent is null for a legacy mode PK room). */
export interface LivePk {
  opponentRoomId: string | null;
  opponentUsername: string | null;
  opponentDisplayName: string | null;
}

export interface LiveRow {
  id: string;
  title: string;
  mode: string;
  viewers: number;
  startedAt: string;
  coverUrl: string | null;
  score: number;
  categoryAr: string | null;
  categoryEn: string | null;
  host: PersonRef;
  /** D241: null when not in a PK. */
  pk: LivePk | null;
  /** D250: the live's open reports (the red badge; absent from an older API). */
  openReports?: number;
}

interface LiveDetailDto extends Omit<LiveRow, 'score' | 'openReports'> {
  topic: string | null;
  status: string;
  endReason: string | null;
  peakViewers: number;
  endedAt: string | null;
  chatEnabled: boolean;
  allowGuests: boolean;
  roomNumber: number | null;
  giftCoins: number;
  giftsSent: number;
  seatsTaken: number;
  openReports: number;
  moderators: number;
}

interface HostRow {
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: string;
  source: string;
  grantedAt: string;
  grantedBy: string | null;
  roomNumber: number;
  liveRoomId: string | null;
}

/** Minutes on air, as «1:05». */
export function onAir(startedAt: string, now = Date.now()): string {
  const m = Math.max(0, Math.floor((now - Date.parse(startedAt)) / 60_000));
  return `${Math.floor(m / 60)}:${String(m % 60).padStart(2, '0')}`;
}

function LiveDialog({ id, onClose, onEnded }: { id: string; onClose: () => void; onEnded: () => void }) {
  const { t, lang, can, toast } = useApp();
  const { data, error } = useAsync(() => api.get<LiveDetailDto>(`/admin/lives/${id}`), [id]);
  const [ending, setEnding] = useState(false);
  const n = (v: number) => formatNumber(v, lang);
  if (ending)
    return (
      <FormDialog
        title={t('liveEnd')}
        intro={<p className="muted small">{t('liveEndIntro')}</p>}
        fields={[reasonField(t)]}
        confirmLabel={t('liveEnd')}
        danger
        submit={(v) => api.post(`/admin/lives/${id}/end`, { reason: v.reason })}
        onClose={() => setEnding(false)}
        onDone={() => {
          toast(t('liveEnded'));
          onEnded();
        }}
      />
    );
  return (
    <Dialog title={data?.title ?? t('loading')} onClose={onClose}>
      <ErrorAlert error={error} />
      {data && (
        <>
          <div className="live-hero">
            {data.coverUrl ? <img src={data.coverUrl} alt="" /> : <span className="cover-fallback">{(data.host.displayName || '?')[0]}</span>}
            <span className="live-badge">{data.status === 'LIVE' ? t('liveNow') : t('liveOver')}</span>
          </div>
          <dl className="kv">
            <dt>{t('colHost')}</dt>
            <dd>
              <a href={`/users/${data.host.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${data.host.id}`))}>
                @{data.host.username}
              </a>
            </dd>
            <dt>{t('colViewers')}</dt>
            <dd className="num">
              {n(data.viewers)} <span className="muted small">({t('livePeak', { n: n(data.peakViewers) })})</span>
            </dd>
            <dt>{t('liveOnAir')}</dt>
            <dd className="num">{onAir(data.startedAt)}</dd>
            <dt>{t('colMode')}</dt>
            <dd>{data.pk ? t('livePkBadge') : data.mode}</dd>
            {data.pk && (
              <>
                <dt>{t('livePkOpponent')}</dt>
                <dd>{data.pk.opponentUsername ? <span className="ltr">@{data.pk.opponentUsername}</span> : t('livePkLegacy')}</dd>
              </>
            )}
            <dt>{t('liveGiftCoins')}</dt>
            <dd className="num">
              {n(data.giftCoins)} <span className="muted small">({n(data.giftsSent)})</span>
            </dd>
            <dt>{t('liveSeats')}</dt>
            <dd className="num">{n(data.seatsTaken)}</dd>
            <dt>{t('openReports')}</dt>
            <dd className="num">{n(data.openReports)}</dd>
            <dt>{t('liveRoomNumber')}</dt>
            <dd className="mono">{data.roomNumber ?? '—'}</dd>
          </dl>
          <div className="actions">
            <button className="btn" onClick={onClose}>
              {t('close')}
            </button>
            {can('lives.manage') && data.status === 'LIVE' && (
              <button className="btn danger" onClick={() => setEnding(true)}>
                <Icon name="stop" size={16} />
                {t('liveEnd')}
              </button>
            )}
          </div>
        </>
      )}
    </Dialog>
  );
}

/**
 * D250: the card's picture — a muted live preview while the card holds a slot of the page's pool (on screen, at most
 * {@link PreviewPool.max} at once), else the cover with a play button that takes a slot.
 */
function CardThumb({ live: l, pool, enabled }: { live: LiveRow; pool: PreviewPool; enabled: boolean }) {
  const { t } = useApp();
  const box = useRef<HTMLSpanElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const [el, setEl] = useState<HTMLSpanElement | null>(null);
  const playing = usePreviewSlot(pool, l.id) && enabled;
  const [state, setState] = useState<'loading' | 'video' | 'audio-only' | 'failed'>('loading');
  useEffect(() => setEl(box.current), []);
  useOnScreenSlot(pool, l.id, el, enabled);
  useEffect(() => {
    if (!playing || !video.current) return;
    setState('loading');
    let stop: (() => void) | null = null;
    let gone = false;
    void startPreview(l.id, video.current, (s) => !gone && setState(s)).then((f) => {
      if (gone) f();
      else stop = f;
    });
    return () => {
      gone = true;
      stop?.();
    };
  }, [playing, l.id]);
  const cover = l.coverUrl ? <img src={l.coverUrl} alt="" loading="lazy" /> : <span className="cover-fallback">{(l.host.displayName || '?')[0]}</span>;
  return (
    <span className="thumb" ref={box} data-preview={playing ? state : 'off'}>
      {cover}
      {playing && <video ref={video} className={`live-preview-video${state === 'video' ? ' on' : ''}`} muted playsInline autoPlay aria-hidden="true" />}
      {playing && state === 'loading' && <span className="preview-note">{t('livePreviewLoading')}</span>}
      {playing && state === 'audio-only' && (
        <span className="preview-note">
          <Icon name="mic" size={14} /> {t('livePreviewAudio')}
        </span>
      )}
      {playing && state === 'failed' && <span className="preview-note">{t('livePreviewFailed')}</span>}
      {enabled && !playing && (
        <span
          role="button"
          tabIndex={0}
          className="play-btn"
          aria-label={t('livePreviewPlay')}
          title={t('livePreviewPlay')}
          onClick={(e) => {
            e.stopPropagation();
            pool.request(l.id, true);
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              e.stopPropagation();
              pool.request(l.id, true);
            }
          }}
        >
          <Icon name="play" size={22} />
        </span>
      )}
    </span>
  );
}

/**
 * One card of «البث الآن». D241: a live in a PK (an open D195 match: the rooms stay SOLO) shows a «PK» badge and
 * «ضد @handle». D250: a muted live preview (when the session may watch), a red badge with the live's open reports, and
 * a ⋯ menu with «مشاهدة» and the actions.
 */
export function LiveCard({
  live: l,
  onOpen,
  pool = previewPool,
  onAction,
}: {
  live: LiveRow;
  onOpen: () => void;
  pool?: PreviewPool;
  onAction?: (a: ModAction) => void;
}) {
  const { t, lang, can } = useApp();
  const [menu, setMenu] = useState(false);
  const actions = onAction ? liveActions(can as never, true, l.openReports ?? 0) : [];
  return (
    <article className="live-card" data-live-pk={l.pk ? 'true' : undefined} data-reported={(l.openReports ?? 0) > 0 ? 'true' : undefined}>
      <button type="button" className="card-open" onClick={onOpen}>
        <span className="thumb-wrap">
          <CardThumb live={l} pool={pool} enabled={can('lives.watch')} />
          <span className="live-badge">{t('liveNow')}</span>
          <LiveModeTag mode={l.mode} />
          {l.pk && <span className="live-badge pk-badge">{t('livePkBadge')}</span>}
          {(l.openReports ?? 0) > 0 && (
            <span className="report-badge" data-open-reports={l.openReports}>
              <span className="red-dot" aria-hidden="true" />
              {t('liveReportsBadge', { n: formatNumber(l.openReports ?? 0, lang) })}
            </span>
          )}
          <span className="viewers">
            <Icon name="eye" size={14} /> {formatNumber(l.viewers, lang)}
          </span>
        </span>
        <span className="live-info">
          <span className="live-title">{l.title}</span>
          {l.pk?.opponentUsername && (
            <span className="small pk-vs" dir="auto">
              {t('livePkVs', { handle: l.pk.opponentUsername })}
            </span>
          )}
          <span className="row small muted">
            <Avatar url={l.host.avatarUrl ?? null} name={l.host.displayName || l.host.username} />
            <span className="ltr">@{l.host.username}</span>
            <span className="spacer" />
            <span className="num">{onAir(l.startedAt)}</span>
          </span>
        </span>
      </button>
      {(actions.length > 0 || can('lives.watch')) && onAction && (
        <div className="card-menu">
          <button type="button" className="icon-btn" aria-label={t('liveCardMenu')} aria-expanded={menu} onClick={() => setMenu((m) => !m)}>
            <Icon name="more" />
          </button>
          {menu && (
            <div className="menu" role="menu">
              {can('lives.watch') && (
                <button role="menuitem" className="menu-row" onClick={onOpen}>
                  <Icon name="eye" size={16} /> {t('liveWatch')}
                </button>
              )}
              {actions.map((a) => (
                <button
                  key={a}
                  role="menuitem"
                  className={`menu-row${a === 'DISMISS' ? '' : ' danger'}`}
                  data-action={a}
                  onClick={() => {
                    setMenu(false);
                    onAction(a);
                  }}
                >
                  <Icon name={ACTION_ICON[a]} size={16} /> {t(ACTION_LABEL[a])}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </article>
  );
}

/** D212: the mode filter's chips, in the app's category order; D213 adds the streamer. */
export const LIVE_MODES = ['', 'SOLO', 'AUDIO', 'PODCAST', 'MULTI', 'STREAMER', 'PK'] as const;
export type LiveModeChip = (typeof LIVE_MODES)[number];

/** D212 / D213: the mode chips ('' = all); D250 appends the «لايفات مبلّغ عنها» chip as `children`. */
export function LiveModeTabs({
  mode,
  onMode,
  children,
}: {
  mode: LiveModeChip | 'REPORTED';
  onMode: (m: LiveModeChip) => void;
  children?: ReactNode;
}) {
  const { t } = useApp();
  return (
    <div className="tabs" role="group" aria-label={t('liveModeFilter')}>
      {LIVE_MODES.map((m) => (
        <button key={m || 'all'} className="tab" aria-pressed={mode === m} onClick={() => onMode(m)}>
          {t(m ? (`liveMode${m}` as never) : 'statusAll')}
        </button>
      ))}
      {children}
    </div>
  );
}

/** D213: a streamer's card says so («ستريمر») next to the live badge. */
export function LiveModeTag({ mode }: { mode: string }) {
  const { t } = useApp();
  if (mode !== 'STREAMER') return null;
  return <span className="live-mode-tag">{t('liveModeSTREAMER')}</span>;
}

/** D250: the «لايفات مبلّغ عنها» chip — a red dot and the count while reported lives are on air. */
export function ReportedTab({ rooms, pressed, onClick }: { rooms: number; pressed: boolean; onClick: () => void }) {
  const { t, lang } = useApp();
  return (
    <button className="tab reported-tab" aria-pressed={pressed} data-reported-rooms={rooms} onClick={onClick}>
      {rooms > 0 && <span className="red-dot" aria-hidden="true" />}
      {t('liveReported')}
      {rooms > 0 && <span className="count-pill">{formatNumber(rooms, lang)}</span>}
    </button>
  );
}

/**
 * «البث الآن» (D197): every live on air as a card grid (most viewers first); details and END LIVE with a reason. D250: the
 * cards play muted live previews; the «لايفات مبلّغ عنها» chip (a red dot and the count) lists the reported lives; the list
 * refreshes every 15 s; a card opens the watch view and its ⋯ menu holds the actions.
 */
export function Lives({ pool = previewPool }: { pool?: PreviewPool } = {}) {
  const { t, lang, can } = useApp();
  const [page, setPage] = useState(1);
  const [bump, setBump] = useState(0);
  const [open, setOpen] = useState<string | null>(null);
  const [act, setAct] = useState<{ live: LiveRow; action: ModAction } | null>(null);
  // D212: the app's live categories as a mode filter ('' = all). D241: «PK» = the lives in an open PK; «بث مباشر» =
  // SOLO lives not in one (the chips partition the lives). D213 adds «ستريمر». D250: `reported` = «لايفات مبلّغ عنها».
  const [mode, setMode] = useState<LiveModeChip | 'REPORTED'>('');
  const summary = useLiveReportsSummary(can('lives.reports'));
  const { data, error, loading } = useAsync(
    () =>
      api.get<TablePage<LiveRow>>('/admin/lives', {
        page,
        pageSize: 24,
        sort: 'viewers',
        order: 'desc',
        ...(mode === 'REPORTED' ? { reported: 'true' } : mode ? { mode } : {}),
      }),
    [page, bump, mode],
  );
  useEffect(() => {
    const h = window.setInterval(() => setBump((b) => b + 1), 15_000);
    return () => window.clearInterval(h);
  }, []);
  useEffect(() => () => pool.clear(), [pool]);
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const openLive = (id: string) => (can('lives.watch') ? navigate(`/lives/${id}`) : setOpen(id));
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('livesTitle')}</h1>
          <p className="muted small">{data ? t('livesCount', { n: formatNumber(data.total, lang) }) : t('livesSubtitle')}</p>
        </div>
        <button className="btn" onClick={() => setBump((b) => b + 1)}>
          <Icon name="refresh" size={16} />
          {t('refresh')}
        </button>
      </div>
      <LiveModeTabs
        mode={mode}
        onMode={(m) => {
          setMode(m);
          setPage(1);
        }}
      >
        {can('lives.reports') && (
          <ReportedTab
            rooms={summary?.rooms ?? 0}
            pressed={mode === 'REPORTED'}
            onClick={() => {
              setMode('REPORTED');
              setPage(1);
            }}
          />
        )}
      </LiveModeTabs>
      {mode === 'REPORTED' && summary && summary.reports > 0 && (
        <p className="muted small">{t('liveReportedCount', { n: formatNumber(summary.reports, lang) })}</p>
      )}
      <ErrorAlert error={error} />
      {loading && !data && (
        <div className="live-grid">
          {Array.from({ length: 8 }, (_, i) => (
            <div key={i} className="live-card skeleton-card" />
          ))}
        </div>
      )}
      {data && data.data.length === 0 && (
        <div className="card state empty-state">
          <Icon name={mode === 'REPORTED' ? 'flag' : 'live'} size={32} />
          <p>{mode === 'REPORTED' ? t('liveReportedNone') : t('livesNone')}</p>
        </div>
      )}
      <div className="live-grid">
        {data?.data.map((l) => (
          <LiveCard key={l.id} live={l} pool={pool} onOpen={() => openLive(l.id)} onAction={(action) => setAct({ live: l, action })} />
        ))}
      </div>
      {pages > 1 && (
        <div className="pager">
          <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            {t('previous')}
          </button>
          <button className="btn small" disabled={page >= pages} onClick={() => setPage(page + 1)}>
            {t('next')}
          </button>
        </div>
      )}
      {open && (
        <LiveDialog
          id={open}
          onClose={() => setOpen(null)}
          onEnded={() => {
            setOpen(null);
            setBump((b) => b + 1);
          }}
        />
      )}
      {act && (
        <ModerateDialog
          roomId={act.live.id}
          host={`@${act.live.host.username}`}
          action={act.action}
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}

/** The hosting permissions «صلاحيات البث»: who may go live (admin, agency, identity), give / take back. */
export function Hosts() {
  const { t, lang, can, toast } = useApp();
  const [dialog, setDialog] = useState<'grant' | { revoke: string } | null>(null);
  const [bump, setBump] = useState(0);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('hostsTitle')}</h1>
          <p className="muted small">{t('hostsSubtitle')}</p>
        </div>
        {can('lives.manage') && (
          <button className="btn primary" onClick={() => setDialog('grant')}>
            <Icon name="plus" size={16} />
            {t('hostGrant')}
          </button>
        )}
      </div>
      <DataTable<HostRow>
        id="hosts"
        endpoint="/admin/live-hosts"
        rowKey={(r) => r.userId}
        reloadKey={bump}
        defaultSort={{ sort: 'grantedAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        filters={[{ name: 'source', label: 'colSource', options: ['ADMIN', 'AGENCY', 'IDENTITY'].map((s) => ({ value: s, label: `source${s}` })) }]}
        columns={[
          { key: 'user', label: 'colHost', render: (r) => <UserCell username={r.username} displayName={r.displayName} avatarUrl={r.avatarUrl} /> },
          { key: 'status', label: 'colStatus', render: (r) => <StatusBadge status={r.status} /> },
          { key: 'source', label: 'colSource', render: (r) => t(`source${r.source}` as never) },
          { key: 'room', label: 'liveRoomNumber', render: (r) => <span className="mono">{r.roomNumber}</span> },
          { key: 'live', label: 'liveNow', render: (r) => (r.liveRoomId ? <span className="badge bad">{t('liveNow')}</span> : '—') },
          { key: 'granted', label: 'colGranted', sort: 'grantedAt', render: (r) => <span className="date small">{formatDate(r.grantedAt, lang)}</span> },
          { key: 'by', label: 'colGrantedBy', optional: true, render: (r) => (r.grantedBy ? `@${r.grantedBy}` : '—') },
          {
            key: 'act',
            label: 'colActions',
            render: (r) =>
              can('lives.manage') ? (
                <button className="btn small" onClick={() => setDialog({ revoke: r.username })}>
                  {t('hostRevoke')}
                </button>
              ) : null,
          },
        ]}
      />
      {dialog === 'grant' && (
        <FormDialog
          title={t('hostGrant')}
          fields={[{ name: 'username', label: t('colUsername'), maxLength: 31 }, reasonField(t)]}
          confirmLabel={t('hostGrant')}
          submit={(v) => api.post('/admin/live-hosts/grant', { username: (v.username ?? '').replace(/^@/, ''), reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
      {dialog && dialog !== 'grant' && (
        <FormDialog
          title={t('hostRevoke')}
          intro={<p className="muted small">{t('hostRevokeIntro', { name: `@${dialog.revoke}` })}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('hostRevoke')}
          danger
          submit={(v) => api.post('/admin/live-hosts/revoke', { username: dialog.revoke, reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
