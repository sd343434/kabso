import { z } from 'zod';
import { limitSchema } from '../posts/posts.schemas.js';

/** D125: the orders of a follow list (`newest` = the D121 default). */
export const FOLLOW_LIST_ORDERS = ['newest', 'oldest'] as const;
export type FollowListOrder = (typeof FOLLOW_LIST_ORDERS)[number];

/**
 * `GET /users/{username}/followers|following` (v1.25.2-live, D121; v1.26.1-live, D125 adds `q`
 * and `order`): `q` keeps the accounts whose username or display name starts with it
 * (case-insensitive, trimmed, 1–30 characters); `order` is by the follow's time.
 */
export const followListQuerySchema = z.strictObject({
  q: z.string().trim().min(1).max(30).optional(),
  order: z
    .string()
    .pipe(z.enum(FOLLOW_LIST_ORDERS))
    .optional()
    .transform((v) => v ?? 'newest'),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FollowListQuery = z.output<typeof followListQuerySchema>;
