import { useEffect, useState } from 'react';
import { api, ApiError } from '../api';
import { ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { Page, PanelReport, StaffSchedule } from '../types';
import { StatusTabs } from './Applications';

/**
 * v1.78-live (D288, CONVENTIONS §10.101; owner: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله»): the
 * shared queue — «غير محلولة» (OPEN, oldest first) and «تم حلها» (every closed report, newest resolution first).
 */
export const REPORT_TABS = ['OPEN', 'RESOLVED'] as const;
export type ReportTab = (typeof REPORT_TABS)[number];
type Action = 'DISMISS' | 'REMOVE_TARGET' | 'WARN' | 'BAN';

/** Tell the nav badge to read the counter again (after «تم حله», an action or a reopen). */
export const REPORTS_CHANGED = 'kabso:reports-changed';
export function reportsChanged(): void {
  if (typeof window !== 'undefined') window.dispatchEvent(new Event(REPORTS_CHANGED));
}

/** D288: the nav badge's text — hidden at 0 (null), «99+» above 99. */
export function badgeText(open: number): string | null {
  if (!Number.isFinite(open) || open <= 0) return null;
  return open > 99 ? '99+' : String(Math.floor(open));
}

/**
 * D288: the unresolved counter for the nav badge — read now, every 30 s, on each page change and whenever the queue
 * changes here (`reportsChanged`). Null without `reports.view` or before the first answer.
 */
export function useOpenReports(enabled: boolean, path: string): number | null {
  const [open, setOpen] = useState<number | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    const load = () =>
      api.get<{ open: number }>('/admin/moderation/reports/summary').then(
        (d) => live && setOpen(d.open),
        () => undefined,
      );
    void load();
    const h = window.setInterval(load, 30_000);
    window.addEventListener(REPORTS_CHANGED, load);
    return () => {
      live = false;
      window.clearInterval(h);
      window.removeEventListener(REPORTS_CHANGED, load);
    };
  }, [enabled, path]);
  return enabled ? open : null;
}

/** `POST …/resolve`'s body: the note only when one was written. */
export function resolveBody(note: string | undefined): { note?: string } {
  const n = (note ?? '').trim();
  return n ? { note: n } : {};
}

/** D288: the second «تم حله» (somebody else was first). */
export function isAlreadyResolved(e: unknown): boolean {
  return e instanceof ApiError && e.code === 'REPORT_ALREADY_RESOLVED';
}

