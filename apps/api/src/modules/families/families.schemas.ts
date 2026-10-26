import { z } from 'zod';
import { isUuid } from '../live/live.schemas.js';
import { limitSchema } from '../posts/posts.schemas.js';

const uuid = z.string().refine(isUuid, { message: 'invalid_value', params: { issue: 'invalid_value' } });

/** `CreateFamilyRequest` (strict). The name's text rules are checked by the service. */
export const createFamilySchema = z.strictObject({
  name: z.string().max(1000),
  emblemMediaId: uuid.nullable().optional(),
  clientId: uuid,
});
export type CreateFamilyInput = z.output<typeof createFamilySchema>;

/** `UpdateFamilyRequest` (strict): the leader changes or removes the emblem. */
export const updateFamilySchema = z.strictObject({ emblemMediaId: uuid.nullable() });

/** `SetFamilyRoleRequest`. */
export const setFamilyRoleSchema = z.strictObject({ role: z.enum(['DEPUTY', 'MEMBER']) });

/** `TransferFamilyRequest`. */
export const transferFamilySchema = z.strictObject({ username: z.string().min(1).max(64) });

/** `GET /families`: `q` a name (contains, case-insensitive) or a family number (digits only). */
export const familySearchQuerySchema = z.strictObject({
  q: z.string().trim().min(1).max(40).optional(),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type FamilySearchQuery = z.output<typeof familySearchQuerySchema>;
