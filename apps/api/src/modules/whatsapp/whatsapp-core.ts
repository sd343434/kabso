import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * v1.116-social (D355, CONVENTIONS §10.151): the pure rules of «واتساب» — the webhook signature, the payload parser, the
 * 24-hour customer-service window, the media allowlist and the previews. No Nest, no database: shared by the service and
 * the unit tests.
 *
 * Meta's shapes (WhatsApp Business Platform, Cloud API, Graph API v2x) as documented for the `messages` webhook field:
 * `{object: 'whatsapp_business_account', entry: [{id, changes: [{field: 'messages', value: {messaging_product,
 * metadata: {display_phone_number, phone_number_id}, contacts: [{profile: {name}, wa_id}], messages: [...],
 * statuses: [...], errors: [...]}}]}]}`. developers.facebook.com was not reachable from the build machine (D355): the
 * parser is deliberately lenient (unknown fields ignored, unknown types stored as UNSUPPORTED) and strict only where
 * a wrong value would be stored (ids, phone, timestamps).
 */

/** Meta's 24-hour customer-service window (free-form messages only within it; afterwards an approved template). */
export const CUSTOMER_WINDOW_MS = 24 * 3600 * 1000;

/** The longest text Meta accepts in a text message body. */
export const MAX_TEXT_CHARS = 4096;

/** The media types kept and sent (Meta's supported types, §10.151.6); anything else is refused. */
export const MEDIA_MIME_ALLOWLIST: Readonly<
  Record<string, 'IMAGE' | 'AUDIO' | 'VIDEO' | 'DOCUMENT' | 'STICKER'>
> = {
  'image/jpeg': 'IMAGE',
  'image/png': 'IMAGE',
  'image/webp': 'STICKER',
  'audio/aac': 'AUDIO',
  'audio/mp4': 'AUDIO',
  'audio/mpeg': 'AUDIO',
  'audio/amr': 'AUDIO',
  'audio/ogg': 'AUDIO',
  'video/mp4': 'VIDEO',
  'video/3gpp': 'VIDEO',
  'application/pdf': 'DOCUMENT',
  'text/plain': 'DOCUMENT',
  'application/msword': 'DOCUMENT',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'DOCUMENT',
  'application/vnd.ms-excel': 'DOCUMENT',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'DOCUMENT',
  'application/vnd.ms-powerpoint': 'DOCUMENT',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'DOCUMENT',
};

/** The mime type without parameters (`audio/ogg; codecs=opus` → `audio/ogg`), lower case. */
export function baseMime(mime: string | null | undefined): string {
  return (mime ?? '').split(';')[0]!.trim().toLowerCase();
}

export function mediaAllowed(mime: string | null | undefined): boolean {
  return baseMime(mime) in MEDIA_MIME_ALLOWLIST;
}

const EXTENSIONS: Readonly<Record<string, string>> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'audio/aac': 'aac',
  'audio/mp4': 'm4a',
  'audio/mpeg': 'mp3',
  'audio/amr': 'amr',
  'audio/ogg': 'ogg',
  'video/mp4': 'mp4',
  'video/3gpp': '3gp',
  'application/pdf': 'pdf',
  'text/plain': 'txt',
};

/** The private storage key of a message's media (the private bucket, §10.72). */
export function mediaKey(conversationId: string, messageId: string, mime: string): string {
  return `private/whatsapp/${conversationId}/${messageId}.${EXTENSIONS[baseMime(mime)] ?? 'bin'}`;
}

/**
 * `X-Hub-Signature-256: sha256=<hex>` — HMAC-SHA256 of the exact request bytes with the Meta app secret. Constant-time.
 */
export function signatureValid(raw: Buffer, header: string | undefined, appSecret: string): boolean {
  if (typeof header !== 'string') return false;
  const m = /^sha256=([0-9a-f]{64})$/i.exec(header.trim());
  if (!m) return false;
  const expected = createHmac('sha256', appSecret).update(raw).digest();
  const given = Buffer.from(m[1]!.toLowerCase(), 'hex');
  return given.length === expected.length && timingSafeEqual(given, expected);
}

/** The signature header Meta would send for `raw` (tests and the fake Graph API). */
export function signatureOf(raw: Buffer | string, appSecret: string): string {
  return `sha256=${createHmac('sha256', appSecret).update(raw).digest('hex')}`;
}

