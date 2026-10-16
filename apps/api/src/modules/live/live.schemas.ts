import { z } from 'zod';
import { normalizeDisplayName, textHygieneIssue, type TextHygieneIssue } from '../users/display-name.js';
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

/** `StartLiveRoomRequest`: only SOLO rooms exist, so there is no `mode` (→ `unknown_field`). */
export const startLiveRoomSchema = z.strictObject({
  title: liveTitleSchema,
  categorySlug: categorySlugSchema.optional(),
});
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
