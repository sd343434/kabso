import { z } from 'zod';

// Request schemas mirror docs/contracts/openapi.yaml v1.5-social, CP-009 (strict objects).

/** `MarkNotificationsReadRequest`: exactly one of `ids` (1–100 distinct) or `all: true`. */
export const markReadSchema = z.union([
  z.strictObject({
    ids: z
      .array(z.uuid())
      .min(1)
      .max(100)
      .refine((ids) => new Set(ids.map((i) => i.toLowerCase())).size === ids.length, {
        message: 'not_unique',
        params: { issue: 'invalid_value' },
      }),
  }),
  z.strictObject({ all: z.literal(true) }),
]);
export type MarkReadInput = z.output<typeof markReadSchema>;

/** `UpdateNotificationSettingsRequest` (at least one field). */
export const updateNotificationSettingsSchema = z
  .strictObject({
    likes: z.boolean().optional(),
    comments: z.boolean().optional(),
    mentions: z.boolean().optional(),
    follows: z.boolean().optional(),
    reposts: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'too_small', params: { issue: 'too_small' } });
