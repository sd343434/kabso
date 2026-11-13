import { useMemo, useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { isKey, type Key, type Lang } from '../i18n';
import type { ExchangeRateRow, ExchangeRates, FxStatus } from '../types';
import { FxProviderSection } from './FxProvider';

/**
 * «أسعار الصرف» (v1.69-social, D204; v1.81-social, D245, CONVENTIONS §10.87): every country with its effective rate —
 * the manual rate «يدوي» over the automatic one «تلقائي» —, a search and a filter, the automatic feed's status card with
 * «تحديث الآن», and for each country «سعر يدوي», «إعادة إلى التلقائي» and «قبول السعر الجديد» for a held value. The
 * OWNER also sees «مزوّد أسعار الصرف» (the paid provider) below.
 */
export function Rates() {
  const { t, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<ExchangeRates>('/admin/recharge/exchange-rates'), []);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<RateFilter>('all');
  const [editing, setEditing] = useState<ExchangeRateRow | null>(null);
  const [resetting, setResetting] = useState<ExchangeRateRow | null>(null);
  const [accepting, setAccepting] = useState<ExchangeRateRow | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshError, setRefreshError] = useState<unknown>(null);
  const canEdit = can('recharge.rates');
  const refresh = () => {
    setRefreshing(true);
    setRefreshError(null);
    api.post<{ result: { status: string; accepted?: number; issue?: string } }>('/admin/fx/refresh', {}).then(
      (r) => {
        setRefreshing(false);
        toast(
          r.result.status === 'ok'
            ? t('fxrRefreshOk', { accepted: r.result.accepted ?? 0 })
            : t('fxrRefreshFailed', { issue: issueText(t, r.result.issue ?? r.result.status) }),
        );
        reload();
      },
      (err: unknown) => {
        setRefreshing(false);
        setRefreshError(err);
      },
    );
  };
  return (
    <>
      <ErrorAlert error={error} />
      <ErrorAlert error={refreshError} />
      {loading && !data && <Loading />}
      {data && (
        <RatesView
          data={data}
          query={query}
          filter={filter}
          onQuery={setQuery}
          onFilter={setFilter}
          canEdit={canEdit}
          refreshing={refreshing}
          onRefresh={refresh}
          onEdit={setEditing}
          onReset={setResetting}
          onAccept={setAccepting}
        />
      )}
      {can('fx.settings') && <FxProviderSection onChanged={reload} />}
      {editing && (
        <FormDialog
          title={t('rateEditTitle', { country: editing.country })}
          intro={<p className="small muted">{t('fxrManualIntro')}</p>}
          fields={[
            { name: 'currency', label: t('colCurrency'), maxLength: 3, required: false, hint: editing.currency ?? undefined },
            { name: 'unitsPerUsd', label: t('colRate'), maxLength: 16, hint: editing.unitsPerUsd ?? editing.auto?.unitsPerUsd ?? undefined },
            { name: 'digits', label: t('colDigits'), maxLength: 1, required: false, hint: String(editing.digits) },
            reasonField(t),
          ]}
          confirmLabel={t('save')}
          submit={(v) =>
            api.post(`/admin/recharge/exchange-rates/${editing.country}`, {
              currency: (v.currency || editing.currency || '').toUpperCase(),
              unitsPerUsd: v.unitsPerUsd,
              digits: Number(v.digits || editing.digits),
              reason: v.reason,
            })
          }
          onClose={() => setEditing(null)}
          onDone={() => {
            setEditing(null);
            toast(t('saved'));
            reload();
          }}
        />
      )}
      {resetting && (
        <FormDialog
          title={t('fxrReset')}
          intro={<p className="small">{t('fxrResetIntro', { country: resetting.country })}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('fxrReset')}
          submit={(v) => api.post(`/admin/recharge/exchange-rates/${resetting.country}/clear`, { reason: v.reason })}
          onClose={() => setResetting(null)}
          onDone={() => {
            setResetting(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
      {accepting?.auto?.held && (
        <FormDialog
          title={t('fxrAcceptHeld')}
          intro={
            <p className="small">
              {t('fxrAcceptIntro', {
                currency: accepting.auto.currency,
                rate: accepting.auto.held.unitsPerUsd,
                jump: accepting.auto.held.jumpPercent,
                old: accepting.auto.unitsPerUsd,
              })}
            </p>
          }
          fields={[reasonField(t)]}
          confirmLabel={t('fxrAcceptHeld')}
          submit={(v) => api.post(`/admin/fx/held/${accepting.auto!.currency}/accept`, { reason: v.reason })}
          onClose={() => setAccepting(null)}
          onDone={() => {
            setAccepting(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}

export type RateFilter = 'all' | 'manual' | 'held' | 'none';

const SOURCE_BADGE: Record<ExchangeRateRow['source'], string> = { MANUAL: 'info', AUTO: 'ok', USD: '', NONE: 'warn' };

type T = ReturnType<typeof useApp>['t'];

function issueText(t: T, issue: string): string {
  const key = `fxrIssue_${issue}`;
  return isKey(key) ? t(key) : issue;
}

/** The country's name in the panel's language (the code when the runtime has no name). */
export function countryName(code: string, lang: Lang): string {
  try {
    return new Intl.DisplayNames([lang], { type: 'region' }).of(code) ?? code;
  } catch {
    return code;
  }
}

/** The rows a search and a filter keep (country code or name in either language, currency). */
export function filterRates(rows: ExchangeRateRow[], query: string, filter: RateFilter, lang: Lang): ExchangeRateRow[] {
  const q = query.trim().toLowerCase();
  return rows.filter((r) => {
    if (filter === 'manual' && r.source !== 'MANUAL') return false;
    if (filter === 'held' && !r.auto?.held) return false;
    if (filter === 'none' && r.source !== 'NONE') return false;
    if (!q) return true;
    return (
      r.country.toLowerCase() === q ||
      (r.currency ?? '').toLowerCase().includes(q) ||
      countryName(r.country, lang).toLowerCase().includes(q) ||
      countryName(r.country, lang === 'ar' ? 'en' : 'ar').toLowerCase().includes(q)
    );
  });
}

function StatusCard({ status, canEdit, refreshing, onRefresh }: { status: FxStatus; canEdit: boolean; refreshing: boolean; onRefresh: () => void }) {
  const { t, lang } = useApp();
  const when = (iso: string | null) => (iso ? formatDate(iso, lang) : t('fxrNever'));
  return (
    <section className="card" aria-labelledby="fxr-status" data-testid="fxr-status">
      <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
        <h2 id="fxr-status" style={{ margin: 0 }}>
          {t('fxrStatus')}
        </h2>
        {canEdit && (
          <button type="button" className="btn small" disabled={refreshing} onClick={onRefresh} data-testid="fxr-refresh">
            {t(refreshing ? 'fxrRefreshing' : 'fxrRefresh')}
          </button>
        )}
      </div>
      {status.paidIgnored && (
        <div className="alert error small" role="alert">
          {t('fxrPaidIgnored')}
        </div>
      )}
      <dl className="kv">
        <dt>{t('fxrSource')}</dt>
        <dd>
          <bdi>{status.sourceName}</bdi>
          <div className="small muted">{status.paidActive ? t('fxrSourcePaid', { seconds: status.intervalSeconds }) : t('fxrSourceFree')}</div>
        </dd>
        <dt>{t('fxrLastUpdate')}</dt>
        <dd data-testid="fxr-last-update">{when(status.lastSuccessAt)}</dd>
        <dt>{t('fxrNextFetch')}</dt>
        <dd>{status.polling ? when(status.nextFetchAt) : <span className="muted">{t('fxrPollingOff')}</span>}</dd>
        <dt>{t('fxrProviderTime')}</dt>
        <dd>{when(status.lastProviderUpdatedAt)}</dd>
        <dt>{t('fxrLastError')}</dt>
        <dd data-testid="fxr-last-error">
          {status.lastError ? (
            <>
              <span className="badge bad">{issueText(t, status.lastError.issue)}</span> <span className="small muted">{formatDate(status.lastError.at, lang)}</span>
              {status.failures > 0 && <div className="small">{t('fxrFailures', { n: status.failures })}</div>}
            </>
          ) : (
            <span className="muted">{t('fxrNoError')}</span>
          )}
        </dd>
      </dl>
      <p className="small muted" style={{ marginBottom: 0 }}>
        {t('fxrCounts', { currencies: status.currencies, held: status.held })} · {t('fxrStaleRule', { hours: status.staleAfterHours })}
      </p>
      {status.attribution && (
        <p className="small muted" style={{ marginBottom: 0 }} data-testid="fxr-attribution">
          {t('fxrAttribution')}{' '}
          <a href={status.attribution.url} target="_blank" rel="noreferrer noopener" className="ltr">
            {status.attribution.text}
          </a>
        </p>
      )}
    </section>
  );
}

export function RatesView(props: {
  data: ExchangeRates;
  query: string;
  filter: RateFilter;
  onQuery: (q: string) => void;
  onFilter: (f: RateFilter) => void;
  canEdit: boolean;
  refreshing: boolean;
  onRefresh: () => void;
  onEdit: (r: ExchangeRateRow) => void;
  onReset: (r: ExchangeRateRow) => void;
  onAccept: (r: ExchangeRateRow) => void;
}) {
  const { t, lang } = useApp();
  const { data, canEdit } = props;
  const rows = useMemo(() => filterRates(data.data, props.query, props.filter, lang), [data.data, props.query, props.filter, lang]);
  const hours = data.status.staleAfterHours;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('ratesTitle')}</h1>
          <p className="muted small">{t('fxrSubtitle', { usd: data.retailUsdPerMillion })}</p>
        </div>
      </div>
      <StatusCard status={data.status} canEdit={canEdit} refreshing={props.refreshing} onRefresh={props.onRefresh} />
      <div className="row" style={{ gap: 8, flexWrap: 'wrap', margin: '16px 0 8px' }}>
        <input
          type="search"
          aria-label={t('fxrSearch')}
          placeholder={t('fxrSearch')}
          value={props.query}
          onChange={(e) => props.onQuery(e.target.value)}
          style={{ flex: '1 1 220px', maxWidth: 360 }}
          data-testid="fxr-search"
        />
        <div className="row" role="group" style={{ gap: 4, flexWrap: 'wrap' }}>
          {(['all', 'manual', 'held', 'none'] as const).map((f) => (
            <button
              key={f}
              type="button"
              className={`btn small${props.filter === f ? ' primary' : ''}`}
              aria-pressed={props.filter === f}
              onClick={() => props.onFilter(f)}
            >
              {t(`fxrFilter${f === 'all' ? 'All' : f === 'manual' ? 'Manual' : f === 'held' ? 'Held' : 'None'}` as Key)}
            </button>
          ))}
        </div>
        <span className="small muted">{t('fxrCount', { shown: rows.length, total: data.data.length })}</span>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>{t('colCountry')}</th>
              <th>{t('colCurrency')}</th>
              <th>{t('colRate')}</th>
              <th>{t('fxrColSource')}</th>
              <th>{t('fxrColUpdated')}</th>
              {canEdit && <th>{t('actions')}</th>}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr>
                <td colSpan={canEdit ? 6 : 5} className="muted">
                  {t('fxrNoMatch')}
                </td>
              </tr>
            )}
            {rows.map((r) => (
              <tr key={r.country} data-country={r.country}>
                <td>
                  <bdi>{countryName(r.country, lang)}</bdi> <span className="mono muted small">{r.country}</span>
                </td>
                <td className="mono">{r.currency ?? t('none')}</td>
                <td className="num">
                  {r.unitsPerUsd !== null ? <span className="ltr">{r.unitsPerUsd}</span> : <span className="muted">{t('rateNone')}</span>}
                  {r.source === 'MANUAL' && r.auto && (
                    <div className="small muted ltr">{t('fxrAutoBehind', { rate: r.auto.unitsPerUsd })}</div>
                  )}
                  {r.auto?.held && (
                    <div className="small">
                      <span className="badge warn">{t('fxrHeld', { rate: r.auto.held.unitsPerUsd, jump: r.auto.held.jumpPercent })}</span>
                    </div>
                  )}
                </td>
                <td>
                  <span className={`badge ${SOURCE_BADGE[r.source]}`} data-testid="fxr-source">
                    {t(`fxrSrc${r.source}` as Key)}
                  </span>
                  {r.stale && (
                    <div className="small">
                      <span className="badge warn">{t('fxrStale', { hours })}</span>
                    </div>
                  )}
                </td>
                <td className="date small">{r.updatedAt ? formatDate(r.updatedAt, lang) : t('none')}</td>
                {canEdit && (
                  <td>
                    <div className="row" style={{ gap: 4, flexWrap: 'wrap' }}>
                      {r.source !== 'USD' && (
                        <button className="btn small" onClick={() => props.onEdit(r)}>
                          {t('fxrSetManual')}
                        </button>
                      )}
                      {r.manual && (
                        <button className="btn small" onClick={() => props.onReset(r)}>
                          {t('fxrReset')}
                        </button>
                      )}
                      {r.auto?.held && (
                        <button className="btn small primary" onClick={() => props.onAccept(r)}>
                          {t('fxrAcceptHeld')}
                        </button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
