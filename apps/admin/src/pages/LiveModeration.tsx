import { useEffect, useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, FormDialog, reasonField, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { Key } from '../i18n';
import { navigate } from '../router';
import type { PersonRef } from '../types';
import { DataTable } from '../ui/DataTable';
import { Icon } from '../ui/icons';

/**
 * v1.60-live (D250, CONVENTIONS §10.91.4): the actions on a live from «البث الآن» and the watch view — «إغلاق البث»,
 * «حظر مؤقت» («منع من البث» or «تعليق الحساب» for 1 h … 30 d or a custom end), «حظر جهاز» (with the authenticator code
 * again; for a while or for good) and «لا مخالفة». Every one needs a reason, which the host is told (except a dismissal).
 * D273b (§10.96.10): «تحذير المضيف» — the same WARN as the staff tools in the app (`lives.moderate`, a written message
 * required, audited); the live goes on and the host sees «تنبيه من فريق Kabso», never a staff name.
 */

export type ModAction = 'END' | 'WARN' | 'BAN' | 'DEVICE_BAN' | 'DISMISS';
/** What a row of a live's moderation history may be (`GET /admin/lives/{roomId}/moderations`). */
export type ModKind = 'END' | 'WARN' | 'NO_LIVE' | 'SUSPEND' | 'DEVICE_BAN';
export type BanScope = 'NO_LIVE' | 'SUSPEND';
export type Duration = '1h' | '24h' | '3d' | '7d' | '30d' | 'custom' | 'permanent';

export const DURATION_HOURS: Record<Exclude<Duration, 'custom' | 'permanent'>, number> = {
  '1h': 1,
  '24h': 24,
  '3d': 72,
  '7d': 168,
  '30d': 720,
};
const DURATION_KEY: Record<Duration, Key> = {
  '1h': 'modDuration1h',
  '24h': 'modDuration24h',
  '3d': 'modDuration3d',
  '7d': 'modDuration7d',
  '30d': 'modDuration30d',
  custom: 'modDurationCustom',
  permanent: 'modDurationPermanent',
};
export const BAN_DURATIONS: Duration[] = ['1h', '24h', '3d', '7d', '30d', 'custom'];
export const DEVICE_DURATIONS: Duration[] = ['24h', '7d', '30d', 'permanent', 'custom'];

export interface ModForm {
  action: ModAction;
  scope: BanScope;
  duration: Duration;
  /** `datetime-local` value for «مخصّص». */
  until: string;
  reason: string;
  totpCode: string;
}

/** What the form sends, or null while something required is missing (the confirm button stays off). */
export function moderateRequest(roomId: string, f: ModForm): { path: string; body: Record<string, unknown> } | null {
  const reason = f.reason.trim();
  if (!reason) return null;
  if (f.action === 'DISMISS') return { path: `/admin/lives/${roomId}/reports/dismiss`, body: { reason } };
  if (f.action === 'END' || f.action === 'WARN')
    return { path: `/admin/lives/${roomId}/moderate`, body: { action: f.action, reason } };
  let timing: Record<string, unknown>;
  if (f.duration === 'permanent') {
    if (f.action !== 'DEVICE_BAN') return null;
    timing = { permanent: true };
  } else if (f.duration === 'custom') {
    const at = new Date(f.until);
    if (!f.until || Number.isNaN(at.getTime()) || at.getTime() <= Date.now()) return null;
    timing = { until: at.toISOString() };
  } else {
    timing = { hours: DURATION_HOURS[f.duration] };
  }
  if (f.action === 'DEVICE_BAN') {
    if (!/^[0-9]{6}$/.test(f.totpCode)) return null;
    return {
      path: `/admin/lives/${roomId}/moderate`,
      body: { action: 'DEVICE_BAN', reason, ...timing, totpCode: f.totpCode },
    };
  }
  return { path: `/admin/lives/${roomId}/moderate`, body: { action: f.scope, reason, ...timing } };
}

const TITLE: Record<ModAction, Key> = {
  END: 'modEnd',
  WARN: 'modWarn',
  BAN: 'modBan',
  DEVICE_BAN: 'modDeviceBan',
  DISMISS: 'modDismissTitle',
};
const INTRO: Record<ModAction, Key> = {
  END: 'modEndIntro',
  WARN: 'modWarnIntro',
  BAN: 'modBanIntro',
  DEVICE_BAN: 'modDeviceBanIntro',
  DISMISS: 'modDismissIntro',
};

/** One action's dialog: the reason (required), the scope and duration of a ban, the code of a device ban. */
export function ModerateDialog({
  roomId,
  host,
  action,
  onClose,
  onDone,
  initial,
}: {
  roomId: string;
  host: string;
  action: ModAction;
  onClose: () => void;
  onDone: () => void;
  /** Tests and captures: a filled form. */
  initial?: Partial<ModForm>;
}) {
  const { t, toast } = useApp();
  const [f, setF] = useState<ModForm>({
    action,
    scope: 'NO_LIVE',
    duration: action === 'DEVICE_BAN' ? '7d' : '24h',
    until: '',
    reason: '',
    totpCode: '',
    ...initial,
  });
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const req = moderateRequest(roomId, f);
  const set = (patch: Partial<ModForm>) => setF((v) => ({ ...v, ...patch }));
  const durations = action === 'DEVICE_BAN' ? DEVICE_DURATIONS : BAN_DURATIONS;
  const go = async () => {
    if (!req) return;
    setBusy(true);
    setError(null);
    try {
      await api.post(req.path, req.body);
      toast(t('modDone', { what: t(TITLE[action]) }));
      onDone();
    } catch (e) {
      setError(e);
      setBusy(false);
    }
  };
  return (
    <Dialog title={`${t(TITLE[action])} — \u2066${host}\u2069`} onClose={onClose}>
      <p className="muted small">{t(INTRO[action])}</p>
      {action === 'DEVICE_BAN' && (
        <p className="alert warn small" data-honest-limits>
          {t('modDeviceBanLimits')}
        </p>
      )}
      <ErrorAlert error={error} />
      <form
        className="mod-form"
        data-mod-action={action}
        onSubmit={(e) => {
          e.preventDefault();
          if (req && !busy) void go();
        }}
      >
        {action === 'BAN' && (
          <fieldset className="field">
            <legend>{t('modScope')}</legend>
            {(['NO_LIVE', 'SUSPEND'] as const).map((s) => (
              <label key={s} className={`choice${f.scope === s ? ' on' : ''}`}>
                <input type="radio" name="scope" value={s} checked={f.scope === s} onChange={() => set({ scope: s })} />
                <span>
                  <b>{t(`modScope${s}`)}</b>
                  <span className="hint">{t(`modScope${s}Hint`)}</span>
                </span>
              </label>
            ))}
          </fieldset>
        )}
        {(action === 'BAN' || action === 'DEVICE_BAN') && (
          <fieldset className="field">
            <legend>{t('modDuration')}</legend>
            <div className="chips" role="group" aria-label={t('modDuration')}>
              {durations.map((d) => (
                <button
                  type="button"
                  key={d}
                  className="chip"
                  aria-pressed={f.duration === d}
                  data-duration={d}
                  onClick={() => set({ duration: d })}
                >
                  {t(DURATION_KEY[d])}
                </button>
              ))}
            </div>
            {f.duration === 'custom' && (
              <label className="inline-field">
                <span>{t('modUntil')}</span>
                <input type="datetime-local" value={f.until} onChange={(e) => set({ until: e.target.value })} />
              </label>
            )}
          </fieldset>
        )}
        <div className="field">
          <label htmlFor="mod-reason">
            {action === 'DISMISS' ? t('modNote') : action === 'WARN' ? t('modWarnMessage') : t('modReasonHost')}
          </label>
          <textarea
            id="mod-reason"
            required
            maxLength={500}
            value={f.reason}
            onChange={(e) => set({ reason: e.target.value })}
          />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        {action === 'DEVICE_BAN' && (
          <div className="field">
            <label htmlFor="mod-code">{t('totpCode')}</label>
            <input
              id="mod-code"
              className="code-input"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              value={f.totpCode}
              onChange={(e) => set({ totpCode: e.target.value.replace(/[^0-9]/g, '') })}
            />
            <span className="hint">{t('totpHint')}</span>
          </div>
        )}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button type="submit" className={`btn ${action === 'DISMISS' || action === 'WARN' ? 'primary' : 'danger'}`} disabled={!req || busy}>
            {t(action === 'DISMISS' ? 'modDismiss' : TITLE[action])}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** The actions a staff member may take on a live (by capability; never on a live that ended, except dismissing). */
export function liveActions(can: (c: never) => boolean, onAir: boolean, openReports: number): ModAction[] {
  const may = can as (c: string) => boolean;
  const out: ModAction[] = [];
  if (may('lives.moderate') && onAir) out.push('END', 'WARN', 'BAN');
  if (may('lives.moderate') && may('devices.ban') && onAir) out.push('DEVICE_BAN');
  if (may('lives.moderate') && openReports > 0) out.push('DISMISS');
  return out;
}

export const ACTION_ICON = { END: 'stop', WARN: 'alert', BAN: 'clock', DEVICE_BAN: 'ban', DISMISS: 'check' } as const;
/** The actions that change the host's standing (drawn red); a warning and a dismissal are not. */
export const isDangerAction = (a: ModAction) => a !== 'DISMISS' && a !== 'WARN';
export const ACTION_LABEL: Record<ModAction, Key> = {
  END: 'modEnd',
  WARN: 'modWarn',
  BAN: 'modBan',
  DEVICE_BAN: 'modDeviceBan',
  DISMISS: 'modDismiss',
};

/** D273b: a history row's label («تحذير للمضيف» / "Host warned" …), never the raw kind; an unknown kind shows as is. */
const KIND_LABEL: Record<ModKind, Key> = {
  END: 'modKindEND',
  WARN: 'modKindWARN',
  NO_LIVE: 'modKindNO_LIVE',
  SUSPEND: 'modKindSUSPEND',
  DEVICE_BAN: 'modKindDEVICE_BAN',
};
export function moderationKindLabel(t: (k: Key) => string, kind: string): string {
  const key = (KIND_LABEL as Record<string, Key | undefined>)[kind];
  return key ? t(key) : kind;
}

export interface LiveReportsSummary {
  rooms: number;
  reports: number;
}

/** The red dots: the reported lives on air (every 15 s while the panel is open; null without `lives.reports`). */
export function useLiveReportsSummary(enabled: boolean, everyMs = 15_000): LiveReportsSummary | null {
  const [data, setData] = useState<LiveReportsSummary | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    const load = () =>
      api.get<LiveReportsSummary>('/admin/live-reports/summary').then(
        (d) => live && setData(d),
        () => undefined,
      );
    void load();
    const h = window.setInterval(load, everyMs);
    return () => {
      live = false;
      window.clearInterval(h);
    };
  }, [enabled, everyMs]);
  return enabled ? data : null;
}

interface DeviceBanRow {
  id: string;
  status: 'ACTIVE' | 'LIFTED' | 'EXPIRED';
  reason: string;
  createdAt: string;
  endsAt: string | null;
  liftedAt: string | null;
  liftReason: string | null;
  account: PersonRef | null;
  createdBy: PersonRef | null;
  liftedBy: PersonRef | null;
  liveRoomId: string | null;
}

const BAN_BADGE = { ACTIVE: 'bad', LIFTED: '', EXPIRED: 'warn' } as const;

/** «الأجهزة المحظورة» (`devices.ban`): the device bans, named by their account; lift with a reason. */
export function DeviceBans() {
  const { t, lang, toast } = useApp();
  const [lift, setLift] = useState<DeviceBanRow | null>(null);
  const [bump, setBump] = useState(0);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('deviceBansTitle')}</h1>
          <p className="muted small">{t('deviceBansSubtitle')}</p>
        </div>
      </div>
      <p className="alert warn small">{t('modDeviceBanLimits')}</p>
      <DataTable<DeviceBanRow>
        id="device-bans"
        endpoint="/admin/device-bans"
        rowKey={(r) => r.id}
        reloadKey={bump}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        filters={[
          {
            name: 'status',
            label: 'colStatus',
            options: (['ACTIVE', 'LIFTED', 'EXPIRED'] as const).map((s) => ({ value: s, label: `deviceBanStatus${s}` })),
          },
        ]}
        columns={[
          {
            key: 'account',
            label: 'deviceBanAccount',
            render: (r) =>
              r.account ? (
                <UserCell username={r.account.username} displayName={r.account.displayName} avatarUrl={r.account.avatarUrl} />
              ) : (
                '—'
              ),
          },
          {
            key: 'status',
            label: 'colStatus',
            render: (r) => <span className={`badge ${BAN_BADGE[r.status]}`}>{t(`deviceBanStatus${r.status}`)}</span>,
          },
          { key: 'reason', label: 'reason', render: (r) => <span className="clamp-2">{r.reason}</span> },
          { key: 'created', label: 'colCreated', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
          {
            key: 'ends',
            label: 'deviceBanEnds',
            render: (r) => (r.endsAt ? <span className="date small">{formatDate(r.endsAt, lang)}</span> : <b>{t('deviceBanPermanent')}</b>),
          },
          { key: 'by', label: 'deviceBanBy', optional: true, render: (r) => (r.createdBy ? <span className="ltr">@{r.createdBy.username}</span> : '—') },
          {
            key: 'live',
            label: 'deviceBanLive',
            optional: true,
            render: (r) =>
              r.liveRoomId ? (
                <a
                  href={`/lives/${r.liveRoomId}`}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate(`/lives/${r.liveRoomId}`);
                  }}
                >
                  <Icon name="live" size={16} />
                </a>
              ) : (
                '—'
              ),
          },
          {
            key: 'act',
            label: 'colActions',
            render: (r) =>
              r.status === 'ACTIVE' ? (
                <button className="btn small" onClick={() => setLift(r)}>
                  {t('deviceBanLift')}
                </button>
              ) : r.liftReason ? (
                <span className="muted small clamp-2">{r.liftReason}</span>
              ) : null,
          },
        ]}
      />
      {lift && (
        <FormDialog
          title={`${t('deviceBanLift')} — \u2066@${lift.account?.username ?? ''}\u2069`}
          intro={<p className="muted small">{t('deviceBanLiftIntro')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('deviceBanLift')}
          submit={(v) => api.post(`/admin/device-bans/${lift.id}/lift`, { reason: v.reason })}
          onClose={() => setLift(null)}
          onDone={() => {
            setLift(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