/** Constant-time comparison of the webhook verify token. */
export function verifyTokenMatches(given: unknown, expected: string): boolean {
  if (typeof given !== 'string' || given.length === 0) return false;
  const a = Buffer.from(given, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

/** Meta's `wa_id` (digits, the country code first) as E.164, or null when it is not a phone number. */
export function e164Of(waId: unknown): string | null {
  if (typeof waId !== 'string') return null;
  const digits = waId.replace(/^\+/, '');
  return /^[1-9][0-9]{6,14}$/.test(digits) ? `+${digits}` : null;
}

/** A staff search term as a phone prefix (digits only, with or without +), or null when it is not one. */
export function phoneSearchOf(q: string): string | null {
  const digits = q.replace(/[\s()+-]/g, '');
  return /^[0-9]{3,15}$/.test(digits) ? `+${digits.replace(/^00/, '')}` : null;
}

export interface CustomerWindow {
  readonly open: boolean;
  /** When free-form replies stop being allowed (null: the customer never wrote). */
  readonly closesAt: Date | null;
}

/** The 24-hour window from the customer's last message. */
export function windowOf(lastInboundAt: Date | null, now: Date): CustomerWindow {
  if (!lastInboundAt) return { open: false, closesAt: null };
  const closesAt = new Date(lastInboundAt.getTime() + CUSTOMER_WINDOW_MS);
  return { open: now.getTime() < closesAt.getTime(), closesAt };
}

// ---- the webhook payload ------------------------------------------------------------------------------------------

export type InboundType =
  | 'TEXT'
  | 'IMAGE'
  | 'AUDIO'
  | 'VIDEO'
  | 'DOCUMENT'
  | 'STICKER'
  | 'LOCATION'
  | 'REACTION'
  | 'CONTACTS'
  | 'INTERACTIVE'
  | 'UNSUPPORTED';

export interface InboundMessage {
  readonly kind: 'message';
  readonly phoneNumberId: string | null;
  readonly waMessageId: string;
  readonly phoneE164: string;
  readonly waId: string;
  readonly profileName: string | null;
  readonly timestamp: Date;
  readonly type: InboundType;
  readonly body: string | null;
  readonly media: {
    readonly id: string;
    readonly mime: string | null;
    readonly filename: string | null;
    readonly voice: boolean;
  } | null;
  readonly location: {
    readonly latitude: number;
    readonly longitude: number;
    readonly name: string | null;
  } | null;
  readonly reaction: { readonly emoji: string | null; readonly toWaMessageId: string } | null;
  /**
   * v1.140-social (D388, §10.177.2): the id of the reply button or list row the customer tapped (the language question's
   * `kabso_lang_ar` / `kabso_lang_en`), or a quick-reply button's payload; null otherwise.
   */
  readonly replyId: string | null;
}

export interface StatusUpdate {
  readonly kind: 'status';
  readonly phoneNumberId: string | null;
  readonly waMessageId: string;
  readonly status: 'SENT' | 'DELIVERED' | 'READ' | 'FAILED';
  readonly timestamp: Date;
  readonly errorCode: number | null;
  readonly errorTitle: string | null;
}

export type WebhookEvent = InboundMessage | StatusUpdate;

const obj = (v: unknown): Record<string, unknown> | null =>
  typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const str = (v: unknown, max = 4096): string | null =>
  typeof v === 'string' && v.length > 0 ? v.slice(0, max) : null;
const WAMID = /^[A-Za-z0-9._=:+/-]{1,160}$/;

/** Meta's seconds-since-epoch string, or `fallback` when missing or absurd. */
function timeOf(v: unknown, fallback: Date): Date {
  const n = typeof v === 'string' && /^[0-9]{1,12}$/.test(v) ? Number(v) : typeof v === 'number' ? v : NaN;
  if (!Number.isFinite(n) || n <= 0) return fallback;
  const d = new Date(n * 1000);
  return d.getUTCFullYear() < 2000 || d.getTime() > fallback.getTime() + 24 * 3600 * 1000 ? fallback : d;
}

function number(v: unknown): number | null {
  const n = typeof v === 'number' ? v : typeof v === 'string' ? Number(v) : NaN;
  return Number.isFinite(n) ? n : null;
}

const MEDIA_TYPES = {
  image: 'IMAGE',
  audio: 'AUDIO',
  video: 'VIDEO',
  document: 'DOCUMENT',
  sticker: 'STICKER',
} as const;

function messageOf(
  m: Record<string, unknown>,
  value: Record<string, unknown>,
  phoneNumberId: string | null,
  now: Date,
) {
  const waMessageId = str(m.id, 200);
  const phoneE164 = e164Of(m.from);
  if (!waMessageId || !WAMID.test(waMessageId) || !phoneE164) return null;
  const contacts = arr(value.contacts).map(obj);
  const contact = contacts.find((c) => c?.wa_id === m.from) ?? contacts[0] ?? null;
  const profileName = str(obj(contact?.profile)?.name, 200);
  const rawType = typeof m.type === 'string' ? m.type : '';
  let type: InboundType = 'UNSUPPORTED';
  let body: string | null = null;
  let media: InboundMessage['media'] = null;
  let location: InboundMessage['location'] = null;
  let reaction: InboundMessage['reaction'] = null;
  let replyId: string | null = null;
  if (rawType === 'text') {
    type = 'TEXT';
    body = str(obj(m.text)?.body);
  } else if (rawType in MEDIA_TYPES) {
    const o = obj(m[rawType]);
    const id = str(o?.id, 128);
    if (id) {
      type = MEDIA_TYPES[rawType as keyof typeof MEDIA_TYPES];
      body = str(o?.caption, 1024);
      media = { id, mime: str(o?.mime_type, 100), filename: str(o?.filename, 240), voice: o?.voice === true };
    }
  } else if (rawType === 'location') {
    const o = obj(m.location);
    const latitude = number(o?.latitude);
    const longitude = number(o?.longitude);
    if (latitude !== null && longitude !== null && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180) {
      type = 'LOCATION';
      location = { latitude, longitude, name: str(o?.name, 240) ?? str(o?.address, 240) };
    }
  } else if (rawType === 'reaction') {
    const o = obj(m.reaction);
    const to = str(o?.message_id, 200);
    if (to && WAMID.test(to)) {
      type = 'REACTION';
      // An empty emoji removes the reaction.
      reaction = { emoji: str(o?.emoji, 16), toWaMessageId: to };
    }
  } else if (rawType === 'contacts') {
    type = 'CONTACTS';
    const names = arr(m.contacts)
      .map((c) => str(obj(obj(c)?.name)?.formatted_name, 100))
      .filter((n): n is string => n !== null);
    body = names.length > 0 ? names.join(', ') : null;
  } else if (rawType === 'interactive') {
    type = 'INTERACTIVE';
    const o = obj(m.interactive);
    body = str(obj(o?.button_reply)?.title, 200) ?? str(obj(o?.list_reply)?.title, 200);
    replyId = str(obj(o?.button_reply)?.id, 256) ?? str(obj(o?.list_reply)?.id, 256);
  } else if (rawType === 'button') {
    type = 'INTERACTIVE';
    body = str(obj(m.button)?.text, 200);
    replyId = str(obj(m.button)?.payload, 256);
  }
  return {
    kind: 'message',
    phoneNumberId,
    waMessageId,
    phoneE164,
    waId: phoneE164.slice(1),
    profileName,
    timestamp: timeOf(m.timestamp, now),
    type,
    body,
    media,
    location,
    reaction,
    replyId,
  } satisfies InboundMessage;
}

const STATUSES = { sent: 'SENT', delivered: 'DELIVERED', read: 'READ', failed: 'FAILED' } as const;

function statusOf(s: Record<string, unknown>, phoneNumberId: string | null, now: Date): StatusUpdate | null {
  const waMessageId = str(s.id, 200);
  const status = typeof s.status === 'string' ? STATUSES[s.status as keyof typeof STATUSES] : undefined;
  if (!waMessageId || !WAMID.test(waMessageId) || !status) return null;
  const err = obj(arr(s.errors)[0]);
  const code = number(err?.code);
  return {
    kind: 'status',
    phoneNumberId,
    waMessageId,
    status,
    timestamp: timeOf(s.timestamp, now),
    errorCode: code !== null ? Math.trunc(code) : null,
    errorTitle: str(err?.title, 300) ?? str(err?.message, 300),
  };
}

/** Every message and status in a webhook body (other fields and objects are ignored). */
export function parseWebhook(body: unknown, now: Date): WebhookEvent[] {
  const root = obj(body);
  if (!root || root.object !== 'whatsapp_business_account') return [];
  const out: WebhookEvent[] = [];
  for (const entry of arr(root.entry)) {
    for (const change of arr(obj(entry)?.changes)) {
      const c = obj(change);
      if (c?.field !== 'messages') continue;
      const value = obj(c.value);
      if (!value) continue;
      const phoneNumberId = str(obj(value.metadata)?.phone_number_id, 40);
      for (const m of arr(value.messages)) {
        const o = obj(m);
        const parsed = o ? messageOf(o, value, phoneNumberId, now) : null;
        if (parsed) out.push(parsed);
      }
      for (const s of arr(value.statuses)) {
        const o = obj(s);
        const parsed = o ? statusOf(o, phoneNumberId, now) : null;
        if (parsed) out.push(parsed);
      }
    }
  }
  return out;
}

/** The status order: a late `delivered` never overwrites `read`; `failed` always wins. */
const STATUS_RANK = { SENT: 1, DELIVERED: 2, READ: 3, FAILED: 4 } as const;
export function statusAdvances(current: string, next: StatusUpdate['status']): boolean {
  if (current === 'FAILED') return false;
  const rank = STATUS_RANK[current as keyof typeof STATUS_RANK] ?? 0;
  return STATUS_RANK[next] > rank;
}

/** The inbox row's one-line preview (no media bytes, never a note). */
export function previewOf(type: string, body: string | null): string {
  const text = (body ?? '').replace(/\s+/g, ' ').trim();
  const label: Record<string, string> = {
    IMAGE: '📷',
    AUDIO: '🎤',
    VIDEO: '🎬',
    DOCUMENT: '📄',
    STICKER: '🙂',
    LOCATION: '📍',
    CONTACTS: '👤',
    TEMPLATE: '📋',
    UNSUPPORTED: '…',
  };
  const head = label[type];
  const line = head ? (text ? `${head} ${text}` : head) : text;
  return [...line].slice(0, 120).join('');
}

/** The template's body text with its {{n}} placeholders filled (what the conversation shows for a sent template). */
export function fillTemplate(text: string | null, params: readonly string[]): string | null {
  if (text === null) return null;
  return text.replace(/\{\{([0-9]{1,2})\}\}/g, (all, n: string) => params[Number(n) - 1] ?? all);
}
