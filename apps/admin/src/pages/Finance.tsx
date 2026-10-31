import { useState } from 'react';
import { api, downloadCsv } from '../api';
import { codeField, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatMoney, formatNumber } from '../format';
import type { Key } from '../i18n';
import type { PersonRef } from '../types';
import { LineChart } from '../ui/charts';
import { DataTable } from '../ui/DataTable';
import { Icon } from '../ui/icons';

interface ReportRow {
  period: string;
  agentTopupCoins: number;
  agentRevenueMinor: number;
  agentExpectedMinor: number;
  agentSalesCoins: number;
  cardCoins: number;
  cardRevenueMinor: number;
  cardRefundedMinor: number;
  hostPayoutsMinor: number;
  cherriesWithdrawn: number;
  agencyCommissionCherries: number;
  cherriesIssued: number;
  cherriesReversed: number;
  cherriesSoldToAgents: number;
  cherriesIssuedValueMinor: number;
  estimatedMarginMinor: number;
}

interface ReportDto {
  granularity: 'day' | 'month';
  from: string;
  to: string;
  timeZone: string;
  currency: string;
  rate: { cherries: number; minor: number };
  rows: ReportRow[];
  totals: ReportRow;
}

/** YYYY-MM-DD of a date in Asia/Riyadh (the report's day). */
export function riyadhDay(at: Date): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh' }).format(at);
}

/** The default range of a granularity: the last 30 days, or the last 12 months. */
export function defaultRange(granularity: 'day' | 'month', now = new Date()): { from: string; to: string } {
  const to = riyadhDay(now);
  if (granularity === 'day') return { from: riyadhDay(new Date(now.getTime() - 29 * 86_400_000)), to };
  const [y, m] = to.split('-').map(Number) as [number, number];
  const start = new Date(Date.UTC(y, m - 1 - 11, 1));
  return { from: `${start.getUTCFullYear()}-${String(start.getUTCMonth() + 1).padStart(2, '0')}-01`, to };
}

