/**
 * The panel's only way to the server: same-origin `fetch` to /api/v1/admin/* with the HttpOnly session cookie
 * (`credentials: 'same-origin'`) and, on every change, the session's CSRF token (CONVENTIONS §10.54.2). No token
 * is stored by the page: the CSRF token lives in memory and is fetched again from `GET /admin/auth/session`.
 */
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

let csrfToken: string | null = null;
let onUnauthenticated: (() => void) | null = null;

export function setCsrfToken(token: string | null): void {
  csrfToken = token;
}

/** Called when a request comes back 401 (the session ended): the app shows the sign-in again. */
export function setUnauthenticatedHandler(handler: (() => void) | null): void {
  onUnauthenticated = handler;
}

export type Query = Record<string, string | number | undefined | null>;

export function withQuery(path: string, query: Query = {}): string {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) if (v !== undefined && v !== null && v !== '') params.set(k, String(v));
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

export async function request<T>(
  method: 'GET' | 'POST' | 'PUT' | 'PATCH',
  path: string,
  body?: unknown,
  opts: { auth?: boolean } = {},
): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (method !== 'GET' && csrfToken) headers['X-CSRF-Token'] = csrfToken;
  let res: Response;
  try {
    res = await fetch(`/api/v1${path}`, {
      method,
      headers,
      credentials: 'same-origin',
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
    if (res.status === 401 && opts.auth !== false) onUnauthenticated?.();
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

export const api = {
  get: <T>(path: string, query?: Query) => request<T>('GET', withQuery(path, query)),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body ?? {}),
  put: <T>(path: string, body: unknown) => request<T>('PUT', path, body),
  patch: <T>(path: string, body: unknown) => request<T>('PATCH', path, body),
};
