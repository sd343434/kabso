import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, UserCell, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { PanelRole } from '../types';
import { AgencyBanDialog } from './AgencyBan';

/**
 * D285 (owner, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب».
 *  - «استقطاباتي» (`recruits.mine`: MODERATION, BD): the signed-in staff member's OWN recruits by type with their
 *    status, the profit they generated and the commissions paid (never another staff member's);
 *  - «الاستقطاب» (`recruits.view` / `recruits.manage`: OWNER): per staff member the recruits by type, each recruit's
 *    profit and the commissions paid, the shares per type (the code again and a reason) and the reassignment;
 *  - «طلبات صناع المحتوى» (`creators.applications` / `creators.decide`: OWNER, SUPPORT).
 */

export const RECRUIT_TYPES = ['HOST', 'AGENCY', 'RECHARGE_AGENT', 'CREATOR'] as const;
export type RecruitType = (typeof RECRUIT_TYPES)[number];
export type RecruitCounts = Record<RecruitType, number> & { total: number };
export type RecruitBps = Record<RecruitType, number>;

interface Summary {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}
export interface StaffRecruit {
  id: string;
  type: RecruitType;
  recruit: Summary;
  status: 'ACTIVE' | 'INACTIVE';
  activatedAt: string;
  profitUsd: number;
  profitUsd30d: number;
  commissionCherries: number;
  lastDay: string | null;
}
export interface AdminRecruit extends StaffRecruit {
  recruiter: Summary;
  reassignedAt: string | null;
}
interface MyRecruits {
  counts: RecruitCounts;
  commissionCherries: number;
  bps: RecruitBps;
  data: StaffRecruit[];
}
interface StaffRow {
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  staffId: string | null;
  status: string;
  roles: PanelRole[];
  canRecruit: boolean;
  recruits: RecruitCounts;
  commissionCherries: number;
  profitUsd: number;
}
interface Settings {
  bps: RecruitBps;
  defaults: RecruitBps;
  updatedAt: string;
}
interface CommissionDay {
  day: string;
  recruiter: Summary;
  profitUsd: number;
  bps: number;
  cherries: number;
  skipped: string | null;
}

type T = ReturnType<typeof useApp>['t'];

/** Basis points as a percentage: 100 → «1%», 75 → «0.75%» (pure: tested). */
export function bpsPercent(bps: number): string {
  const v = bps / 100;
  return `${Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')}%`;
}

/** «2 مضيف · 1 وكالة» — the non-zero types (pure: tested). */
export function recruitBreakdown(c: RecruitCounts, t: T): string {
  return RECRUIT_TYPES.filter((k) => c[k] > 0)
    .map((k) => `${c[k]} ${t(`recruitType${k}`)}`)
    .join(' · ');
}

/** The shares that changed, in the API's body names (pure: tested). */
export function shareChanges(saved: RecruitBps, draft: RecruitBps): Record<string, number> {
  const names: Record<RecruitType, string> = {
    HOST: 'host',
    AGENCY: 'agency',
    RECHARGE_AGENT: 'rechargeAgent',
    CREATOR: 'creator',
  };
  const out: Record<string, number> = {};
  for (const k of RECRUIT_TYPES) if (draft[k] !== saved[k]) out[names[k]] = draft[k];
  return out;
}

function usd(v: number, lang: 'ar' | 'en'): string {
  return `$${formatNumber(Math.round(v * 100) / 100, lang)}`;
}

function TypeTabs({ value, onChange, counts }: { value: RecruitType | null; onChange: (v: RecruitType | null) => void; counts?: RecruitCounts }) {
  const { t } = useApp();
  return (
    <div className="segmented wrap" role="group" aria-label={t('recruitsType')}>
      <button type="button" aria-pressed={value === null} onClick={() => onChange(null)}>
        {t('recruitsAll')}
        {counts ? ` (${counts.total})` : ''}
      </button>
      {RECRUIT_TYPES.map((k) => (
        <button key={k} type="button" aria-pressed={value === k} onClick={() => onChange(k)} data-type={k}>
          {t(`recruitType${k}`)}
          {counts ? ` (${counts[k]})` : ''}
        </button>
      ))}
    </div>
  );
}

