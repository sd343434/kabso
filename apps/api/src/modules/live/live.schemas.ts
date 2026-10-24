import { z } from 'zod';
import { normalizeContentText } from '../posts/content-text.js';
import { normalizeDisplayName, textHygieneIssue, type TextHygieneIssue } from '../users/display-name.js';
import { trimHygiene } from '../users/text-hygiene.js';
import { LIVE_TABS } from './live-cursor.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.3 (strict objects: unknown fields fail
// with `unknown_field`).

/** CONVENTIONS §10.3: 1–80 grapheme clusters and ≤ 160 code points after NFC + trim. */
export const LIVE_TITLE_MAX_GRAPHEMES = 80;
export const LIVE_TITLE_MAX_CODE_POINTS = 160;

/**
 * Validates a RAW live-room title with the displayName character-hygiene rules (CONVENTIONS
 * §10.3): same NFC + trim, control/bidi/zero-width bans, joiner placement, zalgo cap, at least one
 * letter/digit/RGI emoji. The reserved-term/brand, confusable and mixed-script rules do NOT apply
 * (a title is content, not an identity). A non-empty, whitespace-only title is `invalid_format`
 * (as for displayName, v1.2.4).
 */
export function liveTitleIssue(raw: string): TextHygieneIssue | null {
  const value = normalizeDisplayName(raw);
  if (raw.length > 0 && value.length === 0) return 'invalid_format';
  return textHygieneIssue(value, {
    maxGraphemes: LIVE_TITLE_MAX_GRAPHEMES,
    maxCodePoints: LIVE_TITLE_MAX_CODE_POINTS,
  });
}

export const CATEGORY_SLUG_PATTERN = /^[a-z0-9-]{2,32}$/;

export const categorySlugSchema = z.string().min(2).max(32).regex(CATEGORY_SLUG_PATTERN);

export const liveTitleSchema = z
  .string()
  .max(1000)
  .superRefine((raw, ctx) => {
    const issue = liveTitleIssue(raw);
    if (issue) ctx.addIssue({ code: 'custom', message: `title ${issue}`, params: { issue } });
  })
  .transform(normalizeDisplayName);

// ---- CP-011 (D94): modes, seat counts and themes ---------------------------------------------

/** Room themes the server accepts, in display order; the first is the default (§10.9). */
export const LIVE_THEMES = ['classic', 'ice-palace', 'desert-night', 'rose-garden'] as const;
export const DEFAULT_LIVE_THEME = LIVE_THEMES[0];

/** Allowed `seatCount` per mode, host tile included (owner D94). */
export const LIVE_SEAT_COUNTS = { MULTI: [4, 6, 9, 12], AUDIO: [5, 9, 13] } as const;
export type SeatedMode = keyof typeof LIVE_SEAT_COUNTS;

/** Seat indexes 1 … 12 (the host is 0; the largest room has 13 tiles). */
export const MAX_SEAT_INDEX = 12;

export function isSeatedMode(mode: string): mode is SeatedMode {
  return mode === 'MULTI' || mode === 'AUDIO';
}

/** True when `count` is an allowed seat count for `mode`. */
export function seatCountFits(mode: string, count: number): boolean {
  return isSeatedMode(mode) && (LIVE_SEAT_COUNTS[mode] as readonly number[]).includes(count);
}

const ALL_SEAT_COUNTS = [...new Set<number>([...LIVE_SEAT_COUNTS.MULTI, ...LIVE_SEAT_COUNTS.AUDIO])];

/** `LiveSeatCount`: an integer of the enum (else `invalid_value`). */
const seatCountSchema = z
  .number()
  .int()
  .refine((v) => ALL_SEAT_COUNTS.includes(v), { params: { issue: 'invalid_value' } });

/** `LiveThemeSlug`: the slug format (`invalid_format`) and one of {@link LIVE_THEMES} (`invalid_value`). */
const themeSchema = z
  .string()
  .regex(CATEGORY_SLUG_PATTERN)
  // A malformed slug is reported as `invalid_format` only.
  .refine((v) => !CATEGORY_SLUG_PATTERN.test(v) || (LIVE_THEMES as readonly string[]).includes(v), {
    params: { issue: 'invalid_value' },
  });

/** A seat index in a body: an integer 1 … 12 (a seat beyond the room's count is a 409, not a 400). */
const seatIndexSchema = z.number().int().min(1).max(MAX_SEAT_INDEX);

/**
 * `StartLiveRoomRequest`: CP-011 adds `mode` (SOLO default; PK cannot be started), `seatCount`
 * (required for MULTI and AUDIO with a count of that mode, forbidden for SOLO) and `theme`.
 */
export const startLiveRoomSchema = z
  .strictObject({
    title: liveTitleSchema,
    categorySlug: categorySlugSchema.optional(),
    /** CP-010: default true (owner D93). */
    allowGuests: z.boolean().optional(),
    mode: z.enum(['SOLO', 'MULTI', 'AUDIO']).optional(),
    seatCount: seatCountSchema.optional(),
    theme: themeSchema.optional(),
  })
  .superRefine((input, ctx) => {
    const mode = input.mode ?? 'SOLO';
    // A count outside the enum is already reported by the field itself.
    if (input.seatCount !== undefined && !ALL_SEAT_COUNTS.includes(input.seatCount)) return;
    if (mode === 'SOLO') {
      if (input.seatCount !== undefined) {
        ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'invalid_value' } });
      }
    } else if (input.seatCount === undefined) {
      ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'required' } });
    } else if (!seatCountFits(mode, input.seatCount)) {
      ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'invalid_value' } });
    }
  });

