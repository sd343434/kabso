import { useState } from 'react';
import { api } from '../api';
import { Avatar, ErrorAlert, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey, type Key } from '../i18n';
import { navigate } from '../router';
import type { ActivityRow, Attention, Kpi, StatsDay, StatsOverview } from '../types';
import { LineChart, Sparkline } from '../ui/charts';
import { Icon, type IconName } from '../ui/icons';
import { ATTENTION_LINK } from '../ui/Shell';
import { homesOf, RoleHomes } from './RoleHomes';

/** The dashboard's day in its own time zone (Asia/Riyadh), whatever the browser's zone. */
export function formatDay(iso: string, timeZone: string, lang: 'ar' | 'en'): string {
  return new Intl.DateTimeFormat(lang === 'ar' ? 'ar-u-nu-latn' : 'en-GB', { dateStyle: 'full', timeZone }).format(
    new Date(new Date(iso).getTime() + 12 * 3_600_000),
  );
}

/** The change against yesterday, in percent (null when yesterday was 0). */
export function deltaPercent(today: number, yesterday: number): number | null {
  if (yesterday === 0) return today === 0 ? 0 : null;
  return Math.round(((today - yesterday) / yesterday) * 100);
}

function Delta({ kpi }: { kpi: Kpi }) {
  const { t, lang } = useApp();
  const p = deltaPercent(kpi.today, kpi.yesterday);
  const up = kpi.today >= kpi.yesterday;
  return (
    <span className={`delta ${kpi.today === kpi.yesterday ? 'flat' : up ? 'up' : 'down'}`}>
      <Icon name={up ? 'arrowUp' : 'arrowDown'} size={13} />
      {p === null ? t('kpiNew') : `${formatNumber(Math.abs(p), lang)}%`}
      <span className="vs">{t('kpiVsYesterday', { n: formatNumber(kpi.yesterday, lang) })}</span>
    </span>
  );
}

function KpiCard({
  tone,
  icon,
  label,
  kpi,
  sub,
  onOpen,
}: {
  tone: string;
  icon: IconName;
  label: Key;
  kpi: Kpi;
  sub?: string;
  onOpen?: () => void;
}) {
  const { t, lang } = useApp();
  return (
    <div className={`kpi tone-${tone}`}>
      <div className="kpi-top">
        <span className="kpi-icon">
          <Icon name={icon} size={22} />
        </span>
        <span className="kpi-label">{t(label)}</span>
      </div>
      <div className="kpi-value num">{formatNumber(kpi.value, lang)}</div>
      {sub && <div className="kpi-sub">{sub}</div>}
      <div className="kpi-foot">
        <Delta kpi={kpi} />
        {onOpen && (
          <button type="button" className="kpi-open" onClick={onOpen} aria-label={t('dashOpen')}>
            <Icon name="chevron" size={16} />
          </button>
        )}
      </div>
      <Sparkline values={kpi.spark} label={t('kpiSpark', { label: t(label) })} />
    </div>
  );
}

function actionLabel(t: (k: Key) => string, action: string): string {
  const key = `act_${action.replace(/[.]/g, '_')}`;
  return isKey(key) ? t(key) : action;
}

/**
 * The panel's landing page. v1.139-social (D387, CONVENTIONS §10.176.2–3): the KPI dashboard (coins sold, gift coin
 * value) is the OWNER's alone (`revenue.view`); anyone else lands on their role's home (`RoleHomes`) or, with no role
 * home (SUPPORT, FINANCE), on the attention list and the activity — no money card.
 */
export function Dashboard() {
  const { can } = useApp();
  return can('revenue.view') ? <OwnerDashboard /> : <StaffDashboard />;
}

/** «يحتاج انتباهك» (D197; every role with `dashboard.view`). */
export function AttentionCard() {
  const { t, lang } = useApp();
  const attention = useAsync(() => api.get<Attention>('/admin/stats/attention'), []);
  const n = (v: number) => formatNumber(v, lang);
  return (
    <section className="card">
      <div className="card-head">
        <h2>{t('attnTitle')}</h2>
      </div>
      <ErrorAlert error={attention.error} />
      <ul className="attention">
        {attention.data?.items.map((i) => (
          <li key={i.kind}>
            <button type="button" onClick={() => navigate(ATTENTION_LINK[i.kind].to)} className={i.count > 0 ? 'hot' : ''}>
              <span className="names">
                <span>{t(ATTENTION_LINK[i.kind].key)}</span>
                <span className="muted small">
                  {i.oldestAt ? t('attnOldest', { date: formatDate(i.oldestAt, lang) }) : t('attnClear')}
                </span>
              </span>
              <span className={`pill ${i.count > 0 ? 'hot' : ''}`}>{n(i.count)}</span>
            </button>
          </li>
        ))}
        {attention.data && attention.data.items.length === 0 && <li className="muted small">{t('attnNone')}</li>}
      </ul>
    </section>
  );
}

/** A staff member's landing page (D387): their role homes, then the attention list. */
function StaffDashboard() {
  const { t, can, session } = useApp();
  const homes = homesOf(can);
  return (
    <>
      {homes.length > 0 ? (
        <RoleHomes />
      ) : (
        <div className="page-head">
          <div>
            <h1>{t('homeHello', { name: session?.admin.displayName ?? '' })}</h1>
            <p className="muted small">
              {session?.roles.map((r) => t(`role${r}`)).join(' · ')} · {t('homeNoMoney')}
            </p>
          </div>
        </div>
      )}
      {can('dashboard.view') && (
        <div className="dash-grid">
          <AttentionCard />
        </div>
      )}
    </>
  );
}