/** «التقرير المالي» (D197): money in and out by day or month (Asia/Riyadh), the estimated margin, CSV (audited). */
export function Report() {
  const { t, lang } = useApp();
  const [granularity, setGranularity] = useState<'day' | 'month'>('day');
  const [range, setRange] = useState(() => defaultRange('day'));
  const [csvError, setCsvError] = useState<unknown>(null);
  const { data, error, loading } = useAsync(() => api.get<ReportDto>('/admin/finance/report', { granularity, ...range }), [granularity, range.from, range.to]);
  const money = (v: number) => formatMoney(v, data?.currency ?? 'USD', lang);
  const n = (v: number) => formatNumber(v, lang);
  const cards: { key: Key; value: string; tone: string; note?: Key }[] = data
    ? [
        { key: 'repAgentRevenue', value: money(data.totals.agentRevenueMinor), tone: 'gold' },
        { key: 'repCardRevenue', value: money(data.totals.cardRevenueMinor - data.totals.cardRefundedMinor), tone: 'blue', note: 'repCardNet' },
        { key: 'repHostPayouts', value: money(data.totals.hostPayoutsMinor), tone: 'red' },
        { key: 'repMargin', value: money(data.totals.estimatedMarginMinor), tone: 'green', note: 'repMarginNote' },
      ]
    : [];
  const rows: { key: Key; get: (r: ReportRow) => string }[] = [
    { key: 'repAgentTopupCoins', get: (r) => n(r.agentTopupCoins) },
    { key: 'repAgentRevenue', get: (r) => money(r.agentRevenueMinor) },
    { key: 'repAgentExpected', get: (r) => money(r.agentExpectedMinor) },
    { key: 'repAgentSales', get: (r) => n(r.agentSalesCoins) },
    { key: 'repCardCoins', get: (r) => n(r.cardCoins) },
    { key: 'repCardRevenue', get: (r) => money(r.cardRevenueMinor) },
    { key: 'repCardRefunded', get: (r) => money(r.cardRefundedMinor) },
    { key: 'repHostPayouts', get: (r) => money(r.hostPayoutsMinor) },
    { key: 'repCherriesWithdrawn', get: (r) => n(r.cherriesWithdrawn) },
    { key: 'repCommissions', get: (r) => n(r.agencyCommissionCherries) },
    { key: 'repCherriesIssued', get: (r) => n(r.cherriesIssued) },
    { key: 'repCherriesIssuedValue', get: (r) => money(r.cherriesIssuedValueMinor) },
    { key: 'repCherriesReversed', get: (r) => n(r.cherriesReversed) },
    { key: 'repCherriesSold', get: (r) => n(r.cherriesSoldToAgents) },
    { key: 'repMargin', get: (r) => money(r.estimatedMarginMinor) },
  ];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('reportTitle')}</h1>
          <p className="muted small">{t('reportSubtitle')}</p>
        </div>
        <button
          className="btn"
          disabled={!data}
          onClick={() => {
            setCsvError(null);
            downloadCsv('/admin/finance/report', { granularity, ...range }, 'kabso-finance-report.csv').catch(setCsvError);
          }}
        >
          <Icon name="download" size={16} />
          {t('tableCsv')}
        </button>
      </div>
      <div className="filters card">
        <div className="segmented" role="group" aria-label={t('repGranularity')}>
          {(['day', 'month'] as const).map((g) => (
            <button
              key={g}
              type="button"
              aria-pressed={granularity === g}
              onClick={() => {
                setGranularity(g);
                setRange(defaultRange(g));
              }}
            >
              {t(g === 'day' ? 'repDaily' : 'repMonthly')}
            </button>
          ))}
        </div>
        <label className="field">
          <span>{t('from')}</span>
          <input type="date" value={range.from} max={range.to} onChange={(e) => e.target.value && setRange((r) => ({ ...r, from: e.target.value }))} />
        </label>
        <label className="field">
          <span>{t('to')}</span>
          <input type="date" value={range.to} min={range.from} onChange={(e) => e.target.value && setRange((r) => ({ ...r, to: e.target.value }))} />
        </label>
      </div>
      <ErrorAlert error={error ?? csvError} />
      {loading && !data && <div className="kpis">{Array.from({ length: 4 }, (_, i) => <div key={i} className="kpi skeleton-card" />)}</div>}
      {data && (
        <>
          <div className="kpis four">
            {cards.map((c) => (
              <div key={c.key} className={`kpi tone-${c.tone}`}>
                <div className="kpi-label">{t(c.key)}</div>
                <div className="kpi-value num small-value">{c.value}</div>
                {c.note && <div className="kpi-sub">{t(c.note)}</div>}
              </div>
            ))}
          </div>
          <section className="card chart-card">
            <h2>{t('repChart')}</h2>
            <LineChart
              rtl={lang === 'ar'}
              label={t('repChart')}
              labels={data.rows.map((r) => (granularity === 'month' ? `${r.period}-01` : r.period))}
              format={(v) => money(Math.round(v * 100))}
              series={[
                { key: 'agent', label: t('repAgentRevenue'), color: 'var(--c-gold)', values: data.rows.map((r) => r.agentRevenueMinor / 100) },
                { key: 'card', label: t('repCardRevenue'), color: 'var(--c-blue)', values: data.rows.map((r) => r.cardRevenueMinor / 100) },
                { key: 'payout', label: t('repHostPayouts'), color: 'var(--primary)', values: data.rows.map((r) => r.hostPayoutsMinor / 100) },
              ]}
            />
            <p className="muted small">{t('repChartNote')}</p>
          </section>
          <section className="card">
            <h2>{t('repTable')}</h2>
            <div className="table-wrap report-table">
              <table>
                <thead>
                  <tr>
                    <th>{t('repMetric')}</th>
                    {data.rows.map((r) => (
                      <th key={r.period} className="num">
                        {granularity === 'day' ? r.period.slice(5) : r.period}
                      </th>
                    ))}
                    <th className="num">{t('total')}</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((m) => (
                    <tr key={m.key}>
                      <th scope="row">{t(m.key)}</th>
                      {data.rows.map((r) => (
                        <td key={r.period} className="num">
                          {m.get(r)}
                        </td>
                      ))}
                      <td className="num strong">{m.get(data.totals)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="muted small">{t('repRateNote', { cherries: n(data.rate.cherries), money: money(data.rate.minor), zone: data.timeZone })}</p>
          </section>
        </>
      )}
    </>
  );
}

interface TopupRow {
  id: string;
  agent: PersonRef & { code: string | null };
  coins: number;
  tier: string;
  pricePerMillionMinor: number;
  expectedMinor: number;
  paidMinor: number;
  currency: string;
  first: boolean;
  note: string | null;
  createdAt: string;
}

/** The recharge agents' top-ups «شحن الوكلاء»: coins, tier price and what was paid (FINANCE, OWNER). */
export function AgentTopups() {
  const { t, lang } = useApp();
  const [totals, setTotals] = useState<{ coins: number; paidMinor: number; expectedMinor: number } | null>(null);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('topupsTitle')}</h1>
          <p className="muted small">{t('topupsSubtitle')}</p>
        </div>
      </div>
      {totals && (
        <div className="mini-stats">
          <div className="mini-stat">
            <span className="muted small">{t('repAgentTopupCoins')}</span>
            <strong className="num">{formatNumber(totals.coins, lang)}</strong>
          </div>
          <div className="mini-stat">
            <span className="muted small">{t('topupsPaid')}</span>
            <strong className="num">{formatMoney(totals.paidMinor, 'USD', lang)}</strong>
          </div>
          <div className="mini-stat">
            <span className="muted small">{t('repAgentExpected')}</span>
            <strong className="num">{formatMoney(totals.expectedMinor, 'USD', lang)}</strong>
          </div>
        </div>
      )}
      <DataTable<TopupRow>
        id="recharge-topups"
        endpoint="/admin/finance/recharge-topups"
        rowKey={(r) => r.id}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="topupsSearch"
        csv
        onLoaded={(p) => setTotals((p as unknown as { totals: { coins: number; paidMinor: number; expectedMinor: number } }).totals)}
        columns={[
          {
            key: 'agent',
            label: 'colAgent',
            render: (r) => (
              <span className="names">
                <span className="mono">{r.agent.code ?? '—'}</span>
                <span className="ltr muted small">@{r.agent.username}</span>
              </span>
            ),
          },
          { key: 'coins', label: 'coins', sort: 'coins', numeric: true, render: (r) => formatNumber(r.coins, lang) },
          { key: 'tier', label: 'colTier', render: (r) => <span className="mono small">{r.tier}</span> },
          { key: 'expected', label: 'repAgentExpected', numeric: true, render: (r) => formatMoney(r.expectedMinor, r.currency, lang) },
          {
            key: 'paid',
            label: 'topupsPaid',
            sort: 'paidMinor',
            numeric: true,
            render: (r) => <span className={r.paidMinor !== r.expectedMinor ? 'warn-text' : ''}>{formatMoney(r.paidMinor, r.currency, lang)}</span>,
          },
          { key: 'first', label: 'topupsFirst', optional: true, render: (r) => (r.first ? t('yes') : t('no')) },
          { key: 'note', label: 'note', optional: true, render: (r) => <span className="clip small">{r.note ?? '—'}</span> },
          { key: 'date', label: 'colDate', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
        ]}
      />
    </>
  );
}

