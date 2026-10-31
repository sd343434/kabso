import { useState } from 'react';
import { api } from '../api';
import { Avatar, ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync, Dialog } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { LedgerRow, UserDetail as Detail } from '../types';

type Action = 'ban' | 'unban' | 'avatar' | 'gift' | 'revoke' | null;

function Ledger({ title, rows }: { title: string; rows: LedgerRow[] }) {
  const { t, lang } = useApp();
  return (
    <div className="card">
      <h2>{title}</h2>
      {rows.length === 0 ? (
        <p className="muted">{t('empty')}</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colDelta')}</th>
                <th>{t('colBalance')}</th>
                <th>{t('colReason')}</th>
                <th>{t('colDate')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td className="num" style={{ color: r.delta < 0 ? 'var(--error)' : 'var(--success)' }}>
                    {r.delta > 0 ? '+' : ''}
                    {formatNumber(r.delta, lang)}
                  </td>
                  <td className="num">{formatNumber(r.balanceAfter, lang)}</td>
                  <td className="mono small">{r.reason}</td>
                  <td className="date small">{formatDate(r.createdAt, lang)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

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

export function UserDetail({ id }: { id: string }) {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<Detail>(`/admin/users/${id}`), [id]);
  const [action, setAction] = useState<Action>(null);
  const done = () => {
    setAction(null);
    toast(t('done'));
    reload();
  };
  const n = (v: number) => formatNumber(v, lang);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const u = data.user;
  const reasonAction = (path: string, label: string, danger = false) => (
    <FormDialog
      title={label}
      fields={[reasonField(t)]}
      confirmLabel={label}
      danger={danger}
      submit={(v) => api.post(`/admin/users/${id}/${path}`, { reason: v.reason })}
      onClose={() => setAction(null)}
      onDone={done}
    />
  );
  return (
    <>
      <div className="page-head">
        <div className="row" style={{ gap: 14 }}>
          <Avatar url={u.avatarUrl} name={u.displayName || u.username} large />
          <div>
            <h1>{u.displayName}</h1>
            <div className="row small">
              <span className="ltr muted">@{u.username}</span>
              <StatusBadge status={u.status} />
              {data.adminRoles.map((r) => (
                <span className="badge info" key={r}>
                  {t(`role${r}`)}
                </span>
              ))}
            </div>
          </div>
        </div>
        <button className="btn" onClick={() => window.history.length > 1 ? window.history.back() : navigate('/users')}>
          {t('back')}
        </button>
      </div>
      <ErrorAlert error={error} />
      <div className="grid cols-2">
        <div className="card">
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
            <dt>ID</dt>
            <dd className="mono small">{u.id}</dd>
          </dl>
        </div>
        <div className="card">
          <h2>{t('balances')}</h2>
          {data.balances ? (
            <dl className="kv">
              <dt>{t('coins')}</dt>
              <dd className="num">{n(data.balances.coins)}</dd>
              <dt>{t('cherries')}</dt>
              <dd className="num">{n(data.balances.cherries)}</dd>
              <dt>{t('lockedTaskCherries')}</dt>
              <dd className="num">{n(data.balances.lockedTaskCherries)}</dd>
            </dl>
          ) : (
            <p className="muted small">{t('balancesHidden')}</p>
          )}
          <hr style={{ border: 0, borderTop: '1px solid var(--border)', margin: '14px 0' }} />
          <dl className="kv">
            {data.rechargeAgent && (
              <>
                <dt>{t('rechargeAgent')}</dt>
                <dd>
                  <span className="mono">{data.rechargeAgent.code ?? t('none')}</span> <StatusBadge status={data.rechargeAgent.status} /> ·{' '}
                  {t('stock')} <span className="num">{n(data.rechargeAgent.stockCoins)}</span>
                </dd>
              </>
            )}
            {data.hostAgent && (
              <>
                <dt>{t('hostAgent')}</dt>
                <dd>
                  <span className="mono">{data.hostAgent.hostCode ?? data.hostAgent.inviteCode}</span> · {data.hostAgent.rank}
                  {data.hostAgent.suspended ? ` · ${t('statusSUSPENDED')}` : ''}
                </dd>
              </>
            )}
            {data.agencyHost && (
              <>
                <dt>{t('agencyHost')}</dt>
                <dd>
                  <span className="mono">{data.agencyHost.agencyInviteCode}</span> · {data.agencyHost.status}
                </dd>
              </>
            )}
            <dt>{t('reportsAgainst')}</dt>
            <dd>
              <span className="num">{n(data.reports.open)}</span> {t('openReports')}
            </dd>
          </dl>
        </div>
      </div>
      {(can('users.ban') || can('users.avatar') || can('users.special_username')) && (
        <div className="card" style={{ marginTop: 14 }}>
          <h2>{t('actions')}</h2>
          <div className="row">
            {can('users.ban') && u.status === 'ACTIVE' && (
              <button className="btn danger" onClick={() => setAction('ban')}>
                {t('ban')}
              </button>
            )}
            {can('users.ban') && u.status === 'SUSPENDED' && (
              <button className="btn" onClick={() => setAction('unban')}>
                {t('unban')}
              </button>
            )}
            {can('users.avatar') && u.avatarUrl && (
              <button className="btn" onClick={() => setAction('avatar')}>
                {t('removeAvatar')}
              </button>
            )}
            {can('users.special_username') && (
              <button className="btn" onClick={() => setAction('gift')}>
                {t('giftSpecial')}
              </button>
            )}
            {can('users.special_username') && data.specialUsername && (
              <button className="btn" onClick={() => setAction('revoke')}>
                {t('revokeSpecial')}
              </button>
            )}
          </div>
        </div>
      )}
      {data.reports.recent.length > 0 && (
        <div className="card" style={{ marginTop: 14 }}>
          <h2>{t('reportsAgainst')}</h2>
          <div className="table-wrap">
            <table>
              <tbody>
                {data.reports.recent.map((r) => (
                  <tr key={r.id}>
                    <td>{isKey(`reason${r.reason}`) ? t(`reason${r.reason}` as never) : r.reason}</td>
                    <td>
                      <StatusBadge status={r.status} />
                    </td>
                    <td className="date small">{formatDate(r.createdAt, lang)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      {data.ledger && (
        <div className="grid cols-2" style={{ marginTop: 14 }}>
          <Ledger title={t('ledgerCoins')} rows={data.ledger.coins} />
          <Ledger title={t('ledgerCherries')} rows={data.ledger.cherries} />
        </div>
      )}
      {action === 'ban' && reasonAction('ban', t('ban'), true)}
      {action === 'unban' && reasonAction('unban', t('unban'))}
      {action === 'avatar' && reasonAction('avatar/remove', t('removeAvatar'), true)}
      {action === 'revoke' && reasonAction('special-username/revoke', t('revokeSpecial'))}
      {action === 'gift' && <GiftDialog userId={id} onClose={() => setAction(null)} onDone={done} />}
    </>
  );
}
