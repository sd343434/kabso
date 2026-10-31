import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { navigate } from '../router';
import type { Application, ApplicationRow, Page } from '../types';

const STATUSES = ['PENDING', 'APPROVED', 'REJECTED', ''] as const;

export function StatusTabs<S extends string>({ value, options, onChange }: { value: S; options: readonly S[]; onChange: (s: S) => void }) {
  const { t } = useApp();
  return (
    <div className="tabs" role="group">
      {options.map((s) => (
        <button key={s || 'all'} className="tab" aria-pressed={value === s} onClick={() => onChange(s)}>
          {s ? t(`status${s}` as never) : t('statusAll')}
        </button>
      ))}
    </div>
  );
}

export function Applications() {
  const { t, lang } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('PENDING');
  const pages = useCursorPages(status);
  const { data, error, loading } = useAsync(
    () => api.get<Page<ApplicationRow>>('/admin/recharge/applications', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  return (
    <>
      <div className="page-head">
        <h1>{t('appsTitle')}</h1>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colUser')}</th>
                <th>{t('colStatus')}</th>
                <th>{t('colSubmitted')}</th>
                <th>{t('colDecided')}</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((a) => (
                <tr key={a.id} className="clickable" onClick={() => navigate(`/recharge/applications/${a.id}`)}>
                  <td>
                    <UserCell username={a.user.username} displayName={a.user.displayName} />
                  </td>
                  <td>
                    <StatusBadge status={a.status} /> {a.purged && <span className="badge">{t('purged')}</span>}
                  </td>
                  <td className="date">{formatDate(a.createdAt, lang)}</td>
                  <td className="date">{formatDate(a.decidedAt, lang)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
    </>
  );
}

/** One private picture: fetched only when asked (each fetch is an audited view). */
function PrivatePhoto({ appId, which, exists }: { appId: string; which: 'photo' | 'selfie'; exists: boolean }) {
  const { t } = useApp();
  const [shown, setShown] = useState(false);
  return (
    <div className="card">
      <h2>{t(which)}</h2>
      <div className="photo-box" data-private-photo={which}>
        {!exists ? (
          <span className="muted">{t('photoMissing')}</span>
        ) : shown ? (
          <img src={`/api/v1/admin/recharge/applications/${appId}/photos/${which}`} alt={t(which)} referrerPolicy="no-referrer" />
        ) : (
          <button className="btn" onClick={() => setShown(true)}>
            {t('showPhoto')}
          </button>
        )}
      </div>
    </div>
  );
}

export function ApplicationDetail({ id }: { id: string }) {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<Application>(`/admin/recharge/applications/${id}`), [id]);
  const [rejecting, setRejecting] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<unknown>(null);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const approve = () => {
    setBusy(true);
    setActionError(null);
    api.post(`/admin/recharge/applications/${id}/approve`).then(
      () => {
        setBusy(false);
        toast(t('done'));
        reload();
      },
      (e: unknown) => {
        setBusy(false);
        setActionError(e);
      },
    );
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('appDetail')}</h1>
          <div className="row small">
            <StatusBadge status={data.status} />
            <span className="date muted">{formatDate(data.createdAt, lang)}</span>
          </div>
        </div>
        <button className="btn" onClick={() => navigate('/recharge/applications')}>
          {t('back')}
        </button>
      </div>
      <div className="alert info">{t('privateNotice')}</div>
      <ErrorAlert error={actionError} />
      <div className="grid cols-2">
        <div className="card">
          <dl className="kv">
            <dt>{t('colUser')}</dt>
            <dd>
              <a href={`/users/${data.user.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${data.user.id}`))}>
                {data.user.displayName} <span className="ltr">@{data.user.username}</span>
              </a>
            </dd>
            <dt>{t('colEmail')}</dt>
            <dd className="ltr">{data.user.email}</dd>
            {data.purgedAt ? (
              <>
                <dt>{t('purged')}</dt>
                <dd className="date">{formatDate(data.purgedAt, lang)}</dd>
              </>
            ) : (
              <>
                <dt>{t('fullName')}</dt>
                <dd>{data.fullName}</dd>
                <dt>{t('phone')}</dt>
                <dd className="ltr">{data.phone}</dd>
                <dt>{t('locations')}</dt>
                <dd>
                  {(data.locations ?? []).map((l) => (
                    <div key={l.country}>
                      <span className="mono">{l.country}</span>: {l.cities.join('، ')}
                    </div>
                  ))}
                </dd>
                <dt>{t('paymentMethods')}</dt>
                <dd>
                  {(data.paymentMethods ?? []).map((m, i) => (
                    <div key={i}>
                      <span className="mono">{m.country}</span> · {m.type}
                    </div>
                  ))}
                </dd>
              </>
            )}
            {data.rejectReason && (
              <>
                <dt>{t('rejectReason')}</dt>
                <dd>{data.rejectReason}</dd>
              </>
            )}
          </dl>
          {data.status === 'PENDING' && can('recharge.decide') && (
            <div className="row" style={{ marginTop: 16 }}>
              <button className="btn primary" disabled={busy} onClick={approve}>
                {t('approve')}
              </button>
              <button className="btn danger" disabled={busy} onClick={() => setRejecting(true)}>
                {t('reject')}
              </button>
            </div>
          )}
        </div>
        <div className="grid">
          <PrivatePhoto appId={id} which="photo" exists={data.photos.photo} />
          <PrivatePhoto appId={id} which="selfie" exists={data.photos.selfie} />
        </div>
      </div>
      {rejecting && (
        <FormDialog
          title={t('reject')}
          fields={[reasonField(t, t('rejectReason'))]}
          confirmLabel={t('reject')}
          danger
          submit={(v) => api.post(`/admin/recharge/applications/${id}/reject`, { reason: v.reason })}
          onClose={() => setRejecting(false)}
          onDone={() => {
            setRejecting(false);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}
