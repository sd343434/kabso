import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey, type Key } from '../i18n';
import { navigate } from '../router';
import { StatusTabs } from './Applications';

/**
 * «برنامج سفراء كابسو» (v1.140-social, D390, CONVENTIONS §10.179): the panel's ambassadors — the list with the
 * performance (`ambassadors.view`; money totals only for the OWNER, `ambassadors.settings`), one ambassador's page
 * (flags, months, friends, commissions; freeze / unfreeze / end a review: OWNER), the applications (approve / reject:
 * `ambassadors.manage`), appoint directly, the campaigns and events, and the OWNER's settings (the switch, every
 * number and the levels, with the code again).
 */

export interface AmbassadorTotals {
  pendingCherries: number;
  heldCherries: number;
  paidCherries: number;
  reversedCherries: number;
}
export interface AmbassadorRow {
  user: { id: string; username: string; displayName: string; avatarUrl: string | null };
  status: 'ACTIVE' | 'FROZEN';
  level: string;
  source: 'APPLICATION' | 'APPOINTED';
  country: string | null;
  activatedAt: string;
  underReview: boolean;
  reviewReason: string | null;
  frozenReason: string | null;
  referrals: { total: number; active: number; pending: number; void: number };
  month: { month: string; activeReferrals: number; topupCoins: number };
  commissions: AmbassadorTotals | null;
}
export interface AmbassadorDetailData extends AmbassadorRow {
  flags: { id: string; kind: string; createdAt: string; clearedAt: string | null }[];
  months: {
    month: string;
    activeReferrals: number;
    topupCoins: number;
    commissionCherries: number | null;
    levelBefore: string;
    levelAfter: string;
    metLevel: string | null;
    rewardStatus: 'NONE' | 'GRANTED' | 'HELD';
  }[];
  referralList: {
    invitee: { id: string; username: string; displayName: string };
    status: 'PENDING' | 'ACTIVE' | 'VOID';
    voidReason: string | null;
    createdAt: string;
    activeAt: string | null;
  }[];
  commissionList: {
    id: string;
    createdAt: string;
    recharge: string;
    coins: number;
    level: string;
    rateBps: number;
    cherries: number | null;
    status: string;
    voidReason: string | null;
    holdUntil: string;
  }[];
  campaigns: { id: string; title: string }[];
}
export interface AmbassadorApplicationRow {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED';
  country: string;
  links: string[];
  audienceSize: number;
  motivation: string;
  createdAt: string;
  decidedAt: string | null;
  rejectReason: string | null;
  user: { id: string; username: string; displayName: string; avatarUrl: string | null };
  creator: boolean;
}
export interface AmbassadorCampaign {
  id: string;
  title: string;
  country: string | null;
  startsOn: string;
  endsOn: string;
  notes: string;
  ambassadors: { id: string; username: string; displayName: string }[];
}
export type RewardKind = 'NONE' | 'COINS' | 'VIP_DAYS' | 'BAG_ITEM';
export interface AmbassadorLevel {
  code: string;
  minActiveReferrals: number;
  minTopupCoins: number;
  commissionBps: number;
  reward: { kind: RewardKind; amount?: number; vipTier?: string; itemCode?: string };
}
export interface AmbassadorSettings {
  enabled: boolean;
  attributionWindowDays: number;
  holdDays: number;
  minActiveDays: number;
  minActiveTopupCoins: number;
  monthlyCapCherries: number;
  velocityMaxPerDay: number;
  ipClusterMax: number;
  ipClusterWindowDays: number;
  levels: AmbassadorLevel[];
  updatedAt: string;
}

/** The text of a key built from a value (an unknown value is shown as is). */
function useKeyed() {
  const { t } = useApp();
  return (prefix: string, value: string) => {
    const key = `${prefix}${value}`;
    return isKey(key) ? t(key) : value;
  };
}

/** Basis points as a percentage («5%», «7.5%»). */
export function bpsLabel(bps: number): string {
  return `${Number((bps / 100).toFixed(2))}%`;
}

