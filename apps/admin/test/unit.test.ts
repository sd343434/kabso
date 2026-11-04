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

// ---- v1.65-social (D197): the panel v2's pure parts -----------------------------------------------------------
import { attachmentName } from '../src/api';
import { visibleNav, CAP_OF_ROUTE } from '../src/nav';
import { CAPABILITY_ROLES } from './capabilities';
import { diffOf, metaText } from '../src/pages/Audit';
import { filesBody, filesOf, giftBody, type GiftDto } from '../src/pages/Catalog';
import { categoryBody } from '../src/pages/GiftCategories';
import { parseMovieEntity } from '../src/svga';
import { deltaPercent, formatDay } from '../src/pages/Dashboard';
import { defaultRange } from '../src/pages/Finance';
import { onAir } from '../src/pages/Lives';
import type { Capability } from '../src/types';
import { areaPath, compact, linePath, nearestIndex, niceMax, xOf, yOf } from '../src/ui/charts';
import { pageWindow } from '../src/ui/DataTable';

describe('charts (hand-rolled SVG)', () => {
  it('rounds the axis top up to 1, 2, 2.5 or 5 × 10ⁿ', () => {
    expect(niceMax(0)).toBe(1);
    expect(niceMax(7)).toBe(10);
    expect(niceMax(12)).toBe(20);
    expect(niceMax(21)).toBe(25);
    expect(niceMax(16_226_647)).toBe(20_000_000);
    expect(niceMax(25_000_000)).toBe(25_000_000);
  });
  it('maps values to the plot box and draws paths', () => {
    expect(yOf(0, 10, 100)).toBe(100);
    expect(yOf(10, 10, 100)).toBe(0);
    expect(yOf(-5, 10, 100)).toBe(100);
    expect(xOf(0, 3, 200)).toBe(0);
    expect(xOf(2, 3, 200)).toBe(200);
    expect(xOf(0, 1, 200)).toBe(100);
    expect(linePath([0, 5, 10], 100, 50, 10)).toBe('M0.0 50.0 L50.0 25.0 L100.0 0.0');
    expect(areaPath([0, 10], 100, 50, 10)).toBe('M0.0 50.0 L100.0 0.0 L100.0 50 L0.0 50 Z');
    expect(areaPath([], 100, 50, 10)).toBe('');
  });
  it('finds the nearest point under the pointer and prints compact axis numbers', () => {
    expect(nearestIndex(0, 30, 300)).toBe(0);
    expect(nearestIndex(300, 30, 300)).toBe(29);
    expect(nearestIndex(-20, 30, 300)).toBe(0);
    expect(nearestIndex(151, 3, 300)).toBe(1);
    expect(compact(2.5)).toBe('2.5');
    expect(compact(950)).toBe('950');
    expect(compact(12_500)).toBe('12.5K');
    expect(compact(18_750_000)).toBe('18.8M');
    expect(compact(2_000_000_000)).toBe('2B');
  });
});

