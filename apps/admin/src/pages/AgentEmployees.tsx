import { api } from '../api';
import { Dialog, ErrorAlert, Loading, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { AgentEmployee, AgentRow, EmployeeStats } from '../types';

/**
 * D287 (v1.87-social, CONVENTIONS §10.100): an agent's employees with what each did for the agent — sales, cherry purchases (coins into the
 * stock) and orders done (coins to buyers), today / 7 / 30 days — and their two permissions. Read only
 * (`recharge.agents`); the agent sets the permissions in the app.
 */
export function AgentEmployeesTable({ rows }: { rows: AgentEmployee[] }) {
  const { t, lang } = useApp();
  if (rows.length === 0)
    return <p className="muted">{t('agentEmployeesEmpty')}</p>;
  const totals = (s: EmployeeStats) =>
    t('empTotals', {
      today: `${formatNumber(s.today.count, lang)} (${formatNumber(s.today.coins, lang)})`,
      d7: `${formatNumber(s.last7Days.count, lang)} (${formatNumber(s.last7Days.coins, lang)})`,
      d30: `${formatNumber(s.last30Days.count, lang)} (${formatNumber(s.last30Days.coins, lang)})`,
    });
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>{t('colUser')}</th>
            <th>{t('empPerms')}</th>
            <th>{t('empSales')}</th>
            <th>{t('empCherries')}</th>
            <th>{t('empOrders')}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((e) => (
            <tr key={e.userId} data-employee={e.username}>
              <td>
                <UserCell username={e.username} displayName={e.displayName} />
                <div className="muted small">
                  {e.removedAt
                    ? t('empRemoved', { date: formatDate(e.removedAt, lang) })
                    : e.onShiftNow
                      ? t('empOnShift')
                      : e.timeZone}
                </div>
              </td>
              <td className="small">
                <div>{(e.canBuyCherries ? '✓ ' : '✗ ') + t('empCanBuy')}</div>
                <div>{(e.receivesOrders ? '✓ ' : '✗ ') + t('empReceives')}</div>
              </td>
              <td className="num small">{totals(e.sales)}</td>
              <td className="num small">{totals(e.cherryPurchases)}</td>
              <td className="num small">{totals(e.orders)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function AgentEmployeesDialog({
  agent,
  onClose,
}: {
  agent: AgentRow;
  onClose: () => void;
}) {
  const { t } = useApp();
  const { data, error, loading } = useAsync(
    () =>
      api.get<{ data: AgentEmployee[] }>(
        `/admin/recharge/agents/${agent.userId}/employees`,
      ),
    [agent.userId],
  );
  return (
    <Dialog
      title={t('agentEmployeesTitle', {
        name: agent.displayName || agent.username,
      })}
      onClose={onClose}
    >
      <p className="muted small">{t('agentEmployeesIntro')}</p>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && <AgentEmployeesTable rows={data.data} />}
      <div className="actions">
        <button type="button" className="btn" onClick={onClose}>
          {t('close')}
        </button>
      </div>
    </Dialog>
  );
}
