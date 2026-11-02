import { z } from 'zod';
import type { ErrorDetail } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { normalizeContentText } from '../posts/content-text.js';
import { normalizeDisplayName, textHygieneIssue, type TextHygieneIssue } from '../users/display-name.js';
import { isCountryCode } from '../users/country.js';
import { trimHygiene } from '../users/text-hygiene.js';
import { LIVE_KINDS, LIVE_SCOPES, LIVE_TABS } from './live-cursor.js';
import { isSeatEmojiToken } from './live-seat-emoji.js';

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
export const LIVE_THEMES = [
  'classic',
  'ice-palace',
  'desert-night',
  'rose-garden',
  // The owner's seven room themes (2026-10-24), after the CP-011 ones.
  'sunset-sky',
  'moon-palace',
  'ocean-depths',
  'golden-hall',
  'game-arena',
  'heart-garden',
  'galaxy',
  // v1.47-live (D212): the owner's podcast backgrounds (2026-10-31), the first the PODCAST default.
  'podcast-studio',
  'podcast-majlis',
  'podcast-library',
] as const;
export const DEFAULT_LIVE_THEME = LIVE_THEMES[0];
/** v1.47-live (D212): a PODCAST started without a theme gets the owner's studio background. */
export const DEFAULT_PODCAST_THEME = 'podcast-studio';

/**
 * Allowed `seatCount` per mode for a start or a change, host tile included (owner D94; AUDIO owner
 * D103, D123: 25 removed). A room already LIVE with 25 keeps it until it ends (seats 1 … 24 keep
 * working: {@link MAX_SEAT_INDEX}; the database CHECK still admits 25).
 */
export const LIVE_SEAT_COUNTS = { MULTI: [4, 6, 9, 12], AUDIO: [5, 10, 15, 20] } as const;
export type SeatedMode = keyof typeof LIVE_SEAT_COUNTS;

/** Seat indexes 1 … 24 (the host is 0; a room started with 25 tiles before D123 has 24 seats). */
export const MAX_SEAT_INDEX = 24;

export function isSeatedMode(mode: string): mode is SeatedMode {
  return mode === 'MULTI' || mode === 'AUDIO';
}

/**
 * v1.40-live (D174, owner: «نعم بالطبع» — viewers join a solo live as guests; PK design: at most 3):
 * a SOLO live has 3 guest seats (1 … 3) besides the host's, with the CP-011 seat flow. Its
 * `seat_count` stays null; this is its fixed count, host tile included.
 */
export const SOLO_SEAT_COUNT = 4;

/**
 * The modes whose rooms have guest seats: MULTI and AUDIO (their own count), SOLO (D174) and
 * PODCAST (v1.47-live, D212: the host and 3 speakers).
 */
export type GuestSeatMode = SeatedMode | 'SOLO' | 'PODCAST';

export function hasGuestSeats(mode: string): mode is GuestSeatMode {
  return isSeatedMode(mode) || mode === 'SOLO' || mode === 'PODCAST';
}

/** The seat count of a room with guest seats (SOLO: {@link SOLO_SEAT_COUNT}; PODCAST: {@link PODCAST_SEAT_COUNT}). */
export function guestSeatCount(mode: GuestSeatMode, seatCount: number | null): number {
  if (mode === 'SOLO') return SOLO_SEAT_COUNT;
  if (mode === 'PODCAST') return PODCAST_SEAT_COUNT;
  return seatCount ?? 0;
}

/** v1.47-live (D212): voice-only modes (no camera for anyone): AUDIO rooms and PODCAST episodes. */
export function isVoiceMode(mode: string): boolean {
  return mode === 'AUDIO' || mode === 'PODCAST';
}

// ---- v1.47-live (D212, CONVENTIONS §10.69): podcast episodes ---------------------------------

/** Owner D212: at most 4 speakers — the host and up to 3 guests (stored as `seat_count` 4). */
export const PODCAST_SEAT_COUNT = 4;

/** The topic chips of the podcast setup, in display order (owner D212); `other` last. */
export const PODCAST_TOPICS = [
  'business',
  'tech',
  'sports',
  'religion',
  'society',
  'entertainment',
  'other',
] as const;
export type PodcastTopic = (typeof PODCAST_TOPICS)[number];