/** One report of the shared queue, with its buttons (each only for the roles the server allows). */
export function ReportCard({
  r,
  busy,
  onQuick,
  onAct,
  onResolve,
  onReopen,
}: {
  r: PanelReport;
  busy: boolean;
  onQuick: (r: PanelReport, action: Action) => void;
  onAct: (r: PanelReport, action: Action) => void;
  onResolve: (r: PanelReport) => void;
  onReopen: (r: PanelReport) => void;
}) {
  const { t, lang, can } = useApp();
  const label = (prefix: string, v: string) => (isKey(`${prefix}${v}`) ? t(`${prefix}${v}` as never) : v);
  const p = r.preview;
  const text = r.dmSnapshot?.text ?? r.linkSnapshot?.url ?? p.text;
  const media = r.dmSnapshot?.mediaUrl ?? p.mediaUrl;
  const open = r.status === 'OPEN';
  const when = r.resolvedAt ? formatDate(r.resolvedAt, lang) : '';
  return (
    <article className={`card report-card${open ? '' : ' resolved'}`} data-report={r.id}>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <div className="row">
          <span className="badge info">{label('type', r.targetType)}</span>
          <span className="badge warn">{label('reason', r.reason)}</span>
          {open && r.priority === 2 && (
            <span className="badge bad" data-priority="2">
              {t('prioritySafety')}
            </span>
          )}
          {open && r.priority === 1 && (
            <span className="badge info" data-priority="1">
              {t('priorityVip')}
            </span>
          )}
          {open ? <StatusBadge status={r.status} /> : <span className="badge ok">{label('repOutcome', r.status)}</span>}
        </div>
        <span className="date small muted">{formatDate(r.createdAt, lang)}</span>
      </div>
      {p.author && (
        <div className="row">
          <span className="muted small">{t('author')}:</span>
          <a href={`/users/${p.author.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${p.author!.id}`))} style={{ color: 'inherit' }}>
            <UserCell username={p.author.username} displayName={p.author.displayName} />
          </a>
          <StatusBadge status={p.author.status} />
        </div>
      )}
      {(text || media) && (
        <div className="preview">
          {media && <img src={media} alt="" style={{ maxHeight: 120, borderRadius: 8, display: 'block', marginBottom: text ? 8 : 0 }} />}
          {text}
        </div>
      )}
      {r.dmGroupSnapshot && (
        <div className="preview small" data-group-snapshot={r.id}>
          <div>
            {t('repGroupMembers', {
              n: String(r.dmGroupSnapshot.memberCount),
              names: r.dmGroupSnapshot.members.map((u) => `@${u}`).join('، '),
            })}
          </div>
          {r.dmGroupSnapshot.thread && r.dmGroupSnapshot.thread.messages.length > 0 && (
            <details>
              <summary>{t('repGroupMessages', { n: String(r.dmGroupSnapshot.thread.messages.length) })}</summary>
              {r.dmGroupSnapshot.thread.messages.slice(-20).map((m) => (
                <div key={m.id}>
                  <span className="ltr">@{m.sender ?? '?'}</span>: {m.text ?? m.kind}
                </div>
              ))}
            </details>
          )}
        </div>
      )}
      {p.gone && <p className="muted small">{t('targetGone')}</p>}
      <div className="small muted">
        {t('reportedBy')}: {r.reporter ? <span className="ltr">@{r.reporter.username}</span> : t('none')}
        {r.note ? ` — ${r.note}` : ''}
      </div>
      {!open && (
        <div className="resolved-by small" data-resolved-by={r.resolvedBy?.id ?? ''}>
          <strong>
            {r.resolvedBy
              ? t('repResolvedBy', { name: r.resolvedBy.displayName || `@${r.resolvedBy.username}`, when })
              : t('repResolvedUnknown', { when })}
          </strong>
          {r.resolutionNote && (
            <div className="muted">
              {t('repResolutionNote')}: {r.resolutionNote}
            </div>
          )}
        </div>
      )}
      {open && (can('reports.resolve') || can('reports.act')) && (
        <div className="row">
          {can('reports.resolve') && (
            <button className="btn small primary" disabled={busy} onClick={() => onResolve(r)}>
              {t('repResolve')}
            </button>
          )}
          {can('reports.act') && (
            <>
              <button className="btn small" disabled={busy} onClick={() => onQuick(r, 'DISMISS')}>
                {t('dismiss')}
              </button>
              {r.targetType !== 'USER' && !p.gone && (
                <button className="btn small" disabled={busy} onClick={() => onAct(r, 'REMOVE_TARGET')}>
                  {t('removeTarget')}
                </button>
              )}
              {p.author && (
                <>
                  <button className="btn small" onClick={() => onAct(r, 'WARN')}>
                    {t('warn')}
                  </button>
                  {p.author.status === 'ACTIVE' && (
                    <button className="btn small danger" onClick={() => onAct(r, 'BAN')}>
                      {t('banAuthor')}
                    </button>
                  )}
                </>
              )}
            </>
          )}
        </div>
      )}
      {!open && can('reports.reopen') && (
        <div className="row">
          <button className="btn small" onClick={() => onReopen(r)}>
            {t('repReopen')}
          </button>
        </div>
      )}
    </article>
  );
}

/**
 * v1.139-social (D387, §10.176.6): who is on shift now above the shared queue — the viewer's own «في المناوبة الآن»
 * badge and the people on shift (pure: rendered in the tests).
 */
export function ShiftStrip({ schedule }: { schedule: StaffSchedule }) {
  const { t } = useApp();
  return (
    <p className="small" data-shift-strip>
      {schedule.me.onShiftNow && (
        <span className="badge ok" data-on-shift-badge>
          {t('shiftOnNow')}
        </span>
      )}{' '}
      <span className="muted">
        {schedule.shift.onShiftNow.length === 0
          ? t('shiftNobody')
          : `${t('shiftOnNow')}: ${schedule.shift.onShiftNow.map((p) => p.displayName).join('، ')}`}
      </span>
    </p>
  );
}

