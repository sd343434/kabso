import { z } from 'zod';
import { isUuid } from '../live/live.schemas.js';
import { limitSchema } from '../posts/posts.schemas.js';
import { CP_GIFT_AMOUNTS } from './couples.constants.js';

const uuid = z.string().refine(isUuid, { message: 'invalid_value', params: { issue: 'invalid_value' } });

/** `CpRequestSendRequest` (strict). */
export const cpRequestSendSchema = z.strictObject({
  username: z.string().min(1).max(64),
  clientId: uuid,
});

/** `CpGiftSendRequest` (strict): `amount` one of {@link CP_GIFT_AMOUNTS}. */
export const cpGiftSendSchema = z.strictObject({
  amount: z
    .number()
    .int()
    .refine((v) => CP_GIFT_AMOUNTS.includes(v), {
      message: 'invalid_value',
      params: { issue: 'invalid_value' },
    }),
  clientId: uuid,
});

/** `GET /cp/requests?direction=incoming|outgoing`. */
export const cpRequestListQuerySchema = z.strictObject({
  direction: z.enum(['incoming', 'outgoing']),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type CpRequestListQuery = z.output<typeof cpRequestListQuerySchema>;
