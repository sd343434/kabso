import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { HostApplicationDetail as Detail, HostApplicationRow } from '../types';
import { DataTable } from '../ui/DataTable';
import { StatusTabs } from './Applications';
import { KycBlock } from './Kyc';

/**
 * «طلبات المضيفين» (v1.73-social, D209, CONVENTIONS §10.68): the applications «كن مضيفاً مع الإدارة» — people who
 * apply to host directly with the Kabso team. The list shows no private field; an application's page shows its fields
 * and the applicant's account summary (the read is audited), the ID pictures one at a time on request (each view
 * audited), and approve / reject with a reason. MODERATION may look; deciding and the pictures are OWNER + SUPPORT.
 */
const STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', ''] as const;

export function HostApplications() {
  const { t, lang } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('PENDING');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('hostAppsTitle')}</h1>
          <p className="muted small">{t('hostAppsSubtitle')}</p>
        </div>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <DataTable<HostApplicationRow>
        id="host-applications"
        endpoint="/admin/host-applications"
        rowKey={(r) => r.id}
        extraQuery={{ status: status || undefined }}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        onRowClick={(r) => navigate(`/host-applications/${r.id}`)}
        columns={[
          { key: 'user', label: 'colUser', render: (r) => <UserCell username={r.user.username} displayName={r.user.displayName} avatarUrl={r.user.avatarUrl} /> },
          { key: 'name', label: 'hostAppName', render: (r) => r.displayName },
          { key: 'country', label: 'hostAppCountry', render: (r) => <span className="mono">{r.country}</span> },
          {
            key: 'status',
            label: 'colStatus',
            render: (r) => (
              <>
                <StatusBadge status={r.status} /> {r.purged && <span className="badge">{t('purged')}</span>}
              </>
            ),
          },
          { key: 'created', label: 'colSubmitted', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
          { key: 'decided', label: 'colDecided', sort: 'decidedAt', render: (r) => <span className="date small">{formatDate(r.decidedAt, lang)}</span> },
          { key: 'by', label: 'hostAppDecidedBy', optional: true, render: (r) => (r.decidedBy ? `@${r.decidedBy.username}` : '—') },
        ]}
      />
    </>
  );
}

/** One private picture: fetched only when asked (each fetch is an audited view). */
function HostPhoto({ appId, which, exists, label }: { appId: string; which: 'photo' | 'selfie'; exists: boolean; label: string }) {
  const { t, can } = useApp();
  const [shown, setShown] = useState(false);
  return (
    <div className="card">
      <h3>{label}</h3>
      <div className="photo-box" data-private-photo={which}>
        {!exists ? (
          <span className="muted">{t('photoMissing')}</span>
        ) : !can('hosts.applications.photos') ? (
          <span className="muted">{t('hostAppPhotoNotAllowed')}</span>
        ) : shown ? (
          <img src={`/api/v1/admin/host-applications/${appId}/photos/${which}`} alt={label} referrerPolicy="no-referrer" />
        ) : (
          <button className="btn" onClick={() => setShown(true)}>
            {t('showPhoto')}
          </button>
        )}
      </div>
    </div>
  );
}

