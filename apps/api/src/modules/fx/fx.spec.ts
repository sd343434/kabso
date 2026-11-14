import { describe, expect, it } from 'vitest';
import { COUNTRY_CURRENCY, CURRENCY_DIGITS } from './fx-countries.js';
import {
  currencyOfCountry,
  decide,
  FxFetchError,
  newFxSecretBox,
  nextDelaySeconds,
  parseCurrencyApi,
  parseExchangeRateApi,
  priceRateOf,
  rateMicroOf,
  resolveRate,
  FX_AAD,
} from './fx.rules.js';
import { isCountryCode } from '../users/country.js';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';

const NOW = new Date('2026-11-02T12:00:00Z');
const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000);

describe('D245 country → currency table', () => {
  it('covers every ISO 3166 country the app accepts (but AQ) with a currency that has decimals', () => {
    expect(Object.keys(COUNTRY_CURRENCY).length).toBe(248);
    for (const [country, currency] of Object.entries(COUNTRY_CURRENCY)) {
      expect(isCountryCode(country), country).toBe(true);
      expect(currency).toMatch(/^[A-Z]{3}$/);
      expect(CURRENCY_DIGITS[currency], currency).toBeGreaterThanOrEqual(0);
    }
  });

  it('keeps the D150 Arab currencies and decimals; official ISO codes elsewhere', () => {
    expect(currencyOfCountry('IQ')).toEqual({ currency: 'IQD', digits: 0 });
    expect(currencyOfCountry('KW')).toEqual({ currency: 'KWD', digits: 3 });
    expect(currencyOfCountry('PS')).toEqual({ currency: 'ILS', digits: 2 });
    expect(currencyOfCountry('JP')).toEqual({ currency: 'JPY', digits: 0 });
    expect(currencyOfCountry('DE')).toEqual({ currency: 'EUR', digits: 2 });
    expect(currencyOfCountry('EC')).toEqual({ currency: 'USD', digits: 2 });
    expect(currencyOfCountry('AQ')).toBeNull();
  });
});

describe('D245 feeds', () => {
  it('reads the free feed (open access) and the paid ExchangeRate-API answer', () => {
    const f = parseExchangeRateApi(
      {
        result: 'success',
        base_code: 'USD',
        time_last_update_unix: 1_793_577_600,
        rates: { USD: 1, EGP: 48.6 },
      },
      'OPEN_ER_API',
    );
    expect(f.rates.EGP).toBe(48.6);
    expect(f.providerUpdatedAt?.toISOString()).toBe('2026-11-02T00:00:00.000Z');
    expect(() =>
      parseExchangeRateApi({ result: 'error', 'error-type': 'invalid-key' }, 'EXCHANGERATE_API'),
    ).toThrow(expect.objectContaining({ issue: 'bad_api_key' }) as Error);
    expect(() =>
      parseExchangeRateApi({ result: 'error', 'error-type': 'quota-reached' }, 'EXCHANGERATE_API'),
    ).toThrow(FxFetchError);
    expect(() =>
      parseExchangeRateApi({ result: 'success', base_code: 'EUR', rates: {} }, 'OPEN_ER_API'),
    ).toThrow(FxFetchError);
    expect(() => parseExchangeRateApi('nope', 'OPEN_ER_API')).toThrow(FxFetchError);
  });

  it('reads currencyapi.com', () => {
    const f = parseCurrencyApi({
      meta: { last_updated_at: '2026-11-02T11:59:59Z' },
      data: { EGP: { code: 'EGP', value: 48.61 }, EUR: { code: 'EUR', value: 0.92 } },
    });
    expect(f.source).toBe('CURRENCYAPI');
    expect(f.rates).toEqual({ EGP: 48.61, EUR: 0.92 });
    expect(f.providerUpdatedAt?.toISOString()).toBe('2026-11-02T11:59:59.000Z');
  });
});

