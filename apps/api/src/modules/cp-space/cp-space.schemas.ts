import { z } from 'zod';
import { normalizeLiveChatText } from '../live/live.schemas.js';
import { limitSchema } from '../posts/posts.schemas.js';
import { CP_CONFESSION_MAX_CODE_POINTS, CP_RANKING_PERIODS } from './cp-space.constants.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.24-live (strict objects). CONVENTIONS §10.24.

/** A confession's text: the live chat text rules (§10.11) with at most 200 code points. */
const confessionTextSchema = z
  .string()
  .max(CP_CONFESSION_MAX_CODE_POINTS * 8)
  .transform((raw, ctx) => {
    const result = normalizeLiveChatText(raw, CP_CONFESSION_MAX_CODE_POINTS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

/** `CpConfessionCreateRequest`. */
export const cpConfessionCreateSchema = z.strictObject({
  text: confessionTextSchema,
  clientId: z.uuid(),
});

/** A plain page (`cursor`, `limit` 1–50, default 20). */
export const cpPageQuerySchema = z.strictObject({
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type CpPageQuery = z.output<typeof cpPageQuerySchema>;

/** `GET /cp/rankings?period=WEEK|ALL` (default WEEK). */
export const cpRankingsQuerySchema = z.strictObject({
  period: z
    .enum(CP_RANKING_PERIODS)
    .optional()
    .transform((v) => v ?? 'WEEK'),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type CpRankingsQuery = z.output<typeof cpRankingsQuerySchema>;
