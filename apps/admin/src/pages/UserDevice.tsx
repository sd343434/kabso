import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, StatusBadge, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { DeviceSignups } from '../types';
import { Icon } from '../ui/icons';

/**
 * D223 (v1.78-social, CONVENTIONS §10.75): the user page's «الجهاز» — the accounts created on the device this account
 * was created on (deleted ones count toward the limit), the limit and an OWNER's exception for that device (a reason
 * and the authenticator code again). Opening the tab is audited by the API.
 */
export function UserDevice({ id }: { id: string }) {
  const { t, toast } = useApp();
  const [bump, setBump] = useState(0);
  const [dialog, setDialog] = useState<'grant' | 'remove' | null>(null);
  const { data, error, loading } = useAsync(
    () => api.get<DeviceSignups>(`/admin/users/${id}/device-signups`),
    [id, bump],
  );
  const done = () => {
    setDialog(null);
    toast(t('done'));
    setBump((b) => b + 1);
  };
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <div className="card" data-testid="user-device">
      <DeviceSignupsView data={data} onGrant={() => setDialog('grant')} onRemove={() => setDialog('remove')} />
      <ErrorAlert error={error} />
      {dialog === 'grant' && (
        <FormDialog
          title={t('dvGrant')}
          intro={<p className="muted small">{t('dvGrantIntro')}</p>}
          fields={[
            { name: 'maxAccounts', label: t('dvMaxAccounts'), maxLength: 3 },
            reasonField(t),
            { ...codeField(t), hint: t('ctCodeHint') },
          ]}
          confirmLabel={t('confirm')}
          submit={(v) =>
            api.put(`/admin/users/${id}/device-signups/exception`, {
              maxAccounts: Number(v.maxAccounts),
              reason: v.reason,
              totpCode: v.totpCode,
            })
          }
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
      {dialog === 'remove' && (
        <FormDialog
          title={t('dvRemove')}
          intro={<p className="muted small">{t('dvRemoveIntro')}</p>}
          fields={[reasonField(t), { ...codeField(t), hint: t('ctCodeHint') }]}
          confirmLabel={t('dvRemove')}
          danger
          submit={(v) => api.post(`/admin/users/${id}/device-signups/exception/remove`, v)}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
    </div>
  );
}

/** The tab's content for `data` (rendered without the network in the tests). */
export function DeviceSignupsView({
  data,
  onGrant,
  onRemove,
}: {
  data: DeviceSignups;
  onGrant: () => void;
  onRemove: () => void;
}) {
  const { t, lang, can } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  const owner = can('users.device_exception');
  return (
    <>
      <h2>{t('dvTitle')}</h2>
      <p className="muted small">{t('dvIntro', { max: n(data.defaultMax) })}</p>
      {!data.known ? (
        <div className="state empty-state">
          <Icon name="shield" size={28} />
          <p>{t('dvUnknown')}</p>
        </div>
      ) : (
        <>
          <dl className="kv">
            <dt>{t('dvCount')}</dt>
            <dd>
              <b>{n(data.count)}</b> / {n(data.maxAccounts)}
            </dd>
            <dt>{t('dvLimit')}</dt>
            <dd>{n(data.maxAccounts)}</dd>
            <dt>{t('dvDefault')}</dt>
            <dd>{n(data.defaultMax)}</dd>
            <dt>{t('dvPlatform')}</dt>
            <dd>{data.platform ?? t('none')}</dd>
            <dt>{t('dvRecorded')}</dt>
            <dd className="date">{formatDate(data.createdAt, lang)}</dd>
            <dt>{t('dvException')}</dt>
            <dd>
              {data.exception ? (
                <>
                  <b>{n(data.exception.maxAccounts)}</b> — {data.exception.reason}
                  <div className="muted small">
                    {t('dvExceptionBy', {
                      who: data.exception.grantedBy ? `@${data.exception.grantedBy.username}` : t('system'),
                      date: formatDate(data.exception.grantedAt, lang),
                    })}
                  </div>
                </>
              ) : (
                t('dvExceptionNone')
              )}
            </dd>
          </dl>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t('colUser')}</th>
                  <th>{t('colStatus')}</th>
                  <th>{t('colJoined')}</th>
                </tr>
              </thead>
              <tbody>
                {data.accounts.map((a) => (
                  <tr key={a.id}>
                    <td>
                      {a.self ? (
                        <span>
                          <span className="ltr">@{a.username}</span> <span className="muted small">({t('dvThisAccount')})</span>
                        </span>
                      ) : (
                        <button className="btn small ghost" onClick={() => navigate(`/users/${a.id}`)}>
                          <span className="ltr">@{a.username}</span>
                        </button>
                      )}
                    </td>
                    <td>
                      <StatusBadge status={a.status} />
                    </td>
                    <td className="date small">{formatDate(a.createdAt, lang)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {owner && (
            <div className="row actions-row" style={{ marginTop: 10 }}>
              <button className="btn" onClick={onGrant}>
                {t('dvGrant')}
              </button>
              {data.exception && (
                <button className="btn danger" onClick={onRemove}>
                  {t('dvRemove')}
                </button>
              )}
            </div>
          )}
        </>
      )}
    </>
  );
}