/** A question's speaking time in seconds (owner D212: 1, 2, 3 or 5 minutes; null = no limit). */
export const PODCAST_QUESTION_SECONDS = [60, 120, 180, 300] as const;
/** Owner D212: 2 minutes by default. */
export const DEFAULT_PODCAST_QUESTION_SECONDS = 120;
/** A raised hand's optional question: 1–80 code points (the chat text rules, §10.11). */
export const PODCAST_QUESTION_MAX_CODE_POINTS = 80;

const questionSecondsSchema = z
  .number()
  .int()
  .refine((v) => (PODCAST_QUESTION_SECONDS as readonly number[]).includes(v), {
    params: { issue: 'invalid_value' },
  })
  .nullable();

/** `PodcastSetup` of `StartLiveRoomRequest` (required with mode PODCAST, refused otherwise). */
const podcastSetupSchema = z.strictObject({
  topic: z.enum(PODCAST_TOPICS),
  /** Default true: listeners may raise a hand. */
  questionsOpen: z.boolean().optional(),
  /** Default {@link DEFAULT_PODCAST_QUESTION_SECONDS}; null = no limit. */
  questionSeconds: questionSecondsSchema.optional(),
});

// ---- v1.56-live (D213, CONVENTIONS §10.86): streamer lives ------------------------------------

/** The screen picture's orientation (it follows the host's screen). */
export const STREAMER_ORIENTATIONS = ['PORTRAIT', 'LANDSCAPE'] as const;
export type StreamerOrientation = (typeof STREAMER_ORIENTATIONS)[number];

/**
 * The camera bubble's corner of the screen picture. Physical corners (the screen picture is never
 * mirrored for a right-to-left language), so every viewer sees it where the host put it.
 */
export const STREAMER_CORNERS = ['TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'] as const;
export type StreamerCorner = (typeof STREAMER_CORNERS)[number];

/**
 * v1.57-live (D247, CONVENTIONS §10.88): the main picture. `SCREEN` = the screen track with the camera as the
 * bubble (D213); `CAMERA` = the camera track alone (a browser studio's OBS Virtual Camera holds the whole scene).
 */
export const STREAMER_MAINS = ['SCREEN', 'CAMERA'] as const;
export type StreamerMain = (typeof STREAMER_MAINS)[number];

/** A STREAMER started without a choice: portrait, the bubble shown at the top left, the screen as the picture. */
export const DEFAULT_STREAMER_CORNER: StreamerCorner = 'TOP_LEFT';

const cameraOverlaySchema = z.strictObject({
  visible: z.boolean().optional(),
  corner: z.enum(STREAMER_CORNERS).optional(),
});

/** `StreamerSetup` of `StartLiveRoomRequest` (optional with mode STREAMER, refused otherwise). */
const streamerSetupSchema = z.strictObject({
  orientation: z.enum(STREAMER_ORIENTATIONS).optional(),
  cameraOverlay: cameraOverlaySchema.optional(),
  /** v1.57-live (D247): `SCREEN` (default) or `CAMERA`. */
  main: z.enum(STREAMER_MAINS).optional(),
});

/**
 * `UpdateLiveStreamerRequest` (`PUT /live/rooms/{roomId}/streamer`): at least one field; a
 * `cameraOverlay` with neither key is refused too.
 */
export const updateLiveStreamerSchema = streamerSetupSchema.superRefine((input, ctx) => {
  if (input.orientation === undefined && input.cameraOverlay === undefined && input.main === undefined) {
    ctx.addIssue({ code: 'custom', path: [], params: { issue: 'too_few' } });
  }
  if (
    input.cameraOverlay !== undefined &&
    input.cameraOverlay.visible === undefined &&
    input.cameraOverlay.corner === undefined
  ) {
    ctx.addIssue({ code: 'custom', path: ['cameraOverlay'], params: { issue: 'too_few' } });
  }
});
export type UpdateLiveStreamerInput = z.output<typeof updateLiveStreamerSchema>;

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

/** A seat index in a body: an integer 1 … 24 (a seat beyond the room's count is a 409, not a 400). */
const seatIndexSchema = z.number().int().min(1).max(MAX_SEAT_INDEX);

