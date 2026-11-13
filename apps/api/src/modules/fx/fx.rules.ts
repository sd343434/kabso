import { z } from 'zod';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { ARAB_CURRENCIES } from '../recharge/recharge-order-rules.js';
import { COUNTRY_CURRENCY, CURRENCY_DIGITS } from './fx-countries.js';

/**
 * v1.81-social (D245, CONVENTIONS §10.87): automatic exchange rates for every country — the pure rules (no I/O): the
 * providers and their answers, the checks on every value, the hold of a value that jumped, the poll interval and the
 * back-off, the stale rule and the one resolver «manual over automatic» every price reads.
 */

/** Units per 1 USD × 1 000 000 (the D204 storage unit). */
export const MICRO = 1_000_000n;
/** The largest rate accepted (D204's limit: 10^12 units per USD). */
export const MAX_RATE_MICRO = 1_000_000_000_000_000_000n;

/** Where an automatic rate came from. */
export const FX_SOURCES = ['OPEN_ER_API', 'CURRENCYAPI', 'EXCHANGERATE_API'] as const;
export type FxSource = (typeof FX_SOURCES)[number];

/** The paid providers the OWNER can choose in «مزوّد أسعار الصرف». */
export const FX_PAID_PROVIDERS = ['CURRENCYAPI', 'EXCHANGERATE_API'] as const;
export type FxPaidProvider = (typeof FX_PAID_PROVIDERS)[number];

/** The free feed's attribution (ExchangeRate-API's open-access terms ask for it where the rates are shown). */
export const FREE_ATTRIBUTION = {
  text: 'Rates By Exchange Rate API',
  url: 'https://www.exchangerate-api.com',
} as const;

/** What the panel shows of each provider (no secrets). */
export const PROVIDER_INFO: Readonly<
  Record<FxSource, { name: string; site: string; signupUrl: string | null; docsUrl: string }>
> = {
  OPEN_ER_API: {
    name: 'ExchangeRate-API (open access, free)',
    site: 'https://www.exchangerate-api.com',
    signupUrl: null,
    docsUrl: 'https://www.exchangerate-api.com/docs/free',
  },
  CURRENCYAPI: {
    name: 'currencyapi.com',
    site: 'https://currencyapi.com',
    signupUrl: 'https://app.currencyapi.com/register',
    docsUrl: 'https://currencyapi.com/docs/latest',
  },
  EXCHANGERATE_API: {
    name: 'ExchangeRate-API (paid key)',
    site: 'https://www.exchangerate-api.com',
    signupUrl: 'https://app.exchangerate-api.com/sign-up',
    docsUrl: 'https://www.exchangerate-api.com/docs/standard-requests',
  },
};

/** HKDF info of the key that seals the paid provider's API key (a different key from the TOTP / Stripe / R2 / Didit). */
export const FX_SETTINGS_KEY_INFO = 'fx-settings/v1';
/** Additional data binding the sealed key to its column. */
export const FX_AAD = { apiKey: 'fx_settings.api_key' } as const;
export const API_KEY_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

export function newFxSecretBox(adminTotpKey: string | null): AdminSecretBox | null {
  return adminTotpKey ? new AdminSecretBox(adminTotpKey, FX_SETTINGS_KEY_INFO) : null;
}

/** `…AbCd` (never more). */
export function maskedOf(value: string | null | undefined): string | null {
  return value ? `…${value.slice(-4)}` : null;
}

// ---- countries --------------------------------------------------------------------------------------------------

/** The currency of a country (ISO 4217) and its decimals; null for a code without one (AQ, unknown). */
export function currencyOfCountry(country: string): { currency: string; digits: number } | null {
  const arab = ARAB_CURRENCIES[country];
  if (arab) return arab;
  const currency = COUNTRY_CURRENCY[country];
  if (!currency) return null;
  return { currency, digits: CURRENCY_DIGITS[currency] ?? 2 };
}

/** Every country of the table, sorted. */
export function allCountries(): string[] {
  return Object.keys(COUNTRY_CURRENCY).sort();
}

// ---- the feeds' answers -----------------------------------------------------------------------------------------

/** Why a fetch failed (the panel's «آخر خطأ»). */
export type FxIssue =
  | 'unreachable'
  | 'timeout'
  | 'http_error'
  | 'bad_api_key'
  | 'quota_reached'
  | 'rate_limited'
  | 'bad_response'
  | 'no_rates';

export class FxFetchError extends Error {
  constructor(
    readonly issue: FxIssue,
    readonly detail: string,
  ) {
    super(`${issue}: ${detail}`);
  }
}

