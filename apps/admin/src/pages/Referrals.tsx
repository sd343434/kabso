import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { ReferralDetail as Detail, ReferralRow, ReferralSettings, ReferralStatus } from '../types';
import { DataTable } from '../ui/DataTable';
import { StatusTabs } from './Applications';

/**
 * «الدعوات» (v1.74-social, D217, CONVENTIONS §10.71): the referrals of «دعوة الأصدقاء» — the table (status tabs, CSV),
 * a referral with its rewards and the fraud signals (the read is audited), approve / void with a reason and the
 * authenticator code again (OWNER, FINANCE), and the settings page (every amount; OWNER, FINANCE with the code again;
 * SUPPORT reads).
 */
const STATUSES = ['PENDING', 'QUALIFIED', 'REJECTED', 'VOID', ''] as const;

function useReason() {
  const { t } = useApp();
  return (reason: string | null) => {
    if (!reason) return '—';
    const key = `refReason${reason}`;
    return isKey(key) ? t(key) : reason;
  };
}

export function Referrals() {
  const { t, lang } = useApp();
  const reasonText = useReason();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('PENDING');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('refTitle')}</h1>
          <p className="muted small">{t('refSubtitle')}</p>
        </div>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} label={(s) => t(`refStatus${s}` as never)} />
      </div>
      <DataTable<ReferralRow>
        id="referrals"
        endpoint="/admin/referrals"
        rowKey={(r) => r.id}
        extraQuery={{ status: status || undefined }}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        onRowClick={(r) => navigate(`/referrals/${r.id}`)}
        columns={[
          { key: 'inviter', label: 'refColInviter', render: (r) => <UserCell username={r.inviter.username} displayName={r.inviter.displayName} avatarUrl={r.inviter.avatarUrl} /> },
          { key: 'invitee', label: 'refColInvitee', render: (r) => <UserCell username={r.invitee.username} displayName={r.invitee.displayName} avatarUrl={r.invitee.avatarUrl} /> },
          { key: 'status', label: 'colStatus', render: (r) => <StatusBadge status={r.status} /> },
          { key: 'reason', label: 'refColReason', render: (r) => <span className="small">{reasonText(r.rejectReason ?? r.voidReason)}</span> },
          { key: 'source', label: 'refColSource', optional: true, render: (r) => t(`refSource${r.source}`) },
          { key: 'recharge', label: 'refColRecharge', optional: true, render: (r) => (r.firstRecharge ? '✓' : '—') },
          { key: 'pending', label: 'refColPending', render: (r) => <span className="mono">{formatNumber(r.pendingCherries, lang)}</span> },
          { key: 'credited', label: 'refColCredited', render: (r) => <span className="mono">{formatNumber(r.creditedCherries, lang)}</span> },
          { key: 'hold', label: 'refHoldUntil', sort: 'holdUntil', optional: true, render: (r) => <span className="date small">{formatDate(r.holdUntil, lang)}</span> },
          { key: 'created', label: 'colSubmitted', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
        ]}
      />
    </>
  );
}