/** v1.27.3-live (D136, §10.29): the host's wish list holds at most this many gifts. */
export const MAX_WISH_GIFTS = 4;

/**
 * v1.27.3-live (D136): the host's wish list — up to 4 distinct gift codes, in display order
 * (`[]` empties it). Whether each gift exists and can be sent now is checked by the service (400
 * `wishGifts` / `invalid_value`).
 */
export const wishGiftsSchema = z
  .array(z.string().regex(/^[a-z0-9][a-z0-9_]{0,39}$/))
  .max(MAX_WISH_GIFTS)
  .superRefine((codes, ctx) => {
    if (new Set(codes).size !== codes.length) {
      ctx.addIssue({ code: 'custom', path: [], params: { issue: 'invalid_value' } });
    }
  });

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
    mode: z.enum(['SOLO', 'MULTI', 'AUDIO', 'PODCAST', 'STREAMER']).optional(),
    seatCount: seatCountSchema.optional(),
    /** v1.47-live (D212): the episode's topic and question settings (PODCAST only). */
    podcast: podcastSetupSchema.optional(),
    /** v1.56-live (D213): the screen's orientation and the camera bubble (STREAMER only). */
    streamer: streamerSetupSchema.optional(),
    theme: themeSchema.optional(),
    /** v1.27.3-live (D136): the wish list; absent → the host's last live's list. */
    wishGifts: wishGiftsSchema.optional(),
  })
  .superRefine((input, ctx) => {
    const mode = input.mode ?? 'SOLO';
    // A count outside the enum is already reported by the field itself.
    if (mode !== 'PODCAST' && input.podcast !== undefined) {
      ctx.addIssue({ code: 'custom', path: ['podcast'], params: { issue: 'invalid_value' } });
    }
    if (mode === 'PODCAST' && input.podcast === undefined) {
      ctx.addIssue({ code: 'custom', path: ['podcast'], params: { issue: 'required' } });
    }
    if (mode !== 'STREAMER' && input.streamer !== undefined) {
      ctx.addIssue({ code: 'custom', path: ['streamer'], params: { issue: 'invalid_value' } });
    }
    if (input.seatCount !== undefined && !ALL_SEAT_COUNTS.includes(input.seatCount)) return;
    if (mode === 'SOLO' || mode === 'PODCAST' || mode === 'STREAMER') {
      if (input.seatCount !== undefined) {
        ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'invalid_value' } });
      }
    } else if (input.seatCount === undefined) {
      ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'required' } });
    } else if (!seatCountFits(mode, input.seatCount)) {
      ctx.addIssue({ code: 'custom', path: ['seatCount'], params: { issue: 'invalid_value' } });
    }
  });

// ---- CP-014 (D97): the live's topic ---------------------------------------------------------

/** Line breaks are refused (CONVENTIONS §10.11, §10.12): LF, CR, LINE SEPARATOR, PARAGRAPH SEPARATOR. */
const LINE_BREAK = /[\n\r\u2028\u2029]/u;

/** 0–100 code points (CONVENTIONS §10.12). */
export const LIVE_TOPIC_MAX_CODE_POINTS = 100;

export type LiveTopicIssue = 'too_long' | 'invalid_format';

/**
 * A live's topic (CONVENTIONS §10.12): NFC, trimmed (spaces and U+FEFF, §6 rule 4); empty → null
 * (no topic); a line break → `invalid_format`; over 100 code points → `too_long`; then the §6
 * hygiene rules shared with comments and chat (rejected code points, misplaced joiners, the zalgo
 * cap) → `invalid_format`.
 */
export function normalizeLiveTopic(raw: string): { value: string | null } | { issue: LiveTopicIssue } {
  const value = trimHygiene(raw.normalize('NFC'));
  if (value.length === 0) return { value: null };
  if (LINE_BREAK.test(value)) return { issue: 'invalid_format' };
  if ([...value].length > LIVE_TOPIC_MAX_CODE_POINTS) return { issue: 'too_long' };
  const result = normalizeContentText(value, {
    maxCodePoints: LIVE_TOPIC_MAX_CODE_POINTS,
    maxLineBreaks: 0,
    allowEmpty: true,
  });
  if ('issue' in result) return { issue: result.issue === 'too_short' ? 'invalid_format' : result.issue };
  return { value: result.value.length === 0 ? null : result.value };
}

