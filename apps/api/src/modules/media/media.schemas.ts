import { z } from 'zod';
import { MEDIA_CONTENT_TYPES, MEDIA_MAX_DECLARED_BYTES } from './media.constants.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.4 (strict objects).

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** `CreateMediaUploadRequest`. `byteSize` above the purpose limit is checked after parsing. */
export const createMediaUploadSchema = z.strictObject({
  // string first, so a missing value reports `required` (a bare enum reports `invalid_value`).
  purpose: z.string().pipe(z.enum(['avatar', 'room_cover'])),
  contentType: z
    .string()
    .pipe(z.enum(MEDIA_CONTENT_TYPES as unknown as ['image/jpeg', 'image/png', 'image/webp'])),
  byteSize: z.number().int().min(1).max(MEDIA_MAX_DECLARED_BYTES),
});
export type CreateMediaUploadInput = z.output<typeof createMediaUploadSchema>;

/** An upload id in a request body (`format: uuid`). */
export const uploadIdSchema = z.string().max(64).regex(UUID);