/**
 * `UpdateLiveRoomRequest` (CP-010; CP-011 adds `seatCount` and `theme`): at least one field. Whether
 * `seatCount` fits the room's mode is checked against the room (400 `seatCount` / `invalid_value`).
 */
export const updateLiveRoomSchema = z
  .strictObject({
    allowGuests: z.boolean().optional(),
    seatCount: seatCountSchema.optional(),
    theme: themeSchema.optional(),
    /** CP-013: the room chat on or off (host only). */
    chatEnabled: z.boolean().optional(),
  })
  .superRefine((input, ctx) => {
    if (Object.keys(input).length === 0) {
      ctx.addIssue({ code: 'custom', path: [], params: { issue: 'too_few' } });
    }
  });
export type UpdateLiveRoomInput = z.output<typeof updateLiveRoomSchema>;

/** `LiveSeatRequestBody` (request a seat, accept a request). */
export const liveSeatRequestBodySchema = z.strictObject({ seatIndex: seatIndexSchema.optional() });

/** `LiveSeatInviteBody`; a malformed username is simply not found (404). */
export const liveSeatInviteBodySchema = z.strictObject({
  username: z.string().max(1000),
  seatIndex: seatIndexSchema.optional(),
});

export const liveSeatMuteBodySchema = z.strictObject({ muted: z.boolean() });
export const liveSeatLockBodySchema = z.strictObject({ locked: z.boolean() });

/**
 * The `{seatIndex}` path segment as an integer, else null. Whether it is a seat of the room is
 * checked against the room (out of range or not an integer → 409 LIVE_SEAT_UNAVAILABLE).
 */
export function parseSeatIndexPath(raw: string): number | null {
  if (!/^\d{1,3}$/.test(raw)) return null;
  return Number(raw);
}

/** `LiveTapsRequest` (CP-012): the taps since the last batch, 1–50. */
export const liveTapsRequestSchema = z.strictObject({ count: z.number().int().min(1).max(50) });

// ---- CP-013 (D96): room chat ----------------------------------------------------------------

/** 1–200 code points (owner D96). */
export const LIVE_CHAT_MAX_CODE_POINTS = 200;
/** Line breaks are refused (CONVENTIONS §10.11): LF, CR, LINE SEPARATOR, PARAGRAPH SEPARATOR. */
const LINE_BREAK = /[\n\r\u2028\u2029]/u;

export type LiveChatTextIssue = 'required' | 'too_long' | 'invalid_format';

/**
 * A chat message's text (CONVENTIONS §10.11): NFC, trimmed (spaces and U+FEFF, §6 rule 4); empty
 * → `required`; a line break → `invalid_format`; over 200 code points → `too_long`; then the §6
 * hygiene rules shared with comments (rejected code points, misplaced joiners, the zalgo cap) →
 * `invalid_format`.
 */
export function normalizeLiveChatText(raw: string): { value: string } | { issue: LiveChatTextIssue } {
  const value = trimHygiene(raw.normalize('NFC'));
  if (value.length === 0) return { issue: 'required' };
  if (LINE_BREAK.test(value)) return { issue: 'invalid_format' };
  if ([...value].length > LIVE_CHAT_MAX_CODE_POINTS) return { issue: 'too_long' };
  const result = normalizeContentText(value, {
    maxCodePoints: LIVE_CHAT_MAX_CODE_POINTS,
    maxLineBreaks: 0,
    allowEmpty: false,
  });
  if ('issue' in result) return { issue: result.issue === 'too_short' ? 'required' : result.issue };
  return { value: result.value };
}

/** `LiveChatSendRequest`; the raw text is bounded first (no unbounded work), then normalized. */
export const liveChatSendSchema = z.strictObject({
  text: z
    .string()
    .max(LIVE_CHAT_MAX_CODE_POINTS * 8)
    .transform((raw, ctx) => {
      const result = normalizeLiveChatText(raw);
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    }),
  clientId: z.uuid(),
});
export type LiveChatSendInput = z.output<typeof liveChatSendSchema>;

/** `LiveMediaTokenRequest` (CP-010): `guestId` is required without a bearer token. */
export const liveMediaTokenSchema = z.strictObject({ guestId: z.uuid().optional() });
export type StartLiveRoomInput = z.output<typeof startLiveRoomSchema>;

/** `limit`: integer 1–50, default 20 (CONVENTIONS §5). */
const limitSchema = z
  .string()
  .regex(/^\d{1,4}$/)
  .transform(Number)
  .pipe(z.number().int().min(1).max(50));

export const listLiveRoomsQuerySchema = z.strictObject({
  // string first, so a missing tab reports `required` (a bare enum reports `invalid_value`).
  tab: z.string().pipe(z.enum(LIVE_TABS)),
  category: categorySlugSchema.optional(),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type ListLiveRoomsQuery = z.output<typeof listLiveRoomsQuerySchema>;

const UUID_ANY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Path ids that are not UUIDs are treated as not found (404), never 400. */
export function isUuid(value: string): boolean {
  return UUID_ANY.test(value);
}