/**
 * The OWNER's home (D197): five KPI cards with a 14-day sparkline and the change against yesterday, the 7/30/90-day chart of
 * new users, coins sold and gift coins, «يحتاج انتباهك» and the latest panel activity — every number a real
 * aggregate of `/admin/stats/*` on the Asia/Riyadh day.
 */
function OwnerDashboard() {
  const { t, lang, can, session } = useApp();
  const [days, setDays] = useState<7 | 30 | 90>(30);
  const overview = useAsync(() => api.get<StatsOverview>('/admin/stats/overview'), []);
  const series = useAsync(() => api.get<{ timeZone: string; days: StatsDay[] }>('/admin/stats/series', { days }), [days]);
  const activity = useAsync(() => api.get<{ data: ActivityRow[] }>('/admin/stats/activity'), []);
  const n = (v: number) => formatNumber(v, lang);
  const k = overview.data?.kpis;
  const hour = new Date().getHours();
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t(hour < 12 ? 'dashMorning' : 'dashEvening', { name: session?.admin.displayName ?? '' })}</h1>
          <p className="muted small">
            {t('dashSubtitle')}
            {overview.data && (
              <>
                {' · '}
                <span className="date">{formatDay(overview.data.since, overview.data.timeZone, lang)}</span>
              </>
            )}
          </p>
        </div>
      </div>
      <ErrorAlert error={overview.error} />
      <div className="kpis">
        {k ? (
          <>
            <KpiCard tone="red" icon="users" label="kpiNewUsers" kpi={k.newUsers} onOpen={can('users.list') ? () => navigate('/users') : undefined} />
            <KpiCard
              tone="gold"
              icon="coins"
              label="kpiCoinsSold"
              kpi={k.coinsSold}
              sub={t('kpiCoinsSplit', { agents: n(k.coinsSold.agentsToday), web: n(k.coinsSold.websiteToday) })}
              onOpen={can('finance.view') ? () => navigate('/finance/report') : undefined}
            />
            <KpiCard tone="blue" icon="gift" label="kpiGiftCoins" kpi={k.giftCoins} sub={t('kpiGiftsCount', { n: n(k.giftCoins.giftsToday) })} />
            <KpiCard
              tone="green"
              icon="live"
              label="kpiLivesNow"
              kpi={k.lives}
              sub={t('kpiLivesStarted', { n: n(k.lives.today) })}
              onOpen={can('lives.view') ? () => navigate('/lives') : undefined}
            />
            <KpiCard tone="wine" icon="inbox" label="kpiPending" kpi={k.pending} sub={t('kpiPendingNew', { n: n(k.pending.today) })} />
          </>
        ) : (
          !overview.error && Array.from({ length: 5 }, (_, i) => <div key={i} className="kpi skeleton-card" />)
        )}
      </div>

      <div className="dash-grid">
        <section className="card chart-card">
          <div className="card-head">
            <div>
              <h2>{t('chartTitle')}</h2>
              <p className="muted small">{t('chartSubtitle')}</p>
            </div>
            <div className="segmented" role="group" aria-label={t('chartRange')}>
              {([7, 30, 90] as const).map((d) => (
                <button key={d} type="button" aria-pressed={days === d} onClick={() => setDays(d)}>
                  {t('chartDays', { n: d })}
                </button>
              ))}
            </div>
          </div>
          <ErrorAlert error={series.error} />
          {series.data ? (
            <LineChart
              rtl={lang === 'ar'}
              label={t('chartTitle')}
              labels={series.data.days.map((d) => d.day)}
              format={(v) => formatNumber(v, lang)}
              series={[
                { key: 'coins', label: t('chartCoinsSold'), color: 'var(--c-gold)', values: series.data.days.map((d) => d.coinsSold) },
                { key: 'gifts', label: t('chartGiftCoins'), color: 'var(--c-blue)', values: series.data.days.map((d) => d.giftCoins) },
                { key: 'users', label: t('chartNewUsers'), color: 'var(--primary)', values: series.data.days.map((d) => d.newUsers), axis: 'end' },
              ]}
            />
          ) : (
            !series.error && <div className="chart skeleton-card tall" />
          )}
          <p className="muted small">{t('chartAxesNote')}</p>
        </section>

        <AttentionCard />

        <section className="card activity-card">
          <div className="card-head">
            <h2>{t('activityTitle')}</h2>
            {can('audit.view') && (
              <button className="btn small ghost" onClick={() => navigate('/audit')}>
                {t('activityAll')}
              </button>
            )}
          </div>
          <ErrorAlert error={activity.error} />
          <ul className="activity">
            {activity.data?.data.map((r) => (
              <li key={r.id}>
                <Avatar url={r.actor?.avatarUrl ?? null} name={r.actor?.displayName || r.actor?.username || '?'} />
                <span className="names">
                  <span>
                    <strong>{r.actor?.displayName ?? t('system')}</strong> · {actionLabel(t, r.action)}
                  </span>
                  <span className="muted small">
                    <span className="date">{formatDate(r.createdAt, lang)}</span>
                    {r.targetType ? ` · ${r.targetType}` : ''}
                  </span>
                </span>
              </li>
            ))}
            {activity.data && activity.data.data.length === 0 && <li className="muted small">{t('activityNone')}</li>}
          </ul>
        </section>
      </div>
    </>
  );
}
