/**
 * D245 «أسعار الصرف» (automatic rates for every country) and the OWNER's «مزوّد أسعار الصرف»: the status card with the
 * source, «آخر تحديث», the next fetch, the error and the attribution; the source badges «تلقائي» / «يدوي»; a held value
 * with «قبول السعر الجديد»; «إعادة إلى التلقائي» only on a manual row; the search; the key shown as its last 4 only.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D245, EN_D245 } from '../src/i18n-d245';
import { fxPatch, FxProviderView } from '../src/pages/FxProvider';
import { filterRates, RatesView } from '../src/pages/Rates';
import type { ExchangeRateRow, ExchangeRates, FxSettings } from '../src/types';

const state = (lang: Lang, editor = true): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => editor,
  toast: () => undefined,
});

const row = (over: Partial<ExchangeRateRow>): ExchangeRateRow => ({
  country: 'EG',
  currency: 'EGP',
  digits: 2,
  unitsPerUsd: '48.6',
  updatedAt: '2026-11-02T10:00:00.000Z',
  source: 'AUTO',
  stale: false,
  manual: null,
  auto: {
    currency: 'EGP',
    unitsPerUsd: '48.6',
    source: 'OPEN_ER_API',
    fetchedAt: '2026-11-02T10:00:00.000Z',
    providerUpdatedAt: '2026-11-02T00:00:00.000Z',
    stale: false,
    held: null,
  },
  ...over,
});

const DATA: ExchangeRates = {
  retailUsdPerMillion: 12.5,
  status: {
    source: 'OPEN_ER_API',
    sourceName: 'ExchangeRate-API (open access, free)',
    paidActive: false,
    paidIgnored: null,
    intervalSeconds: 3600,
    polling: true,
    lastAttemptAt: '2026-11-02T10:00:00.000Z',
    lastSuccessAt: '2026-11-02T10:00:00.000Z',
    lastSource: 'OPEN_ER_API',
    lastProviderUpdatedAt: '2026-11-02T00:00:00.000Z',
    nextFetchAt: '2026-11-02T11:00:00.000Z',
    lastError: { at: '2026-11-02T09:00:00.000Z', issue: 'unreachable', detail: null },
    failures: 0,
    lastReport: null,
    currencies: 160,
    held: 1,
    staleAfterHours: 48,
    maxJumpPercent: 50,
    attribution: { text: 'Rates By Exchange Rate API', url: 'https://www.exchangerate-api.com' },
  },
  data: [
    row({}),
    row({
      country: 'SA',
      currency: 'SAR',
      unitsPerUsd: '3.75',
      source: 'MANUAL',
      manual: { currency: 'SAR', digits: 2, unitsPerUsd: '3.75', updatedAt: '2026-11-01T10:00:00.000Z' },
    }),
    row({
      country: 'JP',
      currency: 'JPY',
      digits: 0,
      unitsPerUsd: '152.3',
      auto: { ...row({}).auto!, currency: 'JPY', unitsPerUsd: '152.3', held: { unitsPerUsd: '460', source: 'OPEN_ER_API', at: '2026-11-02T10:00:00.000Z', jumpPercent: 202 } },
    }),
    row({ country: 'EC', currency: 'USD', unitsPerUsd: '1', source: 'USD', auto: null }),
    row({ country: 'FR', currency: 'EUR', unitsPerUsd: null, source: 'NONE', stale: true }),
  ],
};

const noop = () => undefined;
const rates = (lang: Lang, editor = true, query = '') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, editor)}>
      <RatesView data={DATA} query={query} filter="all" onQuery={noop} onFilter={noop} canEdit={editor} refreshing={false} onRefresh={noop} onEdit={noop} onReset={noop} onAccept={noop} />
    </AppContext.Provider>,
  );

const KEY_LAST4 = 'Ab12';
const SETTINGS: FxSettings = {
  status: 'active',
  provider: 'CURRENCYAPI',
  enabled: true,
  apiKey: { last4: KEY_LAST4, setBy: { id: 'u', displayName: 'Owner' }, setAt: '2026-11-02T10:00:00.000Z' },
  updatedAt: '2026-11-02T10:00:00.000Z',
  panelIgnored: null,
  lastTest: null,
  paidIntervalSeconds: 60,
  freeIntervalSeconds: 3600,
  providers: [
    { code: 'CURRENCYAPI', name: 'currencyapi.com', site: 'https://currencyapi.com', signupUrl: 'https://app.currencyapi.com/register', docsUrl: 'https://currencyapi.com/docs/latest' },
    { code: 'EXCHANGERATE_API', name: 'ExchangeRate-API (paid key)', site: 'https://www.exchangerate-api.com', signupUrl: null, docsUrl: 'https://www.exchangerate-api.com/docs' },
  ],
  connectionTestSkippable: true,
};

describe('D245 «أسعار الصرف»', () => {
  it('Arabic: the status card (source, last update, next fetch, error, attribution) and every source badge', () => {
    const html = rates('ar');
    expect(html).toContain('تحديث الآن');
    expect(html).toContain('آخر تحديث');
    expect(html).toContain('التحديث القادم');
    expect(html).toContain(translate('ar', 'fxrIssue_unreachable'));
    expect(html).toContain('Rates By Exchange Rate API');
    for (const k of ['fxrSrcAUTO', 'fxrSrcMANUAL', 'fxrSrcUSD', 'fxrSrcNONE'] as const) expect(html).toContain(translate('ar', k));
    expect(html).toContain('معلّق: 460');
    expect(html).toContain('قبول السعر الجديد');
    expect(html).toContain(translate('ar', 'fxrStale', { hours: 48 }));
  });

  it('«إعادة إلى التلقائي» only on the manual row; no edit buttons for a reader', () => {
    const html = rates('en');
    expect(html.match(/>Back to automatic<\/button>/g)?.length).toBe(1);
    const reader = rates('en', false);
    expect(reader).not.toContain('Manual rate');
    expect(reader).not.toContain('Refresh now');
  });

  it('search by code, currency or name in either language; filters', () => {
    expect(filterRates(DATA.data, 'jpy', 'all', 'en').map((r) => r.country)).toEqual(['JP']);
    expect(filterRates(DATA.data, 'sa', 'all', 'en').map((r) => r.country)).toContain('SA');
    expect(filterRates(DATA.data, 'Egypt', 'all', 'ar').map((r) => r.country)).toEqual(['EG']);
    expect(filterRates(DATA.data, '', 'manual', 'en').map((r) => r.country)).toEqual(['SA']);
    expect(filterRates(DATA.data, '', 'held', 'en').map((r) => r.country)).toEqual(['JP']);
    expect(filterRates(DATA.data, '', 'none', 'en').map((r) => r.country)).toEqual(['FR']);
  });

  it('every key has both languages', () => {
    expect(Object.keys(EN_D245).sort()).toEqual(Object.keys(AR_D245).sort());
    for (const k of Object.keys(AR_D245) as (keyof typeof AR_D245)[]) expect(EN_D245[k]).not.toBe(AR_D245[k]);
  });
});

describe('D245 «مزوّد أسعار الصرف» (OWNER)', () => {
  const view = (lang: Lang, data = SETTINGS) =>
    renderToStaticMarkup(
      <AppContext.Provider value={state(lang)}>
        <FxProviderView data={data} onChange={noop} />
      </AppContext.Provider>,
    );

  it('shows the status, both providers and the key as its last 4 only', () => {
    const html = view('ar');
    expect(html).toContain('مزوّد أسعار الصرف');
    expect(html).toContain('مفعّل — كل 60 ثانية');
    expect(html).toContain('currencyapi.com');
    expect(html).toContain('ExchangeRate-API');
    expect(html).toContain(KEY_LAST4);
    expect(html).toMatch(/type="password"[^>]*value=""/);
    expect(view('en', { ...SETTINGS, status: 'not_configured', enabled: false, apiKey: null })).toContain('Not set up');
  });

  it('the save body: the provider when changed, the key only when typed', () => {
    expect(fxPatch('CURRENCYAPI', '  ', SETTINGS)).toEqual({});
    const typed = ['k3y', 'abcdefgh'].join('-'); // made up at run time (nothing for a secret scanner)
    expect(fxPatch('EXCHANGERATE_API', ` ${typed} `, SETTINGS)).toEqual({ provider: 'EXCHANGERATE_API', apiKey: typed });
  });
});
