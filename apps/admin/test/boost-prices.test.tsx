/**
 * D233 «صواريخ الزيارات»: the rocket stages' prices form rendered to HTML in Node — four stages with their length and
 * the server's price, coins only (no currency), read-only for SUPPORT, editable for the OWNER, rising prices only.
 * Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D233, EN_D233 } from '../src/i18n-d233';
import { NAV } from '../src/nav';
import { matchPath } from '../src/router';
import { BoostPricesForm, pricesValid } from '../src/pages/LiveBoostPrices';
import type { AdminLiveBoostPrices, Capability } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: 'OWNER' | 'SUPPORT' | 'FINANCE' | 'MODERATION') =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const PRICES = [200_000, 550_000, 1_500_000, 3_500_000];
const SAVED: AdminLiveBoostPrices = {
  stages: PRICES.map((c, i) => ({
    stage: i + 1,
    minutes: [10, 20, 30, 60][i]!,
    priceCoins: c,
    configCoins: c,
    custom: false,
    updatedAt: null,
  })),
};

describe('D233 visit rockets in the panel', () => {
  it('has every string in both languages, a route and a nav item under catalog.view', () => {
    expect(Object.keys(EN_D233).sort()).toEqual(Object.keys(AR_D233).sort());
    for (const k of Object.keys(AR_D233)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D233]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D233]).toBeTruthy();
    }
    expect(matchPath('/live-boost-prices')?.name).toBe('boostPrices');
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === '/live-boost-prices');
    expect(item?.cap).toBe('catalog.view');
  });

  it('SUPPORT reads the four stages, in coins only, without a save button', () => {
    const html = render('ar', capsOf('SUPPORT'), (
      <BoostPricesForm saved={SAVED} draft={PRICES} onChange={() => undefined} onSave={() => undefined} />
    ));
    expect(html).toContain('للعرض فقط');
    expect(html).not.toContain('data-boost-save');
    for (const n of [1, 2, 3, 4]) expect(html).toContain(`صاروخ ${n}`);
    expect(html).toContain('60 دقيقة');
    expect(html).toContain('سعر الخادم: 3,500,000');
    expect(html).not.toMatch(/دينار|\$|USD|JOD/);
  });

  it('the OWNER edits; nothing changed or falling prices cannot be saved', () => {
    const same = render('en', capsOf('OWNER'), (
      <BoostPricesForm saved={SAVED} draft={PRICES} onChange={() => undefined} onSave={() => undefined} />
    ));
    expect(same).toContain('data-boost-save');
    expect(same).toContain('No change');
    expect(same).toMatch(/<button[^>]*disabled=""[^>]*data-boost-save/);
    const changed = render('en', capsOf('OWNER'), (
      <BoostPricesForm saved={SAVED} draft={[250_000, 550_000, 1_500_000, 3_500_000]} onChange={() => undefined} onSave={() => undefined} />
    ));
    expect(changed).toContain('Save prices');
    expect(changed).not.toMatch(/<button[^>]*disabled=""[^>]*data-boost-save/);
    const falling = render('en', capsOf('OWNER'), (
      <BoostPricesForm saved={SAVED} draft={[600_000, 550_000, 1_500_000, 3_500_000]} onChange={() => undefined} onSave={() => undefined} />
    ));
    expect(falling).toContain('Each stage must cost more than the one before.');
    expect(pricesValid(PRICES)).toBe(true);
    expect(pricesValid([1, 1, 2, 3])).toBe(false);
    expect(pricesValid([0, 1, 2, 3])).toBe(false);
    expect(pricesValid([1, 2, 3])).toBe(false);
    expect(pricesValid([1, 2, 3, 1_000_000_001])).toBe(false);
  });
});