/** The application's fields, the account summary and the decision buttons (pure: rendered in the tests). */
export function HostApplicationView({ data, busy, onApprove, onReject }: { data: Detail; busy: boolean; onApprove: () => void; onReject: () => void }) {
  const { t, lang, can } = useApp();
  const a = data.account;
  const decide = data.status === 'PENDING' && can('hosts.applications.decide');
  return (
    <div className="grid cols-2" data-host-application={data.id}>
      <div className="grid">
        <div className="card">
          <h2>{t('hostAppFields')}</h2>
          <dl className="kv">
            <dt>{t('hostAppName')}</dt>
            <dd>{data.displayName}</dd>
            <dt>{t('hostAppCountry')}</dt>
            <dd className="mono">{data.country}</dd>
            {data.purgedAt ? (
              <>
                <dt>{t('purged')}</dt>
                <dd className="date">{formatDate(data.purgedAt, lang)}</dd>
              </>
            ) : (
              <>
                <dt>{t('hostAppBirth')}</dt>
                <dd>
                  <span className="date">{data.dateOfBirth ?? '—'}</span> {data.age !== null && <span className="badge">{t('hostAppAge', { n: data.age })}</span>}
                </dd>
                <dt>{t('hostAppContact')}</dt>
                <dd>
                  {t(`hostContact${data.contact.type}`)} · <span dir="ltr">{data.contact.value ?? '—'}</span>
                </dd>
                <dt>{t('hostAppBio')}</dt>
                <dd style={{ whiteSpace: 'pre-line' }}>{data.bio ?? '—'}</dd>
                <dt>{t('hostAppLinks')}</dt>
                <dd>
                  {data.links.length === 0
                    ? '—'
                    : data.links.map((l) => (
                        <div key={l} dir="ltr" className="small">
                          {l}
                        </div>
                      ))}
                </dd>
              </>
            )}
            <dt>{t('hostAppRules')}</dt>
            <dd className="date">{formatDate(data.rulesAcceptedAt, lang)}</dd>
            {data.decidedBy && (
              <>
                <dt>{t('hostAppDecidedBy')}</dt>
                <dd>
                  @{data.decidedBy.username} · <span className="date">{formatDate(data.decidedAt, lang)}</span>
                </dd>
              </>
            )}
            {data.rejectReason && (
              <>
                <dt>{t('rejectReason')}</dt>
                <dd>{data.rejectReason}</dd>
              </>
            )}
            {data.reapplyAt && (
              <>
                <dt>{t('hostAppReapply')}</dt>
                <dd className="date">{formatDate(data.reapplyAt, lang)}</dd>
              </>
            )}
            {data.cancelReason && (
              <>
                <dt>{t('hostAppCancelled')}</dt>
                <dd>{t(`hostAppCancel${data.cancelReason}`)}</dd>
              </>
            )}
          </dl>
          {decide && (
            <>
              <div className="row" style={{ marginTop: 16 }}>
                <button className="btn primary" disabled={busy || (data.kyc?.required === true && !data.kyc.satisfied)} onClick={onApprove} data-host-approve>
                  {t('hostAppApprove')}
                </button>
                <button className="btn danger" disabled={busy} onClick={onReject} data-host-reject>
                  {t('reject')}
                </button>
              </div>
              <p className="muted small">{t('hostAppApproveNote')}</p>
              {data.kyc?.required === true && !data.kyc.satisfied && <p className="small" data-kyc-needed>{t('kycErrRequired')}</p>}
            </>
          )}
        </div>
        <div className="card" data-host-account>
          <h2>{t('hostAppAccount')}</h2>
          <dl className="kv">
            <dt>{t('colUser')}</dt>
            <dd>
              <a href={`/users/${a.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${a.id}`))}>
                {a.displayName} <span className="ltr">@{a.username}</span>
              </a>
            </dd>
            <dt>{t('colEmail')}</dt>
            <dd className="ltr">{a.email}</dd>
            <dt>{t('colStatus')}</dt>
            <dd>
              <StatusBadge status={a.status} />
            </dd>
            <dt>{t('hostAppAccountAge')}</dt>
            <dd>
              {t('hostAppDays', { n: formatNumber(a.accountAgeDays, lang) })} · <span className="date small">{formatDate(a.createdAt, lang)}</span>
            </dd>
            <dt>{t('hostAppReports')}</dt>
            <dd>
              <span className={a.openReports > 0 ? 'badge bad' : 'badge'}>{t('hostAppReportsOpen', { n: a.openReports })}</span>{' '}
              <span className="muted small">{t('hostAppReportsTotal', { n: a.totalReports })}</span>
            </dd>
            <dt>{t('hostAppBans')}</dt>
            <dd>
              <span className={a.bans > 0 ? 'badge bad' : 'badge'}>{formatNumber(a.bans, lang)}</span> <span className="muted small">{t('hostAppWarnings', { n: a.warnings })}</span>
            </dd>
            <dt>{t('hostAppHostNow')}</dt>
            <dd>{a.host ? t(`source${a.host.source}`) : '—'}</dd>
            <dt>{t('hostAppAgency')}</dt>
            <dd>{a.agency ? `${t(a.agency.role === 'OWNER' ? 'hostAppAgencyOwner' : 'hostAppAgencyHost')} · ${a.agency.inviteCode}` : '—'}</dd>
          </dl>
          {data.history.length > 0 && (
            <>
              <h3>{t('hostAppHistory')}</h3>
              <ul className="plain-list">
                {data.history.map((h) => (
                  <li key={h.id} className="row small">
                    <StatusBadge status={h.status} />
                    <span className="date">{formatDate(h.createdAt, lang)}</span>
                    {h.rejectReason && <span className="muted">{h.rejectReason}</span>}
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      </div>
      <div className="grid">
        <KycBlock summary={data.kyc} />
        {/* D227: with Didit on and no manual pictures, the check above replaces the two empty boxes. */}
        {(data.photos.photo || data.photos.selfie || !data.kyc?.required) && (
          <>
            <HostPhoto appId={data.id} which="photo" exists={data.photos.photo} label={t('hostAppIdCard')} />
            <HostPhoto appId={data.id} which="selfie" exists={data.photos.selfie} label={t('hostAppSelfie')} />
          </>
        )}
      </div>
    </div>
  );
}

export function HostApplicationDetail({ id }: { id: string }) {
  const { t, lang, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<Detail>(`/admin/host-applications/${id}`), [id]);
  const [rejecting, setRejecting] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<unknown>(null);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const approve = () => {
    setBusy(true);
    setActionError(null);
    api.post(`/admin/host-applications/${id}/approve`).then(
      () => {
        setBusy(false);
        toast(t('hostAppApproved'));
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
          <h1>{t('hostAppDetail')}</h1>
          <div className="row small">
            <StatusBadge status={data.status} />
            <span className="date muted">{formatDate(data.createdAt, lang)}</span>
          </div>
        </div>
        <button className="btn" onClick={() => navigate('/host-applications')}>
          {t('back')}
        </button>
      </div>
      <div className="alert info">{t('hostAppPrivate')}</div>
      <ErrorAlert error={actionError} />
      <HostApplicationView data={data} busy={busy} onApprove={approve} onReject={() => setRejecting(true)} />
      {rejecting && (
        <FormDialog
          title={t('reject')}
          intro={<p className="muted small">{t('hostAppRejectIntro')}</p>}
          fields={[reasonField(t, t('rejectReason'))]}
          confirmLabel={t('reject')}
          danger
          submit={(v) => api.post(`/admin/host-applications/${id}/reject`, { reason: v.reason })}
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
