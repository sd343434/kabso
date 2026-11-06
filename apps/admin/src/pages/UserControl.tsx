import { useState, type ReactNode } from 'react';
import { api } from '../api';
import { codeField, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Key } from '../i18n';
import type { Restriction, RestrictionKind, UserControl, UserDetail } from '../types';
import { DataTable } from '../ui/DataTable';
import { Icon } from '../ui/icons';
import './control.css';

/**
 * D208 «تحكم كامل» (v1.72-social, CONVENTIONS §10.67): the user page's action groups — Account (lock, ban, delete),
 * Security (password, email, sessions), Profile, Restrictions, Content, Money — each showing the current state, and
 * their dialogs (a reason always; the authenticator code where the action is destructive or touches money). Every
 * button follows the session's capabilities; the server checks them again.
 */

export type ControlAction =
  | 'lock'
  | 'unlock'
  | 'ban'
  | 'unban'
  | 'delete'
  | 'cancelDeletion'
  | 'resetLink'
  | 'tempPassword'
  | 'requireChange'
  | 'email'
  | 'resend'
  | 'signout'
  | 'profile'
  | 'avatar'
  | 'cover'
  | 'gift'
  | 'revokeSpecial'
  | 'restrict'
  | 'adjust'
  | { lift: RestrictionKind };

export const RESTRICTION_KINDS: Exclude<RestrictionKind, 'LOCK'>[] = ['CHAT_MUTE', 'NO_LIVE', 'NO_GIFTS', 'NO_POSTING'];
const QUICK_DAYS = [1, 3, 7, 30] as const;
const DAY_KEY: Record<(typeof QUICK_DAYS)[number], Key> = { 1: 'ctDays1', 3: 'ctDays3', 7: 'ctDays7', 30: 'ctDays30' };

function Group({ icon, title, state, children }: { icon: Parameters<typeof Icon>[0]['name']; title: string; state?: ReactNode; children: ReactNode }) {
  return (
    <section className="card ct-group" aria-label={title}>
      <header className="ct-head">
        <span className="ct-icon" aria-hidden="true">
          <Icon name={icon} size={18} />
        </span>
        <h2>{title}</h2>
      </header>
      {state ? <div className="ct-state">{state}</div> : null}
      <div className="ct-buttons">{children}</div>
    </section>
  );
}

