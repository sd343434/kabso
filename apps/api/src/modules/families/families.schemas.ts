import { z } from 'zod';
import { isUuid, normalizeLiveChatText } from '../live/live.schemas.js';
import { limitSchema } from '../posts/posts.schemas.js';
import {
  FAMILY_CHAT_MAX_CODE_POINTS,
  FAMILY_RANKING_BOARDS,
  FAMILY_TAGLINE_MAX_CODE_POINTS,
} from './families.constants.js';

const uuid = z.string().refine(isUuid, { message: 'invalid_value', params: { issue: 'invalid_value' } });

/** `CreateFamilyRequest` (strict). The name's text rules are checked by the service. */
export const createFamilySchema = z.strictObject({
  name: z.string().max(1000),
  emblemMediaId: uuid.nullable().optional(),
  clientId: uuid,
});
export type CreateFamilyInput = z.output<typeof createFamilySchema>;

/**
 * One line of the live chat text rules (§10.11) of at most `max` code points: bounded first (no
 * unbounded work), then normalized.
 */
function lineSchema(max: number) {
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

/** The tagline: one line of at most 60 code points; empty after trimming → null (removes it). */
const taglineSchema = z
  .string()
  .max(FAMILY_TAGLINE_MAX_CODE_POINTS * 8)
  .transform((raw, ctx): string | null => {
    if (raw.normalize('NFC').trim() === '') return null;
    const result = normalizeLiveChatText(raw, FAMILY_TAGLINE_MAX_CODE_POINTS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

/**
 * `UpdateFamilyRequest` (strict, at least one field): the leader changes or removes the emblem
 * and, since v1.25-live (CP-022), the cover and the tagline (`null` or `""` removes it).
 */
export const updateFamilySchema = z
  .strictObject({
    emblemMediaId: uuid.nullable().optional(),
    coverMediaId: uuid.nullable().optional(),
    tagline: taglineSchema.nullable().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'too_small', params: { issue: 'too_small' } });
export type UpdateFamilyInput = z.output<typeof updateFamilySchema>;

/** `SetFamilyRoleRequest`. */
export const setFamilyRoleSchema = z.strictObject({ role: z.enum(['DEPUTY', 'MEMBER']) });

/** `TransferFamilyRequest`. */
export const transferFamilySchema = z.strictObject({ username: z.string().min(1).max(64) });

/** `GET /families`: `q` a name (contains, case-insensitive) or a family number (digits only). */
export const familySearchQuerySchema = z.strictObject({
  q: z.string().trim().min(1).max(40).optional(),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FamilySearchQuery = z.output<typeof familySearchQuerySchema>;

/**
 * `GET /families/{familyId}/members` (v1.25-live adds `sort` and `q`): `ROLE` (default) = leader,
 * deputies, members by join time; `POINTS` = by the points each gave, highest first, with `rank`.
 * `q` keeps members whose username or display name contains it (case-insensitive).
 */
export const familyMembersQuerySchema = z.strictObject({
  sort: z
    .enum(['ROLE', 'POINTS'])
    .optional()
    .transform((v) => v ?? 'ROLE'),
  q: z.string().trim().min(1).max(40).optional(),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FamilyMembersQuery = z.output<typeof familyMembersQuerySchema>;

/** `GET /families/rankings` (v1.25-live): one board, paged (top 100). */
export const familyRankingsQuerySchema = z.strictObject({
  board: z
    .enum(FAMILY_RANKING_BOARDS)
    .optional()
    .transform((v) => v ?? 'PRESTIGE'),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FamilyRankingsQuery = z.output<typeof familyRankingsQuerySchema>;

/** `FamilyChatSendRequest` (v1.25-live, strict). */
export const familyChatSendSchema = z.strictObject({
  text: lineSchema(FAMILY_CHAT_MAX_CODE_POINTS),
  clientId: uuid,
});

/** `GET /families/{familyId}/chat`: newest first; `limit` 1–50, default 30. */
export const familyChatQuerySchema = z.strictObject({
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 30),
});
export type FamilyChatQuery = z.output<typeof familyChatQuerySchema>;