/** The status cell: frozen / under review badges. */
function AmbStatus({ row }: { row: AmbassadorRow }) {
  const { t } = useApp();
  return (
    <span className="row" style={{ gap: 4 }}>
      <span className={`badge ${row.status === 'FROZEN' ? 'danger' : 'ok'}`} data-amb-status={row.status}>
        {t(row.status === 'FROZEN' ? 'ambStatusFROZEN' : 'ambStatusACTIVE')}
      </span>
      {row.underReview && (
        <span className="badge warn" data-amb-review>
          {t('ambReview')}
        </span>
      )}
    </span>
  );
}

/** The list (pure: rendered in the tests). */
export function AmbassadorTable({ rows }: { rows: AmbassadorRow[] }) {
  const { t, lang } = useApp();
  const money = rows.some((r) => r.commissions !== null);
  return (
    <div className="table-wrap card">
      <table className="table" data-ambassadors>
        <thead>
          <tr>
            <th>{t('ambColAmbassador')}</th>
            <th>{t('ambColLevel')}</th>
            <th>{t('ambColReferrals')}</th>
            <th>{t('ambColActive')}</th>
            <th>{t('ambColMonthTopups')}</th>
            <th>{money ? t('ambColPaid') : t('ambMoneyOwnerOnly')}</th>
            <th>{t('ambColStatus')}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.user.id} className="clickable" onClick={() => navigate(`/ambassadors/${r.user.id}`)} data-amb-row={r.user.id}>
              <td>
                <UserCell username={r.user.username} displayName={r.user.displayName} avatarUrl={r.user.avatarUrl} />
              </td>
              <td>
                <span className={`amb-level amb-${r.level.toLowerCase()}`}>{r.level}</span>
              </td>
              <td className="mono">{formatNumber(r.referrals.total, lang)}</td>
              <td className="mono">{formatNumber(r.referrals.active, lang)}</td>
              <td className="mono">{formatNumber(r.month.topupCoins, lang)}</td>
              <td className="mono" data-amb-money>
                {r.commissions ? formatNumber(r.commissions.paidCherries, lang) : '—'}
              </td>
              <td>
                <AmbStatus row={r} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const LIST_TABS = ['', 'ACTIVE', 'FROZEN', 'REVIEW'] as const;

export function Ambassadors() {
  const { t, can, toast } = useApp();
  const [tab, setTab] = useState<(typeof LIST_TABS)[number]>('');
  const [q, setQ] = useState('');
  const [appoint, setAppoint] = useState(false);
  const { data, error, loading, reload } = useAsync(
    () => api.get<{ data: AmbassadorRow[] }>('/admin/ambassadors', { status: tab || undefined, q: q || undefined }),
    [tab, q],
  );
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('ambTitle')}</h1>
          <p className="muted small">{t('ambSubtitle')}</p>
        </div>
        <div className="row">
          <StatusTabs value={tab} options={LIST_TABS} onChange={setTab} label={(s) => t(s ? (`ambTab${s}` as Key) : 'ambTabAll')} />
          {can('ambassadors.manage') && (
            <button className="btn primary" onClick={() => setAppoint(true)} data-amb-appoint>
              {t('ambAppoint')}
            </button>
          )}
        </div>
      </div>
      <div className="field">
        <input type="search" placeholder={t('usersSearch')} value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      <ErrorAlert error={error} />
      {loading && !data ? <Loading /> : data ? <AmbassadorTable rows={data.data} /> : null}
      {appoint && (
        <FormDialog
          title={t('ambAppoint')}
          intro={<p className="muted small">{t('ambAppointIntro')}</p>}
          fields={[
            { name: 'username', label: t('ambUsername'), maxLength: 64 },
            { name: 'country', label: t('ambCountryOptional'), required: false, maxLength: 2 },
            reasonField(t),
          ]}
          confirmLabel={t('ambAppoint')}
          submit={(v) =>
            api.post('/admin/ambassadors', {
              username: v.username,
              reason: v.reason,
              ...(v.country ? { country: v.country.toUpperCase() } : {}),
            })
          }
          onClose={() => setAppoint(false)}
          onDone={() => {
            setAppoint(false);
            toast(t('ambAppointed'));
            reload();
          }}
        />
      )}
    </>
  );
}