function RecruitTable({
  rows,
  withRecruiter,
  onOpen,
  onReassign,
}: {
  rows: (StaffRecruit | AdminRecruit)[];
  withRecruiter?: boolean;
  onOpen: (r: StaffRecruit) => void;
  onReassign?: (r: AdminRecruit) => void;
}) {
  const { t, lang } = useApp();
  if (rows.length === 0) return <p className="muted" data-empty>{t('recruitsNone')}</p>;
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            <th>{t('recruitsRecruit')}</th>
            <th>{t('recruitsType')}</th>
            {withRecruiter && <th>{t('recruitsRecruiter')}</th>}
            <th>{t('recruitsStatus')}</th>
            <th>{t('recruitsActivated')}</th>
            <th>{t('recruitsProfit')}</th>
            <th>{t('recruitsProfit30')}</th>
            <th>{t('recruitsCommission')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} data-recruit={r.id} data-type={r.type}>
              <td>
                <UserCell username={r.recruit.username} displayName={r.recruit.displayName} avatarUrl={r.recruit.avatarUrl} />
              </td>
              <td>
                <span className="badge info">{t(`recruitType${r.type}`)}</span>
              </td>
              {withRecruiter && (
                <td>
                  <UserCell
                    username={(r as AdminRecruit).recruiter.username}
                    displayName={(r as AdminRecruit).recruiter.displayName}
                    avatarUrl={(r as AdminRecruit).recruiter.avatarUrl}
                  />
                  {(r as AdminRecruit).reassignedAt ? <span className="badge warn">{t('recruitsReassigned')}</span> : null}
                </td>
              )}
              <td>
                <span className={`badge ${r.status === 'ACTIVE' ? 'ok' : ''}`}>{t(`recruitStatus${r.status}`)}</span>
              </td>
              <td className="date">{formatDate(r.activatedAt, lang)}</td>
              <td className="num">{usd(r.profitUsd, lang)}</td>
              <td className="num">{usd(r.profitUsd30d, lang)}</td>
              <td className="num">{formatNumber(r.commissionCherries, lang)}</td>
              <td>
                <div className="row">
                  <button className="btn small ghost" onClick={() => onOpen(r)}>
                    {t('recruitsDays')}
                  </button>
                  {onReassign && (
                    <button className="btn small" data-reassign={r.id} onClick={() => onReassign(r as AdminRecruit)}>
                      {t('recruitsReassign')}
                    </button>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DaysPanel({ path, onClose }: { path: string; onClose: () => void }) {
  const { t, lang } = useApp();
  const { data, error, loading } = useAsync(() => api.get<{ data: CommissionDay[] }>(path), [path]);
  return (
    <div className="card" data-days>
      <div className="row">
        <h3 className="grow">{t('recruitsDays')}</h3>
        <button className="btn small ghost" onClick={onClose}>
          {t('cancel')}
        </button>
      </div>
      <ErrorAlert error={error} />
      {loading ? (
        <Loading />
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>{t('recruitsDay')}</th>
              <th>{t('recruitsRecruiter')}</th>
              <th>{t('recruitsProfit')}</th>
              <th>%</th>
              <th>{t('recruitsCommission')}</th>
            </tr>
          </thead>
          <tbody>
            {(data?.data ?? []).map((d) => (
              <tr key={d.day}>
                <td className="ltr">{d.day}</td>
                <td>@{d.recruiter.username}</td>
                <td className="num">{usd(d.profitUsd, lang)}</td>
                <td className="num">{bpsPercent(d.bps)}</td>
                <td className="num">{d.skipped ? <span className="muted">{t('recruitsSkipped')}</span> : formatNumber(d.cherries, lang)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

/** «استقطاباتي» — the signed-in staff member's own recruits (MODERATION, BD). */
export function MyRecruits() {
  const { t, lang } = useApp();
  const [type, setType] = useState<RecruitType | null>(null);
  const [open, setOpen] = useState<StaffRecruit | null>(null);
  const { data, error, loading } = useAsync(() => api.get<MyRecruits>('/admin/recruits/mine'), []);
  const rows = (data?.data ?? []).filter((r) => type === null || r.type === type);
  return (
    <div className="page" data-page="my-recruits">
      <h1>{t('navMyRecruits')}</h1>
      <p className="muted">{t('recruitsMineIntro')}</p>
      <ErrorAlert error={error} />
      {loading || !data ? (
        <Loading />
      ) : (
        <>
          <div className="row stats">
            <div className="card stat">
              <div className="muted small">{t('recruitsTitle')}</div>
              <div className="strong" data-total>{formatNumber(data.counts.total, lang)}</div>
            </div>
            <div className="card stat">
              <div className="muted small">{t('recruitsMyCommission')}</div>
              <div className="strong" data-commission>{formatNumber(data.commissionCherries, lang)}</div>
            </div>
            <div className="card stat">
              <div className="muted small">{t('recruitsShares')}</div>
              <div className="small" data-shares>
                {RECRUIT_TYPES.map((k) => t('recruitsShareOf', { type: t(`recruitType${k}`), pct: bpsPercent(data.bps[k]) })).join(' · ')}
              </div>
            </div>
          </div>
          <TypeTabs value={type} onChange={setType} counts={data.counts} />
          <RecruitTable rows={rows} onOpen={setOpen} />
          {open && <DaysPanel path={`/admin/recruits/mine/${open.id}/commissions`} onClose={() => setOpen(null)} />}
        </>
      )}
    </div>
  );
}

function SettingsCard({ settings, onSaved }: { settings: Settings; onSaved: () => void }) {
  const { t, can, toast } = useApp();
  const [draft, setDraft] = useState<RecruitBps>(settings.bps);
  const [confirm, setConfirm] = useState(false);
  const changes = shareChanges(settings.bps, draft);
  const valid = RECRUIT_TYPES.every((k) => Number.isInteger(draft[k]) && draft[k] >= 0 && draft[k] <= 2000);
  return (
    <div className="card" data-recruit-settings>
      <h2>{t('recruitsSettings')}</h2>
      <p className="muted small">{t('recruitsSettingsIntro')}</p>
      <div className="grid-4">
        {RECRUIT_TYPES.map((k) => (
          <div className="field" key={k}>
            <label htmlFor={`bps-${k}`}>
              {t(`recruitType${k}`)} — {bpsPercent(draft[k])}
            </label>
            <input
              id={`bps-${k}`}
              type="number"
              min={0}
              max={2000}
              step={5}
              disabled={!can('recruits.manage')}
              value={draft[k]}
              onChange={(e) => setDraft((d) => ({ ...d, [k]: Math.trunc(Number(e.target.value)) }))}
            />
            <span className="hint">{t('recruitsDefault', { pct: bpsPercent(settings.defaults[k]) })}</span>
          </div>
        ))}
      </div>
      <p className="muted small">{t('recruitsBpsHint')}</p>
      {can('recruits.manage') && (
        <button className="btn primary" disabled={!valid || Object.keys(changes).length === 0} onClick={() => setConfirm(true)}>
          {t('recruitsSave')}
        </button>
      )}
      {confirm && (
        <FormDialog
          title={t('recruitsSettings')}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('recruitsSave')}
          submit={(v) => api.put('/admin/recruits/settings', { ...changes, reason: v.reason, totpCode: v.totpCode })}
          onClose={() => setConfirm(false)}
          onDone={() => {
            setConfirm(false);
            toast(t('recruitsSaved'));
            onSaved();
          }}
        />
      )}
    </div>
  );
}

/** «الاستقطاب» — the OWNER's view of every staff member's recruits. */
/** D343 (§10.142): one account created with a supervisor's staff ID (`AdminSignupRecruit`). */
export interface SignupRecruit {
  user: Summary;
  recruiter: Summary;
  code: string;
  status: 'GRANTED' | 'WITHHELD';
  withholdReason: 'DEVICE_HAD_ACCOUNT' | 'EMAIL_HAD_ACCOUNT' | 'RECRUITER_INACTIVE' | null;
  createdAt: string;
}

/** D343: «التسجيل برمز المشرف» — credited or withheld, and why. */
export function SignupRecruitsTable({ rows }: { rows: SignupRecruit[] }) {
  const { t, lang } = useApp();
  if (rows.length === 0) return <p className="muted">{t('signupRecruitsNone')}</p>;
  return (
    <div className="table-wrap">
      <table className="table" data-signup-recruits>
        <thead>
          <tr>
            <th>{t('signupRecruitsUser')}</th>
            <th>{t('recruitsRecruiter')}</th>
            <th>{t('signupRecruitsCode')}</th>
            <th>{t('signupRecruitsCredit')}</th>
            <th>{t('signupRecruitsAt')}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.user.id} data-status={r.status}>
              <td>
                <UserCell username={r.user.username} displayName={r.user.displayName} avatarUrl={r.user.avatarUrl} />
              </td>
              <td>
                <UserCell
                  username={r.recruiter.username}
                  displayName={r.recruiter.displayName}
                  avatarUrl={r.recruiter.avatarUrl}
                />
              </td>
              <td className="ltr">{r.code}</td>
              <td>
                <span className={`badge ${r.status === 'GRANTED' ? 'ok' : 'warn'}`}>{t(`signupCredit${r.status}`)}</span>
                {r.withholdReason && (
                  <div className="muted small" data-withhold-reason>
                    {t(`signupWithhold${r.withholdReason}`)}
                  </div>
                )}
              </td>
              <td>{formatDate(r.createdAt, lang)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Recruits() {
  const { t, lang, can } = useApp();
  const [staff, setStaff] = useState<string | null>(null);
  const [type, setType] = useState<RecruitType | null>(null);
  const [open, setOpen] = useState<StaffRecruit | null>(null);
  const [moving, setMoving] = useState<AdminRecruit | null>(null);
  const settings = useAsync(() => api.get<Settings>('/admin/recruits/settings'), []);
  const people = useAsync(() => api.get<{ data: StaffRow[] }>('/admin/recruits/staff'), []);
  const list = useAsync(
    () => api.get<{ data: AdminRecruit[] }>('/admin/recruits', { recruiter: staff, type }),
    [staff, type],
  );
  const signups = useAsync(
    () => api.get<{ data: SignupRecruit[] }>('/admin/recruits/signups', { recruiter: staff }),
    [staff],
  );
  return (
    <div className="page" data-page="recruits">
      <h1>{t('navRecruits')}</h1>
      <ErrorAlert error={settings.error ?? people.error ?? list.error} />
      {settings.data && <SettingsCard key={settings.data.updatedAt} settings={settings.data} onSaved={settings.reload} />}
      <div className="card">
        <h2>{t('recruitsStaff')}</h2>
        {people.loading ? (
          <Loading />
        ) : (
          <table className="table" data-staff-table>
            <thead>
              <tr>
                <th>{t('recruitsRecruiter')}</th>
                <th>ID</th>
                {RECRUIT_TYPES.map((k) => (
                  <th key={k}>{t(`recruitType${k}`)}</th>
                ))}
                <th>{t('recruitsProfit')}</th>
                <th>{t('recruitsCommission')}</th>
              </tr>
            </thead>
            <tbody>
              {(people.data?.data ?? [])
                .filter((p) => p.canRecruit || p.recruits.total > 0)
                .map((p) => (
                  <tr
                    key={p.userId}
                    data-staff={p.userId}
                    aria-selected={staff === p.userId}
                    className="clickable"
                    onClick={() => setStaff(staff === p.userId ? null : p.userId)}
                  >
                    <td>
                      <UserCell username={p.username} displayName={p.displayName} avatarUrl={p.avatarUrl} />
                      {p.roles.map((r) => (
                        <span key={r} className="badge info">
                          {t(`role${r}`)}
                        </span>
                      ))}
                    </td>
                    <td className="ltr">{p.staffId ?? '—'}</td>
                    {RECRUIT_TYPES.map((k) => (
                      <td key={k} className="num">
                        {p.recruits[k]}
                      </td>
                    ))}
                    <td className="num">{usd(p.profitUsd, lang)}</td>
                    <td className="num">{formatNumber(p.commissionCherries, lang)}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        )}
      </div>
      <TypeTabs value={type} onChange={setType} />
      {list.loading ? (
        <Loading />
      ) : (
        <RecruitTable
          rows={list.data?.data ?? []}
          withRecruiter
          onOpen={setOpen}
          onReassign={can('recruits.manage') ? setMoving : undefined}
        />
      )}
      <div className="card" data-signup-card>
        <h2>{t('signupRecruitsTitle')}</h2>
        <p className="muted small">{t('signupRecruitsIntro')}</p>
        <ErrorAlert error={signups.error} />
        {signups.loading ? <Loading /> : <SignupRecruitsTable rows={signups.data?.data ?? []} />}
      </div>
      {open && <DaysPanel path={`/admin/recruits/${open.id}/commissions`} onClose={() => setOpen(null)} />}
      {moving && (
        <FormDialog
          title={t('recruitsReassign')}
          intro={<p className="muted small">{t('recruitsReassignHint')}</p>}
          fields={[
            { name: 'recruiter', label: t('recruitsReassignTo'), maxLength: 64 },
            reasonField(t),
            codeField(t),
          ]}
          confirmLabel={t('recruitsReassign')}
          submit={(v) =>
            api.post(`/admin/recruits/${moving.id}/reassign`, {
              recruiter: v.recruiter,
              reason: v.reason,
              totpCode: v.totpCode,
            })
          }
          onClose={() => setMoving(null)}
          onDone={() => {
            setMoving(null);
            list.reload();
            people.reload();
          }}
        />
      )}
    </div>
  );
}

export interface CreatorApp {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED' | 'REVOKED';
  /** v1.82-live (D295): the person's own application or an agency owner's activation. */
  source?: 'APPLICATION' | 'AGENCY';
  revokedAt?: string | null;
  memberActive?: boolean;
  activatedBy?: {
    agencyId: string;
    agencyName: string | null;
    inviteCode: string;
    hostCode: string | null;
    owner: { id: string; username: string; displayName: string };
  } | null;
  revokeReason?: string | null;
  revokedBy?: string | null;
  country: string;
  category: string;
  links: string[];
  bio: string | null;
  recruiter: { staffId: string | null; displayName: string } | null;
  createdAt: string;
  rejectReason: string | null;
  user: { id: string; username: string; displayName: string };
}

/** v1.82-live (D295, §10.108): «فعّله وكيل: …» — the agency whose owner activated the person (a link to its page). */
export function CreatorActivatedBy({ app }: { app: CreatorApp }) {
  const { t } = useApp();
  if (!app.activatedBy) return null;
  const a = app.activatedBy;
  const agent = `${a.owner.displayName} (@${a.owner.username})`;
  return (
    <p className="small" data-activated-by={a.agencyId}>
      {t('creatorActivatedBy', { agent })} ·{' '}
      <a href={`/agencies/${a.agencyId}`} onClick={(e) => (e.preventDefault(), navigate(`/agencies/${a.agencyId}`))}>
        {t('creatorActivatedByAgency')}: <span className="mono">{a.hostCode ?? a.inviteCode}</span>
        {a.agencyName ? ` · ${a.agencyName}` : ''}
      </a>
    </p>
  );
}

/** «طلبات صناع المحتوى» (OWNER, SUPPORT). */
export function CreatorApplications() {
  const { t, lang, can, toast } = useApp();
  const [status, setStatus] = useState<CreatorApp['status']>('PENDING');
  const [rejecting, setRejecting] = useState<CreatorApp | null>(null);
  // v1.82-live (D295): the team ends a membership; the OWNER bans the activating agency.
  const [revoking, setRevoking] = useState<CreatorApp | null>(null);
  const [banning, setBanning] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<unknown>(null);
  const { data, error, loading, reload } = useAsync(
    () => api.get<{ data: CreatorApp[] }>('/admin/creator-applications', { status }),
    [status],
  );
  const approve = async (a: CreatorApp) => {
    setBusy(a.id);
    setActionError(null);
    try {
      await api.post(`/admin/creator-applications/${a.id}/approve`);
      reload();
    } catch (e) {
      setActionError(e);
    } finally {
      setBusy(null);
    }
  };
  return (
    <div className="page" data-page="creator-applications">
      <h1>{t('navCreatorApplications')}</h1>
      <p className="muted">{t('creatorAppsIntro')}</p>
      <div className="segmented wrap" role="group">
        {(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'REVOKED'] as const).map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {t(`status${s}` as never)}
          </button>
        ))}
      </div>
      <ErrorAlert error={error ?? actionError} />
      {loading ? (
        <Loading />
      ) : (data?.data ?? []).length === 0 ? (
        <p className="muted">{t('recruitsNone')}</p>
      ) : (
        (data?.data ?? []).map((a) => (
          <div className="card" key={a.id} data-creator-app={a.id}>
            <div className="row">
              <UserCell username={a.user.username} displayName={a.user.displayName} />
              {a.source && (
                <span className="badge" data-creator-source={a.source}>
                  {t(a.source === 'AGENCY' ? 'creatorSourceAGENCY' : 'creatorSourceAPPLICATION')}
                </span>
              )}
              {a.memberActive !== undefined && a.status !== 'PENDING' && (a.status === 'APPROVED' || a.status === 'REVOKED') && (
                <span className={`badge ${a.memberActive ? 'ok' : 'muted'}`}>
                  {t(a.memberActive ? 'creatorMemberActive' : 'creatorMemberEnded')}
                </span>
              )}
              <span className="grow" />
              <span className="date muted">{formatDate(a.createdAt, lang)}</span>
            </div>
            <CreatorActivatedBy app={a} />
            <dl className="kv small">
              <dt>{t('creatorAppCategory')}</dt>
              <dd>
                {t(`creatorCat${a.category}` as never)} · {a.country}
              </dd>
              <dt>{t('creatorAppLinks')}</dt>
              <dd className="ltr">
                {a.links.map((l) => (
                  <div key={l}>
                    <a href={l} target="_blank" rel="noreferrer noopener">
                      {l}
                    </a>
                  </div>
                ))}
              </dd>
              {a.bio ? (
                <>
                  <dt>{t('reason')}</dt>
                  <dd>{a.bio}</dd>
                </>
              ) : null}
              {a.recruiter ? (
                <>
                  <dt>{t('creatorAppRecruiter')}</dt>
                  <dd data-recruiter>
                    {a.recruiter.displayName} <span className="badge staff-id ltr">{a.recruiter.staffId}</span>
                  </dd>
                </>
              ) : null}
              {a.rejectReason ? (
                <>
                  <dt>{t('creatorReject')}</dt>
                  <dd>{a.rejectReason}</dd>
                </>
              ) : null}
              {a.revokeReason ? (
                <>
                  <dt>{t('creatorRevoke')}</dt>
                  <dd data-revoke-reason>
                    {a.revokeReason}
                    {a.revokedBy ? <span className="muted"> · {t('creatorRevokedBy', { name: a.revokedBy })}</span> : null}
                  </dd>
                </>
              ) : null}
            </dl>
            {a.memberActive && (can('creators.decide') || (a.activatedBy && can('agencies.ban'))) && (
              <div className="row">
                {can('creators.decide') && (
                  <button className="btn small danger" data-creator-revoke onClick={() => setRevoking(a)}>
                    {t('creatorRevoke')}
                  </button>
                )}
                {a.activatedBy && can('agencies.ban') && (
                  <button className="btn small danger" data-agency-ban onClick={() => setBanning(a.activatedBy!.agencyId)}>
                    {t('agencyBan')}
                  </button>
                )}
              </div>
            )}
            {a.status === 'PENDING' && can('creators.decide') && (
              <div className="row">
                <button className="btn primary small" disabled={busy === a.id} onClick={() => void approve(a)}>
                  {t('creatorApprove')}
                </button>
                <button className="btn small" onClick={() => setRejecting(a)}>
                  {t('creatorReject')}
                </button>
              </div>
            )}
          </div>
        ))
      )}
      {revoking && (
        <FormDialog
          title={t('creatorRevokeTitle')}
          intro={<p className="muted small">{t('creatorRevokeIntro')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('creatorRevoke')}
          danger
          submit={(v) => api.post(`/admin/creator-members/${revoking.user.id}/revoke`, { reason: v.reason })}
          onClose={() => setRevoking(null)}
          onDone={() => {
            setRevoking(null);
            reload();
          }}
        />
      )}
      {banning && (
        <AgencyBanDialog
          agencyId={banning}
          onClose={() => setBanning(null)}
          onDone={(r) => {
            setBanning(null);
            toast(
              r.alreadyBanned
                ? t('agencyBanAlready')
                : t('agencyBanDone', { forfeited: formatNumber(r.forfeitedCherries, lang) }),
            );
            reload();
          }}
        />
      )}
      {rejecting && (
        <FormDialog
          title={t('creatorRejectTitle')}
          fields={[reasonField(t)]}
          confirmLabel={t('creatorReject')}
          danger
          submit={(v) => api.post(`/admin/creator-applications/${rejecting.id}/reject`, { reason: v.reason })}
          onClose={() => setRejecting(null)}
          onDone={() => {
            setRejecting(null);
            reload();
          }}
        />
      )}
    </div>
  );
}
