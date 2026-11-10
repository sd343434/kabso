import { readFileSync } from 'node:fs';
import type { AppConfig } from '../../config/app-config.js';

/**
 * v1.116-social (D355, CONVENTIONS §10.151.2): the WhatsApp Business Platform Cloud API (Meta's Graph API) — the only
 * code that talks to Meta. Calls (Graph API v2x, `Authorization: Bearer <System User token>`):
 *
 * - `POST /{version}/{phone-number-id}/messages` — text, media (by an uploaded media id), template; and
 *   `{status: 'read', message_id}` (the customer's blue ticks);
 * - `POST /{version}/{phone-number-id}/media` (multipart: `messaging_product`, `type`, `file`) → `{id}`;
 * - `GET /{version}/{media-id}` → `{url, mime_type, file_size}`, then `GET url` with the same bearer token;
 * - `GET /{version}/{waba-id}/message_templates?status=APPROVED` (paged);
 * - `GET /{version}/{phone-number-id}?fields=display_phone_number,verified_name,quality_rating` («اختبار الاتصال»).
 *
 * The token is never logged; errors keep Meta's numeric code and title only.
 */

export const WHATSAPP_GRAPH = Symbol('WHATSAPP_GRAPH');
/** The secrets read at boot (null: WhatsApp is off). */
export const WHATSAPP_SECRETS = Symbol('WHATSAPP_SECRETS');

export interface WhatsAppSecrets {
  readonly accessToken: string;
  readonly appSecret: string;
  readonly verifyToken: string;
}

function readSecret(path: string, name: string): string {
  let text: string;
  try {
    text = readFileSync(path, 'utf8').trim();
  } catch {
    throw new Error(`${name}: the file cannot be read (check the path and its permissions).`);
  }
  if (text.length < 8 || /\s/.test(text)) {
    throw new Error(`${name}: the file must hold one value of at least 8 characters with no spaces.`);
  }
  return text;
}

/** The secrets of the configured files, read once at boot (a missing or empty file refuses to boot). */
export function loadWhatsAppSecrets(config: AppConfig['whatsapp']): WhatsAppSecrets | null {
  const c = config.credentials;
  if (!c) return null;
  return {
    accessToken: readSecret(c.accessTokenFile, 'WHATSAPP_ACCESS_TOKEN_FILE'),
    appSecret: readSecret(c.appSecretFile, 'WHATSAPP_APP_SECRET_FILE'),
    verifyToken: readSecret(c.verifyTokenFile, 'WHATSAPP_VERIFY_TOKEN_FILE'),
  };
}

/** Meta refused (an HTTP error with Graph's `error` object) or did not answer (`status` 0). */
export class GraphError extends Error {
  constructor(
    readonly status: number,
    readonly code: number | null,
    readonly title: string | null,
  ) {
    super(`Graph API ${status}${code !== null ? ` code ${code}` : ''}${title ? `: ${title}` : ''}`);
  }
}

export interface GraphTemplate {
  readonly name: string;
  readonly language: string;
  readonly category: string | null;
  readonly status: string;
  /** The BODY component's text with its {{n}} placeholders. */
  readonly body: string | null;
  readonly parameterCount: number;
}

export interface GraphPhoneInfo {
  readonly displayPhoneNumber: string | null;
  readonly verifiedName: string | null;
  readonly qualityRating: string | null;
}

export interface WhatsAppGraph {
  sendMessage(payload: Record<string, unknown>): Promise<{ waMessageId: string }>;
  markRead(waMessageId: string): Promise<void>;
  uploadMedia(bytes: Buffer, mime: string, filename: string): Promise<string>;
  mediaInfo(mediaId: string): Promise<{ url: string; mime: string | null; size: number | null }>;
  /** The bytes, or null when larger than `maxBytes`. */
  download(url: string, maxBytes: number): Promise<Buffer | null>;
  templates(): Promise<GraphTemplate[]>;
  phoneInfo(): Promise<GraphPhoneInfo>;
}

const TIMEOUT_MS = 15_000;
const MAX_TEMPLATE_PAGES = 5;

/** Hosts Meta serves media from (the download URL comes from Meta; anything else is never fetched — SSRF). */
const MEDIA_HOSTS = [/\.fbsbx\.com$/i, /\.facebook\.com$/i, /\.whatsapp\.net$/i, /\.fbcdn\.net$/i];

export class FetchWhatsAppGraph implements WhatsAppGraph {
  private readonly base: string;
  private readonly origin: string;

  constructor(
    private readonly config: AppConfig['whatsapp'],
    private readonly secrets: WhatsAppSecrets,
  ) {
    this.base = `${config.graphBaseUrl}/${config.graphApiVersion}`;
    this.origin = new URL(config.graphBaseUrl).origin;
  }

  private get ids() {
    const c = this.config.credentials;
    if (!c) throw new GraphError(0, null, 'not configured');
    return c;
  }

  private async call(url: string, init: RequestInit = {}): Promise<Record<string, unknown>> {
    let res: Response;
    try {
      res = await fetch(url, {
        ...init,
        headers: { Authorization: `Bearer ${this.secrets.accessToken}`, ...(init.headers ?? {}) },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        redirect: 'error',
      });
    } catch {
      throw new GraphError(0, null, 'no answer');
    }
    const text = await res.text();
    let json: Record<string, unknown> = {};
    try {
      const parsed: unknown = text.length > 0 ? JSON.parse(text) : {};
      if (typeof parsed === 'object' && parsed !== null) json = parsed as Record<string, unknown>;
    } catch {
      // not JSON
    }
    if (!res.ok) {
      const err = (json.error ?? {}) as Record<string, unknown>;
      const code = typeof err.code === 'number' ? err.code : null;
      const title =
        typeof err.error_user_title === 'string'
          ? err.error_user_title
          : typeof err.message === 'string'
            ? err.message
            : null;
      throw new GraphError(res.status, code, title?.slice(0, 300) ?? null);
    }
    return json;
  }