/** A referral's fields, signals and rewards with the decision buttons (pure: rendered in the tests). */
export function ReferralView({ data, onApprove, onVoid }: { data: Detail; onApprove: () => void; onVoid: () => void }) {
  const { t, lang, can } = useApp();
  const reasonText = useReason();
  const decide = can('referrals.decide');
  const person = (p: Detail['inviter']) => (
    <a href={`/users/${p.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${p.id}`))}>
      {p.displayName} <span className="ltr">@{p.username}</span> <StatusBadge status={p.status} />
    </a>
  );
  return (
    <div className="grid cols-2" data-referral={data.id}>
      <div className="grid">
        <div className="card">
          <h2>{t('refDetail')}</h2>
          <dl className="kv">
            <dt>{t('refColInviter')}</dt>
            <dd>{person(data.inviter)}</dd>
            <dt>{t('refColInvitee')}</dt>
            <dd>{person(data.invitee)}</dd>
            <dt>{t('refCode')}</dt>
            <dd className="mono ltr">{data.code}</dd>
            <dt>{t('refColSource')}</dt>
            <dd>{t(`refSource${data.source}`)}</dd>
            <dt>{t('colStatus')}</dt>
            <dd>
              <StatusBadge status={data.status} />
            </dd>
            {data.rejectReason && (
              <>
                <dt>{t('refColReason')}</dt>
                <dd data-reject-reason>{reasonText(data.rejectReason)}</dd>
              </>
            )}
            {data.voidReason && (
              <>
                <dt>{t('refVoidedAt')}</dt>
                <dd>
                  {reasonText(data.voidReason)} · <span className="date small">{formatDate(data.voidedAt, lang)}</span>
                </dd>
              </>
            )}
            <dt>{t('refHoldUntil')}</dt>
            <dd className="date">{formatDate(data.holdUntil, lang)}</dd>
            {data.qualifiedAt && (
              <>
                <dt>{t('refQualifiedAt')}</dt>
                <dd className="date">{formatDate(data.qualifiedAt, lang)}</dd>
              </>
            )}
            <dt>{t('refColRecharge')}</dt>
            <dd className="date">{data.firstRechargeAt ? formatDate(data.firstRechargeAt, lang) : '—'}</dd>
            {data.decidedBy && (
              <>
                <dt>{t('refDecidedBy')}</dt>
                <dd>@{data.decidedBy.username}</dd>
              </>
            )}
          </dl>
          {decide && (
            <div className="row" style={{ marginTop: 16 }}>
              {data.status !== 'QUALIFIED' && (
                <button className="btn primary" onClick={onApprove} data-referral-approve>
                  {t('refApprove')}
                </button>
              )}
              {data.status !== 'VOID' && (
                <button className="btn danger" onClick={onVoid} data-referral-void>
                  {t('refVoid')}
                </button>
              )}
            </div>
          )}
        </div>
        <div className="card" data-referral-signals>
          <h2>{t('refSignals')}</h2>
          <dl className="kv">
            <dt>{t('refSignalInstall')}</dt>
            <dd>{data.signals.installId ? '✓' : '—'}</dd>
            <dt>{t('refSignalIp')}</dt>
            <dd className="mono ltr">{data.signals.ip ?? '—'}</dd>
            <dt>{t('refSignalSameDevice')}</dt>
            <dd>
              <span className={data.signals.sameDeviceReferrals > 0 ? 'badge bad' : 'badge'}>{formatNumber(data.signals.sameDeviceReferrals, lang)}</span>
            </dd>
            <dt>{t('refSignalSameEmail')}</dt>
            <dd>
              <span className={data.signals.sameEmailReferrals > 0 ? 'badge bad' : 'badge'}>{formatNumber(data.signals.sameEmailReferrals, lang)}</span>
            </dd>
          </dl>
        </div>
      </div>
      <div className="card" data-referral-rewards>
        <h2>{t('refRewards')}</h2>
        {data.rewards.length === 0 ? (
          <p className="muted">{t('refNoRewards')}</p>
        ) : (
          <ul className="plain-list">
            {data.rewards.map((w) => (
              <li key={w.id} className="row small" data-reward={w.kind}>
                <StatusBadge status={w.status} />
                <span>{t(`refReward${w.kind}`)}</span>
                <span className="mono">{formatNumber(w.cherries, lang)}</span>
                {w.baseCoins !== null && (
                  <span className="muted">
                    {formatNumber(w.baseCoins, lang)} · {w.rechargeReason}
                  </span>
                )}
                {w.voidReason && <span className="muted">{reasonText(w.voidReason)}</span>}
                {w.reversalShortfall !== null && w.reversalShortfall > 0 && (
                  <span className="badge bad">{t('refShortfall', { n: formatNumber(w.reversalShortfall, lang) })}</span>
                )}
                <span className="date muted">{formatDate(w.reversedAt ?? w.creditedAt ?? w.voidedAt ?? w.holdUntil, lang)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

/**
 * What «إلغاء الدعوة» takes back (owner 2026-11-01), shown in the dialog before the team confirms: the cherries, and per
 * person the balance and the part it does not cover (the balance goes below 0: a debt that blocks withdrawals).
 */
export function ClawbackNotice({ data }: { data: Detail }) {
  const { t, lang } = useApp();
  const c = data.voidClawback;
  if (c.cherries === 0) return <p className="small" data-clawback="none">{t('refClawbackNone')}</p>;
  const nameOf = (userId: string) =>
    userId === data.inviter.id ? `@${data.inviter.username}` : userId === data.invitee.id ? `@${data.invitee.username}` : userId;
  return (
    <div className="small" data-clawback={c.cherries}>
      <p>
        <strong>{t('refClawback', { n: formatNumber(c.cherries, lang), r: formatNumber(c.rewards, lang) })}</strong>
      </p>
      <ul className="plain-list">
        {c.people.map((p) => (
          <li key={p.userId} data-clawback-person={p.userId}>
            {t('refClawbackPerson', {
              who: nameOf(p.userId),
              n: formatNumber(p.cherries, lang),
              balance: formatNumber(p.balance, lang),
            })}
            {p.shortfall > 0 && (
              <span className="badge bad" data-clawback-shortfall={p.shortfall}>
                {' '}
                {t('refClawbackShortfall', { n: formatNumber(p.shortfall, lang) })}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

export function ReferralDetail({ id }: { id: string }) {
  const { t, lang, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<Detail>(`/admin/referrals/${id}`), [id]);
  const [action, setAction] = useState<'approve' | 'void' | null>(null);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('refDetail')}</h1>
          <div className="row small">
            <StatusBadge status={data.status as ReferralStatus} />
            <span className="date muted">{formatDate(data.createdAt, lang)}</span>
          </div>
        </div>
        <button className="btn" onClick={() => navigate('/referrals')}>
          {t('back')}
        </button>
      </div>
      <ReferralView data={data} onApprove={() => setAction('approve')} onVoid={() => setAction('void')} />
      {action && (
        <FormDialog
          title={t(action === 'approve' ? 'refApprove' : 'refVoid')}
          intro={
            <>
              <p className="muted small">{t(action === 'approve' ? 'refApproveIntro' : 'refVoidIntro')}</p>
              {action === 'void' && <ClawbackNotice data={data} />}
            </>
          }
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t(action === 'approve' ? 'refApprove' : 'refVoid')}
          danger={action === 'void'}
          submit={async (v) => {
            if (action === 'approve') {
              const r = await api.post<{ changed: boolean; creditedCherries: number }>(`/admin/referrals/${id}/approve`, v);
              toast(r.changed ? t('refApproved', { n: formatNumber(r.creditedCherries, lang) }) : t('refAlreadyQualified'));
            } else {
              const r = await api.post<{ changed: boolean; voidedRewards: number; reversedCherries: number; shortfall: number }>(
                `/admin/referrals/${id}/void`,
                v,
              );
              toast(
                r.changed
                  ? t('refVoided', {
                      n: r.voidedRewards,
                      c: formatNumber(r.reversedCherries, lang),
                      s: formatNumber(r.shortfall, lang),
                    })
                  : t('refAlreadyVoid'),
              );
            }
          }}
          onClose={() => setAction(null)}
          onDone={() => {
            setAction(null);
            reload();
          }}
        />
      )}
    </>
  );
}

type Draft = Omit<ReferralSettings, 'updatedAt' | 'updatedById'>;
const NUMBER_FIELDS = [
  ['inviterSignupCherries', 'refInviterSignup'],
  ['inviteeSignupCherries', 'refInviteeSignup'],
  ['firstRechargeBps', 'refFirstRechargeBps'],
  ['dailySignupCap', 'refDailyCap'],
  ['holdHours', 'refHoldHours'],
  ['applyWindowDays', 'refApplyWindow'],
  ['selfIpWindowHours', 'refSelfIpWindow'],
] as const;

/** The fields of `draft` that differ from `saved` (the PUT body sends only those). */
export function settingsChanges(saved: Draft, draft: Draft): Partial<Draft> {
  const out: Partial<Draft> = {};
  if (saved.enabled !== draft.enabled) out.enabled = draft.enabled;
  for (const [k] of NUMBER_FIELDS) if (saved[k] !== draft[k]) out[k] = draft[k];
  if (JSON.stringify(saved.milestones) !== JSON.stringify(draft.milestones)) out.milestones = draft.milestones;
  return out;
}

/** Milestones must increase in friends and pay more than 0 (the server checks it again). */
export function milestonesValid(ms: Draft['milestones']): boolean {
  return ms.length <= 5 && ms.every((m, i) => Number.isInteger(m.friends) && m.friends >= 1 && m.cherries >= 1 && (i === 0 || m.friends > ms[i - 1]!.friends));
}

/** The settings form (pure: rendered in the tests). */
export function ReferralSettingsForm({ saved, draft, onChange, onSave }: { saved: ReferralSettings; draft: Draft; onChange: (d: Draft) => void; onSave: () => void }) {
  const { t, lang, can } = useApp();
  const edit = can('referrals.settings');
  const changes = settingsChanges(saved, draft);
  const valid = milestonesValid(draft.milestones);
  const num = (raw: string) => (raw.trim() === '' ? 0 : Math.max(0, Math.floor(Number(raw)) || 0));
  return (
    <div className="card" data-referral-settings>
      {!edit && <div className="alert info">{t('refReadOnly')}</div>}
      <div className="field">
        <label className="row">
          <input type="checkbox" checked={draft.enabled} disabled={!edit} onChange={(e) => onChange({ ...draft, enabled: e.target.checked })} data-field="enabled" />
          {t('refEnabled')}
        </label>
        <p className="muted small">{t('refEnabledHint')}</p>
      </div>
      {NUMBER_FIELDS.map(([k, label]) => (
        <div className="field" key={k}>
          <label htmlFor={`ref-${k}`}>{t(label)}</label>
          <input id={`ref-${k}`} type="number" min={0} className="ltr mono" value={draft[k]} disabled={!edit} onChange={(e) => onChange({ ...draft, [k]: num(e.target.value) })} data-field={k} />
        </div>
      ))}
      <div className="field">
        <label>{t('refMilestones')}</label>
        {draft.milestones.map((m, i) => (
          <div className="row" key={i} data-milestone={i}>
            <input
              type="number"
              min={1}
              className="ltr mono"
              aria-label={t('refMilestoneFriends')}
              value={m.friends}
              disabled={!edit}
              onChange={(e) => onChange({ ...draft, milestones: draft.milestones.map((x, j) => (j === i ? { ...x, friends: num(e.target.value) } : x)) })}
            />
            <span className="muted small">{t('refMilestoneFriends')} →</span>
            <input
              type="number"
              min={1}
              className="ltr mono"
              aria-label={t('refMilestoneCherries')}
              value={m.cherries}
              disabled={!edit}
              onChange={(e) => onChange({ ...draft, milestones: draft.milestones.map((x, j) => (j === i ? { ...x, cherries: num(e.target.value) } : x)) })}
            />
            <span className="muted small">{t('refMilestoneCherries')}</span>
            {edit && (
              <button className="btn" onClick={() => onChange({ ...draft, milestones: draft.milestones.filter((_, j) => j !== i) })}>
                {t('refRemove')}
              </button>
            )}
          </div>
        ))}
        {edit && draft.milestones.length < 5 && (
          <button
            className="btn"
            onClick={() => {
              const last = draft.milestones.at(-1);
              onChange({ ...draft, milestones: [...draft.milestones, { friends: (last?.friends ?? 0) + 1, cherries: last?.cherries ?? 1 }] });
            }}
          >
            {t('refAddMilestone')}
          </button>
        )}
        {!valid && <div className="alert error">{t('refMilestonesInvalid')}</div>}
      </div>
      <p className="muted small">
        {t('refUpdatedAt')}: <span className="date">{formatDate(saved.updatedAt, lang)}</span>
      </p>
      {edit && (
        <button className="btn primary" disabled={!valid || Object.keys(changes).length === 0} onClick={onSave} data-referral-save>
          {Object.keys(changes).length === 0 ? t('refNoChange') : t('refSave')}
        </button>
      )}
    </div>
  );
}

export function ReferralSettingsPage() {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<ReferralSettings>('/admin/referral-settings'), []);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const current: Draft = draft ?? data;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('refSettingsTitle')}</h1>
          <p className="muted small">{t('refSettingsSubtitle')}</p>
        </div>
      </div>
      <ReferralSettingsForm saved={data} draft={current} onChange={setDraft} onSave={() => setSaving(true)} />
      {saving && (
        <FormDialog
          title={t('refSave')}
          intro={<p className="muted small">{t('refSaveIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('refSave')}
          submit={(v) => api.put('/admin/referral-settings', { ...settingsChanges(data, current), ...v })}
          onClose={() => setSaving(false)}
          onDone={() => {
            setSaving(false);
            setDraft(null);
            toast(t('refSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}
