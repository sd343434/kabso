import { z } from 'zod';
import { isSeatEmojiToken } from '../live/live-seat-emoji.js';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';
import { limitSchema } from '../posts/posts.schemas.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.40-social (D155, strict objects).
// CONVENTIONS §11.13.

/** A `TEXT` direct message: 1–1 000 code points, at most 20 line breaks, §6 hygiene. */
export const DM_TEXT_LIMITS: ContentTextLimits = {
  maxCodePoints: 1000,
  maxLineBreaks: 20,
  allowEmpty: false,
};

const dmTextSchema = z
  .string()
  .max(8000)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, DM_TEXT_LIMITS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

const recipientSchema = z.string().min(1).max(64);

/** `DmSendRequest`: the field of the kind is required, the others are refused. */
export const dmSendSchema = z
  .strictObject({
    to: recipientSchema,
    kind: z.string().pipe(z.enum(['TEXT', 'IMAGE', 'VOICE', 'EMOJI'])),
    text: dmTextSchema.optional(),
    mediaId: z.uuid().optional(),
    token: z.string().max(64).optional(),
    clientId: z.uuid(),
  })
  .superRefine((v, ctx) => {
    const need = v.kind === 'TEXT' ? 'text' : v.kind === 'EMOJI' ? 'token' : 'mediaId';
    for (const field of ['text', 'mediaId', 'token'] as const) {
      if (field === need) {
        if (v[field] === undefined)
          ctx.addIssue({ code: 'custom', path: [field], params: { issue: 'required' } });
      } else if (v[field] !== undefined) {
        ctx.addIssue({ code: 'custom', path: [field], params: { issue: 'unknown_field' } });
      }
    }
    if (v.kind === 'EMOJI' && v.token !== undefined && !isSeatEmojiToken(v.token)) {
      ctx.addIssue({ code: 'custom', path: ['token'], params: { issue: 'invalid_value' } });
    }
  });
export type DmSendInput = z.output<typeof dmSendSchema>;

/** `DmGiftSendRequest` (the quantity is checked against the catalogue's list). */
export function dmGiftSendSchema(quantities: readonly number[]) {
  return z.strictObject({
    to: recipientSchema,
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
export type DmGiftSendInput = z.output<ReturnType<typeof dmGiftSendSchema>>;

export const dmReadSchema = z.strictObject({ lastMessageId: z.uuid() });

export const dmConversationsQuerySchema = z.strictObject({
  box: z
    .string()
    .pipe(z.enum(['INBOX', 'REQUESTS']))
    .optional()
    .transform((v) => v ?? 'INBOX'),
  /** v1.43-social (D165): a prefix of the peer's username or display name (a leading `@` dropped). */
  q: z
    .string()
    .trim()
    .transform((v) => v.replace(/^@/, '').trim())
    .pipe(z.string().min(1).max(30))
    .optional(),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type DmConversationsQuery = z.output<typeof dmConversationsQuerySchema>;

export const dmMessagesQuerySchema = z.strictObject({
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 30),
});
export type DmMessagesQuery = z.output<typeof dmMessagesQuerySchema>;

export const dmDeleteMessageQuerySchema = z.strictObject({
  scope: z
    .string()
    .pipe(z.enum(['me', 'everyone']))
    .optional()
    .transform((v) => v ?? 'me'),
});
export type DmDeleteMessageQuery = z.output<typeof dmDeleteMessageQuerySchema>;
