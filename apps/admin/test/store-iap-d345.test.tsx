/**
 * D345 «مشتريات المتجر»: rendered to HTML in Node (no DOM library) — the stores' status and the once-per-account+device
 * switch (OWNER only), the catalogue, the purchases' columns (refund reason, test purchases) and the refund bans' reason
 * with «فك الحظر» for the OWNER only. Both languages; the device is never shown.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D345, EN_D345 } from '../src/i18n-d345';
import { NAV } from '../src/nav';
import {
  purchaseColumns,
  refundBanColumns,
  StoreIapOverviewView,
  StoreIapProductsView,
} from '../src/pages/StoreIap';
import type {
  Capability,
  StoreIapOverview,
  StoreIapProduct,
  StoreIapPurchaseRow,
  StoreIapRefundBanRow,
} from '../src/types';
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
const wrap = (lang: Lang, caps: Capability[], node: ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const OVERVIEW: StoreIapOverview = {
  googlePlay: { configured: true, packageName: 'com.kabso.live', rtdnEnabled: false },
  appStore: { configured: false, bundleId: null, roots: 0 },
  acceptSandbox: true,
  voidedPollHours: 24,
  consentVersion: '2026-11-09',
  endpoints: { appleNotifications: '/api/v1/payments/apple/notifications', googleRtdn: '/api/v1/payments/google/rtdn?token=…' },
  settings: { oncePerAccountDevice: false, updatedAt: '2026-11-09T10:00:00.000Z' },
  voided: { lastRunAt: '2026-11-09T09:00:00.000Z', polledUntil: '2026-11-09T09:00:00.000Z', lastError: null },
  counts: { purchases: 12, refunds: 1, activeBans: 1 },
};

const PRODUCTS: StoreIapProduct[] = [
  { id: 'p1', platform: 'GOOGLE_PLAY', productId: 'coins_1m', coins: 1_000_000, referenceUsdCents: 1299, sortOrder: 0, enabled: true, updatedAt: '2026-11-09T10:00:00.000Z' },
  { id: 'p2', platform: 'APP_STORE', productId: 'ios.coins.1m', coins: 1_000_000, referenceUsdCents: null, sortOrder: 0, enabled: false, updatedAt: '2026-11-09T10:00:00.000Z' },
];

const REASON = 'استرداد عبر Google Play بتاريخ 2026-11-09 — طلب GPA.3345-0001-0001 (chargeback)';
const person = { id: 'u1', username: 'layla_22', displayName: 'Layla' };
const PURCHASE: StoreIapPurchaseRow = {
  id: 'x1',
  user: person,
  platform: 'GOOGLE_PLAY',
  productId: 'coins_1m',
  coins: 1_000_000,
  transactionId: 'GPA.3345-0001-0001',
  environment: 'SANDBOX',
  status: 'REFUNDED',
  rejectReason: null,
  deviceRecorded: true,
  consentVersion: '2026-11-09',
  consentShareData: true,
  purchasedAt: '2026-11-09T08:00:00.000Z',
  creditedAt: '2026-11-09T08:00:01.000Z',
  consumedAt: '2026-11-09T08:00:02.000Z',
  refundedAt: '2026-11-09T09:00:00.000Z',
  refundSource: 'GOOGLE_VOIDED',
  refundReason: REASON,
  refundBanId: 'b1',
  createdAt: '2026-11-09T08:00:00.000Z',
};
const BAN: StoreIapRefundBanRow = {
  id: 'b1',
  user: person,
  accountStatus: 'SUSPENDED',
  purchaseId: 'x1',
  platform: 'GOOGLE_PLAY',
  productId: 'coins_1m',
  coins: 1_000_000,
  transactionId: 'GPA.3345-0001-0001',
  refundedAt: '2026-11-09T09:00:00.000Z',
  reason: REASON,
  accountBanned: true,
  deviceBanned: true,
  devicesBanned: 1,
  accountLiftedAt: null,
  accountLiftReason: null,
  deviceLiftedAt: null,
  deviceLiftReason: null,
  createdAt: '2026-11-09T09:00:00.000Z',
};

/** The HTML's text (the reason's Latin runs are isolated in <bdi>). */
const text = (html: string) => html.replace(/<[^>]+>/g, '');
const cells = <R,>(lang: Lang, caps: Capability[], cols: { render: (r: R) => ReactNode }[], row: R) =>
  wrap(lang, caps, <table><tbody><tr>{cols.map((c, i) => <td key={i}>{c.render(row)}</td>)}</tr></tbody></table>);