  async sendMessage(payload: Record<string, unknown>): Promise<{ waMessageId: string }> {
    const json = await this.call(`${this.base}/${this.ids.phoneNumberId}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', recipient_type: 'individual', ...payload }),
    });
    const first = Array.isArray(json.messages)
      ? (json.messages[0] as Record<string, unknown> | undefined)
      : undefined;
    const id = typeof first?.id === 'string' ? first.id : null;
    if (!id) throw new GraphError(200, null, 'no message id in the answer');
    return { waMessageId: id };
  }

  async markRead(waMessageId: string): Promise<void> {
    await this.call(`${this.base}/${this.ids.phoneNumberId}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', status: 'read', message_id: waMessageId }),
    });
  }

  async uploadMedia(bytes: Buffer, mime: string, filename: string): Promise<string> {
    const form = new FormData();
    form.set('messaging_product', 'whatsapp');
    form.set('type', mime);
    form.set('file', new Blob([new Uint8Array(bytes)], { type: mime }), filename);
    const json = await this.call(`${this.base}/${this.ids.phoneNumberId}/media`, {
      method: 'POST',
      body: form,
    });
    if (typeof json.id !== 'string') throw new GraphError(200, null, 'no media id in the answer');
    return json.id;
  }

  async mediaInfo(mediaId: string): Promise<{ url: string; mime: string | null; size: number | null }> {
    if (!/^[0-9A-Za-z_-]{1,128}$/.test(mediaId)) throw new GraphError(400, null, 'bad media id');
    const json = await this.call(`${this.base}/${mediaId}`);
    if (typeof json.url !== 'string') throw new GraphError(200, null, 'no media url');
    return {
      url: json.url,
      mime: typeof json.mime_type === 'string' ? json.mime_type : null,
      size: typeof json.file_size === 'number' ? json.file_size : null,
    };
  }

  private trustedMediaUrl(url: string): boolean {
    let u: URL;
    try {
      u = new URL(url);
    } catch {
      return false;
    }
    if (u.origin === this.origin) return true;
    return u.protocol === 'https:' && MEDIA_HOSTS.some((h) => h.test(u.hostname));
  }

  async download(url: string, maxBytes: number): Promise<Buffer | null> {
    if (!this.trustedMediaUrl(url)) throw new GraphError(400, null, 'media url not on a Meta host');
    let res: Response;
    try {
      res = await fetch(url, {
        headers: { Authorization: `Bearer ${this.secrets.accessToken}` },
        signal: AbortSignal.timeout(60_000),
        redirect: 'error',
      });
    } catch {
      throw new GraphError(0, null, 'no answer');
    }
    if (!res.ok || !res.body) throw new GraphError(res.status, null, 'media download refused');
    const declared = Number(res.headers.get('content-length') ?? NaN);
    if (Number.isFinite(declared) && declared > maxBytes) {
      await res.body.cancel().catch(() => undefined);
      return null;
    }
    const chunks: Uint8Array[] = [];
    let size = 0;
    for await (const chunk of res.body as unknown as AsyncIterable<Uint8Array>) {
      size += chunk.byteLength;
      if (size > maxBytes) {
        await res.body.cancel().catch(() => undefined);
        return null;
      }
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }

  async templates(): Promise<GraphTemplate[]> {
    const out: GraphTemplate[] = [];
    let url: string | null =
      `${this.base}/${this.ids.businessAccountId}/message_templates` +
      '?fields=name,language,status,category,components&status=APPROVED&limit=100';
    for (let page = 0; url && page < MAX_TEMPLATE_PAGES; page += 1) {
      const json = await this.call(url);
      for (const t of Array.isArray(json.data) ? json.data : []) {
        const o = t as Record<string, unknown>;
        if (typeof o.name !== 'string' || typeof o.language !== 'string') continue;
        const comps = Array.isArray(o.components) ? (o.components as Record<string, unknown>[]) : [];
        const bodyComp = comps.find((c) => c.type === 'BODY');
        const body = typeof bodyComp?.text === 'string' ? bodyComp.text : null;
        const parameterCount = new Set([...(body ?? '').matchAll(/\{\{([0-9]{1,2})\}\}/g)].map((m) => m[1]))
          .size;
        out.push({
          name: o.name,
          language: o.language,
          category: typeof o.category === 'string' ? o.category : null,
          status: typeof o.status === 'string' ? o.status : 'APPROVED',
          body,
          parameterCount,
        });
      }
      const next = (json.paging as Record<string, unknown> | undefined)?.next;
      url = typeof next === 'string' && next.startsWith(this.origin) ? next : null;
    }
    return out.filter((t) => t.status === 'APPROVED');
  }

  async phoneInfo(): Promise<GraphPhoneInfo> {
    const json = await this.call(
      `${this.base}/${this.ids.phoneNumberId}?fields=display_phone_number,verified_name,quality_rating`,
    );
    return {
      displayPhoneNumber: typeof json.display_phone_number === 'string' ? json.display_phone_number : null,
      verifiedName: typeof json.verified_name === 'string' ? json.verified_name : null,
      qualityRating: typeof json.quality_rating === 'string' ? json.quality_rating : null,
    };
  }
}
