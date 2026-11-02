import { describe, expect, it, vi } from 'vitest';
import { Api, ApiError } from '../src/api';
import { errorKey } from '../src/errors';
import { REFRESH_KEY, Session, SessionExpiredError, claimTab, type KeyValueStore, type TokenPair } from '../src/session';
import { studioDevice } from '../src/SignIn';

class MemoryStore implements KeyValueStore {
  readonly map = new Map<string, string>();
  getItem(k: string) {
    return this.map.get(k) ?? null;
  }
  setItem(k: string, v: string) {
    this.map.set(k, v);
  }
  removeItem(k: string) {
    this.map.delete(k);
  }
}

const pair = (n: number, ttlMs = 15 * 60_000, now = 0): TokenPair => ({
  accessToken: `access-${n}`,
  accessTokenExpiresAt: new Date(now + ttlMs).toISOString(),
  refreshToken: `refresh-${n}`,
  refreshTokenExpiresAt: new Date(now + 30 * 86_400_000).toISOString(),
});

function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(status === 204 ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...headers } });
}

describe('session: tokens and the single-flight refresh', () => {
  it('keeps the refresh token in the tab store, the access token in memory', async () => {
    const store = new MemoryStore();
    const refresh = vi.fn();
    const s = new Session(store, refresh, () => 0);
    expect(s.hasSession).toBe(false);
    s.signedIn(pair(1));
    expect(store.getItem(REFRESH_KEY)).toBe('refresh-1');
    expect([...store.map.values()]).not.toContain('access-1');
    expect(await s.accessToken()).toBe('access-1');
    expect(refresh).not.toHaveBeenCalled();
  });

  it('concurrent callers share one refresh (two refreshes with one secret would revoke the session)', async () => {
    const store = new MemoryStore();
    let now = 0;
    let resolve!: (p: TokenPair) => void;
    const refresh = vi.fn(() => new Promise<TokenPair>((r) => (resolve = r)));
    const s = new Session(store, refresh, () => now);
    s.signedIn(pair(1, 60_000));
    now = 45_000; // under 30 s left → refresh
    const a = s.accessToken();
    const b = s.accessToken();
    const c = s.refresh();
    expect(refresh).toHaveBeenCalledTimes(1);
    expect(refresh).toHaveBeenCalledWith('refresh-1');
    resolve(pair(2, 15 * 60_000, now));
    expect(await Promise.all([a, b, c])).toEqual(['access-2', 'access-2', 'access-2']);
    expect(store.getItem(REFRESH_KEY)).toBe('refresh-2');
    // A later refresh is a new call with the rotated secret.
    void s.refresh().catch(() => undefined);
    expect(refresh).toHaveBeenLastCalledWith('refresh-2');
  });

  it('a refused refresh (401/403) ends the session; a network failure keeps it', async () => {
    const store = new MemoryStore();
    const refresh = vi.fn<(rt: string) => Promise<TokenPair>>();
    const s = new Session(store, refresh, () => 0);
    const cleared = vi.fn();
    s.onCleared(cleared);
    s.signedIn(pair(1, 1000));
    refresh.mockRejectedValueOnce(new ApiError(0, 'NETWORK', 'network'));
    await expect(s.accessToken()).rejects.toMatchObject({ code: 'NETWORK' });
    expect(store.getItem(REFRESH_KEY)).toBe('refresh-1');
    refresh.mockRejectedValueOnce(new ApiError(401, 'AUTH_REFRESH_INVALID', 'x'));
    await expect(s.accessToken()).rejects.toBeInstanceOf(SessionExpiredError);
    expect(store.getItem(REFRESH_KEY)).toBeNull();
    expect(cleared).toHaveBeenCalledTimes(1);
    await expect(s.accessToken()).rejects.toBeInstanceOf(SessionExpiredError);
  });

  it('works without browser storage (a private window): the session lives in memory', async () => {
    const s = new Session(null, vi.fn(), () => 0);
    s.signedIn(pair(1));
    expect(s.hasSession).toBe(true);
    expect(await s.accessToken()).toBe('access-1');
  });

  it('a duplicated tab gives up its copied refresh token; the original keeps it', async () => {
    type Ch = { onmessage: ((ev: MessageEvent) => void) | null; postMessage(d: unknown): void; close(): void };
    const listeners: Ch[] = [];
    const channel = (): Ch => {
      const ch: Ch = {
        onmessage: null,
        postMessage(data: unknown) {
          for (const other of listeners) if (other !== ch) other.onmessage?.({ data } as MessageEvent);
        },
        close() {},
      };
      listeners.push(ch);
      return ch;
    };
    // The original tab.
    const original = new MemoryStore();
    let n = 0;
    const ids = () => `tab-${++n}`;
    expect(await claimTab(original, channel(), ids, 5)).toBe(false);
    original.setItem(REFRESH_KEY, 'refresh-1');
    // The browser duplicates it: the copy has the same storage.
    const copy = new MemoryStore();
    for (const [k, v] of original.map) copy.setItem(k, v);
    expect(await claimTab(copy, channel(), ids, 5)).toBe(true);
    expect(copy.getItem(REFRESH_KEY)).toBeNull();
    expect(copy.getItem('kabso.studio.tab')).not.toBe(original.getItem('kabso.studio.tab'));
    expect(original.getItem(REFRESH_KEY)).toBe('refresh-1');
    // A reload of the original alone (nobody answers) keeps its token.
    const reloaded = new MemoryStore();
    for (const [k, v] of original.map) reloaded.setItem(k, v);
    listeners.length = 0;
    expect(await claimTab(reloaded, channel(), ids, 5)).toBe(false);
    expect(reloaded.getItem(REFRESH_KEY)).toBe('refresh-1');
  });
});

