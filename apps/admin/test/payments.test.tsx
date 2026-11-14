/**
 * D196 «الدفع (Stripe)»: the section's component, rendered to HTML in Node (no DOM library): what it shows of the keys
 * (fingerprints only, never a value), the webhook URL and events, the read-only base URL, the password inputs, and
 * the PATCH bodies it builds (only what changed).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import {
  feeFormValid,
  fixedMinorOf,
  grossUpMinor,
  keysPatch,
  optionsFormOf,
  optionsPatch,
  PaymentsView,
  percentBpsOf,
} from '../src/pages/Payments';
import type { PaymentSettings } from '../src/types';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const EVENTS = [
  'checkout.session.completed',
  'checkout.session.async_payment_succeeded',
  'checkout.session.async_payment_failed',
  'checkout.session.expired',
  'charge.refunded',
  'radar.early_fraud_warning.created',
  'charge.dispute.created',
  'charge.dispute.closed',
];

function fixture(over: Partial<PaymentSettings> = {}): PaymentSettings {
  const owner = { id: '0190f3a0-0000-7000-8000-000000000001', displayName: 'المالك' };
  return {
    source: 'panel',
    configured: true,
    mode: 'live',
    secretKey: { kind: 'restricted', mode: 'live', last4: 'AbCd', source: 'panel', setBy: owner, setAt: '2026-10-31T09:00:00.000Z' },
    webhookSecret: { kind: 'webhook', mode: null, last4: 'WxYz', source: 'panel', setBy: owner, setAt: '2026-10-31T09:00:00.000Z' },
    previousWebhookSecretValidUntil: null,
    panelKeys: null,
    envKeys: null,
    panelKeysIgnored: null,
    publishableKey: null,
    options: {
      bankTransferEnabled: null,
      statementDescriptorSuffix: null,
      disputeAutoSubmit: null,
      appLinkEnabled: false,
      stripeFeeGrossUp: null,
      stripeFeePercentBps: null,
      stripeFeeFixedMinor: null,
    },
    effective: {
      bankTransferEnabled: true,
      statementDescriptorSuffix: null,
      disputeAutoSubmit: true,
      appLinkEnabled: false,
      stripeFeeGrossUp: true,
      stripeFeePercentBps: 290,
      stripeFeeFixedMinor: 30,
    },
    feeCurrency: 'USD',
    publicBaseUrl: 'https://api.kabsolive.com',
    webhookUrl: 'https://api.kabsolive.com/api/v1/payments/stripe/webhook',
    webhookEvents: EVENTS,
    testKeysAllowed: false,
    connectionTestSkippable: false,
    ...over,
  };
}

const render = (data: PaymentSettings, lang: Lang = 'ar') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <PaymentsView data={data} onChange={() => undefined} />
    </AppContext.Provider>,
  );

describe('PaymentsView', () => {
  it('Arabic: status, fingerprints (type, last 4, who, when) and never a key value', () => {
    const html = render(fixture({ panelKeys: { secretKey: fixture().secretKey!, webhookSecret: fixture().webhookSecret! } }));
    expect(html).toContain('الدفع (Stripe)');
    expect(html).toContain('مفعّل — وضع حقيقي');
    expect(html).toContain('المفاتيح من اللوحة');
    expect(html).toContain('…AbCd');
    expect(html).toContain('…WxYz');
    expect(html).toContain('مقيّد');
    expect(html).toContain('المالك');
    // Nothing that looks like a secret (the API never sends one; the page has no field that holds one).
    expect(html).not.toMatch(/(sk|rk)_(live|test)_[A-Za-z0-9]{4,}/);
    expect(html).not.toMatch(/whsec_[A-Za-z0-9]{4,}/);
    // The remove button only when the panel holds keys.
    expect(html).toContain('حذف مفاتيح اللوحة');
    expect(render(fixture())).not.toContain('حذف مفاتيح اللوحة');
  });

  it('the secret inputs are empty password fields without autocomplete', () => {
    const html = render(fixture());
    for (const id of ['pay-sk', 'pay-wh']) {
      const input = html.match(new RegExp(`<input[^>]*id="${id}"[^>]*>`))?.[0] ?? '';
      expect(input, id).toContain('type="password"');
      expect(input, id).toMatch(/autocomplete="off"/i);
      expect(input, id).toContain('value=""');
    }
  });

  it('shows the webhook URL to copy, the events to subscribe and the base URL read-only', () => {
    const html = render(fixture());
    expect(html).toContain('value="https://api.kabsolive.com/api/v1/payments/stripe/webhook"');
    for (const e of EVENTS) expect(html).toContain(`<code>${e}</code>`);
    const base = html.match(/<input[^>]*id="pay-base"[^>]*>/)?.[0] ?? '';
    expect(base).toContain('readOnly');
    expect(base).toContain('value="https://api.kabsolive.com"');
  });

  it('off, env source, ignored keys and a missing base URL are said plainly; English too', () => {
    const off = render(fixture({ source: 'none', configured: false, mode: null, secretKey: null, webhookSecret: null, publicBaseUrl: null, webhookUrl: null }));
    expect(off).toContain('غير مفعّل');
    expect(off).toContain('لا توجد مفاتيح: الشحن بالبطاقة متوقف');
    expect(off).toContain('TOPUP_PUBLIC_BASE_URL');
    const env = render(fixture({ source: 'env', mode: 'test', secretKey: { kind: 'secret', mode: 'test', last4: 'Env1', source: 'env', setBy: null, setAt: null } }), 'en');
    expect(env).toContain('On — test mode');
    expect(env).toContain('Keys from the server settings');
    expect(env).toContain('Server settings');
    expect(render(fixture({ panelKeysIgnored: 'unreadable' }))).toContain('لا يمكن فكّ تشفيرها');
    expect(render(fixture({ previousWebhookSecretValidUntil: '2026-10-31T09:10:00.000Z' }))).toContain('السرّ السابق يبقى مقبولاً');
  });

  it('the option selects say the server default when the panel does not override', () => {
    const html = render(fixture());
    expect(html).toContain('حسب الخادم (مفعّل)'); // bank transfers: server on
    const appLink = html.match(/<select id="pay-applink"[\s\S]*?<\/select>/)?.[0] ?? '';
    expect(appLink).toContain('حسب الخادم<'); // overridden: the server value is not known here
  });
});

describe('the PATCH bodies', () => {
  it('keys: only the filled fields; skip only with a new key', () => {
    expect(keysPatch({ secretKey: '  ', webhookSecret: '', skip: true })).toEqual({});
    expect(keysPatch({ secretKey: ' sk_x ', webhookSecret: '', skip: false })).toEqual({ secretKey: 'sk_x' });
    expect(keysPatch({ secretKey: 'sk_x', webhookSecret: 'wh_y', skip: true })).toEqual({
      secretKey: 'sk_x',
      webhookSecret: 'wh_y',
      skipConnectionTest: true,
    });
    expect(keysPatch({ secretKey: '', webhookSecret: 'wh_y', skip: true })).toEqual({ webhookSecret: 'wh_y' });
  });

  it('options: only what changed; «server default» is null', () => {
    const data = fixture();
    const form = optionsFormOf(data);
    expect(optionsPatch(form, data)).toEqual({});
    expect(optionsPatch({ ...form, bankTransferEnabled: 'off', appLinkEnabled: 'default', statementDescriptorSuffix: 'COINS' }, data)).toEqual({
      bankTransferEnabled: false,
      appLinkEnabled: null,
      statementDescriptorSuffix: 'COINS',
    });
    expect(optionsPatch({ ...form, publishableKey: ' pk_x ' }, data)).toEqual({ publishableKey: 'pk_x' });
  });
});

describe('D344 Stripe fee in the website price', () => {
  it('shows the switch, the rates with the «set your account rates» note, one-price legal note and an example', () => {
    const html = render(fixture());
    expect(html).toContain('عمولة Stripe في سعر الموقع');
    expect(html).toContain('اضبطها حسب نسبة حسابك في Stripe');
    expect(html).toContain('لا تُعرض العمولة كبند منفصل');
    expect(html).toContain('الرسم الثابت (USD)');
    expect(html).toContain('فارغ = قيمة الخادم (2.9 %)');
    // 12.50 at 2.9 % + 0.30 → 13.19.
    expect(html).toContain('مثال: باقة سعرها 12.50 USD تُعرض بسعر 13.19 USD');
    const select = html.match(/<select id="pay-fee-grossup"[\s\S]*?<\/select>/)?.[0] ?? '';
    expect(select).toContain('حسب الخادم (مفعّل)');
    const off = render(fixture({ options: { ...fixture().options, stripeFeeGrossUp: false }, effective: { ...fixture().effective, stripeFeeGrossUp: false } }), 'en');
    expect(off).toContain('Fee not added: the package sells at 12.50 USD');
    expect(off).toContain("Set these to your Stripe account&#x27;s rates");
  });

  it('parses the typed rates; empty = the server value; invalid is refused', () => {
    expect(percentBpsOf('2.9')).toBe(290);
    expect(percentBpsOf('3,25')).toBe(325);
    expect(percentBpsOf(' ')).toBeNull();
    for (const bad of ['21', '2.905', '-1', 'abc', '100']) expect(percentBpsOf(bad), bad).toBeUndefined();
    expect(fixedMinorOf('0.30')).toBe(30);
    expect(fixedMinorOf('0')).toBe(0);
    expect(fixedMinorOf('')).toBeNull();
    for (const bad of ['101', '0.305', '-0.3', 'x']) expect(fixedMinorOf(bad), bad).toBeUndefined();
    const form = optionsFormOf(fixture());
    expect(feeFormValid({ ...form, stripeFeePercent: '25' })).toBe(false);
    expect(feeFormValid({ ...form, stripeFeePercent: '3.4', stripeFeeFixed: '0.30' })).toBe(true);
  });

  it('the PATCH carries only the changed fee settings, in basis points and cents', () => {
    const data = fixture();
    const form = optionsFormOf(data);
    expect(form).toMatchObject({ stripeFeeGrossUp: 'default', stripeFeePercent: '', stripeFeeFixed: '' });
    expect(optionsPatch({ ...form, stripeFeePercent: '3.4', stripeFeeFixed: '0.30' }, data)).toEqual({
      stripeFeePercentBps: 340,
      stripeFeeFixedMinor: 30,
    });
    expect(optionsPatch({ ...form, stripeFeeGrossUp: 'off' }, data)).toEqual({ stripeFeeGrossUp: false });
    const set = fixture({ options: { ...data.options, stripeFeePercentBps: 340, stripeFeeFixedMinor: 25 } });
    const setForm = optionsFormOf(set);
    expect(setForm).toMatchObject({ stripeFeePercent: '3.4', stripeFeeFixed: '0.25' });
    expect(optionsPatch({ ...setForm, stripeFeePercent: '' }, set)).toEqual({ stripeFeePercentBps: null });
  });

  it('the example uses the server formula', () => {
    expect(grossUpMinor(1250, 290, 30)).toBe(1319);
    expect(grossUpMinor(970, 300, 0)).toBe(1000);
    expect(grossUpMinor(1250, 0, 0)).toBe(1250);
  });
});