describe('D245 checks on every value', () => {
  it('rejects absurd values', () => {
    for (const v of [0, -1, Number.NaN, Number.POSITIVE_INFINITY, '48.6', null, 1e13, 1e-9]) {
      expect(rateMicroOf(v), String(v)).toBeNull();
      expect(decide(v, 48_000_000n, 50)).toEqual({ kind: 'reject', reason: 'absurd' });
    }
    expect(rateMicroOf(0.3071)).toBe(307_100n);
  });

  it('accepts a first value and a move up to the limit; holds a bigger jump', () => {
    expect(decide(48.6, null, 50)).toEqual({ kind: 'accept', rateMicro: 48_600_000n });
    expect(decide(72, 48_000_000n, 50)).toEqual({ kind: 'accept', rateMicro: 72_000_000n });
    expect(decide(72.1, 48_000_000n, 50)).toMatchObject({ kind: 'hold', rateMicro: 72_100_000n });
    expect(decide(20, 48_000_000n, 50)).toMatchObject({ kind: 'hold' });
  });
});

describe('D245 poll interval and back-off', () => {
  it('free: hourly, then 2 h, 4 h, at most 6 h; paid: every minute, then 2, 4 … at most 1 h', () => {
    expect(nextDelaySeconds(3600, 0, false)).toBe(3600);
    expect([1, 2, 3, 4].map((n) => nextDelaySeconds(3600, n, false))).toEqual([3600, 7200, 14_400, 21_600]);
    expect(nextDelaySeconds(60, 0, true)).toBe(60);
    expect([1, 2, 3, 7, 30].map((n) => nextDelaySeconds(60, n, true))).toEqual([60, 120, 240, 3600, 3600]);
  });
});

describe('D245 the resolver', () => {
  const auto = (h: number, rateMicro = 48_600_000n) => ({
    currency: 'EGP',
    rateMicro,
    source: 'OPEN_ER_API',
    providerUpdatedAt: hoursAgo(h),
    fetchedAt: NOW,
  });
  const manual = { currency: 'EGP', rateMicro: 50_500_000n, digits: 2, updatedAt: hoursAgo(1) };

  it('manual wins over automatic', () => {
    const e = resolveRate('EG', manual, auto(1), NOW, 48);
    expect(e.source).toBe('MANUAL');
    expect(e.rate?.rateMicro).toBe(50_500_000n);
  });

  it('automatic when there is no manual rate; stale (older than the limit, by the provider time) → USD only', () => {
    expect(resolveRate('EG', null, auto(47), NOW, 48)).toMatchObject({ source: 'AUTO', stale: false });
    const old = resolveRate('EG', null, auto(49), NOW, 48);
    expect(old).toMatchObject({ source: 'NONE', stale: true, rate: null, currency: 'EGP' });
  });

  it('USD countries are 1 (no second price line); no data → USD only', () => {
    const us = resolveRate('EC', null, null, NOW, 48);
    expect(us).toMatchObject({ source: 'USD', currency: 'USD' });
    expect(us.rate?.rateMicro).toBe(1_000_000n);
    expect(priceRateOf(us)).toBeNull();
    expect(resolveRate('FR', null, null, NOW, 48)).toMatchObject({
      source: 'NONE',
      rate: null,
      currency: 'EUR',
    });
    expect(resolveRate('AQ', null, null, NOW, 48)).toMatchObject({ source: 'NONE', currency: null });
  });

  it("ignores an automatic row of another currency (the country's own currency only)", () => {
    expect(resolveRate('SA', null, auto(1), NOW, 48)).toMatchObject({ source: 'NONE', currency: 'SAR' });
  });
});

describe('D245 the paid key at rest', () => {
  it('is sealed with its own HKDF key (not the TOTP / storage ones) and bound to its column', () => {
    const box = newFxSecretBox('admin-totp-test-key-0123456789-abcdefghijklmnop')!;
    const sealed = box.seal('cur_live_TESTONLY1234', FX_AAD.apiKey);
    expect(sealed).not.toContain('TESTONLY');
    expect(box.open(sealed, FX_AAD.apiKey)).toBe('cur_live_TESTONLY1234');
    expect(box.open(sealed, 'other.column')).toBeNull();
    expect(
      new AdminSecretBox('admin-totp-test-key-0123456789-abcdefghijklmnop').open(sealed, FX_AAD.apiKey),
    ).toBeNull();
    expect(newFxSecretBox(null)).toBeNull();
  });
});