interface OrderRow {
  id: string;
  user: PersonRef;
  coins: number;
  amountMinor: number;
  currency: string;
  status: string;
  paymentMethodType: string | null;
  creditedAt: string | null;
  refundedMinor: number;
  teamRefundedMinor: number;
  disputeStatus: string | null;
  coinsReversed: number;
  cases: number;
  refundable: boolean;
  createdAt: string;
}

interface CaseRow {
  id: string;
  orderId: string;
  kind: string;
  status: string;
  outcome: string | null;
  coinsReversed: number;
  amountMinor: number;
  currency: string;
  note: string | null;
  user: PersonRef;
  createdAt: string;
  closedAt: string | null;
}

/** Website card top-ups (D190): orders with the team refund (code again) and the Stripe cases. */
export function Cards() {
  const { t, lang, can, toast } = useApp();
  const [tab, setTab] = useState<'orders' | 'cases'>('orders');
  const [refund, setRefund] = useState<OrderRow | null>(null);
  const [close, setClose] = useState<CaseRow | null>(null);
  const [bump, setBump] = useState(0);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('cardsTitle')}</h1>
          <p className="muted small">{t('cardsSubtitle')}</p>
        </div>
      </div>
      <div className="tabs">
        <button className="tab" aria-pressed={tab === 'orders'} onClick={() => setTab('orders')}>
          {t('cardsOrders')}
        </button>
        <button className="tab" aria-pressed={tab === 'cases'} onClick={() => setTab('cases')}>
          {t('cardsCases')}
        </button>
      </div>
      {tab === 'orders' && (
        <DataTable<OrderRow>
          id="card-orders"
          endpoint="/admin/finance/card-orders"
          rowKey={(r) => r.id}
          reloadKey={bump}
          defaultSort={{ sort: 'createdAt', order: 'desc' }}
          searchLabel="cardsSearch"
          csv
          filters={[{ name: 'status', label: 'colStatus', options: ['PAID', 'PENDING', 'AWAITING_FUNDS', 'EXPIRED', 'FAILED'].map((s) => ({ value: s, label: `order${s}` })) }]}
          columns={[
            { key: 'user', label: 'colUser', render: (r) => <UserCell username={r.user.username} displayName={r.user.displayName} /> },
            { key: 'coins', label: 'coins', numeric: true, render: (r) => formatNumber(r.coins, lang) },
            { key: 'amount', label: 'colAmount', sort: 'amountMinor', numeric: true, render: (r) => formatMoney(r.amountMinor, r.currency, lang) },
            { key: 'status', label: 'colStatus', render: (r) => <span className={`badge ${r.status === 'PAID' ? 'ok' : r.status === 'FAILED' ? 'bad' : ''}`}>{t(`order${r.status}` as never)}</span> },
            {
              key: 'refunded',
              label: 'cardsRefunded',
              numeric: true,
              render: (r) => (Math.max(r.refundedMinor, r.teamRefundedMinor) > 0 ? formatMoney(Math.max(r.refundedMinor, r.teamRefundedMinor), r.currency, lang) : '—'),
            },
            { key: 'dispute', label: 'cardsDispute', optional: true, render: (r) => r.disputeStatus ?? '—' },
            { key: 'method', label: 'cardsMethod', optional: true, render: (r) => r.paymentMethodType ?? '—' },
            { key: 'date', label: 'colDate', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
            {
              key: 'act',
              label: 'colActions',
              render: (r) =>
                can('finance.refund') && r.refundable ? (
                  <button className="btn small danger" onClick={() => setRefund(r)}>
                    {t('cardsRefund')}
                  </button>
                ) : null,
            },
          ]}
        />
      )}
      {tab === 'cases' && (
        <DataTable<CaseRow>
          id="topup-cases"
          endpoint="/admin/finance/cases"
          rowKey={(r) => r.id}
          reloadKey={bump}
          csv
          filters={[{ name: 'status', label: 'colStatus', options: [{ value: 'OPEN', label: 'statusOPEN' }, { value: 'CLOSED', label: 'caseClosed' }] }]}
          columns={[
            { key: 'kind', label: 'colType', render: (r) => <span className={`badge ${r.kind === 'DISPUTE' ? 'bad' : 'warn'}`}>{t(`case${r.kind}` as never)}</span> },
            { key: 'user', label: 'colUser', render: (r) => <UserCell username={r.user.username} displayName={r.user.displayName} /> },
            { key: 'amount', label: 'colAmount', numeric: true, render: (r) => formatMoney(r.amountMinor, r.currency, lang) },
            { key: 'rev', label: 'cardsCoinsReversed', numeric: true, render: (r) => formatNumber(r.coinsReversed, lang) },
            { key: 'status', label: 'colStatus', render: (r) => (r.status === 'OPEN' ? <StatusBadge status="OPEN" /> : <span className="badge">{t('caseClosed')}</span>) },
            { key: 'date', label: 'colDate', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
            {
              key: 'act',
              label: 'colActions',
              render: (r) =>
                r.status === 'OPEN' && can('finance.refund') ? (
                  <button className="btn small" onClick={() => setClose(r)}>
                    {t('caseClose')}
                  </button>
                ) : (
                  <span className="muted small clip">{r.note ?? ''}</span>
                ),
            },
          ]}
        />
      )}
      {refund && (
        <FormDialog
          title={t('cardsRefund')}
          intro={
            <div className="alert info">
              {t('cardsRefundIntro', {
                amount: formatMoney(refund.amountMinor - Math.max(refund.refundedMinor, refund.teamRefundedMinor), refund.currency, lang),
                user: `@${refund.user.username}`,
              })}
            </div>
          }
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('cardsRefund')}
          danger
          submit={(v) => api.post(`/admin/finance/card-orders/${refund.id}/refund`, { reason: v.reason, totpCode: v.totpCode })}
          onClose={() => setRefund(null)}
          onDone={() => {
            setRefund(null);
            toast(t('cardsRefundAsked'));
            setBump((b) => b + 1);
          }}
        />
      )}
      {close && (
        <FormDialog
          title={t('caseClose')}
          fields={[{ ...reasonField(t, t('caseDecision')), name: 'note' }]}
          confirmLabel={t('caseClose')}
          submit={(v) => api.post(`/admin/finance/cases/${close.id}/close`, { note: v.note })}
          onClose={() => setClose(null)}
          onDone={() => {
            setClose(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
