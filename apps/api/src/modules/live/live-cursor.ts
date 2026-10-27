import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';

/**
 * Signed keyset cursors for `GET /live/rooms` (CONVENTIONS §5, §10.4).
 *
 * Format: `base64url(JSON payload) "." base64url(HMAC-SHA-256 tag truncated to 128 bits)`.
 * The payload holds a format version, the tab, the category filter, the caller's user id (for
 * `following` only) and the sort key of the last row returned (v2, CP-012 / v1.8-live: `score`,
 * `startedAt`, `id`; v1 carried `viewerCount` and is rejected like any unknown version). Nothing in it is secret; the tag
 * only stops crafted cursors from turning into arbitrary keyset queries. A cursor that does not
 * decode, fails the tag, has an unknown version or was issued for another tab, category or
 * caller is rejected (the caller maps that to 400 `cursor` / `invalid_value`).
 */
export const LIVE_TABS = ['popular', 'new', 'following'] as const;
export type LiveTab = (typeof LIVE_TABS)[number];

/**
 * v1.26.4-live (D129): the hub's room kind filter. `audio` = `AUDIO` rooms (voice rooms; podcasts
 * are voice rooms), `video` = `SOLO`, `PK` and `MULTI`. A cursor is bound to it like to the
 * category; a cursor issued without a kind carries no `k` (cursors of older apps stay valid).
 */
export const LIVE_KINDS = ['audio', 'video'] as const;
export type LiveKind = (typeof LIVE_KINDS)[number];

/** v2 (CP-012, v1.8-live): `n` is the room's score (was the viewer count in v1). */
export const CURSOR_VERSION = 2;
const TAG_BYTES = 16;
const TAG_CHARS = 22; // base64url of 16 bytes, no padding
const MAX_CURSOR_CHARS = 512;
const BASE64URL = /^[A-Za-z0-9_-]+$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** What a cursor is bound to: the request parameters it was issued for. */
export interface CursorScope {
  readonly tab: LiveTab;
  readonly category: string | null;
  /** v1.26.4-live (D129): the kind filter; null = all rooms. */
  readonly kind: LiveKind | null;
  /** The caller's id for `following` (personal list); null for the public tabs. */
  readonly userId: string | null;
}

/** Sort key of the last row of a page (`score`, `startedAt`, `id`). */
export interface CursorPosition {
  /** The room's score (`popular` orders by it; carried for every tab). */
  readonly score: number;
  readonly startedAt: Date;
  readonly id: string;
}

/**
 * SEC-038: every sort key must be a value the keyset query can bind without a database error,
 * even in a validly signed payload. `n` is a PostgreSQL `int8` (`score`) that JavaScript represents
 * exactly (at most `Number.MAX_SAFE_INTEGER`). `s` is epoch
 * milliseconds between 1970-01-01 and 9999-12-31T23:59:59.999Z, so `toISOString()` yields a
 * four-digit year that `timestamptz` accepts (larger JavaScript dates serialize as `+275760-…`).
 */
export const CURSOR_MAX_SCORE = Number.MAX_SAFE_INTEGER;
export const CURSOR_MAX_STARTED_AT_MS = Date.UTC(9999, 11, 31, 23, 59, 59, 999);

const payloadSchema = z.strictObject({
  v: z.number(),
  t: z.enum(LIVE_TABS),
  c: z.string().max(32).nullable(),
  k: z.enum(LIVE_KINDS).optional(),
  u: z.string().regex(UUID).nullable(),
  n: z.number().int().min(0).max(CURSOR_MAX_SCORE),
  s: z.number().int().min(0).max(CURSOR_MAX_STARTED_AT_MS),
  i: z.string().regex(UUID),
});

/** The scope a request maps to (`userId` is only bound for the personal `following` tab). */
export function cursorScope(
  tab: LiveTab,
  category: string | undefined,
  callerId: string,
  kind?: LiveKind,
): CursorScope {
  return {
    tab,
    category: category ?? null,
    kind: kind ?? null,
    userId: tab === 'following' ? callerId : null,
  };
}

export class LiveCursorCodec {
  private readonly key: Buffer;

  /** `keySource` is LIVE_CURSOR_KEY (or its non-production fallback); HKDF separates the use. */
  constructor(keySource: string) {
    this.key = Buffer.from(hkdfSync('sha256', keySource, 'kabso', 'live-cursor/v1', 32));
  }

  private tag(payload: string): Buffer {
    return createHmac('sha256', this.key)
      .update(`live-cursor\u0000${payload}`)
      .digest()
      .subarray(0, TAG_BYTES);
  }

  encode(scope: CursorScope, position: CursorPosition): string {
    const payload = Buffer.from(
      JSON.stringify({
        v: CURSOR_VERSION,
        t: scope.tab,
        c: scope.category,
        // Only with a kind, so a request without one gets the same cursor as before v1.26.4-live.
        ...(scope.kind === null ? {} : { k: scope.kind }),
        u: scope.userId,
        n: position.score,
        s: position.startedAt.getTime(),
        i: position.id.toLowerCase(),
      }),
      'utf8',
    ).toString('base64url');
    return `${payload}.${this.tag(payload).toString('base64url')}`;
  }

  /** The position encoded in `cursor`, or null when it is invalid for `scope`. */
  decode(cursor: string, scope: CursorScope): CursorPosition | null {
    if (cursor.length > MAX_CURSOR_CHARS) return null;
    const parts = cursor.split('.');
    if (parts.length !== 2) return null;
    const [payload = '', tagText = ''] = parts;
    if (!BASE64URL.test(payload) || tagText.length !== TAG_CHARS || !BASE64URL.test(tagText)) return null;
    // Compare the canonical text form, so non-canonical encodings of the same tag bytes (the
    // last base64url character carries 4 unused bits) are rejected too.
    const expected = Buffer.from(this.tag(payload).toString('base64url'), 'ascii');
    if (!timingSafeEqual(Buffer.from(tagText, 'ascii'), expected)) return null;

    let decoded: unknown;
    try {
      decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    } catch {
      return null;
    }
    const parsed = payloadSchema.safeParse(decoded);
    if (!parsed.success) return null;
    const p = parsed.data;
    if (p.v !== CURSOR_VERSION) return null;
    if (p.t !== scope.tab || p.c !== scope.category || (p.k ?? null) !== scope.kind || p.u !== scope.userId) {
      return null;
    }
    return { score: p.n, startedAt: new Date(p.s), id: p.i };
  }
}