describe('api: bearer token, one refresh and one retry on 401', () => {
  it('sends the bearer token and the page language; a 401 refreshes once and retries once', async () => {
    const calls: { url: string; auth: string | null; lang: string | null }[] = [];
    let rejectNext = true;
    const fetchFn = vi.fn(async (url: RequestInfo | URL, init?: RequestInit) => {
      const h = new Headers(init?.headers);
      calls.push({ url: String(url), auth: h.get('Authorization'), lang: h.get('Accept-Language') });
      if (String(url).endsWith('/auth/refresh')) return json(200, pair(2, 15 * 60_000, Date.now()));
      if (rejectNext) {
        rejectNext = false;
        return json(401, { error: { code: 'AUTH_UNAUTHENTICATED', message: 'expired' } });
      }
      return json(200, { id: 'me' });
    }) as unknown as typeof fetch;
    const api: Api = new Api(fetchFn, new Session(new MemoryStore(), (rt): Promise<TokenPair> => api.refreshTokens(rt)));
    api.lang = 'en';
    api.session.signedIn(pair(1, 15 * 60_000, Date.now()));
    expect(await api.get('/me')).toEqual({ id: 'me' });
    expect(calls.map((c) => [c.url, c.auth])).toEqual([
      ['/api/v1/me', 'Bearer access-1'],
      ['/api/v1/auth/refresh', null],
      ['/api/v1/me', 'Bearer access-2'],
    ]);
    expect(calls.every((c) => c.lang === 'en')).toBe(true);
  });

  it('turns error envelopes into ApiError (code, details, Retry-After) and maps them to the studio words', async () => {
    const fetchFn = vi.fn(async () =>
      json(403, { error: { code: 'ACCOUNT_LOCKED', message: 'locked', details: [{ field: 'lockedUntil', issue: '2026-12-01T10:00:00.000Z' }] } }, { 'Retry-After': '30' }),
    ) as unknown as typeof fetch;
    const api = new Api(fetchFn, new Session(null, vi.fn()));
    const err = await api.anonymous('POST', '/auth/login', {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 403, code: 'ACCOUNT_LOCKED', retryAfterSeconds: 30 });
    expect(errorKey(err).key).toBe('errLocked');
    expect(errorKey(new ApiError(401, 'AUTH_INVALID_CREDENTIALS', '')).key).toBe('errCredentials');
    expect(errorKey(new ApiError(409, 'ACCOUNT_DELETION_PENDING', '')).key).toBe('errDeletionPending');
    expect(errorKey(new ApiError(403, 'LIVE_HOSTING_NOT_ALLOWED', '')).key).toBe('gateNoPermission');
    expect(errorKey(new ApiError(503, 'LIVE_HOSTING_UNAVAILABLE', '')).key).toBe('gateHostingOff');
    expect(errorKey(new ApiError(400, 'VALIDATION_FAILED', '', null, [{ field: 'newPassword', issue: 'same_as_current' }])).key).toBe('errSamePassword');
    expect(errorKey(new ApiError(0, 'NETWORK', '')).key).toBe('errNetwork');
    expect(errorKey(new Error('x')).key).toBe('errGeneric');
  });

  it('a network failure is ApiError NETWORK (status 0)', async () => {
    const api = new Api((async () => {
      throw new TypeError('failed');
    }) as unknown as typeof fetch, new Session(null, vi.fn()));
    await expect(api.anonymous('GET', '/live/config')).rejects.toMatchObject({ status: 0, code: 'NETWORK' });
  });

  it('the studio signs in as a `web` device named after the browser', () => {
    expect(studioDevice('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36')).toEqual({
      name: 'Kabso Studio — Chrome on Windows',
      platform: 'web',
      appVersion: 'studio-0.1.0',
    });
    expect(studioDevice('Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36 Edg/141.0').name).toBe(
      'Kabso Studio — Edge on macOS',
    );
  });
});
