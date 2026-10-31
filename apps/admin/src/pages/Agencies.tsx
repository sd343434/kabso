import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { PersonRef } from '../types';
import { DataTable } from '../ui/DataTable';
import { Icon } from '../ui/icons';

interface AgencyRow {
  id: string;
  inviteCode: string;
  hostCode: string | null;
  rank: string;
  suspended: boolean;
  /** v1.70-social (D206). */
  name: string | null;
  origin: 'ADMIN' | 'SELF';
  status: 'OPEN' | 'CLOSED';
  probation: 'NONE' | 'RUNNING' | 'PASSED' | 'FAILED' | 'STOPPED';
  owner: PersonRef;
  parentInviteCode: string | null;
  activeHosts: number;
  subAgencies: number;
  monthHostCherries: number;
  monthCommission: number;
  createdAt: string;
}

interface AgencyDetailDto {
  id: string;
  /** v1.70-social (D206): «افتح وكالة». */
  name: string | null;
  origin: 'ADMIN' | 'SELF';
  status: 'OPEN' | 'CLOSED';
  closedAt: string | null;
  closeReason: 'PROBATION_FAILED' | 'ADMIN' | null;
  closeNote: string | null;
  probation: {
    state: 'NONE' | 'RUNNING' | 'PASSED' | 'FAILED' | 'STOPPED';
    endsAt: string;
    passedAt: string | null;
    requiredHosts: number;
    activatedHosts: number | null;
    hosts: { userId: string; joinedAt: string; wentLive: boolean; receivedGifts: boolean; activated: boolean }[];
  } | null;
  applications: { id: string; createdAt: string; purged: boolean }[];
  inviteCode: string;
  hostCode: string | null;
  rank: string;
  rankMonth: string | null;
  evaluateFrom: string;
  suspended: boolean;
  suspendReason: string | null;
  createdAt: string;
  owner: PersonRef;
  parent: { id: string; inviteCode: string } | null;
  subAgencies: { id: string; inviteCode: string; hostCode: string | null; rank: string; suspended: boolean; owner: PersonRef }[];
  hosts: {
    linkId: string;
    status: string;
    commissionEligible: boolean;
    activatedAt: string;
    endedAt: string | null;
    user: PersonRef;
    monthCherries: number;
    monthCommission: number;
  }[];
  months: { month: string; hostCherries: number; commission: number; parentCommission: number }[];
  lifetime: { hostCherries: number; commission: number; parentCommission: number };
  openComplaints: number;
}

interface ComplaintRow {
  id: string;
  status: string;
  resolution: string | null;
  text: string;
  note: string | null;
  createdAt: string;
  resolvedAt: string | null;
  host: PersonRef;
  agency: { id: string; inviteCode: string };
}

const RANK_TONE: Record<string, string> = { NEW: 'info', AGENT: 'ok', ADMIN: 'ok', LAPSED: 'bad' };

export function RankBadge({ rank }: { rank: string }) {
  const { t } = useApp();
  return <span className={`badge ${RANK_TONE[rank] ?? ''}`}>{t(`rank${rank}` as never)}</span>;
}

