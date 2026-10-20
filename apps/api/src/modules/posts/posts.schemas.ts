import { z } from 'zod';
import { normalizeContentText, type ContentTextLimits } from './content-text.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.5-social (strict objects: unknown fields
// fail with `unknown_field`). Text rules: CONVENTIONS §11.2.

export const POST_TEXT_LIMITS: ContentTextLimits = {
  maxCodePoints: 2200,
  maxLineBreaks: 30,
  allowEmpty: true,
};
export const LOCATION_LIMITS: ContentTextLimits = { maxCodePoints: 80, maxLineBreaks: 0, allowEmpty: false };
export const MAX_POST_MEDIA = 10;

/** Free content text: raw length is bounded first (no unbounded work), then normalized. */
const contentText = (limits: ContentTextLimits, rawMax: number) =>
  z
    .string()
    .max(rawMax)
    .transform((raw, ctx) => {
      const result = normalizeContentText(raw, limits);
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    });

export const postTextSchema = contentText(POST_TEXT_LIMITS, 8800);
export const locationSchema = contentText(LOCATION_LIMITS, 320).nullable();

export const WHO_CAN_COMMENT = ['EVERYONE', 'FOLLOWERS', 'NOBODY'] as const;

export const postSettingsPatchSchema = z
  .strictObject({
    commentsEnabled: z.boolean().optional(),
    whoCanComment: z.enum(WHO_CAN_COMMENT).optional(),
    hideLikeCount: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'too_small', params: { issue: 'too_small' } });

const statusSchema = z.enum(['DRAFT', 'SCHEDULED', 'PUBLISHED']);

/** `CreatePostRequest`. Cross-field rules (text or media, publishAt) are checked by the service. */
export const createPostSchema = z.strictObject({
  text: postTextSchema.optional(),
  mediaIds: z.array(z.uuid()).max(MAX_POST_MEDIA).optional(),
  location: locationSchema.optional(),
  status: statusSchema.optional(),
  publishAt: z.iso.datetime({ offset: true }).optional(),
  settings: postSettingsPatchSchema.optional(),
});
export type CreatePostInput = z.output<typeof createPostSchema>;

/** `UpdatePostRequest`: at least one field. */
export const updatePostSchema = z
  .strictObject({
    text: postTextSchema.optional(),
    location: locationSchema.optional(),
    status: statusSchema.optional(),
    publishAt: z.iso.datetime({ offset: true }).optional(),
    settings: postSettingsPatchSchema.optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'too_small', params: { issue: 'too_small' } });
export type UpdatePostInput = z.output<typeof updatePostSchema>;

/** `limit`: integer 1–50, default 20 (CONVENTIONS §5). */
export const limitSchema = z
  .string()
  .regex(/^\d{1,4}$/)
  .transform(Number)
  .pipe(z.number().int().min(1).max(50));

export const pageQuerySchema = z.strictObject({
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type PageQuery = z.output<typeof pageQuerySchema>;

export const myPostsQuerySchema = z.strictObject({
  status: z.string().pipe(z.enum(['DRAFT', 'SCHEDULED'])),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type MyPostsQuery = z.output<typeof myPostsQuerySchema>;

/** `RecordViewsRequest`: 1–50 items. */
export const recordViewsSchema = z.strictObject({
  items: z
    .array(
      z.strictObject({
        postId: z.uuid(),
        watchedMs: z.number().int().min(0).max(3_600_000),
      }),
    )
    .min(1)
    .max(50),
});

export const feedQuerySchema = z.strictObject({
  tab: z.string().pipe(z.enum(['following', 'trending'])),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FeedQuery = z.output<typeof feedQuerySchema>;