function ShiftStripLoader() {
  const { data } = useAsync(() => api.get<StaffSchedule>('/admin/staff-schedule'), []);
  return data ? <ShiftStrip schedule={data} /> : null;
}

export function Reports() {
  const { t, toast, can } = useApp();
  const [status, setStatus] = useState<ReportTab>('OPEN');
  const pages = useCursorPages(status);
  const { data, error, loading, reload } = useAsync(
    () => api.get<Page<PanelReport>>('/admin/moderation/reports', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  const [act, setAct] = useState<{ action: Action; r: PanelReport } | null>(null);
  const [resolving, setResolving] = useState<PanelReport | null>(null);
  const [reopening, setReopening] = useState<PanelReport | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [actError, setActError] = useState<unknown>(null);
  const changed = () => {
    reload();
    reportsChanged();
  };
  const quick = (r: PanelReport, action: Action) => {
    setBusy(r.id);
    setActError(null);
    api.post(`/admin/moderation/reports/${r.id}/actions`, { action }).then(
      () => {
        setBusy(null);
        toast(t('done'));
        changed();
      },
      (e: unknown) => {
        setBusy(null);
        setActError(e);
      },
    );
  };
  const actionLabel: Record<Action, string> = {
    DISMISS: t('dismiss'),
    REMOVE_TARGET: t('removeTarget'),
    WARN: t('warn'),
    BAN: t('banAuthor'),
  };
  return (
    <>
      <div className="page-head">
        <h1>{t('reportsTitle')}</h1>
        <StatusTabs
          value={status}
          options={REPORT_TABS}
          onChange={setStatus}
          label={(s) => (s === 'OPEN' ? t('repTabOpen') : t('repTabResolved'))}
        />
      </div>
      <p className="muted small">{t('repSharedHint')}</p>
      {can('staff.schedule.view') && <ShiftStripLoader />}
      <ErrorAlert error={error} />
      <ErrorAlert error={actError} />
      {loading && !data && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      <div className="grid">
        {data?.data.map((r) => (
          <ReportCard
            key={r.id}
            r={r}
            busy={busy === r.id}
            onQuick={quick}
            onAct={(x, action) => setAct({ action, r: x })}
            onResolve={setResolving}
            onReopen={setReopening}
          />
        ))}
      </div>
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
      {resolving && (
        <FormDialog
          title={t('repResolveTitle')}
          intro={<p className="muted small">{t('repResolveIntro')}</p>}
          fields={[{ name: 'note', label: t('repResolveNote'), kind: 'textarea', required: false, maxLength: 500 }]}
          confirmLabel={t('repResolve')}
          submit={async (v) => {
            try {
              await api.post(`/admin/moderation/reports/${resolving.id}/resolve`, resolveBody(v.note));
            } catch (e) {
              // D288: somebody else pressed first — show it as resolved by them instead of an error.
              if (!isAlreadyResolved(e)) throw e;
              toast(t('repAlreadyResolved'));
            }
          }}
          onClose={() => setResolving(null)}
          onDone={() => {
            setResolving(null);
            toast(t('done'));
            changed();
          }}
        />
      )}
      {reopening && (
        <FormDialog
          title={t('repReopenTitle')}
          intro={<p className="muted small">{t('repReopenIntro')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('repReopen')}
          submit={(v) => api.post(`/admin/moderation/reports/${reopening.id}/reopen`, { reason: v.reason })}
          onClose={() => setReopening(null)}
          onDone={() => {
            setReopening(null);
            toast(t('done'));
            changed();
          }}
        />
      )}
      {act && (
        <FormDialog
          title={actionLabel[act.action]}
          fields={[{ ...reasonField(t), required: act.action !== 'REMOVE_TARGET' }]}
          confirmLabel={actionLabel[act.action]}
          danger={act.action !== 'WARN'}
          submit={(v) =>
            api.post(`/admin/moderation/reports/${act.r.id}/actions`, {
              action: act.action,
              ...(v.reason ? { note: v.reason } : {}),
            })
          }
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            toast(t('done'));
            changed();
          }}
        />
      )}
    </>
  );
}