/** One fetch's raw outcome: numbers per currency (USD base) and the provider's own time. */
export interface FxFeed {
  readonly source: FxSource;
  readonly providerUpdatedAt: Date | null;
  readonly rates: Readonly<Record<string, unknown>>;
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/**
 * ExchangeRate-API's answer — the free «open access» endpoint (`open.er-api.com/v6/latest/USD`) and the paid
 * `v6.exchangerate-api.com/v6/{key}/latest/USD` share it: `{result: "success", base_code: "USD",
 * time_last_update_unix, rates: {EUR: 0.92, …}}`, or `{result: "error", "error-type": "invalid-key" | …}`.
 */
export function parseExchangeRateApi(body: unknown, source: FxSource): FxFeed {
  if (!isObject(body)) throw new FxFetchError('bad_response', 'not a JSON object');
  if (body.result === 'error') {
    const type = typeof body['error-type'] === 'string' ? body['error-type'] : 'unknown';
    if (type === 'invalid-key' || type === 'inactive-account') throw new FxFetchError('bad_api_key', type);
    if (type === 'quota-reached') throw new FxFetchError('quota_reached', type);
    throw new FxFetchError('bad_response', type.slice(0, 100));
  }
  if (body.result !== 'success') throw new FxFetchError('bad_response', 'result is not "success"');
  const base = body.base_code ?? body.base;
  if (base !== 'USD') throw new FxFetchError('bad_response', 'base is not USD');
  const rates = body.rates ?? body.conversion_rates;
  if (!isObject(rates)) throw new FxFetchError('bad_response', 'no rates object');
  const unix = body.time_last_update_unix;
  return {
    source,
    providerUpdatedAt: typeof unix === 'number' && Number.isFinite(unix) ? new Date(unix * 1000) : null,
    rates,
  };
}

/**
 * currencyapi.com `GET /v3/latest?base_currency=USD` (header `apikey`): `{meta: {last_updated_at}, data: {EUR: {code,
 * value}, …}}`; a bad key → 401 (handled by the caller), an error body `{message}`.
 */
export function parseCurrencyApi(body: unknown): FxFeed {
  if (!isObject(body)) throw new FxFetchError('bad_response', 'not a JSON object');
  const data = body.data;
  if (!isObject(data)) throw new FxFetchError('bad_response', 'no data object');
  const rates: Record<string, unknown> = {};
  for (const [code, v] of Object.entries(data)) rates[code] = isObject(v) ? v.value : v;
  const meta = isObject(body.meta) ? body.meta : {};
  const at = typeof meta.last_updated_at === 'string' ? new Date(meta.last_updated_at) : null;
  return {
    source: 'CURRENCYAPI',
    providerUpdatedAt: at && !Number.isNaN(at.getTime()) ? at : null,
    rates,
  };
}

/** A number of units per USD → micro units; null when absurd (not a finite number > 0, or too large / too small). */
export function rateMicroOf(value: unknown): bigint | null {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) return null;
  if (value > 1e12) return null;
  const micro = BigInt(Math.round(value * 1e6));
  return micro > 0n && micro <= MAX_RATE_MICRO ? micro : null;
}

/** The decision for one currency of a feed. */
export type FxDecision =
  | { kind: 'accept'; rateMicro: bigint }
  | { kind: 'hold'; rateMicro: bigint; jumpPercent: number }
  | { kind: 'reject'; reason: 'absurd' };

/**
 * One value against the last good one: absurd values (zero, negative, NaN, not a number, > 10^12) are rejected; a value
 * that moved more than `maxJumpPercent` (default 50 %) from the last good one is held for the team's review (the last
 * good value stays in force); else it is accepted. A first value (no last good one) is accepted.
 */
export function decide(value: unknown, last: bigint | null, maxJumpPercent: number): FxDecision {
  const micro = rateMicroOf(value);
  if (micro === null) return { kind: 'reject', reason: 'absurd' };
  if (last === null || last <= 0n) return { kind: 'accept', rateMicro: micro };
  const jump = (Math.abs(Number(micro - last)) / Number(last)) * 100;
  return jump > maxJumpPercent
    ? { kind: 'hold', rateMicro: micro, jumpPercent: Math.round(jump * 10) / 10 }
    : { kind: 'accept', rateMicro: micro };
}

// ---- the poller -------------------------------------------------------------------------------------------------

/** The longest wait after failures in a row (free feed / paid provider). */
export const MAX_BACKOFF_SECONDS = { free: 6 * 3600, paid: 3600 } as const;

/**
 * Seconds until the next fetch: the interval after a success; after `failures` failures in a row, the interval × 2^(n−1)
 * (paid: 60 s, 2 min, 4 min … at most 1 hour; free: 1 h, 2 h, 4 h, at most 6 hours) — never shorter than the interval.
 */
export function nextDelaySeconds(intervalSeconds: number, failures: number, paid: boolean): number {
  if (failures <= 0) return intervalSeconds;
  const cap = Math.max(intervalSeconds, paid ? MAX_BACKOFF_SECONDS.paid : MAX_BACKOFF_SECONDS.free);
  return Math.min(cap, intervalSeconds * 2 ** Math.min(failures - 1, 16));
}

/** How long a fetching instance holds the lease (another instance takes over after it). */
export const FX_LEASE_SECONDS = 120;
/** «تحديث الآن» is refused within this many seconds of the last attempt (no hammering of the feed). */
export const FX_REFRESH_MIN_SECONDS = 60;

