import { z } from 'zod';
import { STATUS_EMOJI_ID_MAX } from './status-emoji-catalogue.js';

/** v1.130-social (D376, CONVENTIONS §10.167): request bodies of «الحالة». */

/** `PUT /me/status`: an id of the allow-list (checked by the service), or null for «بدون حالة». */
export const setStatusEmojiBody = z.strictObject({
  statusEmojiId: z.string().min(1).max(STATUS_EMOJI_ID_MAX).nullable(),
});
export type SetStatusEmojiBody = z.output<typeof setStatusEmojiBody>;

/** `POST /status-packs/{packId}/purchases`. */
export const buyStatusPackBody = z.strictObject({
  days: z.number().int().min(1).max(365),
  /** The price the app showed (else 409 `STORE_PRICE_CHANGED`); the server charges its own table's price. */
  price: z.number().int().min(1).max(1_000_000_000_000),
});
export type BuyStatusPackBody = z.output<typeof buyStatusPackBody>;

/** `{packId}`: lower-case letters and digits. */
export const statusPackIdPath = z.string().regex(/^[a-z][a-z0-9]{0,23}$/);
