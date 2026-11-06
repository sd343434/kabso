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

/** The file name of a `Content-Disposition: attachment; filename="…"` header, or the fallback. */
export function attachmentName(header: string | null, fallback: string): string {
  const m = header ? /filename="([^"]+)"/.exec(header) : null;
  return m?.[1] ?? fallback;
}

/**
 * v1.65-social (D197): a table's `format=csv` export. The server audits it (`admin.export.csv`); the page only
 * saves the bytes it got (a Blob URL, revoked right after).
 */
export async function downloadCsv(path: string, query: Query, fallback: string): Promise<void> {
  let res: Response;
  try {
    res = await fetch(`/api/v1${withQuery(path, { ...query, format: 'csv' })}`, {
      credentials: 'same-origin',
      cache: 'no-store',
      headers: { Accept: 'text/csv' },
    });
  } catch {
    throw new ApiError(0, 'NETWORK', 'network');
  }
  if (!res.ok) {
    const parsed = (await res.json().catch(() => null)) as ApiErrorBody | null;
    if (res.status === 401) onUnauthenticated?.();
    throw new ApiError(res.status, parsed?.error.code ?? 'HTTP_ERROR', parsed?.error.message ?? res.statusText);
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = attachmentName(res.headers.get('Content-Disposition'), fallback);
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** v1.71-social (D207): what `POST /admin/gift-uploads` answers for a stored file. */
export interface GiftUpload {
  kind: 'image' | 'animation' | 'sound' | 'icon';
  key: string;
  url: string | null;
  bytes: number;
  contentType: string;
  format?: 'SVGA' | 'MP4';
  width?: number;
  height?: number;
  durationMs?: number;
  detectedAlpha?: 'NONE' | 'SIDE_BY_SIDE';
}

/**
 * v1.71-social (D207, CONVENTIONS §10.66): uploads one gift file (or a category icon) as the raw request body, with
 * the CSRF token, reporting progress (0 … 1). XMLHttpRequest because `fetch` has no upload progress. The server
 * checks the file (409 with the reason) and stores it; the key goes into the gift / category form.
 */
export function uploadGiftFile(
  kind: GiftUpload['kind'],
  code: string,
  file: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<GiftUpload> {
  return uploadRaw<GiftUpload>(withQuery('/admin/gift-uploads', { kind, code }), file, onProgress);
}

/** v1.59-live (D248): what `POST /admin/banner-uploads` answers for a stored banner picture. */
export interface BannerUpload {
  mediaId: string;
  placement: string;
  width: number;
  height: number;
  imageUrl: string | null;
  thumbUrl: string | null;
}

/**
 * v1.59-live (D248, CONVENTIONS §10.90): uploads a banner picture as the raw request body; the server cover-crops it to
 * the placement's shape (409 with the reason for a file that is not an acceptable image).
 */
export function uploadBannerPicture(
  placement: string,
  file: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<BannerUpload> {
  return uploadRaw<BannerUpload>(withQuery('/admin/banner-uploads', { placement }), file, onProgress);
}

/** v1.83-social (D258): what `POST /admin/vip/uploads` answers for a stored VIP art file. */
export interface VipUpload {
  kind: 'animation' | 'still';
  url: string;
  bytes: number;
  contentType: string;
  width: number | null;
  height: number | null;
}

/** v1.83-social (D258, §10.94.6): uploads one VIP badge / perk art file (SVGA or PNG / WebP still). */
export function uploadVipArt(
  kind: VipUpload['kind'],
  tier: string,
  file: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<VipUpload> {
  return uploadRaw<VipUpload>(withQuery('/admin/vip/uploads', { kind, tier }), file, onProgress);
}

/** D270 (§10.98.5): `AdminStoreUpload`. */
export interface StoreUpload {
  kind: 'animation' | 'still';
  url: string;
  bytes: number;
  contentType: string;
  format: 'SVGA' | 'MP4' | null;
  width: number | null;
  height: number | null;
  detectedAlpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  durationMs: number | null;
}

/** D270: uploads one store item art file (a PNG / WebP still, or an SVGA / MP4 animation). */
export function uploadStoreArt(
  kind: StoreUpload['kind'],
  file: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<StoreUpload> {
  return uploadRaw<StoreUpload>(withQuery('/admin/store/uploads', { kind }), file, onProgress);
}

/** v1.89-social (D290): what `POST /admin/level-raise-videos` answers for a stored video. */
export interface LevelRaiseVideoUpload {
  videoId: string;
  durationMs: number;
  width: number;
  height: number;
}

/** D290 (CONVENTIONS §10.103.2): uploads a level-raise request's video (MP4 / MOV, ≤ 100 MiB, ≤ 90 s) as raw bytes. */
export function uploadLevelRaiseVideo(
  file: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<LevelRaiseVideoUpload> {
  return uploadRaw<LevelRaiseVideoUpload>('/admin/level-raise-videos', file, onProgress);
}

/** A raw `application/octet-stream` POST with the CSRF token and upload progress (XMLHttpRequest: `fetch` has none). */
function uploadRaw<T>(path: string, file: Blob, onProgress: (fraction: number) => void): Promise<T> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', `/api/v1${path}`);
    xhr.withCredentials = true;
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');
    xhr.setRequestHeader('Accept', 'application/json');
    if (csrfToken) xhr.setRequestHeader('X-CSRF-Token', csrfToken);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && e.total > 0) onProgress(e.loaded / e.total);
    };
    xhr.onerror = () => reject(new ApiError(0, 'NETWORK', 'network'));
    xhr.onload = () => {
      let parsed: unknown;
      try {
        parsed = JSON.parse(xhr.responseText);
      } catch {
        parsed = null;
      }
      if (xhr.status >= 200 && xhr.status < 300) {
        onProgress(1);
        resolve(parsed as T);
        return;
      }
      const err = (parsed as ApiErrorBody | null)?.error;
      if (xhr.status === 401) onUnauthenticated?.();
      reject(new ApiError(xhr.status, err?.code ?? 'HTTP_ERROR', err?.message ?? xhr.statusText, null, err?.details ?? []));
    };
    xhr.send(file);
  });
}