// ---- the resolver -----------------------------------------------------------------------------------------------

export type FxRateSource = 'MANUAL' | 'AUTO' | 'USD' | 'NONE';

export interface ManualRate {
  readonly currency: string;
  readonly rateMicro: bigint;
  readonly digits: number;
  readonly updatedAt: Date;
}

export interface AutoRate {
  readonly currency: string;
  readonly rateMicro: bigint;
  readonly source: string;
  readonly providerUpdatedAt: Date | null;
  readonly fetchedAt: Date;
}

/** The rate a price uses; `rate` null = USD only. */
export interface EffectiveRate {
  readonly country: string;
  readonly source: FxRateSource;
  readonly currency: string | null;
  readonly digits: number;
  readonly rate: { currency: string; rateMicro: bigint; digits: number } | null;
  /** The automatic value exists but is older than the stale limit (then not used: USD only). */
  readonly stale: boolean;
  readonly updatedAt: Date | null;
}

/** The age an automatic rate is judged by: the provider's own time when it gave one, else when it was fetched. */
export function autoAgeFrom(a: AutoRate): Date {
  return a.providerUpdatedAt ?? a.fetchedAt;
}

export function isStale(a: AutoRate, now: Date, staleAfterHours: number): boolean {
  return now.getTime() - autoAgeFrom(a).getTime() > staleAfterHours * 3_600_000;
}

/**
 * The one rule (D245): the admin's MANUAL rate of the country wins; else a USD country is 1; else the AUTOMATIC rate
 * of the country's currency when it is not stale; else none (USD only — D204's rule, the USD price always shows).
 * Stale automatic data is NOT shown as approximate: the price falls back to USD only (owner's choice of the two).
 */
export function resolveRate(
  country: string,
  manual: ManualRate | null,
  auto: AutoRate | null,
  now: Date,
  staleAfterHours: number,
): EffectiveRate {
  const own = currencyOfCountry(country);
  if (manual) {
    return {
      country,
      source: 'MANUAL',
      currency: manual.currency,
      digits: manual.digits,
      rate: { currency: manual.currency, rateMicro: manual.rateMicro, digits: manual.digits },
      stale: false,
      updatedAt: manual.updatedAt,
    };
  }
  if (!own)
    return { country, source: 'NONE', currency: null, digits: 2, rate: null, stale: false, updatedAt: null };
  if (own.currency === 'USD') {
    return {
      country,
      source: 'USD',
      currency: 'USD',
      digits: 2,
      rate: { currency: 'USD', rateMicro: MICRO, digits: 2 },
      stale: false,
      updatedAt: null,
    };
  }
  if (auto && auto.currency === own.currency) {
    const stale = isStale(auto, now, staleAfterHours);
    return {
      country,
      source: stale ? 'NONE' : 'AUTO',
      currency: own.currency,
      digits: own.digits,
      rate: stale ? null : { currency: own.currency, rateMicro: auto.rateMicro, digits: own.digits },
      stale,
      updatedAt: auto.fetchedAt,
    };
  }
  return {
    country,
    source: 'NONE',
    currency: own.currency,
    digits: own.digits,
    rate: null,
    stale: false,
    updatedAt: null,
  };
}

/**
 * The rate an order's price carries: a USD country's rate of 1 gives no local line (the USD line already shows the same
 * amount), so the app shows it once.
 */
export function priceRateOf(
  e: EffectiveRate,
): { currency: string; rateMicro: bigint; digits: number } | null {
  return e.rate && e.rate.currency !== 'USD' ? e.rate : null;
}

// ---- the panel's bodies -----------------------------------------------------------------------------------------

const reason = z.string().trim().min(1).max(500);
const totpCode = z.string().regex(/^[0-9]{6}$/);
const apiKey = z.string().trim().regex(API_KEY_PATTERN);

export const updateFxSettingsSchema = z.strictObject({
  provider: z.enum(FX_PAID_PROVIDERS).optional(),
  apiKey: apiKey.optional(),
  enabled: z.boolean().optional(),
  skipConnectionTest: z.boolean().optional(),
  totpCode,
  reason,
});
export type UpdateFxSettingsInput = z.infer<typeof updateFxSettingsSchema>;

export const testFxSettingsSchema = z.strictObject({
  provider: z.enum(FX_PAID_PROVIDERS).optional(),
  apiKey: apiKey.optional(),
});
export type TestFxSettingsInput = z.infer<typeof testFxSettingsSchema>;

export const clearFxSettingsSchema = z.strictObject({ totpCode, reason });
export type ClearFxSettingsInput = z.infer<typeof clearFxSettingsSchema>;

/** «اختبار الاتصال»'s outcome (kept as the last test; never the key, only its last 4). */
export interface FxTestReport {
  ok: boolean;
  at: string;
  provider: FxPaidProvider;
  apiKeyLast4: string;
  ms: number;
  issue: FxIssue | null;
  detail: string | null;
  currencies: number;
  providerUpdatedAt: string | null;
}