/** The six groups (a pure view: the page owns the dialogs). */
export function ControlGroups({
  detail,
  control,
  onAction,
  onTab,
}: {
  detail: UserDetail;
  control: UserControl | null;
  onAction: (a: ControlAction) => void;
  onTab: (tab: 'content' | 'audit' | 'sessions' | 'money') => void;
}) {
  const { t, lang, can } = useApp();
  const u = detail.user;
  const n = (v: number) => formatNumber(v, lang);
  const btn = (label: string, action: ControlAction, opts: { danger?: boolean; show?: boolean } = {}) =>
    opts.show === false ? null : (
      <button key={label} type="button" className={`btn small${opts.danger ? ' danger' : ''}`} onClick={() => onAction(action)}>
        {label}
      </button>
    );
  const lock = control?.lock ?? null;
  return (
    <div className="ct-grid">
      <Group
        icon="shield"
        title={t('ctGroupAccount')}
        state={
          <>
            <StatusBadge status={u.status} />
            {lock ? (
              <span className="badge bad">{t('ctLockedUntil', { date: formatDate(lock.endsAt, lang) })}</span>
            ) : (
              <span className="muted small">{t('ctNotLocked')}</span>
            )}
            {control?.deletion && <span className="badge warn">{t('ctDeletionPending', { date: formatDate(control.deletion.purgeAfter, lang) })}</span>}
          </>
        }
      >
        {btn(t('ctLock'), 'lock', { danger: true, show: can('users.lock') && u.status === 'ACTIVE' })}
        {btn(t('ctUnlock'), 'unlock', { show: can('users.lock') && lock !== null })}
        {btn(t('ban'), 'ban', { danger: true, show: can('users.ban') && u.status === 'ACTIVE' })}
        {btn(t('unban'), 'unban', { show: can('users.ban') && u.status === 'SUSPENDED' })}
        {btn(t('ctDelete'), 'delete', { danger: true, show: can('users.delete') && u.status === 'ACTIVE' })}
        {btn(t('ctCancelDeletion'), 'cancelDeletion', { show: can('users.delete') && u.status === 'PENDING_DELETION' })}
      </Group>
      <Group
        icon="key"
        title={t('ctGroupSecurity')}
        state={
          control && (
            <>
              <span className="ltr small">{control.email.address}</span>
              <span className={`badge ${control.email.verified ? 'ok' : 'warn'}`}>{t(control.email.verified ? 'ctVerified' : 'ctNotVerified')}</span>
              {control.password.changeRequired && <span className="badge warn">{t('ctChangeRequired')}</span>}
            </>
          )
        }
      >
        {btn(t('ctResetLink'), 'resetLink', { show: can('users.password') })}
        {btn(t('ctTempPassword'), 'tempPassword', { danger: true, show: can('users.password') })}
        {btn(t('ctRequireChange'), 'requireChange', { show: can('users.password') })}
        {btn(t('ctEmail'), 'email', { show: can('users.email') })}
        {btn(t('ctResendVerification'), 'resend', { show: can('users.email') && control?.email.verified === false })}
        {btn(t('ctSignOutAll'), 'signout', { danger: true, show: can('users.sessions') })}
        {can('users.sessions') && (
          <button type="button" className="btn small ghost" onClick={() => onTab('sessions')}>
            {t('tabSessions')}
          </button>
        )}
      </Group>
      <Group icon="users" title={t('ctGroupProfile')}>
        {btn(t('ctEditProfile'), 'profile', { show: can('users.profile_edit') })}
        {btn(t('removeAvatar'), 'avatar', { danger: true, show: can('users.avatar') && u.avatarUrl !== null })}
        {/* D218 (v1.76-social): the profile cover; the server answers 409 when there is none. */}
        {btn(t('ctRemoveCover'), 'cover', { danger: true, show: can('users.avatar') })}
        {btn(t('giftSpecial'), 'gift', { show: can('users.special_username') })}
        {btn(t('revokeSpecial'), 'revokeSpecial', { show: can('users.special_username') && detail.specialUsername !== null })}
      </Group>
      <Group
        icon="stop"
        title={t('ctGroupRestrictions')}
        state={
          control && control.restrictions.length > 0 ? (
            <ul className="ct-list">
              {control.restrictions.map((r) => (
                <li key={r.id}>
                  <span className="badge bad">{t(`ctKind${r.kind}` as Key)}</span>
                  <span className="small muted">
                    {t('ctEndsAt')} <span className="date">{formatDate(r.endsAt, lang)}</span>
                  </span>
                  {can('users.restrict') && (
                    <button type="button" className="btn small ghost" onClick={() => onAction({ lift: r.kind })}>
                      {t('ctLift')}
                    </button>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <span className="muted small">{t('ctNoRestrictions')}</span>
          )
        }
      >
        {btn(t('ctRestrict'), 'restrict', { danger: true, show: can('users.restrict') && u.status !== 'DELETED' })}
      </Group>
      <Group icon="list" title={t('ctGroupContent')} state={<span className="muted small">{t('ctContentHint')}</span>}>
        <button type="button" className="btn small" onClick={() => onTab('content')}>
          {t('ctOpenContent')}
        </button>
        {can('audit.view') && (
          <button type="button" className="btn small ghost" onClick={() => onTab('audit')}>
            {t('ctOpenTimeline')}
          </button>
        )}
      </Group>
      <Group
        icon="coins"
        title={t('ctGroupMoney')}
        state={
          detail.balances ? (
            <>
              <span className="small">
                {t('coins')} <strong className="num">{n(detail.balances.coins)}</strong>
              </span>
              <span className="small">
                {t('cherries')} <strong className="num">{n(detail.balances.cherries)}</strong>
              </span>
            </>
          ) : (
            <span className="muted small">{t('balancesHidden')}</span>
          )
        }
      >
        {btn(t('ctAdjust'), 'adjust', { show: can('users.balance_adjust') })}
        {can('users.balances') && (
          <button type="button" className="btn small ghost" onClick={() => onTab('money')}>
            {t('tabMoney')}
          </button>
        )}
      </Group>
    </div>
  );
}

function historyLabel(r: Restriction, t: ReturnType<typeof useApp>['t']): string {
  if (r.active) return t('ctStateActive');
  if (r.liftReason === 'replaced') return t('ctReplaced');
  if (r.liftedAt) return t('ctLifted');
  return t('ctEnded');
}

export function RestrictionHistory({ rows, kind }: { rows: Restriction[]; kind?: RestrictionKind }) {
  const { t, lang } = useApp();
  const list = rows.filter((r) => (kind === 'LOCK' ? r.kind === 'LOCK' : kind === undefined ? true : r.kind !== 'LOCK'));
  return (
    <div className="ct-history">
      <h3>{t('ctHistory')}</h3>
      {list.length === 0 ? (
        <p className="muted small">{t('ctNoHistory')}</p>
      ) : (
        <ul>
          {list.slice(0, 8).map((r) => (
            <li key={r.id}>
              <span className={`badge ${r.active ? 'bad' : ''}`}>{t(`ctKind${r.kind}` as Key)}</span>
              <span className="small">{historyLabel(r, t)}</span>
              <span className="date small muted">
                {formatDate(r.startsAt, lang)} → {formatDate(r.liftedAt ?? r.endsAt, lang)}
              </span>
              <span className="small clip">{r.reason}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** Lock or restrict: a quick duration (1, 3, 7, 30 days) or an end date, the reason shown to the person. */
export function DurationDialog({
  userId,
  mode,
  control,
  onClose,
  onDone,
}: {
  userId: string;
  mode: 'lock' | 'restrict';
  control: UserControl | null;
  onClose: () => void;
  onDone: (result: { sessions?: number }) => void;
}) {
  const { t } = useApp();
  const [kind, setKind] = useState<Exclude<RestrictionKind, 'LOCK'>>('CHAT_MUTE');
  const [days, setDays] = useState<number | null>(1);
  const [until, setUntil] = useState('');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const untilIso = until ? new Date(until).toISOString() : null;
  const ok = reason.trim() !== '' && (days !== null || (untilIso !== null && !Number.isNaN(Date.parse(untilIso))));
  const title = mode === 'lock' ? t('ctLock') : t('ctRestrict');
  return (
    <Dialog title={title} onClose={onClose}>
      {mode === 'lock' && <p className="muted small">{t('ctLockIntro')}</p>}
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          setError(null);
          const end = days !== null ? { days } : { until: untilIso };
          const req =
            mode === 'lock'
              ? api.post<{ sessions: number }>(`/admin/users/${userId}/lock`, { ...end, reason: reason.trim() })
              : api.post<{ sessions: number }>(`/admin/users/${userId}/restrictions`, { kind, ...end, reason: reason.trim() });
          req.then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        {mode === 'restrict' && (
          <div className="field">
            <span>{t('ctKind')}</span>
            <div className="ct-kinds" role="radiogroup" aria-label={t('ctKind')}>
              {RESTRICTION_KINDS.map((k) => (
                <label key={k} className={`ct-kind${kind === k ? ' on' : ''}`}>
                  <input type="radio" name="kind" value={k} checked={kind === k} onChange={() => setKind(k)} />
                  <strong>{t(`ctKind${k}` as Key)}</strong>
                  <span className="small muted">{t(`ctKindHint${k}` as Key)}</span>
                </label>
              ))}
            </div>
          </div>
        )}
        <div className="field">
          <span>{t('ctDuration')}</span>
          <div className="segmented wrap" role="group" aria-label={t('ctDuration')}>
            {QUICK_DAYS.map((d) => (
              <button
                key={d}
                type="button"
                aria-pressed={days === d}
                onClick={() => {
                  setDays(d);
                  setUntil('');
                }}
              >
                {t(DAY_KEY[d])}
              </button>
            ))}
            <button type="button" aria-pressed={days === null} onClick={() => setDays(null)}>
              {t('ctUntilDate')}
            </button>
          </div>
          {days === null && <input type="datetime-local" aria-label={t('ctUntilDate')} value={until} onChange={(e) => setUntil(e.target.value)} />}
        </div>
        <div className="field">
          <label htmlFor="ct-reason">{t('ctReasonShown')}</label>
          <textarea id="ct-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t('ctReasonShownHint')}</span>
        </div>
        {control && <RestrictionHistory rows={control.history} kind={mode === 'lock' ? 'LOCK' : undefined} />}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn danger" disabled={!ok || busy}>
            {title}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** The temporary password: asked with the reason and the code, then shown ONCE with a copy button. */
export function TempPasswordDialog({ userId, onClose, onDone }: { userId: string; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [shown, setShown] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  if (shown) {
    return (
      <Dialog title={t('ctTempPassword')} onClose={onDone}>
        <div className="alert info" role="status">
          {t('ctTempWarn')}
        </div>
        <div className="field">
          <span>{t('ctTempShown')}</span>
          <div className="ct-secret">
            <code className="ltr">{shown}</code>
            <button
              type="button"
              className="btn small"
              onClick={() => {
                void navigator.clipboard?.writeText(shown).then(() => setCopied(true));
              }}
            >
              {copied ? t('ctCopied') : t('ctCopy')}
            </button>
          </div>
        </div>
        <div className="actions">
          <button type="button" className="btn primary" onClick={onDone}>
            {t('done')}
          </button>
        </div>
      </Dialog>
    );
  }
  return (
    <FormDialog
      title={t('ctTempPassword')}
      intro={<p className="muted small">{t('ctTempIntro')}</p>}
      fields={[reasonField(t), { ...codeField(t), hint: t('ctCodeHint') }]}
      confirmLabel={t('ctTempPassword')}
      danger
      submit={async (v) => {
        const res = await api.post<{ temporaryPassword: string }>(`/admin/users/${userId}/password/temporary`, {
          reason: v.reason,
          totpCode: v.totpCode,
        });
        setShown(res.temporaryPassword);
      }}
      onClose={onClose}
      onDone={() => undefined}
    />
  );
}

export function RequireChangeDialog({ userId, onClose, onDone }: { userId: string; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [endSessions, setEndSessions] = useState(true);
  return (
    <FormDialog
      title={t('ctRequireChange')}
      intro={
        <>
          <p className="muted small">{t('ctRequireChangeIntro')}</p>
          <label className="check field">
            <input type="checkbox" checked={endSessions} onChange={(e) => setEndSessions(e.target.checked)} />
            {t('ctEndSessionsNow')}
          </label>
        </>
      }
      fields={[reasonField(t)]}
      confirmLabel={t('confirm')}
      submit={(v) => api.post(`/admin/users/${userId}/password/require-change`, { reason: v.reason, endSessions })}
      onClose={onClose}
      onDone={onDone}
    />
  );
}

export function EmailDialog({ userId, current, onClose, onDone }: { userId: string; current: string; onClose: () => void; onDone: () => void }) {
  const { t, session } = useApp();
  const owner = session?.roles.includes('OWNER') ?? false;
  const [markVerified, setMarkVerified] = useState(false);
  return (
    <FormDialog
      title={t('ctEmail')}
      intro={
        <>
          <p className="muted small">{t('ctEmailIntro')}</p>
          <p className="small">
            <span className="muted">{t('colEmail')}: </span>
            <span className="ltr">{current}</span>
          </p>
          {owner && (
            <label className="check field">
              <input type="checkbox" checked={markVerified} onChange={(e) => setMarkVerified(e.target.checked)} />
              {t('ctMarkVerified')}
            </label>
          )}
        </>
      }
      fields={[{ name: 'email', label: t('ctNewEmail'), maxLength: 254 }, reasonField(t), { ...codeField(t), hint: t('ctCodeHint') }]}
      confirmLabel={t('ctEmail')}
      danger
      submit={(v) =>
        api.post(`/admin/users/${userId}/email`, { email: v.email, markVerified, reason: v.reason, totpCode: v.totpCode })
      }
      onClose={onClose}
      onDone={onDone}
    />
  );
}

/** The profile: only the fields that differ from now are sent. */
export function profilePatch(
  now: { displayName: string; username: string; bio: string | null; countryCode: string | null; gender: string | null },
  form: { displayName: string; username: string; bio: string; country: string; gender: string },
): Record<string, string | null> {
  const out: Record<string, string | null> = {};
  if (form.displayName.trim() !== now.displayName) out.displayName = form.displayName.trim();
  if (form.username.trim().toLowerCase() !== now.username) out.username = form.username.trim().toLowerCase();
  const bio = form.bio.trim();
  if (bio !== (now.bio ?? '')) out.bio = bio === '' ? null : bio;
  const country = form.country.trim().toUpperCase();
  if (country !== (now.countryCode ?? '')) out.country = country === '' ? null : country;
  if (form.gender !== '' && form.gender !== (now.gender ?? '')) out.gender = form.gender;
  return out;
}

export function ProfileDialog({
  userId,
  detail,
  gender,
  onClose,
  onDone,
}: {
  userId: string;
  detail: UserDetail;
  gender: string | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const u = detail.user;
  const now = { displayName: u.displayName, username: u.username, bio: u.bio, countryCode: u.countryCode, gender };
  const [form, setForm] = useState({
    displayName: u.displayName,
    username: u.username,
    bio: u.bio ?? '',
    country: u.countryCode ?? '',
    gender: gender ?? '',
  });
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const patch = profilePatch(now, form);
  const ok = reason.trim() !== '' && Object.keys(patch).length > 0;
  const set = (k: keyof typeof form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }));
  return (
    <Dialog title={t('ctEditProfile')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          setError(null);
          api.patch(`/admin/users/${userId}/profile`, { ...patch, reason: reason.trim() }).then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        <div className="field">
          <label htmlFor="pf-name">{t('ctDisplayName')}</label>
          <input id="pf-name" type="text" maxLength={100} value={form.displayName} onChange={set('displayName')} />
        </div>
        <div className="field">
          <label htmlFor="pf-user">{t('ctUsername')}</label>
          <input id="pf-user" type="text" className="ltr" maxLength={30} value={form.username} onChange={set('username')} />
          <span className="hint">{t('ctUsernameHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="pf-bio">{t('ctBio')}</label>
          <textarea id="pf-bio" maxLength={300} value={form.bio} onChange={set('bio')} />
        </div>
        <div className="grid cols-2">
          <div className="field">
            <label htmlFor="pf-country">{t('ctCountry')}</label>
            <input id="pf-country" type="text" className="ltr" maxLength={2} value={form.country} onChange={set('country')} />
          </div>
          <div className="field">
            <label htmlFor="pf-gender">{t('ctGender')}</label>
            <select id="pf-gender" value={form.gender} onChange={set('gender')}>
              <option value="">—</option>
              {(['MALE', 'FEMALE', 'UNDISCLOSED'] as const).map((g) => (
                <option key={g} value={g}>
                  {t(`ctGender${g}`)}
                </option>
              ))}
            </select>
          </div>
        </div>
        <p className="muted small">{t('ctNoCover')}</p>
        <div className="field">
          <label htmlFor="pf-reason">{t('reason')}</label>
          <textarea id="pf-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {t('confirm')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** Coins or cherries, credit or debit, with today's use against the cap and the balance after. */
export function AdjustDialog({
  userId,
  detail,
  control,
  onClose,
  onDone,
}: {
  userId: string;
  detail: UserDetail;
  control: UserControl | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t, lang, session } = useApp();
  const owner = session?.roles.includes('OWNER') ?? false;
  const [currency, setCurrency] = useState<'COINS' | 'CHERRIES'>('COINS');
  const [direction, setDirection] = useState<'CREDIT' | 'DEBIT'>('CREDIT');
  const [amount, setAmount] = useState('');
  const [allowNegative, setAllowNegative] = useState(false);
  const [reason, setReason] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const n = (v: number) => formatNumber(v, lang);
  const balance = detail.balances ? (currency === 'COINS' ? detail.balances.coins : detail.balances.cherries) : null;
  const value = /^[1-9][0-9]{0,9}$/.test(amount) ? Number(amount) : null;
  const after = balance !== null && value !== null ? balance + (direction === 'CREDIT' ? value : -value) : null;
  const used = control ? (currency === 'COINS' ? control.adjustToday.coins : control.adjustToday.cherries) : null;
  const cap = control ? (currency === 'COINS' ? control.adjustToday.capCoins : control.adjustToday.capCherries) : null;
  const ok = value !== null && reason.trim() !== '' && /^[0-9]{6}$/.test(code);
  return (
    <Dialog title={t('ctAdjust')} onClose={onClose}>
      <p className="muted small">{t('ctAdjustIntro')}</p>
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          setError(null);
          api
            .post(`/admin/users/${userId}/balance-adjustments`, {
              currency,
              direction,
              amount,
              allowNegative: direction === 'DEBIT' && allowNegative,
              reason: reason.trim(),
              totpCode: code,
            })
            .then(onDone, (err: unknown) => {
              setError(err);
              setBusy(false);
            });
        }}
      >
        <div className="grid cols-2">
          <div className="field">
            <span>{t('ctCurrency')}</span>
            <div className="segmented" role="group" aria-label={t('ctCurrency')}>
              {(['COINS', 'CHERRIES'] as const).map((c) => (
                <button key={c} type="button" aria-pressed={currency === c} onClick={() => setCurrency(c)}>
                  {t(c === 'COINS' ? 'coins' : 'cherries')}
                </button>
              ))}
            </div>
          </div>
          <div className="field">
            <span>{t('ctDirection')}</span>
            <div className="segmented" role="group" aria-label={t('ctDirection')}>
              {(['CREDIT', 'DEBIT'] as const).map((d) => (
                <button key={d} type="button" aria-pressed={direction === d} onClick={() => setDirection(d)}>
                  {t(d === 'CREDIT' ? 'ctCredit' : 'ctDebit')}
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="field">
          <label htmlFor="adj-amount">{t('ctAmount')}</label>
          <input id="adj-amount" type="text" inputMode="numeric" className="ltr" maxLength={10} value={amount} onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, ''))} />
          <span className="hint">
            {balance !== null && t('ctBalanceNow', { value: n(balance) })}
            {after !== null && ` · ${t('ctAfter', { value: n(after) })}`}
            {used !== null && cap !== null && ` · ${t('ctCapToday', { used: n(used), cap: n(cap) })}`}
          </span>
        </div>
        {owner && direction === 'DEBIT' && (
          <label className="check field">
            <input type="checkbox" checked={allowNegative} onChange={(e) => setAllowNegative(e.target.checked)} />
            {t('ctAllowNegative')}
          </label>
        )}
        <div className="field">
          <label htmlFor="adj-reason">{t('reason')}</label>
          <textarea id="adj-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="adj-code">{t('totpCode')}</label>
          <input
            id="adj-code"
            type="text"
            className="code-input"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, ''))}
          />
          <span className="hint">{t('totpHint')}</span>
        </div>
        {control && control.adjustments.length > 0 && (
          <div className="ct-history">
            <h3>{t('ctRecentAdjustments')}</h3>
            <ul>
              {control.adjustments.slice(0, 5).map((a) => (
                <li key={a.id}>
                  <span className="num" style={{ color: a.delta < 0 ? 'var(--error)' : 'var(--success)' }}>
                    {a.delta > 0 ? '+' : ''}
                    {n(a.delta)}
                  </span>
                  <span className="small">{t(a.currency === 'COINS' ? 'coins' : 'cherries')}</span>
                  <span className="date small muted">{formatDate(a.createdAt, lang)}</span>
                  <span className="small clip">{a.reason}</span>
                </li>
              ))}
            </ul>
          </div>
        )}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {t('ctAdjust')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

interface ContentRow {
  id: string;
  text: string;
  state: 'VISIBLE' | 'HIDDEN' | 'DELETED';
  createdAt: string;
  postId?: string;
}
interface PostRow {
  id: string;
  text: string;
  format: string;
  status: string;
  moderation: string;
  likes: number;
  comments: number;
  deleted: boolean;
  createdAt: string;
}

type ContentOp = { type: 'post' | 'story' | 'comment'; id: string; op: 'hide' | 'restore' | 'delete' };

/** The «المحتوى» tab: posts and reels, stories and comments, each row with what the team may do to it. */
export function ContentModeration({ userId }: { userId: string }) {
  const { t, lang, can, toast } = useApp();
  const [kind, setKind] = useState<'posts' | 'stories' | 'comments'>('posts');
  const [bump, setBump] = useState(0);
  const [op, setOp] = useState<ContentOp | null>(null);
  const n = (v: number) => formatNumber(v, lang);
  const manage = can('users.content');
  const state = (s: string) => <span className={`badge ${s === 'VISIBLE' ? 'ok' : 'bad'}`}>{t(`ctState${s}` as Key)}</span>;
  const actions = (type: ContentOp['type'], id: string, s: string) =>
    !manage || s === 'DELETED' ? null : (
      <span className="row">
        {type === 'comment' ? (
          <button type="button" className="btn small danger" onClick={() => setOp({ type, id, op: 'hide' })}>
            {t('ctRemoveComment')}
          </button>
        ) : (
          <>
            {s === 'VISIBLE' ? (
              <button type="button" className="btn small" onClick={() => setOp({ type, id, op: 'hide' })}>
                {t('ctHide')}
              </button>
            ) : (
              <button type="button" className="btn small" onClick={() => setOp({ type, id, op: 'restore' })}>
                {t('ctRestore')}
              </button>
            )}
            <button type="button" className="btn small danger" onClick={() => setOp({ type, id, op: 'delete' })}>
              {t('ctDeleteForGood')}
            </button>
          </>
        )}
      </span>
    );
  const label = op ? (op.op === 'delete' ? t('ctDeleteForGood') : op.op === 'restore' ? t('ctRestore') : op.type === 'comment' ? t('ctRemoveComment') : t('ctHide')) : '';
  return (
    <div className="card">
      <div className="segmented wrap" role="group" aria-label={t('tabContent')}>
        {(['posts', 'stories', 'comments'] as const).map((k) => (
          <button key={k} type="button" aria-pressed={kind === k} onClick={() => setKind(k)}>
            {t(k === 'posts' ? 'ctContentPosts' : k === 'stories' ? 'ctContentStories' : 'ctContentComments')}
          </button>
        ))}
      </div>
      {kind === 'posts' ? (
        <DataTable<PostRow>
          id="user-posts"
          endpoint={`/admin/users/${userId}/posts`}
          rowKey={(r) => r.id}
          pageSize={10}
          reloadKey={bump}
          columns={[
            { key: 'text', label: 'colText', render: (r) => <span className="clip">{r.text || t('none')}</span> },
            { key: 'format', label: 'colFormat', render: (r) => r.format },
            { key: 'mod', label: 'colModeration', render: (r) => state(r.deleted ? 'DELETED' : r.moderation === 'REMOVED' ? 'HIDDEN' : 'VISIBLE') },
            { key: 'likes', label: 'colLikes', numeric: true, render: (r) => n(r.likes) },
            { key: 'comments', label: 'colComments', numeric: true, optional: true, render: (r) => n(r.comments) },
            { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
            { key: 'act', label: 'colAction', render: (r) => actions('post', r.id, r.deleted ? 'DELETED' : r.moderation === 'REMOVED' ? 'HIDDEN' : 'VISIBLE') },
          ]}
        />
      ) : (
        <DataTable<ContentRow>
          id={`user-${kind}`}
          endpoint={`/admin/users/${userId}/content`}
          extraQuery={{ kind }}
          rowKey={(r) => r.id}
          pageSize={10}
          reloadKey={bump}
          columns={[
            { key: 'text', label: 'colText', render: (r) => <span className="clip">{r.text || t('none')}</span> },
            { key: 'state', label: 'colStatus', render: (r) => state(r.state) },
            { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
            { key: 'act', label: 'colAction', render: (r) => actions(kind === 'stories' ? 'story' : 'comment', r.id, r.state) },
          ]}
        />
      )}
      {op && (
        <FormDialog
          title={label}
          // D288 (owner «يلغي»): deleting for good needs the reason only (no authenticator code); audited.
          fields={[reasonField(t)]}
          confirmLabel={label}
          danger={op.op !== 'restore'}
          submit={(v) => api.post(`/admin/content/${op.type}/${op.id}/${op.op}`, v)}
          onClose={() => setOp(null)}
          onDone={() => {
            setOp(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </div>
  );
}
