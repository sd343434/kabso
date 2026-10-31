import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, StatusBadge, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { navigate } from '../router';
import { DataTable } from '../ui/DataTable';

interface TaskDto {
  code: string;
  period: string;
  metric: string;
  audience: string;
  nameAr: string;
  nameEn: string;
  enabled: boolean;
  pool: boolean;
  poolGroup: string | null;
  target: number;
  targetUsd: string | null;
  rewardCherries: number;
  rewardUsd: string;
  bands: { target: number; targetUsd: string | null; rewardCherries: number; rewardUsd: string }[];
}

/** «المهام» (D197): every task with its reward in cherries and USD (D188), read-only (`task-admin` changes them). */
export function Tasks() {
  const { t, lang } = useApp();
  const { data, error } = useAsync(
    () => api.get<{ coinRetailUsdPerMillion: number; payoutRate: { cherries: number; minor: number }; data: TaskDto[] }>('/admin/programs/tasks'),
    [],
  );
  const [pool, setPool] = useState(false);
  const n = (v: number) => formatNumber(v, lang);
  const rows = data?.data.filter((x) => x.pool === pool) ?? [];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('tasksTitle')}</h1>
          <p className="muted small">
            {data
              ? t('tasksSubtitle', { rate: `${n(data.payoutRate.cherries)} = $${(data.payoutRate.minor / 100).toFixed(2)}`, coins: `$${data.coinRetailUsdPerMillion}` })
              : ''}
          </p>
        </div>
      </div>
      <div className="tabs">
        <button className="tab" aria-pressed={!pool} onClick={() => setPool(false)}>
          {t('tasksFixed')}
        </button>
        <button className="tab" aria-pressed={pool} onClick={() => setPool(true)}>
          {t('tasksPool')}
        </button>
      </div>
      <ErrorAlert error={error} />
      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colTitle')}</th>
                <th>{t('tasksPeriod')}</th>
                <th>{t('tasksMetric')}</th>
                <th className="num">{t('tasksTarget')}</th>
                <th className="num">{t('tasksReward')}</th>
                <th>{t('colStatus')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((x) => (
                <tr key={x.code}>
                  <td>
                    <span className="names">
                      <span>{lang === 'ar' ? x.nameAr : x.nameEn}</span>
                      <span className="mono small muted">{x.code}</span>
                    </span>
                  </td>
                  <td className="small">{x.period}</td>
                  <td className="mono small">{x.metric}</td>
                  <td className="num">
                    {x.bands.length > 0 ? (
                      <span className="bands">
                        {x.bands.map((b, i) => (
                          <span key={i}>
                            {n(b.target)}
                            {b.targetUsd && <span className="muted small"> ({b.targetUsd})</span>}
                          </span>
                        ))}
                      </span>
                    ) : (
                      <>
                        {n(x.target)}
                        {x.targetUsd && <span className="muted small"> ({x.targetUsd})</span>}
                      </>
                    )}
                  </td>
                  <td className="num">
                    {x.bands.length > 0 ? (
                      <span className="bands">
                        {x.bands.map((b, i) => (
                          <span key={i}>
                            {n(b.rewardCherries)} <span className="money">{b.rewardUsd}</span>
                          </span>
                        ))}
                      </span>
                    ) : (
                      <>
                        {n(x.rewardCherries)} <span className="money">{x.rewardUsd}</span>
                      </>
                    )}
                  </td>
                  <td>{x.enabled ? <span className="badge ok">{t('enabled')}</span> : <span className="badge">{t('disabled')}</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {data && rows.length === 0 && <p className="muted state">{t('empty')}</p>}
        </div>
        <p className="muted small">{t('tasksCliNote')}</p>
      </div>
    </>
  );
}

interface LevelCat {
  code: string;
  nameAr: string;
  nameEn: string;
  enabled: boolean;
  version: number | null;
  multiplier: string | null;
  valueUnit: string | null;
  publishedAt: string | null;
  levels: { level: number; nameAr: string; nameEn: string; requiredPoints: number; coins: number | null; usd: string | null }[];
}

/** «المستويات» (D197): the published ladders with the coins and USD each level takes (read-only). */
export function Levels() {
  const { t, lang } = useApp();
  const { data, error } = useAsync(() => api.get<{ coinRetailUsdPerMillion: number; data: LevelCat[] }>('/admin/programs/levels'), []);
  const [code, setCode] = useState<string | null>(null);
  const n = (v: number) => formatNumber(v, lang);
  const cat = data?.data.find((c) => c.code === code) ?? data?.data[0];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('levelsTitle')}</h1>
          <p className="muted small">{t('levelsSubtitle')}</p>
        </div>
      </div>
      <ErrorAlert error={error} />
      {data && data.data.length === 0 && <p className="muted">{t('levelsNone')}</p>}
      <div className="tabs">
        {data?.data.map((c) => (
          <button key={c.code} className="tab" aria-pressed={cat?.code === c.code} onClick={() => setCode(c.code)}>
            {lang === 'ar' ? c.nameAr : c.nameEn}
          </button>
        ))}
      </div>
      {cat && (
        <div className="card">
          <div className="row small muted">
            {cat.enabled ? <span className="badge ok">{t('enabled')}</span> : <span className="badge">{t('disabled')}</span>}
            {cat.version !== null ? t('levelsVersion', { v: cat.version, m: cat.multiplier ?? '—' }) : t('levelsUnpublished')}
            {cat.publishedAt && <span className="date">{formatDate(cat.publishedAt, lang)}</span>}
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th className="num">{t('levelsLevel')}</th>
                  <th>{t('colTitle')}</th>
                  <th className="num">{t('levelsPoints')}</th>
                  <th className="num">{t('coins')}</th>
                  <th className="num">USD</th>
                </tr>
              </thead>
              <tbody>
                {cat.levels.map((l) => (
                  <tr key={l.level}>
                    <td className="num">{l.level}</td>
                    <td>{lang === 'ar' ? l.nameAr : l.nameEn}</td>
                    <td className="num">{n(l.requiredPoints)}</td>
                    <td className="num">{l.coins === null ? '—' : n(l.coins)}</td>
                    <td className="num money">{l.usd ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </>
  );
}

interface SpecialRow {
  id: string;
  userId: string;
  username: string;
  baseUsername: string;
  displayName: string;
  avatarUrl: string | null;
  source: string;
  status: string;
  grantedAt: string;
  expiresAt: string | null;
  graceUntil: string | null;
  endedAt: string | null;
  reason: string | null;
}

/** «اليوزرات المميزة» (D185 via D197): every special username, its source and state; actions on the user's page. */
export function SpecialUsernames() {
  const { t, lang } = useApp();
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('specialTitle')}</h1>
          <p className="muted small">{t('specialSubtitle')}</p>
        </div>
      </div>
      <DataTable<SpecialRow>
        id="special-usernames"
        endpoint="/admin/special-usernames"
        rowKey={(r) => r.id}
        defaultSort={{ sort: 'grantedAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        onRowClick={(r) => navigate(`/users/${r.userId}`)}
        filters={[
          { name: 'status', label: 'colStatus', options: ['ACTIVE', 'GRACE', 'ENDED'].map((s) => ({ value: s, label: `su${s}` })) },
          { name: 'source', label: 'colSource', options: ['RECHARGE_AGENT', 'HOST_AGENT', 'ADMIN_GIFT', 'PURCHASE'].map((s) => ({ value: s, label: `suSrc${s}` })) },
        ]}
        columns={[
          { key: 'name', label: 'colUsername', sort: 'username', render: (r) => <span className="mono ltr">@{r.username}</span> },
          { key: 'base', label: 'userBase', render: (r) => <span className="ltr muted">@{r.baseUsername}</span> },
          { key: 'who', label: 'colUser', render: (r) => r.displayName },
          { key: 'source', label: 'colSource', render: (r) => t(`suSrc${r.source}` as never) },
          { key: 'status', label: 'colStatus', render: (r) => (r.status === 'ACTIVE' ? <StatusBadge status="ACTIVE" /> : <span className="badge">{t(`su${r.status}` as never)}</span>) },
          { key: 'granted', label: 'colGranted', sort: 'grantedAt', render: (r) => <span className="date small">{formatDate(r.grantedAt, lang)}</span> },
          { key: 'expires', label: 'expires', render: (r) => <span className="date small">{r.expiresAt ? formatDate(r.expiresAt, lang) : t('never')}</span> },
          { key: 'reason', label: 'colReason', optional: true, render: (r) => <span className="clip small">{r.reason ?? '—'}</span> },
        ]}
      />
    </>
  );
}

interface WaitRow {
  id: string;
  email: string;
  locale: string;
  createdAt: string;
}

/** «قائمة البريد» (D192 via D197, OWNER): the launch waitlist; every view and export is audited like the CLI. */
export function Waitlist() {
  const { t, lang } = useApp();
  const [counts, setCounts] = useState<{ total: number; byLocale: { locale: string; count: number }[] } | null>(null);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('waitlistTitle')}</h1>
          <p className="muted small">{t('waitlistSubtitle')}</p>
        </div>
      </div>
      {counts && (
        <div className="mini-stats">
          <div className="mini-stat">
            <span className="muted small">{t('total')}</span>
            <strong className="num">{formatNumber(counts.total, lang)}</strong>
          </div>
          {counts.byLocale.map((c) => (
            <div className="mini-stat" key={c.locale}>
              <span className="muted small">{c.locale === 'ar' ? t('langAr') : c.locale === 'en' ? t('langEn') : c.locale}</span>
              <strong className="num">{formatNumber(c.count, lang)}</strong>
            </div>
          ))}
        </div>
      )}
      <div className="alert info small">{t('waitlistPrivacy')}</div>
      <DataTable<WaitRow>
        id="waitlist"
        endpoint="/admin/waitlist"
        rowKey={(r) => r.id}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        csv
        onLoaded={(p) => setCounts((p as unknown as { counts: typeof counts }).counts)}
        filters={[{ name: 'locale', label: 'waitlistLang', options: [{ value: 'ar', label: 'langAr' }, { value: 'en', label: 'langEn' }] }]}
        columns={[
          { key: 'email', label: 'colEmail', render: (r) => <span className="ltr">{r.email}</span> },
          { key: 'locale', label: 'waitlistLang', render: (r) => r.locale },
          { key: 'date', label: 'colDate', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
        ]}
      />
    </>
  );
}