describe('table', () => {
  it('shows a window of pages around the current one', () => {
    expect(pageWindow(1, 1)).toEqual([1]);
    expect(pageWindow(3, 7)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(pageWindow(1, 20)).toEqual([1, 2, '…', 20]);
    expect(pageWindow(10, 20)).toEqual([1, '…', 9, 10, 11, '…', 20]);
    expect(pageWindow(20, 20)).toEqual([1, '…', 19, 20]);
  });
  it('names the CSV download from the server header', () => {
    expect(attachmentName('attachment; filename="kabso-users-2026-10-31.csv"', 'x.csv')).toBe('kabso-users-2026-10-31.csv');
    expect(attachmentName(null, 'x.csv')).toBe('x.csv');
  });
});

describe('dashboard and pages', () => {
  it('computes the change against yesterday', () => {
    expect(deltaPercent(12, 10)).toBe(20);
    expect(deltaPercent(5, 10)).toBe(-50);
    expect(deltaPercent(0, 0)).toBe(0);
    expect(deltaPercent(3, 0)).toBeNull();
  });
  it('shows the dashboard day in Asia/Riyadh whatever the browser zone', () => {
    // Riyadh midnight of 31 Oct 2026 is 21:00 UTC on the 30th.
    expect(formatDay('2026-10-30T21:00:00.000Z', 'Asia/Riyadh', 'en')).toContain('31 October 2026');
  });
  it('counts time on air', () => {
    expect(onAir('2026-10-31T10:00:00Z', Date.parse('2026-10-31T11:05:30Z'))).toBe('1:05');
    expect(onAir('2026-10-31T10:00:00Z', Date.parse('2026-10-31T09:00:00Z'))).toBe('0:00');
  });
  it('a report range: the last 30 Riyadh days, or the last 12 months', () => {
    const now = new Date('2026-10-31T12:00:00Z');
    expect(defaultRange('day', now)).toEqual({ from: '2026-10-02', to: '2026-10-31' });
    expect(defaultRange('month', now)).toEqual({ from: '2025-11-01', to: '2026-10-31' });
  });
});

describe('gift form', () => {
  const before: GiftDto = {
    code: 'rose',
    category: 'POPULAR',
    nameAr: 'وردة',
    nameEn: 'Rose',
    priceCoins: 10,
    priceUsd: '0.00',
    assetKey: 'gifts/rose',
    animationKey: null,
    imageUrl: null,
    hostedAnimation: false,
    imageObjectKey: null,
    animationObjectKey: null,
    animationUrl: null,
    animationFormat: null,
    animationAlpha: null,
    animationBytes: null,
    audioObjectKey: null,
    audioUrl: null,
    audioMs: null,
    sortOrder: 0,
    badge: 'NONE',
    lucky: false,
    tagCode: null,
    tagNameAr: null,
    tagNameEn: null,
    soundKey: null,
    soundMs: null,
    quipText: null,
    enabled: true,
    sends: 0,
    coinsSpent: 0,
  };
  const form = (over: Record<string, string>) => ({
    ...Object.fromEntries(Object.entries(before).map(([k, v]) => [k, v === null ? '' : String(v)])),
    ...over,
  });
  it('an edit sends only what changed, null for a cleared optional field', () => {
    expect(giftBody(form({}), before)).toEqual({});
    expect(giftBody(form({ priceCoins: '25', badge: 'NEW' }), before)).toEqual({ priceCoins: 25, badge: 'NEW' });
    expect(giftBody(form({ animationKey: 'fx/rose' }), { ...before })).toEqual({ animationKey: 'fx/rose' });
    expect(giftBody(form({ animationKey: '' }), { ...before, animationKey: 'fx/rose' })).toEqual({ animationKey: null });
  });
  it('a new gift sends every field that is set', () => {
    expect(
      giftBody({ category: 'LUCKY', nameAr: 'نجمة', nameEn: 'Star', priceCoins: '500', assetKey: 'gifts/star', badge: 'NONE', sortOrder: '0' }, null),
    ).toEqual({ category: 'LUCKY', nameAr: 'نجمة', nameEn: 'Star', priceCoins: 500, assetKey: 'gifts/star', sortOrder: 0, badge: 'NONE' });
  });
});

describe('gift files and categories (D207)', () => {
  const key = (ext: string, n = 'a') => `media/gifts/rose/${n.repeat(32)}.${ext}`;
  const gift = {
    code: 'rose',
    imageObjectKey: key('png'),
    imageUrl: 'https://m/x.png',
    animationObjectKey: key('mp4'),
    animationUrl: 'https://m/x.mp4',
    animationFormat: 'MP4',
    animationAlpha: 'NONE',
    audioObjectKey: null,
    audioUrl: null,
    audioMs: null,
  } as unknown as GiftDto;
  it('a new gift sends the uploaded keys (an MP4 with its transparency)', () => {
    const files = filesOf(null);
    expect(filesBody(files, null)).toEqual({});
    expect(
      filesBody(
        { image: { key: key('png'), url: null }, animation: { key: key('mp4'), url: null }, alpha: 'SIDE_BY_SIDE', sound: { key: key('mp3'), url: null } },
        null,
      ),
    ).toEqual({ imageObjectKey: key('png'), animationObjectKey: key('mp4'), animationAlpha: 'SIDE_BY_SIDE', audioObjectKey: key('mp3') });
    expect(filesBody({ ...files, image: { key: key('png'), url: null }, animation: { key: key('svga'), url: null } }, null)).toEqual({
      imageObjectKey: key('png'),
      animationObjectKey: key('svga'),
    });
  });
  it('an edit sends only what changed: the transparency alone, a removal as null', () => {
    const was = filesOf(gift);
    expect(filesBody(was, gift)).toEqual({});
    expect(filesBody({ ...was, alpha: 'SIDE_BY_SIDE' }, gift)).toEqual({ animationAlpha: 'SIDE_BY_SIDE' });
    expect(filesBody({ ...was, animation: { key: null, url: null } }, gift)).toEqual({ animationObjectKey: null });
    expect(filesBody({ ...was, sound: { key: key('mp3'), url: null } }, gift)).toEqual({ audioObjectKey: key('mp3') });
    expect(filesBody({ ...was, image: { key: key('png', 'b'), url: null } }, gift)).toEqual({ imageObjectKey: key('png', 'b') });
  });
  it('the category form: everything on create, only changes on an edit', () => {
    const form = { code: 'SPORTS', nameAr: 'رياضة', nameEn: 'Sports', sortOrder: '60' };
    expect(categoryBody(form, { key: null, url: null }, null)).toEqual({ code: 'SPORTS', nameAr: 'رياضة', nameEn: 'Sports', sortOrder: 60 });
    const before = { code: 'SPORTS', kind: 'NORMAL', nameAr: 'رياضة', nameEn: 'Sports', sortOrder: 60, enabled: true, iconObjectKey: null, iconUrl: null, gifts: 0, enabledGifts: 0, special: false } as const;
    expect(categoryBody(form, { key: null, url: null }, before)).toEqual({});
    expect(categoryBody({ ...form, nameEn: 'Sport' }, { key: 'media/gift-categories/SPORTS/x.png', url: null }, before)).toEqual({
      nameEn: 'Sport',
      iconObjectKey: 'media/gift-categories/SPORTS/x.png',
    });
  });
  it('reads an SVGA MovieEntity: params, images and sprite frames', () => {
    // MovieEntity { version: "2.0", params { 300, 200, fps 20, frames 2 }, images { "a": [1,2,3] }, sprites [{ imageKey "a", frames [{ alpha 1, layout {0,0,10,10} }, {}] }] }
    const f32 = (n: number) => {
      const b = new Uint8Array(4);
      new DataView(b.buffer).setFloat32(0, n, true);
      return [...b];
    };
    const msg = (field: number, bytes: number[]) => [(field << 3) | 2, bytes.length, ...bytes];
    const params = [0x0d, ...f32(300), 0x15, ...f32(200), 0x18, 20, 0x20, 2];
    const image = [...msg(1, [0x61]), ...msg(2, [1, 2, 3])];
    const layout = [0x0d, ...f32(0), 0x15, ...f32(0), 0x1d, ...f32(10), 0x25, ...f32(10)];
    const frame1 = [0x0d, ...f32(1), ...msg(2, layout)];
    const sprite = [...msg(1, [0x61]), ...msg(2, frame1), ...msg(2, [])];
    const bytes = new Uint8Array([...msg(1, [0x32, 0x2e, 0x30]), ...msg(2, params), ...msg(3, image), ...msg(4, sprite)]);
    const movie = parseMovieEntity(bytes);
    expect(movie).toMatchObject({ version: '2.0', width: 300, height: 200, fps: 20, frames: 2, vectorSprites: 0 });
    expect(movie.images.get('a')).toEqual(new Uint8Array([1, 2, 3]));
    expect(movie.sprites[0]!.frames).toHaveLength(2);
    expect(movie.sprites[0]!.frames[0]).toMatchObject({ alpha: 1, layout: { width: 10, height: 10 } });
    expect(movie.sprites[0]!.frames[1]!.alpha).toBe(0);
    expect(() => parseMovieEntity(new Uint8Array([0xff, 0xff]))).toThrow();
  });
});

describe('audit viewer', () => {
  it('shows before/after and a changes map as pairs', () => {
    expect(diffOf({ before: 'ACTIVE', after: 'SUSPENDED', reason: 'x' })).toEqual([{ field: '', before: 'ACTIVE', after: 'SUSPENDED' }]);
    expect(diffOf({ changes: { priceCoins: { from: 500, to: 750 } } })).toEqual([{ field: 'priceCoins', before: '500', after: '750' }]);
    expect(diffOf({ reason: 'x' })).toEqual([]);
    expect(metaText(null)).toBe('—');
    expect(metaText({ a: 1 })).toBe('{"a":1}');
  });
});

describe('navigation by role', () => {
  const CAPS: Record<string, Capability[]> = {
    MODERATION: ['dashboard.view', 'users.view', 'users.list', 'users.balances', 'users.ban', 'users.avatar', 'reports.view', 'reports.act', 'users.sessions', 'lives.view', 'lives.manage', 'hosts.applications'],
    FINANCE: ['dashboard.view', 'users.view', 'users.list', 'users.balances', 'users.ledger', 'recharge.agents', 'recharge.topups.view', 'recharge.topup', 'recharge.cap', 'withdrawals.view', 'withdrawals.decide', 'agencies.view', 'catalog.view', 'finance.view', 'finance.refund', 'programs.view'],
  };
  const items = (role: string) => visibleNav((c) => CAPS[role]!.includes(c)).flatMap((g) => g.items.map((i) => i.to));
  it('shows each role only what it can open (groups without items vanish)', () => {
    expect(items('MODERATION')).toEqual(['/', '/users', '/lives', '/live-hosts', '/host-applications', '/reports']);
    expect(items('FINANCE')).toContain('/finance/report');
    expect(items('FINANCE')).not.toContain('/team');
    expect(items('FINANCE')).not.toContain('/reports');
    expect(visibleNav((c) => CAPS.MODERATION!.includes(c)).map((g) => g.key)).not.toContain('navGroupMoney');
  });
  it('D275: the moderator «مشرف» sees the top-up records and the disputes, not the report, withdrawals or rates editing', () => {
    const mod = visibleNav((c) => (CAPABILITY_ROLES[c] ?? []).includes('MODERATION')).flatMap((g) => g.items.map((i) => i.to));
    expect(mod).toEqual(
      expect.arrayContaining(['/recharge/agents', '/recharge/disputes', '/recharge/exchange-rates', '/finance/topups', '/finance/cards']),
    );
    for (const to of ['/finance/report', '/withdrawals', '/recharge/applications', '/referrals', '/payments']) expect(mod, to).not.toContain(to);
    expect(CAP_OF_ROUTE.topups).toBe('recharge.topups.view');
    expect(CAP_OF_ROUTE.cards).toBe('recharge.topups.view');
    expect(CAP_OF_ROUTE.report).toBe('finance.view');
  });
  it('every v2 route has a capability', () => {
    for (const r of ['agencies', 'agency', 'complaints', 'lives', 'hosts', 'gifts', 'items', 'promo', 'report', 'topups', 'cards', 'tasks', 'levels', 'waitlist', 'team', 'audit', 'specialUsernames', 'hostApplications', 'hostApplication', 'referrals', 'referral', 'referralSettings']) {
      expect(CAP_OF_ROUTE[r], r).toBeTruthy();
    }
    expect(matchPath('/agencies/abc')).toEqual({ name: 'agency', params: { id: 'abc' } });
    expect(matchPath('/finance/report')?.name).toBe('report');
    expect(matchPath('/host-applications/abc')).toEqual({ name: 'hostApplication', params: { id: 'abc' } });
    expect(matchPath('/referrals/abc')).toEqual({ name: 'referral', params: { id: 'abc' } });
    expect(CAP_OF_ROUTE.referralSettings).toBe('referrals.view');
  });
});