describe('D345 «مشتريات المتجر»', () => {
  it('every string exists in both languages and the sidebar names the page', () => {
    expect(Object.keys(EN_D345).sort()).toEqual(Object.keys(AR_D345).sort());
    for (const k of Object.keys(AR_D345)) {
      expect(DICTIONARIES.ar[k as never]).toBeTruthy();
      expect(DICTIONARIES.en[k as never]).toBeTruthy();
    }
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === '/store-purchases');
    expect(item?.cap).toBe('store_iap.view');
  });

  it('the capabilities: the team reads, only the OWNER manages and unbans', () => {
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE'] as const) {
      expect(capsOf(role)).toContain('store_iap.view');
      expect(capsOf(role)).not.toContain('store_iap.manage');
      expect(capsOf(role)).not.toContain('store_iap.unban');
    }
    expect(capsOf('OWNER')).toEqual(expect.arrayContaining(['store_iap.view', 'store_iap.manage', 'store_iap.unban']));
  });

  it('the overview: each store on / off, the switch and its buttons for the OWNER only', () => {
    for (const lang of ['ar', 'en'] as const) {
      const d = DICTIONARIES[lang];
      const owner = wrap(lang, capsOf('OWNER'), <StoreIapOverviewView data={OVERVIEW} onToggle={() => undefined} onSync={() => undefined} />);
      expect(owner).toContain('com.kabso.live');
      expect(owner).toContain(d.iapNotConfigured);
      expect(owner).toContain(d.iapOnceOff);
      expect(owner).toContain(`>${d.iapOnceEnable}</button>`);
      expect(owner).toContain(`>${d.iapVoidedSync}</button>`);
      const mod = wrap(lang, capsOf('MODERATION'), <StoreIapOverviewView data={OVERVIEW} onToggle={() => undefined} onSync={() => undefined} />);
      expect(mod).toContain(d.iapOnceOff);
      expect(mod).not.toContain(`>${d.iapOnceEnable}</button>`);
      expect(mod).not.toContain(`>${d.iapVoidedSync}</button>`);
    }
    const on = wrap('ar', capsOf('OWNER'), (
      <StoreIapOverviewView
        data={{ ...OVERVIEW, settings: { ...OVERVIEW.settings, oncePerAccountDevice: true } }}
        onToggle={() => undefined}
        onSync={() => undefined}
      />
    ));
    expect(on).toContain(AR_D345.iapOnceOn);
    expect(on).toContain(`>${AR_D345.iapOnceDisable}</button>`);
  });

  it('the catalogue lists store product ids and coins; editing for the OWNER only', () => {
    const owner = wrap('en', capsOf('OWNER'), <StoreIapProductsView products={PRODUCTS} onAdd={() => undefined} onEdit={() => undefined} />);
    expect(owner).toContain('coins_1m');
    expect(owner).toContain('ios.coins.1m');
    expect(owner).toContain('1,000,000');
    expect(owner).toContain(EN_D345.iapDisabled);
    expect(owner).toContain(EN_D345.iapAddProduct);
    const finance = wrap('en', capsOf('FINANCE'), <StoreIapProductsView products={PRODUCTS} onAdd={() => undefined} onEdit={() => undefined} />);
    expect(finance).not.toContain(EN_D345.iapAddProduct);
    expect(finance).not.toContain(EN_D345.iapEditProduct);
    const empty = wrap('ar', capsOf('OWNER'), <StoreIapProductsView products={[]} onAdd={() => undefined} onEdit={() => undefined} />);
    expect(empty).toContain(AR_D345.iapNoProducts);
  });

  it('a purchase row: refunded with the reason, a test purchase marked, no device or token', () => {
    for (const lang of ['ar', 'en'] as const) {
      const t = (k: never, v?: Record<string, string | number>) => translate(lang, k, v);
      const html = cells(lang, capsOf('SUPPORT'), purchaseColumns(t as never, lang), PURCHASE);
      expect(html).toContain(DICTIONARIES[lang].iapStatusREFUNDED);
      expect(html).toContain(DICTIONARIES[lang].iapEnvSANDBOX);
      expect(html).toContain('GPA.3345-0001-0001');
      expect(html).toContain('@layla_22');
    }
    const t = (k: never) => translate('ar', k);
    expect(text(cells('ar', [], purchaseColumns(t as never, 'ar'), PURCHASE))).toContain(REASON);
  });

  it('a refund ban: the reason; «فك الحظر» buttons only for the OWNER; a lifted part shows when and why', () => {
    const tAr = (k: never, v?: Record<string, string | number>) => translate('ar', k, v);
    const unbans: string[] = [];
    const ownerCols = refundBanColumns(tAr as never, 'ar', (c) => capsOf('OWNER').includes(c), (_r, part) => unbans.push(part));
    const owner = cells('ar', capsOf('OWNER'), ownerCols, BAN);
    expect(text(owner)).toContain(REASON);
    expect(owner).toContain('<bdi dir="ltr">2026-11-09</bdi>');
    expect(owner).toContain('<bdi dir="ltr">GPA.3345-0001-0001 (chargeback)</bdi>');
    expect(owner).toContain(AR_D345.iapUnbanAccount);
    expect(owner).toContain(AR_D345.iapUnbanDevice);
    const modCols = refundBanColumns(tAr as never, 'ar', (c) => capsOf('MODERATION').includes(c), () => undefined);
    const mod = cells('ar', capsOf('MODERATION'), modCols, BAN);
    expect(text(mod)).toContain(REASON);
    expect(mod).not.toContain(AR_D345.iapUnbanAccount);
    expect(mod).toContain(AR_D345.iapOwnerOnly);
    const lifted = cells('ar', capsOf('OWNER'), ownerCols, {
      ...BAN,
      accountBanned: false,
      accountLiftedAt: '2026-11-10T10:00:00.000Z',
      accountLiftReason: 'خطأ من المتجر',
    });
    expect(lifted).toContain(AR_D345.iapLifted);
    expect(lifted).toContain('خطأ من المتجر');
    expect(lifted).not.toContain(AR_D345.iapUnbanAccount);
    expect(lifted).toContain(AR_D345.iapUnbanDevice);
    const tEn = (k: never, v?: Record<string, string | number>) => translate('en', k, v);
    const en = cells('en', capsOf('OWNER'), refundBanColumns(tEn as never, 'en', () => true, () => undefined), BAN);
    expect(en).toContain(EN_D345.iapBanned);
    expect(en).not.toMatch(/[0-9a-f]{64}/);
  });
});
