import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { Prisma } from '../../generated/prisma/client.js';

/**
 * Signed keyset cursors for `GET /live/rooms` (CONVENTIONS §5, §10.4).
 *
 * Format: `base64url(JSON payload) "." base64url(HMAC-SHA-256 tag truncated to 128 bits)`.
 * The payload holds a format version, the tab, the category filter, the caller's user id (for
 * `following` only) and the sort key of the last row returned (v3, v1.86-live / D310: the room's `cherries`,
 * `startedAt`, `id`; v2 carried the score and v1 `viewerCount`; both are rejected like any unknown version). Nothing in it is secret; the tag
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
export const LIVE_KINDS = [
  'audio',
  'video',
  'solo',
  'multi',
  'party',
  'podcast',
  'streamer',
  'party_all',
] as const;
export type LiveKind = (typeof LIVE_KINDS)[number];

/**
 * What a kind lists: a room mode, except that a PODCAST is split by `live_rooms.podcast_video` (D363, §10.157) into
 * an audio podcast (`PODCAST_AUDIO`) and a live video podcast (`PODCAST_VIDEO`).
 */
export type LiveKindMember = 'SOLO' | 'PK' | 'AUDIO' | 'PODCAST_AUDIO' | 'PODCAST_VIDEO' | 'STREAMER';

/**
 * v1.27.1-live (D133): `solo` = SOLO and PK, `multi` = MULTI, `party` = AUDIO and MULTI.
 * v1.47-live (D212, §10.69): `podcast` = PODCAST. A podcast is in no other kind (the hub's five
 * category tabs are `solo`, `audio`, `podcast`, `multi` and the streamer tab of D213), so `audio`
 * stays AUDIO rooms only.
 * v1.56-live (D213, §10.86): `streamer` = STREAMER; a streamer is a video live, so `video` and
 * `solo` (the main hub, D239) list it too.
 * v1.107-live (D342, §10.141): `party_all` = AUDIO, PODCAST and MULTI — the party page's one mixed list (the owner
 * removed its three kind tabs); the only kind besides `podcast` that lists a podcast. `party` keeps its meaning.
 * v1.115-live (D368, §10.161): a live VIDEO podcast is a camera live of the main hub — `video` and `solo` list it,
 * `party_all` lists only the audio podcasts; `podcast` keeps every podcast (older apps).
 * v1.116-live (D369, §10.162): MULTI is retired — no kind lists it (`multi` stays valid and lists nothing, `party` =
 * AUDIO), and neither does the list without a kind ({@link LIVE_LISTED_MEMBERS}).
 */
export const LIVE_KIND_MEMBERS: Readonly<Record<LiveKind, readonly LiveKindMember[]>> = {
  podcast: ['PODCAST_AUDIO', 'PODCAST_VIDEO'],
  audio: ['AUDIO'],
  video: ['SOLO', 'PK', 'STREAMER', 'PODCAST_VIDEO'],
  solo: ['SOLO', 'PK', 'STREAMER', 'PODCAST_VIDEO'],
  streamer: ['STREAMER'],
  multi: [],
  party: ['AUDIO'],
  party_all: ['AUDIO', 'PODCAST_AUDIO'],
};

/** v1.116-live (D369): what the list without a kind returns — every member (a MULTI room is never listed). */
export const LIVE_LISTED_MEMBERS: readonly LiveKindMember[] = [
  'SOLO',
  'PK',
  'AUDIO',
  'PODCAST_AUDIO',
  'PODCAST_VIDEO',
  'STREAMER',
];

function memberSql(member: LiveKindMember, alias: string): Prisma.Sql {
  const mode = Prisma.raw(`${alias}.mode`);
  const video = Prisma.raw(`${alias}.podcast_video`);
  switch (member) {
    case 'PODCAST_AUDIO':
      return Prisma.sql`(${mode} = 'PODCAST'::live_room_mode AND NOT ${video})`;
    case 'PODCAST_VIDEO':
      return Prisma.sql`(${mode} = 'PODCAST'::live_room_mode AND ${video})`;
    default:
      return Prisma.sql`${mode} = ${member}::live_room_mode`;
  }
}

/**
 * v1.115-live / v1.116-live (D368, D369): the `WHERE` condition of a kind (absent: the list without a kind) on the room alias
 * `alias`. `multi` lists nothing (`FALSE`).
 */
export function liveKindSql(kind: LiveKind | undefined, alias = 'r'): Prisma.Sql {
  const members = kind === undefined ? LIVE_LISTED_MEMBERS : LIVE_KIND_MEMBERS[kind];
  if (members.length === 0) return Prisma.sql`FALSE`;
  return Prisma.sql`(${Prisma.join(
    members.map((m) => memberSql(m, alias)),
    ' OR ',
  )})`;
}

/** v1.27.1-live (D133): the only `scope`. */
export const LIVE_SCOPES = ['nearby'] as const;
export type LiveScope = (typeof LIVE_SCOPES)[number];

