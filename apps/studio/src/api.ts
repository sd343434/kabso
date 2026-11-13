/**
 * The studio's way to the API (D247): same-origin `fetch` to /api/v1/* (Caddy proxies /api on studio.<domain>, so
 * there is no CORS and the CSP's `connect-src 'self'` covers it) with `Authorization: Bearer <access token>` from the
 * {@link Session}. A 401 on a signed-in call refreshes once (single-flight) and retries once, as the app does.
 */
import { Session, SessionExpiredError, tabStorage, type TokenPair } from './session';

export interface ApiErrorBody {
  error: { code: string; message: string; details?: { field: string; issue: string }[]; requestId?: string };
}

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryAfterSeconds: number | null = null,
    readonly details: { field: string; issue: string }[] = [],
  ) {
    super(message);
  }
}

export type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

type FetchFn = typeof fetch;

export class Api {
  readonly session: Session;
  /** The page's language, sent as `Accept-Language` (the gift catalogue's names follow it). */
  lang: 'ar' | 'en' = 'ar';

  constructor(
    private readonly fetchFn: FetchFn = (...a) => fetch(...a),
    session?: Session,
  ) {
    this.session = session ?? new Session(tabStorage(), (rt) => this.refreshTokens(rt));
  }

  /** `POST /auth/refresh` (no bearer token). */
  refreshTokens(refreshToken: string): Promise<TokenPair> {
    return this.raw<TokenPair>('POST', '/auth/refresh', { refreshToken }, null);
  }

  /** A call without a token (sign-in, refresh, the live config for a guest). */
  anonymous<T>(method: Method, path: string, body?: unknown): Promise<T> {
    return this.raw<T>(method, path, body, null);
  }

  /** A signed-in call; a 401 refreshes once and retries once. */
  async call<T>(method: Method, path: string, body?: unknown): Promise<T> {
    const token = await this.session.accessToken();
    try {
      return await this.raw<T>(method, path, body, token);
    } catch (err) {
      if (!(err instanceof ApiError) || err.status !== 401) throw err;
      let fresh: string;
      try {
        fresh = await this.session.refresh();
      } catch (e) {
        if (e instanceof SessionExpiredError) throw new ApiError(401, 'AUTH_UNAUTHENTICATED', 'session ended');
        throw e;
      }
      return this.raw<T>(method, path, body, fresh);
    }
  }

  get<T>(path: string): Promise<T> {
    return this.call<T>('GET', path);
  }
  post<T>(path: string, body: unknown = {}): Promise<T> {
    return this.call<T>('POST', path, body);
  }
  put<T>(path: string, body: unknown): Promise<T> {
    return this.call<T>('PUT', path, body);
  }

  private async raw<T>(method: Method, path: string, body: unknown, token: string | null): Promise<T> {
    const headers: Record<string, string> = { Accept: 'application/json', 'Accept-Language': this.lang };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (token) headers.Authorization = `Bearer ${token}`;
    let res: Response;
    try {
      res = await this.fetchFn(`/api/v1${path}`, {
        method,
        headers,
        credentials: 'omit',
        cache: 'no-store',
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
    } catch {
      throw new ApiError(0, 'NETWORK', 'network');
    }
    if (res.status === 204) return undefined as T;
    const parsed: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const err = (parsed as ApiErrorBody | null)?.error;
      const retry = res.headers.get('Retry-After');
      throw new ApiError(
        res.status,
        err?.code ?? 'HTTP_ERROR',
        err?.message ?? res.statusText,
        retry ? Number(retry) : null,
        err?.details ?? [],
      );
    }
    return parsed as T;
  }
}
