import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { Page, PanelReport } from '../types';
import { StatusTabs } from './Applications';

const STATUSES = ['OPEN', 'ACTIONED', 'DISMISSED'] as const;
type Action = 'DISMISS' | 'REMOVE_TARGET' | 'WARN' | 'BAN';

export function Reports() {
  const { t, lang, can, toast } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('OPEN');
  const pages = useCursorPages(status);
  const { data, error, loading, reload } = useAsync(
    () => api.get<Page<PanelReport>>('/admin/moderation/reports', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  const [act, setAct] = useState<{ action: Action; r: PanelReport } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [actError, setActError] = useState<unknown>(null);
  const label = (prefix: string, v: string) => (isKey(`${prefix}${v}`) ? t(`${prefix}${v}` as never) : v);
  const quick = (r: PanelReport, action: Action) => {
    setBusy(r.id);
    setActError(null);
    api.post(`/admin/moderation/reports/${r.id}/actions`, { action }).then(
      () => {
        setBusy(null);
        toast(t('done'));
        reload();
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
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <ErrorAlert error={error} />
      <ErrorAlert error={actError} />
      {loading && !data && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      <div className="grid">
        {data?.data.map((r) => {
          const p = r.preview;
          const text = r.dmSnapshot?.text ?? r.linkSnapshot?.url ?? p.text;
          const media = r.dmSnapshot?.mediaUrl ?? p.mediaUrl;
          return (
            <article className="card report-card" key={r.id}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <div className="row">
                  <span className="badge info">{label('type', r.targetType)}</span>
                  <span className="badge warn">{label('reason', r.reason)}</span>
                  <StatusBadge status={r.status} />
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
              {p.gone && <p className="muted small">{t('targetGone')}</p>}
              <div className="small muted">
                {t('reportedBy')}: {r.reporter ? <span className="ltr">@{r.reporter.username}</span> : t('none')}
                {r.note ? ` — ${r.note}` : ''}
              </div>
              {r.status === 'OPEN' && can('reports.act') && (
                <div className="row">
                  <button className="btn small" disabled={busy === r.id} onClick={() => quick(r, 'DISMISS')}>
                    {t('dismiss')}
                  </button>
                  {r.targetType !== 'USER' && !p.gone && (
                    <button className="btn small" disabled={busy === r.id} onClick={() => setAct({ action: 'REMOVE_TARGET', r })}>
                      {t('removeTarget')}
                    </button>
                  )}
                  {p.author && (
                    <>
                      <button className="btn small" onClick={() => setAct({ action: 'WARN', r })}>
                        {t('warn')}
                      </button>
                      {p.author.status === 'ACTIVE' && (
                        <button className="btn small danger" onClick={() => setAct({ action: 'BAN', r })}>
                          {t('banAuthor')}
                        </button>
                      )}
                    </>
                  )}
                </div>
              )}
            </article>
          );
        })}
      </div>
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
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
            reload();
          }}
        />
      )}
    </>
  );
}