/** One ambassador's performance (pure: rendered in the tests). */
export function AmbassadorView({ data, onAction }: { data: AmbassadorDetailData; onAction: (a: 'freeze' | 'unfreeze' | 'review') => void }) {
  const { t, lang, can } = useApp();
  const keyed = useKeyed();
  const owner = can('ambassadors.settings');
  const c = data.commissions;
  return (
    <div className="grid" data-ambassador={data.user.id}>
      <div className="card">
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <UserCell username={data.user.username} displayName={data.user.displayName} avatarUrl={data.user.avatarUrl} />
          <AmbStatus row={data} />
        </div>
        <div className="kpis" style={{ marginTop: 12 }}>
          <div className="kpi">
            <span className="muted small">{t('ambColLevel')}</span>
            <strong className={`amb-level amb-${data.level.toLowerCase()}`}>{data.level}</strong>
          </div>
          <div className="kpi">
            <span className="muted small">{t('ambColReferrals')}</span>
            <strong>{formatNumber(data.referrals.total, lang)}</strong>
          </div>
          <div className="kpi">
            <span className="muted small">{t('ambColActive')}</span>
            <strong>{formatNumber(data.referrals.active, lang)}</strong>
          </div>
          <div className="kpi">
            <span className="muted small">{t('ambColMonthTopups')}</span>
            <strong>{formatNumber(data.month.topupCoins, lang)}</strong>
          </div>
          {c && (
            <>
              <div className="kpi" data-amb-paid>
                <span className="muted small">{t('ambPaid')}</span>
                <strong>{formatNumber(c.paidCherries, lang)}</strong>
              </div>
              <div className="kpi">
                <span className="muted small">{t('ambPending')}</span>
                <strong>{formatNumber(c.pendingCherries, lang)}</strong>
              </div>
              <div className="kpi">
                <span className="muted small">{t('ambHeld')}</span>
                <strong>{formatNumber(c.heldCherries, lang)}</strong>
              </div>
              <div className="kpi">
                <span className="muted small">{t('ambReversed')}</span>
                <strong>{formatNumber(c.reversedCherries, lang)}</strong>
              </div>
            </>
          )}
        </div>
        <p className="muted small">
          {keyed('ambSource', data.source)} · {data.country ?? '—'} · {formatDate(data.activatedAt, lang)}
          {data.frozenReason ? ` · ${data.frozenReason}` : ''}
        </p>
        {owner && (
          <div className="row" style={{ marginTop: 12 }}>
            {data.status === 'ACTIVE' ? (
              <button className="btn danger" onClick={() => onAction('freeze')} data-amb-freeze>
                {t('ambFreeze')}
              </button>
            ) : (
              <button className="btn primary" onClick={() => onAction('unfreeze')} data-amb-unfreeze>
                {t('ambUnfreeze')}
              </button>
            )}
            {data.underReview && (
              <button className="btn" onClick={() => onAction('review')} data-amb-clear-review>
                {t('ambClearReview')}
              </button>
            )}
          </div>
        )}
      </div>
      <div className="grid cols-2">
        <div className="card">
          <h2>{t('ambFlags')}</h2>
          {data.flags.length === 0 ? (
            <p className="muted">{t('ambNoFlags')}</p>
          ) : (
            <ul className="plain" data-amb-flags>
              {data.flags.map((f) => (
                <li key={f.id}>
                  {keyed('ambFlag', f.kind)} · <span className="date small">{formatDate(f.createdAt, lang)}</span>
                  {f.clearedAt ? ' ✓' : ''}
                </li>
              ))}
            </ul>
          )}
        </div>
        <div className="card">
          <h2>{t('ambMonths')}</h2>
          <table className="table">
            <thead>
              <tr>
                <th>{t('ambMonth')}</th>
                <th>{t('ambColActive')}</th>
                <th>{t('ambColCoins')}</th>
                <th>{t('ambMetLevel')}</th>
                <th>{t('ambReward')}</th>
              </tr>
            </thead>
            <tbody>
              {data.months.map((m) => (
                <tr key={m.month}>
                  <td className="mono ltr">{m.month}</td>
                  <td className="mono">{formatNumber(m.activeReferrals, lang)}</td>
                  <td className="mono">{formatNumber(m.topupCoins, lang)}</td>
                  <td>
                    {m.levelBefore} → {m.levelAfter}
                  </td>
                  <td>{keyed('ambReward', m.rewardStatus)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="card">
        <h2>{t('ambFriends')}</h2>
        <table className="table">
          <tbody>
            {data.referralList.map((r) => (
              <tr key={r.invitee.id}>
                <td>
                  {r.invitee.displayName} <span className="ltr muted">@{r.invitee.username}</span>
                </td>
                <td>{keyed('ambRefStatus', r.status)}</td>
                <td className="small">{r.voidReason ?? ''}</td>
                <td className="date small">{formatDate(r.createdAt, lang)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="card">
        <h2>{t('ambCommissions')}</h2>
        <table className="table" data-amb-commissions>
          <thead>
            <tr>
              <th>{t('ambColCoins')}</th>
              <th>{t('ambColRate')}</th>
              <th>{t('ambColCherries')}</th>
              <th>{t('ambColStatus')}</th>
            </tr>
          </thead>
          <tbody>
            {data.commissionList.map((x) => (
              <tr key={x.id}>
                <td className="mono">{formatNumber(x.coins, lang)}</td>
                <td className="mono">
                  {x.level} · {bpsLabel(x.rateBps)}
                </td>
                <td className="mono">{x.cherries === null ? '—' : formatNumber(x.cherries, lang)}</td>
                <td className="small">
                  {x.status}
                  {x.voidReason ? ` · ${x.voidReason}` : ''}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function AmbassadorDetail({ id }: { id: string }) {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AmbassadorDetailData>(`/admin/ambassadors/${id}`), [id]);
  const [action, setAction] = useState<'freeze' | 'unfreeze' | 'review' | null>(null);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const label = action === 'freeze' ? t('ambFreeze') : action === 'unfreeze' ? t('ambUnfreeze') : t('ambClearReview');
  return (
    <>
      <div className="page-head">
        <h1>{t('ambDetail')}</h1>
      </div>
      <AmbassadorView data={data} onAction={setAction} />
      {action && (
        <FormDialog
          title={label}
          intro={action === 'freeze' ? <p className="muted small">{t('ambFreezeIntro')}</p> : undefined}
          fields={action === 'freeze' ? [reasonField(t)] : [reasonField(t), codeField(t)]}
          confirmLabel={label}
          danger={action === 'freeze'}
          submit={(v) => api.post(`/admin/ambassadors/${id}/${action === 'review' ? 'clear-review' : action}`, v)}
          onClose={() => setAction(null)}
          onDone={() => {
            setAction(null);
            toast(t('ambDone'));
            reload();
          }}
        />
      )}
    </>
  );
}

/** One application (pure: rendered in the tests). */
export function ApplicationCard({ app, onApprove, onReject }: { app: AmbassadorApplicationRow; onApprove: () => void; onReject: () => void }) {
  const { t, lang, can } = useApp();
  const keyed = useKeyed();
  return (
    <div className="card" data-amb-application={app.id}>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <UserCell username={app.user.username} displayName={app.user.displayName} avatarUrl={app.user.avatarUrl} />
        <span className="badge">{keyed('ambAppStatus', app.status)}</span>
      </div>
      {app.creator && <span className="badge info">{t('ambCreatorTag')}</span>}
      <dl className="kv">
        <dt>{t('ambColCountry')}</dt>
        <dd>{app.country}</dd>
        <dt>{t('ambAudience')}</dt>
        <dd className="mono">{formatNumber(app.audienceSize, lang)}</dd>
        <dt>{t('ambLinks')}</dt>
        <dd>
          {app.links.map((l) => (
            <div key={l} className="ltr small">
              <a href={l} target="_blank" rel="noopener noreferrer nofollow">
                {l}
              </a>
            </div>
          ))}
        </dd>
        <dt>{t('ambMotivation')}</dt>
        <dd>{app.motivation}</dd>
        {app.rejectReason && (
          <>
            <dt>{t('ambReject')}</dt>
            <dd>{app.rejectReason}</dd>
          </>
        )}
      </dl>
      <p className="muted small">{formatDate(app.createdAt, lang)}</p>
      {app.status === 'PENDING' && can('ambassadors.manage') && (
        <div className="row">
          <button className="btn primary" onClick={onApprove} data-amb-approve>
            {t('ambApprove')}
          </button>
          <button className="btn danger" onClick={onReject} data-amb-reject>
            {t('ambReject')}
          </button>
        </div>
      )}
    </div>
  );
}

const APP_TABS = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'] as const;

export function AmbassadorApplications() {
  const { t, toast } = useApp();
  const [tab, setTab] = useState<(typeof APP_TABS)[number]>('PENDING');
  const [rejecting, setRejecting] = useState<string | null>(null);
  const [failure, setFailure] = useState<unknown>(null);
  const { data, error, loading, reload } = useAsync(
    () => api.get<{ data: AmbassadorApplicationRow[] }>('/admin/ambassador-applications', { status: tab }),
    [tab],
  );
  return (
    <>
      <div className="page-head">
        <h1>{t('ambApplicationsTitle')}</h1>
        <StatusTabs value={tab} options={APP_TABS} onChange={setTab} label={(s) => t(`ambAppStatus${s}`)} />
      </div>
      <ErrorAlert error={error ?? failure} />
      {loading && !data ? (
        <Loading />
      ) : (
        <div className="grid cols-2">
          {data?.data.map((a) => (
            <ApplicationCard
              key={a.id}
              app={a}
              onApprove={() => {
                setFailure(null);
                api.post(`/admin/ambassador-applications/${a.id}/approve`).then(() => {
                  toast(t('ambDone'));
                  reload();
                }, setFailure);
              }}
              onReject={() => setRejecting(a.id)}
            />
          ))}
        </div>
      )}
      {rejecting && (
        <FormDialog
          title={t('ambReject')}
          fields={[reasonField(t, t('ambRejectReason'))]}
          confirmLabel={t('ambReject')}
          danger
          submit={(v) => api.post(`/admin/ambassador-applications/${rejecting}/reject`, v)}
          onClose={() => setRejecting(null)}
          onDone={() => {
            setRejecting(null);
            reload();
          }}
        />
      )}
    </>
  );
}

/** One campaign (pure: rendered in the tests). */
export function CampaignCard({ c, onEdit }: { c: AmbassadorCampaign; onEdit?: () => void }) {
  const { t } = useApp();
  return (
    <div className="card" data-amb-campaign={c.id}>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <h2>{c.title}</h2>
        {onEdit && (
          <button className="btn" onClick={onEdit}>
            {t('ambEditCampaign')}
          </button>
        )}
      </div>
      <p className="muted small">
        <span className="ltr">
          {c.startsOn} → {c.endsOn}
        </span>
        {c.country ? ` · ${c.country}` : ''}
      </p>
      {c.notes && <p>{c.notes}</p>}
      <p className="small">
        {t('ambLinkedAmbassadors')}: {c.ambassadors.length === 0 ? '—' : c.ambassadors.map((a) => `@${a.username}`).join(' · ')}
      </p>
    </div>
  );
}

interface CampaignDraft {
  title: string;
  country: string;
  startsOn: string;
  endsOn: string;
  notes: string;
  ambassadors: string[];
}

function CampaignEditor({ draft, onChange, ambassadors }: { draft: CampaignDraft; onChange: (d: CampaignDraft) => void; ambassadors: AmbassadorRow[] }) {
  const { t } = useApp();
  return (
    <div className="card" data-amb-campaign-editor>
      <div className="field">
        <label>{t('ambCampaignTitle')}</label>
        <input value={draft.title} maxLength={120} onChange={(e) => onChange({ ...draft, title: e.target.value })} />
      </div>
      <div className="row">
        <div className="field">
          <label>{t('ambStartsOn')}</label>
          <input type="date" value={draft.startsOn} onChange={(e) => onChange({ ...draft, startsOn: e.target.value })} />
        </div>
        <div className="field">
          <label>{t('ambEndsOn')}</label>
          <input type="date" value={draft.endsOn} onChange={(e) => onChange({ ...draft, endsOn: e.target.value })} />
        </div>
        <div className="field">
          <label>{t('ambColCountry')}</label>
          <input value={draft.country} maxLength={2} className="ltr" onChange={(e) => onChange({ ...draft, country: e.target.value.toUpperCase() })} />
        </div>
      </div>
      <div className="field">
        <label>{t('ambNotes')}</label>
        <textarea value={draft.notes} maxLength={2000} onChange={(e) => onChange({ ...draft, notes: e.target.value })} />
      </div>
      <div className="field">
        <label>{t('ambLinkedAmbassadors')}</label>
        {ambassadors.map((a) => (
          <label key={a.user.id} className="row">
            <input
              type="checkbox"
              checked={draft.ambassadors.includes(a.user.id)}
              onChange={(e) =>
                onChange({
                  ...draft,
                  ambassadors: e.target.checked ? [...draft.ambassadors, a.user.id] : draft.ambassadors.filter((x) => x !== a.user.id),
                })
              }
            />
            {a.user.displayName} <span className="ltr muted">@{a.user.username}</span>
          </label>
        ))}
      </div>
    </div>
  );
}

/** The body of a campaign save (the empty country is null). */
export function campaignBody(d: CampaignDraft) {
  return {
    title: d.title.trim(),
    country: d.country.trim() === '' ? null : d.country.trim(),
    startsOn: d.startsOn,
    endsOn: d.endsOn,
    notes: d.notes.trim(),
    ambassadors: d.ambassadors,
  };
}

export function AmbassadorCampaigns() {
  const { t, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<{ data: AmbassadorCampaign[] }>('/admin/ambassador-campaigns'), []);
  const people = useAsync(() => api.get<{ data: AmbassadorRow[] }>('/admin/ambassadors'), []);
  const [editing, setEditing] = useState<{ id: string | null; draft: CampaignDraft } | null>(null);
  const [failure, setFailure] = useState<unknown>(null);
  const manage = can('ambassadors.manage');
  const save = () => {
    if (!editing) return;
    setFailure(null);
    const body = campaignBody(editing.draft);
    const call = editing.id ? api.put(`/admin/ambassador-campaigns/${editing.id}`, body) : api.post('/admin/ambassador-campaigns', body);
    call.then(() => {
      setEditing(null);
      toast(t('ambDone'));
      reload();
    }, setFailure);
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('ambCampaignsTitle')}</h1>
          <p className="muted small">{t('ambCampaignsSubtitle')}</p>
        </div>
        {manage && !editing && (
          <button
            className="btn primary"
            onClick={() => setEditing({ id: null, draft: { title: '', country: '', startsOn: '', endsOn: '', notes: '', ambassadors: [] } })}
          >
            {t('ambNewCampaign')}
          </button>
        )}
      </div>
      <ErrorAlert error={error ?? failure} />
      {editing && (
        <>
          <CampaignEditor draft={editing.draft} onChange={(draft) => setEditing({ ...editing, draft })} ambassadors={people.data?.data ?? []} />
          <div className="row">
            <button className="btn" onClick={() => setEditing(null)}>
              {t('cancel')}
            </button>
            <button className="btn primary" disabled={!editing.draft.title.trim() || !editing.draft.startsOn || !editing.draft.endsOn} onClick={save}>
              {t('ambSave')}
            </button>
          </div>
        </>
      )}
      {loading && !data ? (
        <Loading />
      ) : data && data.data.length === 0 ? (
        <p className="muted">{t('ambNoCampaigns')}</p>
      ) : (
        <div className="grid cols-2">
          {data?.data.map((c) => (
            <CampaignCard
              key={c.id}
              c={c}
              onEdit={
                manage
                  ? () =>
                      setEditing({
                        id: c.id,
                        draft: { title: c.title, country: c.country ?? '', startsOn: c.startsOn, endsOn: c.endsOn, notes: c.notes, ambassadors: c.ambassadors.map((a) => a.id) },
                      })
                  : undefined
              }
            />
          ))}
        </div>
      )}
    </>
  );
}

type Draft = Omit<AmbassadorSettings, 'updatedAt'>;
const NUMBER_FIELDS: readonly (readonly [Exclude<keyof Draft, 'enabled' | 'levels'>, Key])[] = [
  ['attributionWindowDays', 'ambAttributionWindowDays'],
  ['holdDays', 'ambHoldDays'],
  ['minActiveDays', 'ambMinActiveDays'],
  ['minActiveTopupCoins', 'ambMinActiveTopupCoins'],
  ['monthlyCapCherries', 'ambMonthlyCapCherries'],
  ['velocityMaxPerDay', 'ambVelocityMaxPerDay'],
  ['ipClusterMax', 'ambIpClusterMax'],
  ['ipClusterWindowDays', 'ambIpClusterWindowDays'],
];

/** The fields of `draft` that differ from `saved` (the PUT body sends only those). */
export function ambassadorSettingsChanges(saved: Draft, draft: Draft): Partial<Draft> {
  const out: Partial<Draft> = {};
  if (saved.enabled !== draft.enabled) out.enabled = draft.enabled;
  for (const [k] of NUMBER_FIELDS) if (saved[k] !== draft[k]) out[k] = draft[k];
  if (JSON.stringify(saved.levels) !== JSON.stringify(draft.levels)) out.levels = draft.levels;
  return out;
}

/** The server's level rules (§10.179.6), checked before sending. */
export function levelsValid(levels: AmbassadorLevel[]): boolean {
  if (levels.length < 1 || levels.length > 10) return false;
  if (new Set(levels.map((l) => l.code)).size !== levels.length) return false;
  if (!levels.every((l) => /^[A-Z][A-Z0-9_]{1,15}$/.test(l.code) && l.commissionBps >= 0 && l.commissionBps <= 5000)) return false;
  if (levels[0]!.minActiveReferrals !== 0 || levels[0]!.minTopupCoins !== 0) return false;
  for (let i = 1; i < levels.length; i++) {
    const a = levels[i - 1]!;
    const b = levels[i]!;
    if (b.minActiveReferrals < a.minActiveReferrals || b.minTopupCoins < a.minTopupCoins) return false;
    if (b.minActiveReferrals === a.minActiveReferrals && b.minTopupCoins === a.minTopupCoins) return false;
    if (b.commissionBps < a.commissionBps) return false;
  }
  return true;
}

/** A reward as the API takes it (only the fields of its kind). */
export function rewardOf(kind: RewardKind, amount: number, ref: string): AmbassadorLevel['reward'] {
  if (kind === 'NONE') return { kind };
  if (kind === 'COINS') return { kind, amount: Math.max(1, amount) };
  if (kind === 'VIP_DAYS') return { kind, amount: Math.max(1, amount), vipTier: ref || 'VIP_1' };
  return { kind, amount: Math.max(1, amount), itemCode: ref };
}

/** The settings form (pure: rendered in the tests). */
export function AmbassadorSettingsForm({ saved, draft, onChange, onSave }: { saved: AmbassadorSettings; draft: Draft; onChange: (d: Draft) => void; onSave: () => void }) {
  const { t, lang } = useApp();
  const changes = ambassadorSettingsChanges(saved, draft);
  const valid = levelsValid(draft.levels);
  const num = (raw: string) => (raw.trim() === '' ? 0 : Math.max(0, Math.floor(Number(raw)) || 0));
  const setLevel = (i: number, l: AmbassadorLevel) => onChange({ ...draft, levels: draft.levels.map((x, j) => (j === i ? l : x)) });
  return (
    <div className="card" data-amb-settings>
      {!saved.enabled && <div className="alert info">{t('ambOff')}</div>}
      <div className="field">
        <label className="row">
          <input type="checkbox" checked={draft.enabled} onChange={(e) => onChange({ ...draft, enabled: e.target.checked })} data-field="enabled" />
          {t('ambEnabled')}
        </label>
        <p className="muted small">{t('ambEnabledHint')}</p>
      </div>
      <div className="grid cols-2">
        {NUMBER_FIELDS.map(([k, label]) => (
          <div className="field" key={k}>
            <label htmlFor={`amb-${k}`}>{t(label)}</label>
            <input id={`amb-${k}`} type="number" min={0} className="ltr mono" value={draft[k]} onChange={(e) => onChange({ ...draft, [k]: num(e.target.value) })} data-field={k} />
          </div>
        ))}
      </div>
      <h2>{t('ambLevels')}</h2>
      <div className="table-wrap">
        <table className="table" data-amb-levels>
          <thead>
            <tr>
              <th>{t('ambLevelCode')}</th>
              <th>{t('ambMinActive')}</th>
              <th>{t('ambMinTopup')}</th>
              <th>{t('ambCommissionPct')}</th>
              <th>{t('ambRewardKind')}</th>
              <th>{t('ambRewardAmount')}</th>
              <th>{t('ambRewardRef')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {draft.levels.map((l, i) => (
              <tr key={i} data-amb-level={l.code}>
                <td>
                  <input className="ltr mono" value={l.code} maxLength={16} onChange={(e) => setLevel(i, { ...l, code: e.target.value.toUpperCase() })} />
                </td>
                <td>
                  <input type="number" min={0} className="ltr mono" value={l.minActiveReferrals} onChange={(e) => setLevel(i, { ...l, minActiveReferrals: num(e.target.value) })} />
                </td>
                <td>
                  <input type="number" min={0} className="ltr mono" value={l.minTopupCoins} onChange={(e) => setLevel(i, { ...l, minTopupCoins: num(e.target.value) })} />
                </td>
                <td>
                  <input
                    type="number"
                    min={0}
                    max={50}
                    step={0.1}
                    className="ltr mono"
                    value={l.commissionBps / 100}
                    onChange={(e) => setLevel(i, { ...l, commissionBps: Math.round(Math.max(0, Number(e.target.value) || 0) * 100) })}
                    data-bps={l.commissionBps}
                  />
                </td>
                <td>
                  <select value={l.reward.kind} onChange={(e) => setLevel(i, { ...l, reward: rewardOf(e.target.value as RewardKind, l.reward.amount ?? 1, l.reward.vipTier ?? l.reward.itemCode ?? '') })}>
                    {(['NONE', 'COINS', 'VIP_DAYS', 'BAG_ITEM'] as const).map((k) => (
                      <option key={k} value={k}>
                        {t(`ambKind${k}`)}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  {l.reward.kind !== 'NONE' && (
                    <input type="number" min={1} className="ltr mono" value={l.reward.amount ?? 1} onChange={(e) => setLevel(i, { ...l, reward: rewardOf(l.reward.kind, num(e.target.value), l.reward.vipTier ?? l.reward.itemCode ?? '') })} />
                  )}
                </td>
                <td>
                  {(l.reward.kind === 'VIP_DAYS' || l.reward.kind === 'BAG_ITEM') && (
                    <input className="ltr mono" value={l.reward.vipTier ?? l.reward.itemCode ?? ''} onChange={(e) => setLevel(i, { ...l, reward: rewardOf(l.reward.kind, l.reward.amount ?? 1, e.target.value) })} />
                  )}
                </td>
                <td>
                  {i > 0 && (
                    <button className="btn" onClick={() => onChange({ ...draft, levels: draft.levels.filter((_, j) => j !== i) })}>
                      {t('ambRemove')}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {draft.levels.length < 10 && (
        <button
          className="btn"
          onClick={() => {
            const last = draft.levels.at(-1)!;
            onChange({
              ...draft,
              levels: [...draft.levels, { code: `L${draft.levels.length + 1}X`, minActiveReferrals: last.minActiveReferrals + 1, minTopupCoins: last.minTopupCoins, commissionBps: last.commissionBps, reward: { kind: 'NONE' } }],
            });
          }}
        >
          {t('ambAddLevel')}
        </button>
      )}
      {!valid && <div className="alert error">{t('ambLevelsInvalid')}</div>}
      <p className="muted small">
        {t('ambUpdatedAt')}: <span className="date">{formatDate(saved.updatedAt, lang)}</span>
      </p>
      <button className="btn primary" disabled={!valid || Object.keys(changes).length === 0} onClick={onSave} data-amb-save>
        {Object.keys(changes).length === 0 ? t('ambNoChange') : t('ambSave')}
      </button>
    </div>
  );
}

export function AmbassadorSettingsPage() {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AmbassadorSettings>('/admin/ambassador-settings'), []);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const current: Draft = draft ?? data;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('ambSettingsTitle')}</h1>
          <p className="muted small">{t('ambSettingsSubtitle')}</p>
        </div>
      </div>
      <AmbassadorSettingsForm saved={data} draft={current} onChange={setDraft} onSave={() => setSaving(true)} />
      {saving && (
        <FormDialog
          title={t('ambSave')}
          intro={<p className="muted small">{t('ambSaveIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('ambSave')}
          submit={(v) => api.put('/admin/ambassador-settings', { ...ambassadorSettingsChanges(data, current), ...v })}
          onClose={() => setSaving(false)}
          onDone={() => {
            setSaving(false);
            setDraft(null);
            toast(t('ambSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}
