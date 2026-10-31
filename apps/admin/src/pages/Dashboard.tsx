import { api } from '../api';
import { ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import type { Dashboard as DashboardDto } from '../types';

export function Dashboard() {
  const { t, lang, can } = useApp();
  const { data, error, loading } = useAsync(() => api.get<DashboardDto>('/admin/dashboard'), []);
  const n = (v: number) => formatNumber(v, lang);
  const pending: { key: Parameters<typeof t>[0]; value: number; to: string; show: boolean }[] = data
    ? [
        { key: 'dashPendingApps', value: data.pending.rechargeApplications, to: '/recharge/applications', show: can('recharge.applications') },
        { key: 'dashPendingWithdrawals', value: data.pending.withdrawals, to: '/withdrawals', show: can('withdrawals.view') },
        { key: 'dashPendingReports', value: data.pending.reports, to: '/reports', show: can('reports.view') },
      ]
    : [];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('dashTitle')}</h1>
          {data && (
            <p className="muted small">
              {t('dashToday')} · <span className="date">{formatDate(data.since, lang)}</span>
            </p>
          )}
        </div>
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && (
        <>
          <div className="grid cols-4">
            <div className="card stat">
              <div className="label">{t('dashNewUsers')}</div>
              <div className="value">{n(data.today.newUsers)}</div>
            </div>
            <div className="card stat">
              <div className="label">{t('dashAgentCoins')}</div>
              <div className="value">{n(data.today.agentCoinsSold)}</div>
              <div className="sub">
                {t('dashAgentSales')}: <span className="num">{n(data.today.agentSales)}</span>
              </div>
            </div>
            <div className="card stat">
              <div className="label">{t('dashGifts')}</div>
              <div className="value">{n(data.today.giftsSent)}</div>
              <div className="sub">
                {t('dashGiftCoins')}: <span className="num">{n(data.today.giftCoins)}</span>
              </div>
            </div>
            <div className="card stat">
              <div className="label">{t('dashLives')}</div>
              <div className="value">{n(data.livesNow)}</div>
            </div>
          </div>
          <h2 style={{ marginTop: 28 }}>{t('dashPending')}</h2>
          <div className="grid cols-3">
            {pending.map((p) => (
              <div className="card stat" key={p.key}>
                <div className="label">{t(p.key)}</div>
                <div className="value">{n(p.value)}</div>
                {p.show && (
                  <button className="btn small" style={{ marginTop: 8 }} onClick={() => navigate(p.to)}>
                    {t('dashOpen')}
                  </button>
                )}
              </div>
            ))}
          </div>
        </>
      )}
    </>
  );
}
