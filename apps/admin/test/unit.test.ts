import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, request, setCsrfToken, setUnauthenticatedHandler, withQuery } from '../src/api';
import { errorKey, serverMessage } from '../src/errors';
import { DICTIONARIES, translate } from '../src/i18n';
import { expectedMinor, minorToUsd, parseUsd, tierFor } from '../src/price';
import { qrModules } from '../src/qr';
import { matchPath } from '../src/router';

const TIERS = [
  { minCoins: 0, minorPerMillion: 1200 },
  { minCoins: 100_000_000, minorPerMillion: 1195 },
  { minCoins: 300_000_000, minorPerMillion: 1190 },
];

describe('i18n', () => {
  it('Arabic and English have the same keys and placeholders, none empty', () => {
    const ar = DICTIONARIES.ar;
    const en = DICTIONARIES.en;
    expect(Object.keys(en).sort()).toEqual(Object.keys(ar).sort());
    for (const k of Object.keys(ar) as (keyof typeof ar)[]) {
      expect(ar[k].trim(), k).not.toBe('');
      expect(en[k].trim(), k).not.toBe('');
      const vars = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
      expect(vars(en[k]), k).toEqual(vars(ar[k]));
    }
  });
  it('fills placeholders', () => {
    expect(translate('en', 'errLocked', { minutes: 15 })).toBe('Too many failed attempts. Try again in 15 min.');
    expect(translate('ar', 'topupDone', { stock: '30,000,000' })).toContain('30,000,000');
  });
});

describe('top-up price (mirror of the API rule)', () => {
  it('picks the highest reached tier and rounds half up', () => {
    expect(tierFor(30_000_000n, TIERS)?.minorPerMillion).toBe(1200);
    expect(tierFor(100_000_000n, TIERS)?.minorPerMillion).toBe(1195);
    expect(tierFor(999_999_999n, TIERS)?.minorPerMillion).toBe(1190);
    expect(tierFor(0n, TIERS)).toBeNull();
    expect(expectedMinor(30_000_000n, TIERS[0]!)).toBe(36_000n);
    expect(expectedMinor(100_000_000n, TIERS[1]!)).toBe(119_500n);
    expect(expectedMinor(1_250_000n, TIERS[0]!)).toBe(1_500n);
    expect(expectedMinor(1n, TIERS[0]!)).toBe(0n);
    expect(expectedMinor(417n, TIERS[0]!)).toBe(1n); // 0.5004 → 1
  });
  it('parses USD like the API', () => {
    expect(parseUsd('360')).toBe(36_000n);
    expect(parseUsd('360.5')).toBe(36_050n);
    expect(parseUsd(' 360.00 ')).toBe(36_000n);
    expect(parseUsd('360.001')).toBeNull();
    expect(parseUsd('-1')).toBeNull();
    expect(minorToUsd(36_005n)).toBe('360.05');
  });
});

describe('router', () => {
  it('matches the panel routes', () => {
    expect(matchPath('/')).toEqual({ name: 'dashboard', params: {} });
    expect(matchPath('/users/')).toEqual({ name: 'users', params: {} });
    expect(matchPath('/users/abc')).toEqual({ name: 'user', params: { id: 'abc' } });
    expect(matchPath('/recharge/applications/x%2Fy')).toEqual({ name: 'application', params: { id: 'x/y' } });
    expect(matchPath('/site-settings')?.name).toBe('site');
    expect(matchPath('/nope')).toBeNull();
    expect(matchPath('/users/a/b')).toBeNull();
  });
});

describe('api client', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    setCsrfToken(null);
    setUnauthenticatedHandler(null);
  });
  it('builds queries without empty values', () => {
    expect(withQuery('/admin/users', { q: 'a b', limit: 20, cursor: undefined, status: '' })).toBe('/admin/users?q=a+b&limit=20');
  });
  it('sends the CSRF token on changes only, same-origin, and maps errors', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    vi.stubGlobal('fetch', (url: string, init: RequestInit) => {
      calls.push({ url, init });
      const body = { error: { code: 'ADMIN_LOCKED', message: 'locked' } };
      return Promise.resolve(new Response(JSON.stringify(body), { status: 429, headers: { 'Retry-After': '120' } }));
    });
    setCsrfToken('csrf-1');
    await expect(request('POST', '/admin/users/x/ban', { reason: 'r' })).rejects.toMatchObject({ status: 429, code: 'ADMIN_LOCKED', retryAfterSeconds: 120 });
    await expect(request('GET', '/admin/dashboard')).rejects.toBeInstanceOf(ApiError);
    expect(calls[0]!.url).toBe('/api/v1/admin/users/x/ban');
    expect((calls[0]!.init.headers as Record<string, string>)['X-CSRF-Token']).toBe('csrf-1');
    expect(calls[0]!.init.credentials).toBe('same-origin');
    expect((calls[1]!.init.headers as Record<string, string>)['X-CSRF-Token']).toBeUndefined();
  });
  it('signals a 401 (session ended)', async () => {
    vi.stubGlobal('fetch', () =>
      Promise.resolve(new Response(JSON.stringify({ error: { code: 'AUTH_UNAUTHENTICATED', message: 'x' } }), { status: 401 })),
    );
    const handler = vi.fn();
    setUnauthenticatedHandler(handler);
    await expect(request('GET', '/admin/dashboard')).rejects.toMatchObject({ status: 401 });
    expect(handler).toHaveBeenCalledOnce();
  });
  it('error keys', () => {
    expect(errorKey(new ApiError(429, 'ADMIN_LOCKED', 'x', 600))).toEqual({ key: 'errLocked', vars: { minutes: 10 } });
    expect(errorKey(new ApiError(403, 'ADMIN_TOTP_INVALID', 'x')).key).toBe('errTotp');
    expect(errorKey(new Error('x')).key).toBe('errGeneric');
    expect(serverMessage(new ApiError(409, 'ADMIN_ACTION_REFUSED', 'The agent is SUSPENDED; reinstate first.'))).toBe(
      'The agent is SUSPENDED; reinstate first.',
    );
    expect(serverMessage(new ApiError(403, 'AUTH_FORBIDDEN', 'x'))).toBeNull();
  });
});

describe('QR', () => {
  it('encodes an otpauth URI into a square module grid', () => {
    const m = qrModules('otpauth://totp/Kabso%20Admin:o%40x.test?secret=JBSWY3DPEHPK3PXP&issuer=Kabso+Admin');
    expect(m.length).toBeGreaterThanOrEqual(25);
    expect(m.every((row) => row.length === m.length)).toBe(true);
    // Finder pattern: the top-left 7×7 corner starts dark.
    expect(m[0]![0]).toBe(true);
    expect(m[0]![6]).toBe(true);
    expect(m[1]![1]).toBe(false);
  });
});