/** Host agencies «الوكالات» (D179/D189 through D197): the list, creation and the monthly rank evaluation. */
export function Agencies() {
  const { t, lang, can, toast } = useApp();
  const [dialog, setDialog] = useState<'create' | 'evaluate' | null>(null);
  const [bump, setBump] = useState(0);
  const n = (v: number) => formatNumber(v, lang);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('agenciesTitle')}</h1>
          <p className="muted small">{t('agenciesSubtitle')}</p>
        </div>
        {can('agencies.manage') && (
          <div className="row">
            <button className="btn" onClick={() => setDialog('evaluate')}>
              <Icon name="refresh" size={16} />
              {t('agencyEvaluate')}
            </button>
            <button className="btn primary" onClick={() => setDialog('create')}>
              <Icon name="plus" size={16} />
              {t('agencyCreate')}
            </button>
          </div>
        )}
      </div>
      <DataTable<AgencyRow>
        id="agencies"
        endpoint="/admin/agencies"
        rowKey={(r) => r.id}
        reloadKey={bump}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="agencySearch"
        csv
        onRowClick={(r) => navigate(`/agencies/${r.id}`)}
        filters={[
          { name: 'rank', label: 'colRank', options: ['NEW', 'AGENT', 'ADMIN', 'LAPSED'].map((r) => ({ value: r, label: `rank${r}` })) },
          {
            name: 'state',
            label: 'colStatus',
            options: [
              { value: 'active', label: 'statusACTIVE' },
              { value: 'suspended', label: 'statusSUSPENDED' },
              { value: 'probation', label: 'statePROBATION' },
              { value: 'closed', label: 'stateCLOSED' },
            ],
          },
          { name: 'origin', label: 'colOrigin', options: [{ value: 'SELF', label: 'agencyOriginSELF' }, { value: 'ADMIN', label: 'agencyOriginADMIN' }] },
        ]}
        columns={[
          {
            key: 'code',
            label: 'colAgency',
            sort: 'inviteCode',
            render: (r) => (
              <span className="names">
                <span className="mono">{r.hostCode ?? '—'}</span>
                <span className="mono muted small">{r.inviteCode}</span>
                {r.name && <span className="small">{r.name}</span>}
              </span>
            ),
          },
          { key: 'owner', label: 'colOwner', render: (r) => <UserCell username={r.owner.username} displayName={r.owner.displayName} avatarUrl={r.owner.avatarUrl} /> },
          { key: 'rank', label: 'colRank', sort: 'rank', render: (r) => <RankBadge rank={r.rank} /> },
          { key: 'state', label: 'colStatus', render: (r) => <StatusBadge status={r.status === 'CLOSED' ? 'CLOSED' : r.suspended ? 'SUSPENDED' : 'ACTIVE'} /> },
          { key: 'probation', label: 'colProbation', render: (r) => (r.probation === 'NONE' ? <span className="muted">—</span> : <StatusBadge status={r.probation} />) },
          { key: 'origin', label: 'colOrigin', optional: true, render: (r) => <span className="small">{t(r.origin === 'SELF' ? 'agencyOriginSELF' : 'agencyOriginADMIN')}</span> },
          { key: 'hosts', label: 'colHosts', numeric: true, render: (r) => n(r.activeHosts) },
          { key: 'subs', label: 'colSubAgencies', numeric: true, render: (r) => n(r.subAgencies) },
          { key: 'cherries', label: 'colMonthCherries', numeric: true, render: (r) => n(r.monthHostCherries) },
          { key: 'commission', label: 'colMonthCommission', numeric: true, render: (r) => n(r.monthCommission) },
          { key: 'parent', label: 'colParent', optional: true, render: (r) => <span className="mono">{r.parentInviteCode ?? '—'}</span> },
          { key: 'created', label: 'colCreated', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
        ]}
      />
      {dialog === 'create' && (
        <FormDialog
          title={t('agencyCreate')}
          intro={<p className="muted small">{t('agencyCreateIntro')}</p>}
          fields={[
            { name: 'ownerEmail', label: t('agencyOwnerEmail'), hint: t('agencyOwnerHint') },
            { name: 'parentInviteCode', label: t('agencyParentCode'), required: false, maxLength: 12 },
            reasonField(t),
          ]}
          confirmLabel={t('agencyCreate')}
          submit={(v) =>
            api.post<{ agencyId: string; hostCode: string }>('/admin/agencies', {
              ownerEmail: v.ownerEmail,
              ...(v.parentInviteCode ? { parentInviteCode: v.parentInviteCode } : {}),
              reason: v.reason,
            })
          }
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
      {dialog === 'evaluate' && (
        <FormDialog
          title={t('agencyEvaluate')}
          intro={<p className="muted small">{t('agencyEvaluateIntro')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('agencyEvaluate')}
          submit={(v) =>
            api.post<{ rankChanges: unknown[]; frameChanges: number }>('/admin/agency-evaluation', { reason: v.reason }).then((r) =>
              toast(t('agencyEvaluated', { ranks: r.rankChanges.length, frames: r.frameChanges })),
            )
          }
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}

/** An agency's page: owner, `hostNN`, rank, six months of totals, hosts with this month's cherries, sub-agencies. */
export function AgencyDetail({ id }: { id: string }) {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AgencyDetailDto>(`/admin/agencies/${id}`), [id]);
  const [dialog, setDialog] = useState<'suspend' | 'reinstate' | null>(null);
  const [probationDialog, setProbationDialog] = useState<'extend' | 'close' | 'reopen' | null>(null);
  const n = (v: number) => formatNumber(v, lang);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const closed = data.status === 'CLOSED';
  const running = data.probation?.state === 'RUNNING';
  const maxMonth = Math.max(1, ...data.months.map((m) => m.hostCherries));
  return (
    <>
      <div className="profile-head card">
        <span className="kpi-icon big">
          <Icon name="agency" size={28} />
        </span>
        <div className="grow">
          <h1 className="mono">{data.hostCode ?? data.inviteCode}</h1>
          {data.name && <p className="agency-name">{data.name}</p>}
          <div className="row small">
            <span className="mono muted">{data.inviteCode}</span>
            <RankBadge rank={data.rank} />
            <StatusBadge status={closed ? 'CLOSED' : data.suspended ? 'SUSPENDED' : 'ACTIVE'} />
            <span className="badge">{t(data.origin === 'SELF' ? 'agencyOriginSELF' : 'agencyOriginADMIN')}</span>
            {data.parent && (
              <a href={`/agencies/${data.parent.id}`} onClick={(e) => (e.preventDefault(), navigate(`/agencies/${data.parent!.id}`))}>
                {t('colParent')}: <span className="mono">{data.parent.inviteCode}</span>
              </a>
            )}
          </div>
          {data.suspendReason && <p className="muted small">{data.suspendReason}</p>}
          {closed && data.closedAt && (
            <p className="small" data-agency-closed>
              {t('agencyClosedOn', { date: formatDate(data.closedAt, lang) })} —{' '}
              {t(data.closeReason === 'PROBATION_FAILED' ? 'agencyCloseReasonPROBATION_FAILED' : 'agencyCloseReasonADMIN')}
              {data.closeNote ? ` · ${data.closeNote}` : ''}
            </p>
          )}
        </div>
        <div className="row actions-row">
          {can('agencies.probation') && running && (
            <button className="btn" onClick={() => setProbationDialog('extend')}>
              {t('agencyExtend')}
            </button>
          )}
          {can('agencies.probation') && !closed && (
            <button className="btn danger" onClick={() => setProbationDialog('close')}>
              {t('agencyClose')}
            </button>
          )}
          {can('agencies.probation') && closed && (
            <button className="btn primary" onClick={() => setProbationDialog('reopen')}>
              {t('agencyReopen')}
            </button>
          )}
          {can('agencies.manage') && !data.suspended && !closed && (
            <button className="btn danger" onClick={() => setDialog('suspend')}>
              {t('agencySuspend')}
            </button>
          )}
          {can('agencies.manage') && data.suspended && (
            <button className="btn" onClick={() => setDialog('reinstate')}>
              {t('agencyReinstate')}
            </button>
          )}
          <button className="btn ghost" onClick={() => navigate('/agencies')}>
            {t('back')}
          </button>
        </div>
      </div>
      <div className="mini-stats">
        <div className="mini-stat">
          <span className="muted small">{t('colOwner')}</span>
          <a href={`/users/${data.owner.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${data.owner.id}`))}>
            <UserCell username={data.owner.username} displayName={data.owner.displayName} avatarUrl={data.owner.avatarUrl} />
          </a>
        </div>
        <div className="mini-stat">
          <span className="muted small">{t('colHosts')}</span>
          <strong className="num">{n(data.hosts.filter((h) => h.status === 'ACTIVE').length)}</strong>
        </div>
        <div className="mini-stat">
          <span className="muted small">{t('agencyLifetimeCommission')}</span>
          <strong className="num">{n(data.lifetime.commission + data.lifetime.parentCommission)}</strong>
        </div>
        <div className="mini-stat">
          <span className="muted small">{t('agencyOpenComplaints')}</span>
          <strong className="num">{n(data.openComplaints)}</strong>
        </div>
        <div className="mini-stat">
          <span className="muted small">{t('agencyEvaluateFrom')}</span>
          <strong className="date">{data.evaluateFrom}</strong>
        </div>
      </div>
      {(data.probation || data.applications.length > 0) && (
        <div className="grid cols-2">
          {data.probation && <ProbationCard data={data} />}
          {data.applications.length > 0 && <ApplicationsCard agencyId={data.id} applications={data.applications} />}
        </div>
      )}
      <div className="grid cols-2">
        <div className="card">
          <h2>{t('agencyMonths')}</h2>
          {data.months.length === 0 ? (
            <p className="muted">{t('empty')}</p>
          ) : (
            <ul className="bars">
              {data.months.map((m) => (
                <li key={m.month}>
                  <span className="mono small">{m.month}</span>
                  <span className="bar">
                    <span style={{ width: `${(m.hostCherries / maxMonth) * 100}%` }} />
                  </span>
                  <span className="num small">{n(m.hostCherries)}</span>
                  <span className="num small muted">{n(m.commission)}</span>
                </li>
              ))}
            </ul>
          )}
          <p className="muted small">{t('agencyMonthsNote')}</p>
        </div>
        <div className="card">
          <h2>{t('colSubAgencies')}</h2>
          {data.subAgencies.length === 0 ? (
            <p className="muted">{t('empty')}</p>
          ) : (
            <div className="table-wrap">
              <table>
                <tbody>
                  {data.subAgencies.map((s) => (
                    <tr key={s.id} className="clickable" onClick={() => navigate(`/agencies/${s.id}`)}>
                      <td className="mono">{s.hostCode ?? s.inviteCode}</td>
                      <td>@{s.owner.username}</td>
                      <td>
                        <RankBadge rank={s.rank} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <h2>{t('colHosts')}</h2>
        {data.hosts.length === 0 ? (
          <p className="muted">{t('empty')}</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t('colUser')}</th>
                  <th>{t('colStatus')}</th>
                  <th className="num">{t('colMonthCherries')}</th>
                  <th className="num">{t('colMonthCommission')}</th>
                  <th>{t('colJoined')}</th>
                </tr>
              </thead>
              <tbody>
                {data.hosts.map((h) => (
                  <tr key={h.linkId} className="clickable" onClick={() => navigate(`/users/${h.user.id}`)}>
                    <td>
                      <UserCell username={h.user.username} displayName={h.user.displayName} avatarUrl={h.user.avatarUrl} />
                    </td>
                    <td>
                      <StatusBadge status={h.status} />
                    </td>
                    <td className="num">{n(h.monthCherries)}</td>
                    <td className="num">{n(h.monthCommission)}</td>
                    <td className="date small">{formatDate(h.activatedAt, lang)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      {dialog && (
        <FormDialog
          title={t(dialog === 'suspend' ? 'agencySuspend' : 'agencyReinstate')}
          intro={<p className="muted small">{t(dialog === 'suspend' ? 'agencySuspendIntro' : 'agencyReinstateIntro')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t(dialog === 'suspend' ? 'agencySuspend' : 'agencyReinstate')}
          danger={dialog === 'suspend'}
          submit={(v) => api.post(`/admin/agencies/${id}/${dialog}`, { reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
      {probationDialog && (
        <FormDialog
          title={t(PROBATION_ACTION[probationDialog])}
          intro={<p className="muted small">{t(`${PROBATION_ACTION[probationDialog]}Intro` as never)}</p>}
          fields={[
            ...(probationDialog === 'extend' ? [{ name: 'days', label: t('agencyExtendDays'), maxLength: 2 }] : []),
            reasonField(t),
            codeField(t),
          ]}
          confirmLabel={t(PROBATION_ACTION[probationDialog])}
          danger={probationDialog === 'close'}
          submit={(v) =>
            api.post(probationDialog === 'extend' ? `/admin/agencies/${id}/probation/extend` : `/admin/agencies/${id}/${probationDialog}`, {
              ...(probationDialog === 'extend' ? { days: Number(v.days) } : {}),
              reason: v.reason,
              totpCode: v.totpCode,
            })
          }
          onClose={() => setProbationDialog(null)}
          onDone={() => {
            setProbationDialog(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}

const PROBATION_ACTION = { extend: 'agencyExtend', close: 'agencyClose', reopen: 'agencyReopen' } as const;

/** v1.70-social (D206): the trial of a self-opened agency — the count, the end and each host's three steps. */
function ProbationCard({ data }: { data: AgencyDetailDto }) {
  const { t, lang } = useApp();
  const p = data.probation!;
  const people = new Map(data.hosts.map((h) => [h.user.id, h.user]));
  const tick = (ok: boolean) => <span className={ok ? 'ok-text' : 'muted'}>{ok ? '✓' : '—'}</span>;
  return (
    <div className="card" data-agency-probation>
      <div className="row">
        <h2 className="grow">{t('agencyProbation')}</h2>
        <StatusBadge status={p.state} />
      </div>
      <p className="num">
        <strong>{t('agencyProbationCount', { x: p.activatedHosts ?? '—', y: p.requiredHosts })}</strong>
      </p>
      <p className="small">
        {p.passedAt ? `${t('agencyProbationPassedAt')}: ${formatDate(p.passedAt, lang)}` : `${t('agencyProbationEnds')}: ${formatDate(p.endsAt, lang)}`}
      </p>
      <p className="muted small">{t('agencyProbationRule')}</p>
      {p.hosts.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colUser')}</th>
                <th>{t('agencyWentLive')}</th>
                <th>{t('agencyGotGifts')}</th>
                <th>{t('agencyActivated')}</th>
              </tr>
            </thead>
            <tbody>
              {p.hosts.map((h) => {
                const u = people.get(h.userId);
                return (
                  <tr key={h.userId}>
                    <td>{u ? <UserCell username={u.username} displayName={u.displayName} avatarUrl={u.avatarUrl} /> : <span className="mono small">{h.userId}</span>}</td>
                    <td>{tick(h.wentLive)}</td>
                    <td>{tick(h.receivedGifts)}</td>
                    <td>{tick(h.activated)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

interface AgencyApplicationDto {
  id: string;
  createdAt: string;
  purgedAt: string | null;
  user: { id: string; username: string; displayName: string; email: string };
  name: string;
  country: string;
  contact: { type: string; value: string | null };
  expectedHosts: number;
  bio: string | null;
  photos: { photo: boolean; selfie: boolean };
}

/** v1.70-social (D206): the applications; the fields and the pictures are read one at a time (each view audited). */
function ApplicationsCard({ agencyId, applications }: { agencyId: string; applications: AgencyDetailDto['applications'] }) {
  const { t, lang, can } = useApp();
  const [open, setOpen] = useState<string | null>(null);
  return (
    <div className="card" data-agency-applications>
      <h2>{t('agencyApplications')}</h2>
      <p className="muted small">{t('agencyApplicationNote')}</p>
      <ul className="plain-list">
        {applications.map((a) => (
          <li key={a.id}>
            <div className="row">
              <span className="date small grow">{formatDate(a.createdAt, lang)}</span>
              {a.purged && <span className="badge">{t('agencyPurged')}</span>}
              {can('agencies.applications') && open !== a.id && (
                <button className="btn" onClick={() => setOpen(a.id)}>
                  {t('agencyApplicationShow')}
                </button>
              )}
            </div>
            {open === a.id && <ApplicationFields agencyId={agencyId} appId={a.id} />}
          </li>
        ))}
      </ul>
    </div>
  );
}

function ApplicationFields({ agencyId, appId }: { agencyId: string; appId: string }) {
  const { t } = useApp();
  const { data, error, loading } = useAsync(() => api.get<AgencyApplicationDto>(`/admin/agencies/${agencyId}/applications/${appId}`), [agencyId, appId]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <div data-agency-application={appId}>
      <dl className="kv">
        <dt>{t('colOwner')}</dt>
        <dd>
          @{data.user.username} · {data.user.email}
        </dd>
        <dt>{t('agencyCountry')}</dt>
        <dd className="mono">{data.country}</dd>
        <dt>{t('agencyContact')}</dt>
        <dd>
          {data.contact.type} · <span dir="ltr">{data.contact.value ?? '—'}</span>
        </dd>
        <dt>{t('agencyExpectedHosts')}</dt>
        <dd className="num">{data.expectedHosts}</dd>
        <dt>{t('agencyBio')}</dt>
        <dd>{data.bio ?? '—'}</dd>
      </dl>
      <div className="grid cols-2">
        <AgencyPhoto agencyId={agencyId} appId={appId} which="photo" exists={data.photos.photo} label={t('agencyIdCard')} />
        <AgencyPhoto agencyId={agencyId} appId={appId} which="selfie" exists={data.photos.selfie} label={t('agencySelfie')} />
      </div>
    </div>
  );
}

function AgencyPhoto(props: { agencyId: string; appId: string; which: 'photo' | 'selfie'; exists: boolean; label: string }) {
  const { t } = useApp();
  const [shown, setShown] = useState(false);
  return (
    <div className="card">
      <h3>{props.label}</h3>
      <div className="photo-box" data-private-photo={props.which}>
        {!props.exists ? (
          <span className="muted">{t('photoMissing')}</span>
        ) : shown ? (
          <img src={`/api/v1/admin/agencies/${props.agencyId}/applications/${props.appId}/photos/${props.which}`} alt={props.label} referrerPolicy="no-referrer" />
        ) : (
          <button className="btn" onClick={() => setShown(true)}>
            {t('showPhoto')}
          </button>
        )}
      </div>
    </div>
  );
}

/** The hosts' complaints about their agency: release, keep or move the host (reason; audited). */
export function Complaints() {
  const { t, lang, can, toast } = useApp();
  const [status, setStatus] = useState<'OPEN' | 'RESOLVED' | 'REJECTED'>('OPEN');
  const [open, setOpen] = useState<ComplaintRow | null>(null);
  const [decision, setDecision] = useState<'release' | 'keep' | 'move'>('release');
  const [bump, setBump] = useState(0);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('complaintsTitle')}</h1>
          <p className="muted small">{t('complaintsSubtitle')}</p>
        </div>
      </div>
      <div className="tabs">
        {(['OPEN', 'RESOLVED', 'REJECTED'] as const).map((s) => (
          <button key={s} className="tab" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {t(`status${s}` as never)}
          </button>
        ))}
      </div>
      <DataTable<ComplaintRow>
        id="complaints"
        endpoint="/admin/agency-complaints"
        extraQuery={{ status }}
        reloadKey={bump}
        rowKey={(r) => r.id}
        csv
        columns={[
          { key: 'host', label: 'colHost', render: (r) => <UserCell username={r.host.username} displayName={r.host.displayName} avatarUrl={r.host.avatarUrl} /> },
          {
            key: 'agency',
            label: 'colAgency',
            render: (r) => (
              <a href={`/agencies/${r.agency.id}`} className="mono" onClick={(e) => (e.preventDefault(), navigate(`/agencies/${r.agency.id}`))}>
                {r.agency.inviteCode}
              </a>
            ),
          },
          { key: 'text', label: 'colText', render: (r) => <span className="clip">{r.text}</span> },
          { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
          { key: 'res', label: 'colDecision', render: (r) => (r.resolution ? <span className="badge">{r.resolution}</span> : <StatusBadge status={r.status} />) },
          {
            key: 'act',
            label: 'colActions',
            render: (r) =>
              r.status === 'OPEN' && can('agencies.manage') ? (
                <button className="btn small primary" onClick={() => setOpen(r)}>
                  {t('complaintResolve')}
                </button>
              ) : (
                <span className="muted small">{r.note ?? ''}</span>
              ),
          },
        ]}
      />
      {open && (
        <FormDialog
          title={t('complaintResolve')}
          intro={
            <>
              <blockquote className="quote">{open.text}</blockquote>
              <div className="segmented" role="group">
                {(['release', 'keep', 'move'] as const).map((d) => (
                  <button key={d} type="button" aria-pressed={decision === d} onClick={() => setDecision(d)}>
                    {t(`decision_${d}` as never)}
                  </button>
                ))}
              </div>
              <p className="muted small">{t(`decision_${decision}_hint` as never)}</p>
            </>
          }
          fields={[
            ...(decision === 'move' ? [{ name: 'toInviteCode', label: t('complaintMoveTo'), maxLength: 12 }] : []),
            { ...reasonField(t), name: 'note' },
          ]}
          confirmLabel={t('confirm')}
          submit={(v) =>
            api.post(`/admin/agency-complaints/${open.id}/resolve`, {
              decision,
              note: v.note,
              ...(decision === 'move' ? { toInviteCode: v.toInviteCode } : {}),
            })
          }
          onClose={() => setOpen(null)}
          onDone={() => {
            setOpen(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
