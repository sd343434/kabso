import { z } from 'zod';
import { localeSchema } from '../auth/auth.schemas.js';
import { COUNTRY_CODE_PATTERN } from '../countries/countries.service.js';
import { uploadIdSchema } from '../media/media.schemas.js';

/**
 * `UpdateMeRequest` (openapi v1.4): every property optional, at least one required (an empty
 * object → 400 `field ""`, `issue "required"`), unknown properties → `unknown_field`. A v1.2 body
 * (`{locale}`) stays valid.
 */
export const updateMeSchema = z
  .strictObject({
    locale: localeSchema.optional(),
    avatarUploadId: uploadIdSchema.nullable().optional(),
    country: z.string().regex(COUNTRY_CODE_PATTERN).nullable().optional(),
  })
  .refine((body) => Object.keys(body).length > 0, {
    message: 'at least one property is required',
    params: { issue: 'required' },
  });
export type UpdateMeInput = z.output<typeof updateMeSchema>;
