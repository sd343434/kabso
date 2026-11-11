import { z } from 'zod';

/**
 * `ContentGiftSendRequest` (v1.127-social, D372, CONVENTIONS §10.164): a catalogue gift on a post or reel — the live
 * send's fields without recipients (the post's author receives).
 */
export function contentGiftSendSchema(quantities: readonly number[]) {
  return z.strictObject({
    giftCode: z.string().min(1).max(40),
    quantity: z
      .number()
      .int()
      .refine((q) => quantities.includes(q), {
        message: 'not an allowed quantity',
        params: { issue: 'invalid_value' },
      }),
    source: z.string().pipe(z.enum(['COINS', 'BAG'])),
    clientId: z.uuid(),
  });
}
export type ContentGiftSendInput = z.output<ReturnType<typeof contentGiftSendSchema>>;
