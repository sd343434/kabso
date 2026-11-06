import { useState } from 'react';
import { api } from '../api';
import { Avatar, ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync, Dialog } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { AuditRow, LedgerRow, UserDetail as Detail } from '../types';
import { DataTable } from '../ui/DataTable';
import { Icon } from '../ui/icons';
import { AuditMeta } from './Audit';
import {
  AdjustDialog,
  ContentModeration,
  ControlGroups,
  DurationDialog,
  EmailDialog,
  ProfileDialog,
  RequireChangeDialog,
  TempPasswordDialog,
  type ControlAction,
} from './UserControl';
import { UserDevice } from './UserDevice';
import type { UserControl } from '../types';

type Action = ControlAction | 'revoke' | 'bag' | null;
type Tab = 'overview' | 'money' | 'content' | 'reports' | 'items' | 'audit' | 'sessions' | 'device';

function GiftDialog({ userId, onClose, onDone }: { userId: string; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [username, setUsername] = useState('');
  const [permanent, setPermanent] = useState(false);
  const [days, setDays] = useState('30');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const daysOk = permanent || /^[1-9][0-9]{0,3}$/.test(days);
  const ok = username.trim() !== '' && reason.trim() !== '' && daysOk;
  return (
    <Dialog title={t('giftSpecial')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok) return;
          setBusy(true);
          setError(null);
          api
            .post(`/admin/users/${userId}/special-username`, {
              username: username.trim(),
              ...(permanent ? { permanent: true } : { days: Number(days) }),
              reason: reason.trim(),
            })
            .then(onDone, (err: unknown) => {
              setError(err);
              setBusy(false);
            });
        }}
      >
        <div className="field">
          <label htmlFor="g-name">{t('specialName')}</label>
          <input id="g-name" type="text" className="ltr" value={username} onChange={(e) => setUsername(e.target.value)} maxLength={31} />
        </div>
        <label className="check field">
          <input type="checkbox" checked={permanent} onChange={(e) => setPermanent(e.target.checked)} />
          {t('permanent')}
        </label>
        {!permanent && (
          <div className="field">
            <label htmlFor="g-days">{t('days')}</label>
            <input id="g-days" type="number" min={1} max={9999} value={days} onChange={(e) => setDays(e.target.value)} />
          </div>
        )}
        <div className="field">
          <label htmlFor="g-reason">{t('reason')}</label>
          <textarea id="g-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
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

interface SessionRow {
  id: string;
  deviceName: string | null;
  platform: string | null;
  appVersion: string | null;
  ip: string | null;
  createdAt: string;
  lastUsedAt: string;
}
interface BagRow {
  code: string;
  category: string;
  nameAr: string;
  nameEn: string;
  equipped: boolean;
  source: string;
  acquiredAt: string;
  expiresAt: string | null;
  expired: boolean;
}

function LedgerTable({ id, kind }: { id: string; kind: 'coins' | 'cherries' }) {
  const { t, lang } = useApp();
  return (
    <DataTable<LedgerRow>
      id={`ledger-${kind}`}
      endpoint={`/admin/users/${id}/ledger`}
      extraQuery={{ kind }}
      rowKey={(r) => r.id}
      pageSize={10}
      header={<h2 className="table-title">{t(kind === 'coins' ? 'ledgerCoins' : 'ledgerCherries')}</h2>}
      columns={[
        {
          key: 'delta',
          label: 'colDelta',
          numeric: true,
          render: (r) => (
            <span style={{ color: r.delta < 0 ? 'var(--error)' : 'var(--success)' }}>
              {r.delta > 0 ? '+' : ''}
              {formatNumber(r.delta, lang)}
            </span>
          ),
        },
        { key: 'balance', label: 'colBalance', numeric: true, render: (r) => formatNumber(r.balanceAfter, lang) },
        { key: 'reason', label: 'colReason', render: (r) => <span className="mono small">{r.reason}</span> },
        { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
      ]}
    />
  );
}

function BagGrantDialog({ userId, onClose, onDone }: { userId: string; onClose: () => void; onDone: () => void }) {
  const { t, lang } = useApp();
  const items = useAsync(() => api.get<{ data: { code: string; category: string; nameAr: string; nameEn: string; automatic: boolean }[] }>('/admin/bag-items'), []);
  const [code, setCode] = useState('');
  const [days, setDays] = useState('30');
  const [forever, setForever] = useState(false);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const ok = code !== '' && reason.trim() !== '' && (forever || /^[1-9][0-9]{0,3}$/.test(days));
  return (
    <Dialog title={t('bagGrant')} onClose={onClose}>
      <ErrorAlert error={error ?? items.error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok) return;
          setBusy(true);
          api.post(`/admin/users/${userId}/bag/grant`, { code, days: forever ? null : Number(days), reason: reason.trim() }).then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        <div className="field">
          <label htmlFor="bg-code">{t('bagItem')}</label>
          <select id="bg-code" value={code} onChange={(e) => setCode(e.target.value)}>
            <option value="">—</option>
            {items.data?.data
              .filter((i) => !i.automatic)
              .map((i) => (
                <option key={i.code} value={i.code}>
                  {(lang === 'ar' ? i.nameAr : i.nameEn) + ` (${i.category === 'AVATAR_FRAME' ? t('catFrame') : t('catCard')})`}
                </option>
              ))}
          </select>
        </div>
        <label className="check field">
          <input type="checkbox" checked={forever} onChange={(e) => setForever(e.target.checked)} />
          {t('permanent')}
        </label>
        {!forever && (
          <div className="field">
            <label htmlFor="bg-days">{t('days')}</label>
            <input id="bg-days" type="number" min={1} max={3650} value={days} onChange={(e) => setDays(e.target.value)} />
          </div>
        )}
        <div className="field">
          <label htmlFor="bg-reason">{t('reason')}</label>
          <textarea id="bg-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
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

/**
 * A user's page (D191 + D197): the profile header with the role-gated actions, and tabs — overview, money
 * (balances and the paged ledgers), content (posts), reports, items (bag), the audit rows about the user and the
 * app sessions (sign out with a reason). Each tab shows only when the role has its capability.
 */
export function UserDetail({ id }: { id: string }) {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<Detail>(`/admin/users/${id}`), [id]);
  const [controlBump, setControlBump] = useState(0);
  // D208: the control state (locks, restrictions, password / email, deletion, adjustments) for the action groups.
  const control = useAsync(
    () => (can('users.control_view') ? api.get<UserControl>(`/admin/users/${id}/control`) : Promise.resolve(null)),
    [id, controlBump],
  );
  const [action, setAction] = useState<Action>(null);
  const [tab, setTab] = useState<Tab>('overview');
  const [bump, setBump] = useState(0);
  const [revokeOne, setRevokeOne] = useState<string | null>(null);
  const done = () => {
    setAction(null);
    setRevokeOne(null);
    toast(t('done'));
    setBump((b) => b + 1);
    setControlBump((b) => b + 1);
    reload();
  };
  const n = (v: number) => formatNumber(v, lang);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const u = data.user;
  const reasonAction = (path: string, label: string, danger = false, extra: Record<string, unknown> = {}) => (
    <FormDialog
      title={label}
      fields={[reasonField(t)]}
      confirmLabel={label}
      danger={danger}
      submit={(v) => api.post(`/admin/users/${id}/${path}`, { ...extra, reason: v.reason })}
      onClose={() => {
        setAction(null);
        setRevokeOne(null);
      }}
      onDone={done}
    />
  );
  const tabs: { key: Tab; label: Parameters<typeof t>[0]; show: boolean }[] = [
    { key: 'overview', label: 'tabOverview', show: true },
    { key: 'money', label: 'tabMoney', show: can('users.balances') },
    { key: 'content', label: 'tabContent', show: can('users.view') },
    { key: 'reports', label: 'tabReports', show: true },
    { key: 'items', label: 'tabItems', show: can('items.grant') },
    { key: 'audit', label: 'tabAudit', show: can('audit.view') },
    { key: 'sessions', label: 'tabSessions', show: can('users.sessions') },
    // D223: the accounts created on this account's sign-up device.
    { key: 'device', label: 'tabDevice', show: can('users.device_view') },
  ];
  return (
    <>
      <div className="profile-head card">
        <Avatar url={u.avatarUrl} name={u.displayName || u.username} large />
        <div className="grow">
          <h1>{u.displayName}</h1>
          <div className="row small">
            <span className="ltr muted">@{u.username}</span>
            <StatusBadge status={u.status} />
            {data.adminRoles.map((r) => (
              <span className="badge info" key={r}>
                {t(`role${r}`)}
              </span>
            ))}
            {data.rechargeAgent?.code && <span className="badge warn mono">{data.rechargeAgent.code}</span>}
            {data.hostAgent?.hostCode && <span className="badge ok mono">{data.hostAgent.hostCode}</span>}
          </div>
        </div>
        <div className="row actions-row">
          {can('items.grant') && (
            <button className="btn" onClick={() => setAction('bag')}>
              {t('bagGrant')}
            </button>
          )}
          <button className="btn ghost" onClick={() => (window.history.length > 1 ? window.history.back() : navigate('/users'))}>
            {t('back')}
          </button>
        </div>
      </div>
      <div className="tabs" role="tablist">
        {tabs
          .filter((x) => x.show)
          .map((x) => (
            <button key={x.key} role="tab" className="tab" aria-selected={tab === x.key} aria-pressed={tab === x.key} onClick={() => setTab(x.key)}>
              {t(x.label)}
            </button>
          ))}
      </div>
      <ErrorAlert error={error} />
      {tab === 'overview' && (
        <ControlGroups detail={data} control={control.data} onAction={setAction} onTab={setTab} />
      )}
      {tab === 'overview' && (
        <div className="grid cols-2">
          <div className="card">
            <h2>{t('tabOverview')}</h2>
            <dl className="kv">
              <dt>{t('colEmail')}</dt>
              <dd className="ltr">{u.email}</dd>
              <dt>{t('userBase')}</dt>
              <dd className="ltr">@{u.baseUsername}</dd>
              {data.specialUsername && (
                <>
                  <dt>{t('userSpecial')}</dt>
                  <dd>
                    <span className="ltr">@{data.specialUsername.username}</span>{' '}
                    <span className="muted small">
                      ({data.specialUsername.source} · {t('expires')}:{' '}
                      {data.specialUsername.expiresAt ? formatDate(data.specialUsername.expiresAt, lang) : t('never')})
                    </span>
                  </dd>
                </>
              )}
              <dt>{t('userRole')}</dt>
              <dd>{u.role}</dd>
              <dt>{t('colJoined')}</dt>
              <dd className="date">{formatDate(u.createdAt, lang)}</dd>
              <dt>{t('userLastActive')}</dt>
              <dd className="date">{formatDate(u.lastActiveAt, lang)}</dd>
              <dt>{t('userCountry')}</dt>
              <dd>{u.countryCode ?? t('none')}</dd>
              <dt>{t('colId')}</dt>
              <dd className="mono small">{u.id}</dd>
            </dl>
          </div>
          <div className="card">
            <h2>{t('userRoles')}</h2>
            <dl className="kv">
              <dt>{t('rechargeAgent')}</dt>
              <dd>
                {data.rechargeAgent ? (
                  <>
                    <span className="mono">{data.rechargeAgent.code ?? t('none')}</span> <StatusBadge status={data.rechargeAgent.status} /> · {t('stock')}{' '}
                    <span className="num">{n(data.rechargeAgent.stockCoins)}</span>
                  </>
                ) : (
                  t('none')
                )}
              </dd>
              <dt>{t('hostAgent')}</dt>
              <dd>
                {data.hostAgent ? (
                  <>
                    <span className="mono">{data.hostAgent.hostCode ?? data.hostAgent.inviteCode}</span> · {data.hostAgent.rank}
                    {data.hostAgent.suspended ? ` · ${t('statusSUSPENDED')}` : ''}
                  </>
                ) : (
                  t('none')
                )}
              </dd>
              <dt>{t('agencyHost')}</dt>
              <dd>{data.agencyHost ? <span className="mono">{data.agencyHost.agencyInviteCode}</span> : t('none')}</dd>
              <dt>{t('reportsAgainst')}</dt>
              <dd>
                <span className="num">{n(data.reports.open)}</span> {t('openReports')}
              </dd>
              {u.bio && (
                <>
                  <dt>{t('userBio')}</dt>
                  <dd>{u.bio}</dd>
                </>
              )}
            </dl>
          </div>
        </div>
      )}
      {tab === 'money' && (
        <>
          <div className="mini-stats">
            {data.balances ? (
              <>
                <div className="mini-stat">
                  <span className="muted small">{t('coins')}</span>
                  <strong className="num">{n(data.balances.coins)}</strong>
                </div>
                <div className="mini-stat">
                  <span className="muted small">{t('cherries')}</span>
                  <strong className="num">{n(data.balances.cherries)}</strong>
                </div>
                <div className="mini-stat">
                  <span className="muted small">{t('lockedTaskCherries')}</span>
                  <strong className="num">{n(data.balances.lockedTaskCherries)}</strong>
                </div>
                <div className="mini-stat">
                  <span className="muted small">{t('cherriesReceivedLifetime')}</span>
                  <strong className="num">{n(data.balances.cherriesReceived)}</strong>
                </div>
                <div className="mini-stat">
                  <span className="muted small">{t('coinsSentLifetime')}</span>
                  <strong className="num">{n(data.balances.coinsSent)}</strong>
                </div>
              </>
            ) : (
              <p className="muted small">{t('balancesHidden')}</p>
            )}
          </div>
          {can('users.ledger') ? (
            <div className="grid cols-2">
              <LedgerTable id={id} kind="coins" />
              <LedgerTable id={id} kind="cherries" />
            </div>
          ) : (
            <p className="muted small">{t('ledgerHidden')}</p>
          )}
        </>
      )}
      {tab === 'content' && <ContentModeration userId={id} />}
      {tab === 'reports' && (
        <div className="card">
          <h2>{t('reportsAgainst')}</h2>
          {data.reports.recent.length === 0 ? (
            <div className="state empty-state">
              <Icon name="flag" size={28} />
              <p>{t('empty')}</p>
            </div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>{t('colReason')}</th>
                    <th>{t('colType')}</th>
                    <th>{t('colStatus')}</th>
                    <th>{t('colDate')}</th>
                  </tr>
                </thead>
                <tbody>
                  {data.reports.recent.map((r) => (
                    <tr key={r.id}>
                      <td>{isKey(`reason${r.reason}`) ? t(`reason${r.reason}` as never) : r.reason}</td>
                      <td>{isKey(`type${r.targetType}`) ? t(`type${r.targetType}` as never) : r.targetType}</td>
                      <td>
                        <StatusBadge status={r.status} />
                      </td>
                      <td className="date small">{formatDate(r.createdAt, lang)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {can('reports.view') && (
            <button className="btn small" style={{ marginTop: 10 }} onClick={() => navigate('/reports')}>
              {t('openQueue')}
            </button>
          )}
        </div>
      )}
      {tab === 'items' && <UserBag id={id} bump={bump} onRevoke={() => setBump((b) => b + 1)} />}
      {tab === 'audit' && (
        <DataTable<AuditRow>
          id="user-audit"
          endpoint={`/admin/users/${id}/audit`}
          rowKey={(r) => r.id}
          pageSize={10}
          reloadKey={bump}
          columns={[
            { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
            { key: 'action', label: 'colAction', render: (r) => <span className="mono small">{r.action}</span> },
            { key: 'actor', label: 'colActor', render: (r) => (r.actor ? `@${r.actor.username}` : t('system')) },
            { key: 'meta', label: 'colDetails', render: (r) => <AuditMeta meta={r.metadata} /> },
          ]}
        />
      )}
      {tab === 'sessions' && (
        <Sessions id={id} bump={bump} onRevoke={(sid) => setRevokeOne(sid)} />
      )}
      {tab === 'device' && <UserDevice id={id} />}
      {/* D208 asked for the authenticator code again; D288 (owner «يلغي»): the reason only — audited. */}
      {action === 'ban' && (
        <FormDialog
          title={t('ban')}
          fields={[reasonField(t)]}
          confirmLabel={t('ban')}
          danger
          submit={(v) => api.post(`/admin/users/${id}/ban`, { reason: v.reason })}
          onClose={() => setAction(null)}
          onDone={done}
        />
      )}
      {action === 'unban' && reasonAction('unban', t('unban'))}
      {action === 'avatar' && reasonAction('avatar/remove', t('removeAvatar'), true)}
      {action === 'cover' && reasonAction('cover/remove', t('ctRemoveCover'), true)}
      {action === 'revoke' && reasonAction('special-username/revoke', t('revokeSpecial'))}
      {action === 'signout' && reasonAction('sessions/revoke', t('signOutAll'), true)}
      {revokeOne && reasonAction('sessions/revoke', t('signOut'), true, { sessionId: revokeOne })}
      {action === 'gift' && <GiftDialog userId={id} onClose={() => setAction(null)} onDone={done} />}
      {action === 'revokeSpecial' && reasonAction('special-username/revoke', t('revokeSpecial'))}
      {/* D208 «تحكم كامل» */}
      {(action === 'lock' || action === 'restrict') && (
        <DurationDialog userId={id} mode={action} control={control.data} onClose={() => setAction(null)} onDone={done} />
      )}
      {action === 'unlock' && reasonAction('unlock', t('ctUnlock'))}
      {typeof action === 'object' && action !== null && 'lift' in action && reasonAction('restrictions/lift', t('ctLift'), false, { kind: action.lift })}
      {action === 'delete' && (
        <FormDialog
          title={t('ctDelete')}
          intro={<p className="muted small">{t('ctDeleteIntro', { days: 30 })}</p>}
          // D288 (owner): starting the deletion needs the reason only (no authenticator code); audited.
          fields={[reasonField(t)]}
          confirmLabel={t('ctDelete')}
          danger
          submit={(v) => api.post(`/admin/users/${id}/deletion`, { reason: v.reason })}
          onClose={() => setAction(null)}
          onDone={done}
        />
      )}
      {action === 'cancelDeletion' && reasonAction('deletion/cancel', t('ctCancelDeletion'))}
      {action === 'resetLink' && reasonAction('password/reset-link', t('ctResetLink'))}
      {action === 'tempPassword' && <TempPasswordDialog userId={id} onClose={() => setAction(null)} onDone={done} />}
      {action === 'requireChange' && <RequireChangeDialog userId={id} onClose={() => setAction(null)} onDone={done} />}
      {action === 'email' && <EmailDialog userId={id} current={u.email} onClose={() => setAction(null)} onDone={done} />}
      {action === 'resend' && reasonAction('email/resend-verification', t('ctResendVerification'))}
      {action === 'profile' && (
        <ProfileDialog userId={id} detail={data} gender={control.data?.gender ?? null} onClose={() => setAction(null)} onDone={done} />
      )}
      {action === 'adjust' && <AdjustDialog userId={id} detail={data} control={control.data} onClose={() => setAction(null)} onDone={done} />}
      {action === 'bag' && <BagGrantDialog userId={id} onClose={() => setAction(null)} onDone={done} />}
    </>
  );
}

function Sessions({ id, bump, onRevoke }: { id: string; bump: number; onRevoke: (sessionId: string) => void }) {
  const { t, lang } = useApp();
  const { data, error } = useAsync(() => api.get<{ data: SessionRow[] }>(`/admin/users/${id}/sessions`), [id, bump]);
  return (
    <div className="card">
      <h2>{t('tabSessions')}</h2>
      <ErrorAlert error={error} />
      {data && data.data.length === 0 && (
        <div className="state empty-state">
          <Icon name="shield" size={28} />
          <p>{t('sessionsNone')}</p>
        </div>
      )}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colDevice')}</th>
                <th>{t('colPlatform')}</th>
                <th>IP</th>
                <th>{t('colLastUsed')}</th>
                <th>{t('colStarted')}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.data.map((s) => (
                <tr key={s.id}>
                  <td>{s.deviceName ?? t('none')}</td>
                  <td>
                    {s.platform ?? t('none')} {s.appVersion && <span className="muted small ltr">v{s.appVersion}</span>}
                  </td>
                  <td className="ltr mono small">{s.ip ?? t('none')}</td>
                  <td className="date small">{formatDate(s.lastUsedAt, lang)}</td>
                  <td className="date small">{formatDate(s.createdAt, lang)}</td>
                  <td>
                    <button className="btn small danger" onClick={() => onRevoke(s.id)}>
                      {t('signOut')}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function UserBag({ id, bump, onRevoke }: { id: string; bump: number; onRevoke: () => void }) {
  const { t, lang, toast } = useApp();
  const { data, error } = useAsync(() => api.get<{ data: BagRow[] }>(`/admin/users/${id}/bag`), [id, bump]);
  const [take, setTake] = useState<string | null>(null);
  return (
    <div className="card">
      <h2>{t('tabItems')}</h2>
      <ErrorAlert error={error} />
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('bagItem')}</th>
                <th>{t('colType')}</th>
                <th>{t('colSource')}</th>
                <th>{t('expires')}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.data.map((b) => (
                <tr key={b.code}>
                  <td>
                    {lang === 'ar' ? b.nameAr : b.nameEn} <span className="mono small muted">{b.code}</span> {b.equipped && <span className="badge ok">{t('worn')}</span>}
                  </td>
                  <td>{b.category === 'AVATAR_FRAME' ? t('catFrame') : t('catCard')}</td>
                  <td className="small">{b.source}</td>
                  <td className="date small">{b.expiresAt ? formatDate(b.expiresAt, lang) : t('never')}</td>
                  <td>
                    <button className="btn small" onClick={() => setTake(b.code)}>
                      {t('bagRevoke')}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {take && (
        <FormDialog
          title={t('bagRevoke')}
          fields={[reasonField(t)]}
          confirmLabel={t('bagRevoke')}
          danger
          submit={(v) => api.post(`/admin/users/${id}/bag/revoke`, { code: take, reason: v.reason })}
          onClose={() => setTake(null)}
          onDone={() => {
            setTake(null);
            toast(t('done'));
            onRevoke();
          }}
        />
      )}
    </div>
  );
}
