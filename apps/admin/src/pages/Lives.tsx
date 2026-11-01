import { useState } from 'react';
import { api } from '../api';
import { Avatar, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { PersonRef } from '../types';
import { DataTable, type TablePage } from '../ui/DataTable';
import { Icon } from '../ui/icons';

interface LiveRow {
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
}

interface LiveDetailDto extends Omit<LiveRow, 'score'> {
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
            <dd>{data.mode}</dd>
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

/** D212: the mode filter's chips, in the app's category order. */
const LIVE_MODES = ['', 'SOLO', 'AUDIO', 'PODCAST', 'MULTI', 'PK'] as const;

/** «البث الآن» (D197): every live on air as a card grid (most viewers first); details and END LIVE with a reason. */
export function Lives() {
  const { t, lang } = useApp();
  const [page, setPage] = useState(1);
  const [bump, setBump] = useState(0);
  const [open, setOpen] = useState<string | null>(null);
  // D212: the app's live categories as a mode filter ('' = all; PK lives count as SOLO's in the app).
  const [mode, setMode] = useState<(typeof LIVE_MODES)[number]>('');
  const { data, error, loading } = useAsync(
    () =>
      api.get<TablePage<LiveRow>>('/admin/lives', {
        page,
        pageSize: 24,
        sort: 'viewers',
        order: 'desc',
        ...(mode ? { mode } : {}),
      }),
    [page, bump, mode],
  );
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
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
      <div className="tabs" role="group" aria-label={t('liveModeFilter')}>
        {LIVE_MODES.map((m) => (
          <button
            key={m || 'all'}
            className="tab"
            aria-pressed={mode === m}
            onClick={() => {
              setMode(m);
              setPage(1);
            }}
          >
            {t(m ? (`liveMode${m}` as never) : 'statusAll')}
          </button>
        ))}
      </div>
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
          <Icon name="live" size={32} />
          <p>{t('livesNone')}</p>
        </div>
      )}
      <div className="live-grid">
        {data?.data.map((l) => (
          <button key={l.id} type="button" className="live-card" onClick={() => setOpen(l.id)}>
            <span className="thumb">
              {l.coverUrl ? <img src={l.coverUrl} alt="" loading="lazy" /> : <span className="cover-fallback">{(l.host.displayName || '?')[0]}</span>}
              <span className="live-badge">{t('liveNow')}</span>
              <span className="viewers">
                <Icon name="eye" size={14} /> {formatNumber(l.viewers, lang)}
              </span>
            </span>
            <span className="live-info">
              <span className="live-title">{l.title}</span>
              <span className="row small muted">
                <Avatar url={l.host.avatarUrl ?? null} name={l.host.displayName || l.host.username} />
                <span className="ltr">@{l.host.username}</span>
                <span className="spacer" />
                <span className="num">{onAir(l.startedAt)}</span>
              </span>
            </span>
          </button>
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