/** The largest feature rank (`live_featured_hosts_rank_range`). */
export const FEATURE_RANK_MAX = 1_000_000;

/**
 * v2 (CP-012, v1.8-live): `n` is the room's score (was the viewer count in v1). v3 (v1.86-live, D310, §10.116): `n` is
 * the room's cherries (the `popular` key); a v2 cursor is rejected like any unknown version (400 `cursor`), so an app
 * scrolling across the deploy reloads the list once instead of paging on the old key.
 */
export const CURSOR_VERSION = 3;
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
  /** The caller's id for `following` and `nearby` (personal lists); null for the public ones. */
  readonly userId: string | null;
  /** v1.27.1-live (D133): `nearby`'s country (the caller's), null without `scope=nearby`. */
  readonly nearbyCountry: string | null;
  /** v1.27.1-live (D133): `featured=true` (order by feature rank first). */
  readonly featured: boolean;
}

/** Sort key of the last row of a page (`score`, `startedAt`, `id`). */
export interface CursorPosition {
  /** The room's `popular` key — v3 (D310) its cherries (was its score in v2); carried for every tab. */
  readonly score: number;
  readonly startedAt: Date;
  readonly id: string;
  /** v1.27.1-live (D133): the row's feature rank (featured lists only). */
  readonly rank?: number;
  /**
   * v1.82-live (D295, §10.108): the 1 : 1 host / creator interleave of `popular` and `new` (and Nearby): each group's
   * own last position (null: none of that group taken yet) and the group of the last row taken. The service requires
   * it on those lists and refuses it elsewhere.
   */
  readonly merge?: CursorMerge;
}

/** v1.82-live (D295): a group's sort key (`score`, `startedAt`, `id`). */
export interface GroupPosition {
  readonly score: number;
  readonly startedAt: Date;
  readonly id: string;
}

export interface CursorMerge {
  readonly host: GroupPosition | null;
  readonly creator: GroupPosition | null;
  readonly last: 'H' | 'C';
}

const groupSchema = z
  .tuple([
    z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
    z
      .number()
      .int()
      .min(0)
      .max(Date.UTC(9999, 11, 31, 23, 59, 59, 999)),
    z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/),
  ])
  .nullable();

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
  sc: z
    .string()
    .regex(/^[A-Z]{2}$/)
    .optional(),
  f: z.number().int().min(0).max(FEATURE_RANK_MAX).optional(),
  u: z.string().regex(UUID).nullable(),
  n: z.number().int().min(0).max(CURSOR_MAX_SCORE),
  s: z.number().int().min(0).max(CURSOR_MAX_STARTED_AT_MS),
  i: z.string().regex(UUID),
  x: z.strictObject({ h: groupSchema, c: groupSchema, g: z.enum(['H', 'C']) }).optional(),
});

function groupOut(p: GroupPosition | null): [number, number, string] | null {
  return p === null ? null : [p.score, p.startedAt.getTime(), p.id.toLowerCase()];
}

function groupIn(t: readonly [number, number, string] | null): GroupPosition | null {
  return t === null ? null : { score: t[0], startedAt: new Date(t[1]), id: t[2] };
}

/** The scope a request maps to (`userId` is only bound for the personal `following` tab). */
export function cursorScope(
  tab: LiveTab,
  category: string | undefined,
  callerId: string,
  kind?: LiveKind,
  extra: { readonly nearbyCountry?: string | null; readonly featured?: boolean } = {},
): CursorScope {
  const nearbyCountry = extra.nearbyCountry ?? null;
  return {
    tab,
    category: category ?? null,
    kind: kind ?? null,
    userId: tab === 'following' || nearbyCountry !== null ? callerId : null,
    nearbyCountry,
    featured: extra.featured === true,
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
        // v1.27.1-live (D133): only with `scope=nearby` / `featured=true` (older cursors unchanged).
        ...(scope.nearbyCountry === null ? {} : { sc: scope.nearbyCountry }),
        ...(scope.featured ? { f: position.rank ?? 0 } : {}),
        u: scope.userId,
        n: position.score,
        s: position.startedAt.getTime(),
        i: position.id.toLowerCase(),
        // v1.82-live (D295): only on the interleaved lists (older cursors unchanged).
        ...(position.merge
          ? {
              x: {
                h: groupOut(position.merge.host),
                c: groupOut(position.merge.creator),
                g: position.merge.last,
              },
            }
          : {}),
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
    if (
      p.t !== scope.tab ||
      p.c !== scope.category ||
      (p.k ?? null) !== scope.kind ||
      (p.sc ?? null) !== scope.nearbyCountry ||
      (p.f !== undefined) !== scope.featured ||
      p.u !== scope.userId
    ) {
      return null;
    }
    return {
      score: p.n,
      startedAt: new Date(p.s),
      id: p.i,
      ...(p.f !== undefined ? { rank: p.f } : {}),
      ...(p.x ? { merge: { host: groupIn(p.x.h), creator: groupIn(p.x.c), last: p.x.g } } : {}),
    };
  }
}