/** `topic` of `UpdateLiveRoomRequest`: the raw text is bounded first, then normalized (null = none). */
export const liveTopicSchema = z
  .string()
  .max(LIVE_TOPIC_MAX_CODE_POINTS * 8)
  .nullable()
  .transform((raw, ctx): string | null => {
    if (raw === null) return null;
    const result = normalizeLiveTopic(raw);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

/**
 * `UpdateLiveRoomRequest` (CP-010; CP-011 adds `seatCount` and `theme`; CP-013 `chatEnabled`; CP-014
 * `title`, `categorySlug` and `topic`): at least one field. Whether
 * `seatCount` fits the room's mode is checked against the room (400 `seatCount` / `invalid_value`).
 */
export const updateLiveRoomSchema = z
  .strictObject({
    /** CP-014: the go-live title rules (§10.3). */
    title: liveTitleSchema.optional(),
    /** CP-014: an active category (checked against `live_categories` by the service), or null for none. */
    categorySlug: categorySlugSchema.nullable().optional(),
    /** CP-014: the topic; null or "" (after trimming) removes it (normalized to null). */
    topic: liveTopicSchema.optional(),
    allowGuests: z.boolean().optional(),
    seatCount: seatCountSchema.optional(),
    theme: themeSchema.optional(),
    /** CP-013: the room chat on or off (host only). */
    chatEnabled: z.boolean().optional(),
    /** v1.27.3-live (D136): the host's wish list. */
    wishGifts: wishGiftsSchema.optional(),
    /** v1.47-live (D212): hands open or closed (PODCAST only; else 400 `invalid_value`). */
    questionsOpen: z.boolean().optional(),
    /** v1.47-live (D212): the question duration for hands accepted from now on (PODCAST only). */
    questionSeconds: questionSecondsSchema.optional(),
  })
  .superRefine((input, ctx) => {
    if (Object.keys(input).length === 0) {
      ctx.addIssue({ code: 'custom', path: [], params: { issue: 'too_few' } });
    }
  });
export type UpdateLiveRoomInput = z.output<typeof updateLiveRoomSchema>;

/** `LiveSeatRequestBody` (request a seat, accept a request). */
export const liveSeatRequestBodySchema = z.strictObject({ seatIndex: seatIndexSchema.optional() });

/**
 * v1.47-live (D212): `LiveSeatAskBody` — a seat request, which in a PODCAST is a raised hand that may
 * carry a short question (1–80 code points, the chat text rules; refused outside PODCAST by the service).
 */
export const liveSeatAskBodySchema = z.strictObject({
  seatIndex: seatIndexSchema.optional(),
  question: z
    .string()
    .max(PODCAST_QUESTION_MAX_CODE_POINTS * 8)
    .transform((raw, ctx) => {
      const result = normalizeLiveChatText(raw, PODCAST_QUESTION_MAX_CODE_POINTS);
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    })
    .optional(),
});

/** `LiveSeatInviteBody`; a malformed username is simply not found (404). */
export const liveSeatInviteBodySchema = z.strictObject({
  username: z.string().max(1000),
  seatIndex: seatIndexSchema.optional(),
});

/** `LiveKickRequest` (v1.20-live, D105); a malformed username is simply not found (404). */
export const liveKickBodySchema = z.strictObject({ username: z.string().max(1000) });

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

export type LiveChatTextIssue = 'required' | 'too_long' | 'invalid_format';

/**
 * A chat message's text (CONVENTIONS §10.11): NFC, trimmed (spaces and U+FEFF, §6 rule 4); empty
 * → `required`; a line break → `invalid_format`; over `max` code points (200; a bullet message
 * 60, CP-017) → `too_long`; then the §6 hygiene rules shared with comments (rejected code points,
 * misplaced joiners, the zalgo cap) → `invalid_format`.
 */
export function normalizeLiveChatText(
  raw: string,
  max: number = LIVE_CHAT_MAX_CODE_POINTS,
): { value: string } | { issue: LiveChatTextIssue } {
  const value = trimHygiene(raw.normalize('NFC'));
  if (value.length === 0) return { issue: 'required' };
  if (LINE_BREAK.test(value)) return { issue: 'invalid_format' };
  if ([...value].length > max) return { issue: 'too_long' };
  const result = normalizeContentText(value, {
    maxCodePoints: max,
    maxLineBreaks: 0,
    allowEmpty: false,
  });
  if ('issue' in result) return { issue: result.issue === 'too_short' ? 'required' : result.issue };
  return { value: result.value };
}

/** A text field of at most `max` code points: bounded first (no unbounded work), then normalized. */
function chatTextSchema(max: number) {
  return z
    .string()
    .max(max * 8)
    .transform((raw, ctx) => {
      const result = normalizeLiveChatText(raw, max);
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    });
}

/** CP-017 (D104): what a chat message carries. */
export const LIVE_CHAT_KINDS = ['TEXT', 'VOICE', 'IMAGE'] as const;
export type LiveChatKind = (typeof LIVE_CHAT_KINDS)[number];

/**
 * The fields of `LiveChatSendRequest`, each checked on its own; which of `text` / `mediaId` is
 * required depends on `kind` ({@link parseLiveChatSend}).
 */
const liveChatSendFieldsSchema = z.strictObject({
  kind: z.enum(LIVE_CHAT_KINDS).optional(),
  text: chatTextSchema(LIVE_CHAT_MAX_CODE_POINTS).optional(),
  mediaId: z.uuid().optional(),
  clientId: z.uuid(),
});

export type LiveChatSendInput =
  | { readonly kind: 'TEXT'; readonly text: string; readonly clientId: string }
  | { readonly kind: 'VOICE' | 'IMAGE'; readonly mediaId: string; readonly clientId: string };

const SEND_FIELD_ORDER = ['kind', 'text', 'mediaId', 'clientId'];

/**
 * `LiveChatSendRequest` (CONVENTIONS §10.11; CP-017 kinds): `kind` defaults to TEXT. TEXT needs
 * `text` and takes no `mediaId`; VOICE and IMAGE need `mediaId` (the caller's `LIVE_CHAT_VOICE` /
 * `LIVE_CHAT_IMAGE` asset) and take no `text`. A missing field → `required`, a field the kind does
 * not take → `invalid_value`; details are in field order.
 */
export function parseLiveChatSend(
  body: unknown,
): { success: true; data: LiveChatSendInput } | { success: false; details: ErrorDetail[] } {
  const parsed = liveChatSendFieldsSchema.safeParse(body ?? {}, { reportInput: true });
  const details: ErrorDetail[] = parsed.success ? [] : zodErrorToDetails(parsed.error);
  const raw = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
  const kind: LiveChatKind | null =
    raw.kind === undefined
      ? 'TEXT'
      : (LIVE_CHAT_KINDS as readonly unknown[]).includes(raw.kind)
        ? (raw.kind as LiveChatKind)
        : null;
  const add = (field: string, issue: string) => {
    if (!details.some((d) => d.field === field)) details.push({ field, issue });
  };
  if (kind === 'TEXT') {
    if (raw.text === undefined) add('text', 'required');
    if (raw.mediaId !== undefined) add('mediaId', 'invalid_value');
  } else if (kind !== null) {
    if (raw.mediaId === undefined) add('mediaId', 'required');
    if (raw.text !== undefined) add('text', 'invalid_value');
  }
  if (details.length > 0 || !parsed.success) {
    const rank = (field: string) => {
      const i = SEND_FIELD_ORDER.indexOf(field);
      return i < 0 ? SEND_FIELD_ORDER.length : i;
    };
    return { success: false, details: [...details].sort((a, b) => rank(a.field) - rank(b.field)) };
  }
  const { text, mediaId, clientId } = parsed.data;
  return kind === 'TEXT'
    ? { success: true, data: { kind, text: text!, clientId } }
    : { success: true, data: { kind: kind!, mediaId: mediaId!, clientId } };
}

// ---- CP-017 (D104): bullet messages ---------------------------------------------------------

/** 1–60 code points (owner D104). */
export const LIVE_BULLET_MAX_CODE_POINTS = 60;

/** `LiveBulletSendRequest`: the chat text rules with at most 60 code points. */
export const liveBulletSendSchema = z.strictObject({
  text: chatTextSchema(LIVE_BULLET_MAX_CODE_POINTS),
  clientId: z.uuid(),
});
export type LiveBulletSendInput = z.output<typeof liveBulletSendSchema>;

// ---- v1.23-live (CP-020, D108): live gifts ------------------------------------------------------

/** At most this many recipients per send (the host and 24 seats, §10.9). */
export const LIVE_GIFT_RECIPIENTS_MAX = 25;

/**
 * `LiveGiftSendRequest` (strict): `quantity` must be one of `quantities` (LIVE_GIFT_QUANTITIES; else
 * `invalid_value`); `recipients` are 1 … 25 distinct usernames (a malformed one is simply not
 * found later: 409 LIVE_GIFT_RECIPIENT_UNAVAILABLE); `source` COINS or BAG.
 */
export function liveGiftSendSchema(quantities: readonly number[]) {
  return z.strictObject({
    giftCode: z.string().min(1).max(40),
    quantity: z
      .number()
      .int()
      .refine((q) => quantities.includes(q), {
        message: 'not an allowed quantity',
        params: { issue: 'invalid_value' },
      }),
    recipients: z
      .array(z.string().min(1).max(64))
      .min(1)
      .max(LIVE_GIFT_RECIPIENTS_MAX)
      .refine((names) => new Set(names.map((n) => n.toLowerCase())).size === names.length, {
        message: 'recipients must be distinct',
        params: { issue: 'invalid_value' },
      }),
    // string first, so a missing source reports `required` (a bare enum reports `invalid_value`).
    source: z.string().pipe(z.enum(['COINS', 'BAG'])),
    clientId: z.uuid(),
  });
}
export type LiveGiftSendInput = z.output<ReturnType<typeof liveGiftSendSchema>>;

// ---- v1.27.5-live (D138): an emoji on one's own seat ----------------------------------------

/**
 * `LiveSeatEmojiRequest` (strict): `token` is `:<pack>_<id>:` of one of the owner's packs
 * (`live-seat-emoji.ts`); a string that is not one → `invalid_value`.
 */
export const liveSeatEmojiSchema = z.strictObject({
  token: z
    .string()
    .refine((t) => isSeatEmojiToken(t), { message: 'not a known emoji', params: { issue: 'invalid_value' } }),
});
export type LiveSeatEmojiInput = z.output<typeof liveSeatEmojiSchema>;

// ---- v1.32-live (D154): the soundboard of the host and moderators --------------------------

/** `LiveSoundRequest` (strict): `soundCode` names a free quip of the catalogue (checked by the service). */
export const liveSoundSchema = z.strictObject({
  soundCode: z.string().regex(/^[a-z0-9][a-z0-9_]{0,39}$/, { message: 'not a gift code' }),
});
export type LiveSoundInput = z.output<typeof liveSoundSchema>;

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
  // v1.26.4-live (D129): `audio` = AUDIO rooms, `video` = SOLO, PK and MULTI; absent = all.
  // v1.27.1-live (D133): `solo` = SOLO and PK, `multi` = MULTI, `party` = AUDIO and MULTI.
  // v1.47-live (D212): `podcast` = PODCAST (the hub's «بث بودكاست» tab).
  kind: z.enum(LIVE_KINDS).optional(),
  // v1.27.1-live (D133): rooms of the caller's country; rooms of featured hosts.
  scope: z.enum(LIVE_SCOPES).optional(),
  // v1.53-live (D240): rooms whose host's country is this ISO 3166-1 alpha-2 code (any case; the
  // viewer's own choice of «القريبة»). Wins over `scope=nearby`'s own country; needs no token.
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((v) => v.toUpperCase())
    .refine(isCountryCode, { params: { issue: 'invalid_value' } })
    .optional(),
  featured: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => (v === undefined ? undefined : v === 'true')),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type ListLiveRoomsQuery = z.output<typeof listLiveRoomsQuerySchema>;

const UUID_ANY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Path ids that are not UUIDs are treated as not found (404), never 400. */
export function isUuid(value: string): boolean {
  return UUID_ANY.test(value);
}

/**
 * v1.42-live (D170, CONVENTIONS §10.44): `POST /live/rooms/{roomId}/host-presence` — the host's app
 * went to the background (camera off) or came back.
 */
export const hostPresenceSchema = z.object({ away: z.boolean() }).strict();
